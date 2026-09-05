param(
    [switch]$DebugMode,
    [switch]$SmokeTest
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolDirectory = Join-Path $projectRoot '.tools'
$engine = Join-Path $toolDirectory 'godot\Godot_v4.6.1-stable_win64.exe'
$consoleEngine = Join-Path $toolDirectory 'godot\Godot_v4.6.1-stable_win64_console.exe'
$asset = 'Godot_v4.6.1-stable_win64.exe.zip'
$assetBase = 'https://github.com/godotengine/godot-builds/releases/download/4.6.1-stable'
$exitCode = 0

function Get-Editor {
    if ((Test-Path -LiteralPath $engine) -and (Test-Path -LiteralPath $consoleEngine)) { return }

    Write-Host 'Menyiapkan Godot portabel (~80 MB, hanya pertama kali)...'
    New-Item -ItemType Directory -Force -Path $toolDirectory | Out-Null
    $checksums = Join-Path $toolDirectory 'SHA512-SUMS.txt'
    $archive = Join-Path $toolDirectory 'godot-editor.zip'
    & curl.exe -fL --retry 3 --silent --show-error "$assetBase/SHA512-SUMS.txt" -o $checksums
    if ($LASTEXITCODE -ne 0) { throw 'Gagal mengunduh checksum Godot. Periksa koneksi internet lalu coba lagi.' }
    if (-not (Test-Path -LiteralPath $archive)) {
        $partial = "$archive.partial"
        & curl.exe -fL --retry 3 --silent --show-error "$assetBase/$asset" -o $partial
        if ($LASTEXITCODE -ne 0) { throw 'Unduhan Godot belum selesai. Periksa koneksi internet lalu coba lagi.' }
        Move-Item -LiteralPath $partial -Destination $archive -Force
    }
    $entry = Get-Content -LiteralPath $checksums | Where-Object { $_.EndsWith($asset) }
    if (-not $entry) { throw 'Checksum resmi Godot tidak ditemukan.' }
    $expected = ($entry -split '\s+')[0]
    $sha512 = [System.Security.Cryptography.SHA512]::Create()
    $stream = [System.IO.File]::OpenRead($archive)
    try {
        $actual = [BitConverter]::ToString($sha512.ComputeHash($stream)).Replace('-', '')
    } finally {
        $stream.Dispose()
        $sha512.Dispose()
    }
    if ($actual -ne $expected) {
        throw "Checksum Godot tidak cocok. Pindahkan file $archive lalu jalankan kembali."
    }
    # Use built-in .NET APIs so bootstrap also works in plain Windows PowerShell.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $engine) | Out-Null
    $zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
    try {
        foreach ($executable in @($engine, $consoleEngine)) {
            $item = $zip.GetEntry([System.IO.Path]::GetFileName($executable))
            if ($null -eq $item) { throw 'Arsip Godot tidak berisi executable yang diharapkan.' }
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($item, $executable, $true)
        }
    } finally {
        $zip.Dispose()
    }
    if (-not (Test-Path -LiteralPath $consoleEngine)) { throw 'Ekstraksi Godot gagal. Jalankan launcher kembali.' }
}

try {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'project.godot'))) {
        throw 'project.godot tidak ditemukan. Ekstrak atau clone seluruh repository terlebih dahulu.'
    }
    Get-Editor
    $logDirectory = Join-Path $projectRoot 'artifacts\logs'
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    $session = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $importLog = Join-Path $logDirectory "import-$session.log"
    $gameLog = Join-Path $logDirectory "game-$session.log"
    Write-Host "Source : $projectRoot"
    Write-Host "Log    : $gameLog"
    Write-Host 'Menyiapkan perubahan source dan aset...'

    # Import first so a freshly cloned repo and newly added assets both work.
    $importArgs = @('--headless', '--path', ('"' + $projectRoot + '"'), '--editor', '--import', '--quit', '--log-file', ('"' + $importLog + '"'))
    $import = Start-Process -FilePath $engine -WorkingDirectory $projectRoot -ArgumentList $importArgs -WindowStyle Hidden -Wait -PassThru
    if ($import.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $importLog)) {
        throw "Persiapan game gagal. Periksa $importLog"
    }
    if (Select-String -LiteralPath $importLog -Pattern '^ERROR:|SCRIPT ERROR:' -Quiet) {
        Get-Content -LiteralPath $importLog | ForEach-Object { Write-Host $_ }
        throw "Ada error saat membaca source. Periksa $importLog"
    }

    $gameArgs = @('--path', $projectRoot, '--log-file', $gameLog)
    if ($DebugMode) { $gameArgs += '--verbose' }
    if ($SmokeTest) { $gameArgs += @('--headless', '--', '--smoke-test') }
    Write-Host 'Menjalankan game dari source terbaru...'
    if ($DebugMode) {
        # Stream live errors in the console; Godot also writes the session log.
        & $consoleEngine @gameArgs
        $exitCode = $LASTEXITCODE
    } else {
        $quotedArgs = $gameArgs | ForEach-Object { '"' + $_ + '"' }
        $windowStyle = if ($SmokeTest) { 'Hidden' } else { 'Normal' }
        $game = Start-Process -FilePath $engine -WorkingDirectory $projectRoot -ArgumentList $quotedArgs -WindowStyle $windowStyle -Wait -PassThru
        $exitCode = $game.ExitCode
    }
    if (-not (Test-Path -LiteralPath $gameLog)) { throw 'Game tidak menghasilkan log. Godot mungkin gagal dijalankan.' }
    if (Select-String -LiteralPath $gameLog -Pattern '^ERROR:|SCRIPT ERROR:' -Quiet) {
        $exitCode = 1
        Write-Host "Game mencatat error. Periksa $gameLog" -ForegroundColor Red
    }
    if ($SmokeTest -and -not (Select-String -LiteralPath $gameLog -Pattern 'SMOKE PASS:' -Quiet)) {
        throw "Uji launcher gagal. Periksa $gameLog"
    }
    if ($exitCode -ne 0) { throw "Game berhenti dengan error $exitCode. Periksa $gameLog" }
    Write-Host "Game ditutup. Log tersimpan: $gameLog"
    if ($DebugMode -and -not $SmokeTest) { Read-Host 'Tekan Enter untuk menutup jendela debug' | Out-Null }
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    $exitCode = 1
}
exit $exitCode
