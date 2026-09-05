param([switch]$SkipSetup)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$version = '4.6.1-stable'
$assetBase = "https://github.com/godotengine/godot-builds/releases/download/$version"
$engine = Join-Path $projectRoot '.tools\godot\Godot_v4.6.1-stable_win64_console.exe'

function Get-VerifiedArchive([string]$Asset, [string]$Destination) {
    if (-not (Test-Path -LiteralPath $Destination)) {
        & curl.exe -fL --retry 3 --silent --show-error "$assetBase/$Asset" -o $Destination
        if ($LASTEXITCODE -ne 0) { throw "Download gagal: $Asset" }
    }
    $entry = Get-Content -LiteralPath '.tools\SHA512-SUMS.txt' | Where-Object { $_.EndsWith($Asset) }
    if (-not $entry) { throw "Checksum tidak ditemukan: $Asset" }
    $expected = ($entry -split '\s+')[0]
    if ((Get-FileHash -LiteralPath $Destination -Algorithm SHA512).Hash -ne $expected) {
        throw "Checksum gagal: $Destination. Pindahkan arsip ini lalu coba lagi."
    }
}

function Invoke-Godot([string[]]$GodotArgs) {
    # Windows PowerShell treats native stderr as ErrorRecord. Collect the complete
    # engine report before failing, rather than interrupting the smoke-test process.
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & $engine @GodotArgs 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    $output | ForEach-Object { Write-Host $_ }
    if ($code -ne 0 -or ($output -match 'SCRIPT ERROR:|^ERROR:')) {
        throw "Godot gagal (exit $code): $GodotArgs"
    }
}

New-Item -ItemType Directory -Force -Path '.tools', 'build', 'artifacts' | Out-Null
if (-not $SkipSetup) {
    & curl.exe -fL --retry 3 --silent --show-error "$assetBase/SHA512-SUMS.txt" -o '.tools\SHA512-SUMS.txt'
    if ($LASTEXITCODE -ne 0) { throw 'Gagal mengunduh checksum resmi Godot.' }
    if (-not (Test-Path -LiteralPath $engine)) {
        Get-VerifiedArchive "Godot_v${version}_win64.exe.zip" '.tools\godot-editor.zip'
        Expand-Archive -LiteralPath '.tools\godot-editor.zip' -DestinationPath '.tools\godot' -Force
    }
    if (-not (Test-Path -LiteralPath '.tools\export\templates\windows_release_x86_64.exe')) {
        Write-Host 'Mengunduh export templates resmi (~1,25 GB, sekali saja).'
        Get-VerifiedArchive "Godot_v${version}_export_templates.tpz" '.tools\godot-templates.tpz'
        New-Item -ItemType Directory -Force -Path '.tools\export' | Out-Null
        & tar.exe -xf '.tools\godot-templates.tpz' -C '.tools\export' templates/windows_release_x86_64.exe templates/windows_debug_x86_64.exe
        if ($LASTEXITCODE -ne 0) { throw 'Ekstraksi export templates gagal.' }
    }
}
if (-not (Test-Path -LiteralPath $engine)) { throw 'Godot tidak tersedia. Jalankan tanpa -SkipSetup.' }
Invoke-Godot @('--headless', '--path', '.', '--editor', '--import', '--quit')
Invoke-Godot @('--headless', '--path', '.', '--script', 'tests/test_core.gd')
Invoke-Godot @('--headless', '--path', '.', '--script', 'tests/test_worlds.gd')
Invoke-Godot @('--headless', '--path', '.', '--script', 'tests/test_valley.gd')
Invoke-Godot @('--headless', '--path', '.', '--', '--smoke-test')
Invoke-Godot @('--headless', '--path', '.', '--export-release', 'Windows Desktop', 'build/DuniaMinecraft.exe')

$buildExe = Join-Path $projectRoot 'build\DuniaMinecraft.exe'
$smokeLog = Join-Path $projectRoot 'artifacts\export-smoke.log'
$process = Start-Process -FilePath $buildExe -WorkingDirectory (Join-Path $projectRoot 'build') -ArgumentList @('--headless', '--log-file', ('"' + $smokeLog + '"'), '--', '--smoke-test') -WindowStyle Hidden -Wait -PassThru
$code = $process.ExitCode
$output = Get-Content -LiteralPath $smokeLog
$output | ForEach-Object { Write-Host $_ }
if ($code -ne 0 -or -not ($output -match 'SMOKE PASS:') -or ($output -match 'SCRIPT ERROR:|^ERROR:')) { throw 'Pengujian EXE hasil export gagal.' }
Copy-Item -LiteralPath 'README.md', 'LICENSE-Godot.txt', 'THIRD-PARTY-Godot.txt' -Destination 'build' -Force
New-Item -ItemType Directory -Force -Path 'build\docs' | Out-Null
Copy-Item -LiteralPath 'docs\gameplay.png', 'docs\materials.png', 'docs\inventory.png', 'docs\CATALOG.md', 'docs\DESA-PERTANIAN.md', 'docs\worlds.png', 'docs\farm-overview.png', 'docs\farm-gameplay.png', 'docs\farm-animals.png', 'docs\farm-fields.png' -Destination 'build\docs' -Force
Copy-Item -LiteralPath 'docs\LEMBAH-AIR-TERJUN.md', 'docs\valley-gameplay.png', 'docs\valley-waterfall.png', 'docs\valley-overview.png', 'docs\valley-terraces.png', 'docs\valley-lake.png', 'docs\valley-tower.png' -Destination 'build\docs' -Force
Compress-Archive -LiteralPath $buildExe, 'build\README.md', 'build\LICENSE-Godot.txt', 'build\THIRD-PARTY-Godot.txt', 'build\docs' -DestinationPath 'build\DuniaMinecraft-Windows-x64.zip' -Force
Write-Host "Build selesai: $buildExe"
Get-FileHash -LiteralPath $buildExe -Algorithm SHA256 | Format-List
