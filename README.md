# Dunia Minecraft

Prototipe game voxel 3D **single-player offline** untuk Windows 10/11, dengan kontrol utama **Xbox 360** dan dukungan keyboard/mouse. Dibuat menggunakan Godot 4.6.1 dan renderer Compatibility.

![Tampilan permainan Dunia Minecraft](docs/gameplay.png)

## Mainkan

1. Unduh `DuniaMinecraft-Windows-x64.zip` dari [Releases](https://github.com/Muhira007/Dunia-Minecraft/releases).
2. Ekstrak ZIP, lalu buka `DuniaMinecraft.exe`. Tidak perlu memasang Godot atau menjalankan server.
3. Pilih **Masuk ke dunia** dengan mouse atau tombol **A** pada controller.

## Jalankan langsung dari repo (Windows)

Clone atau unduh dan ekstrak repository ini, lalu klik dua kali:

- **`Mainkan.bat`**: menjalankan game langsung dari source di folder repo. Setelah kode diperbaiki, tutup game dan klik lagi untuk mencoba perubahan terbaru, tanpa build/export ulang.
- **`Debug.bat`**: menjalankan source yang sama dengan konsol error langsung. Setelah game ditutup, konsol tetap terbuka sampai Anda menekan Enter.

Jika Godot belum tersedia, launcher otomatis mengunduh editor portabel resmi (~80 MB, sekali saja), memverifikasi SHA-512, dan menaruhnya di `.tools/`. Tidak memerlukan instalasi sistem maupun export templates. Setelah itu bisa berjalan offline. Di komputer ini Godot sudah tersedia.

Log setiap sesi disimpan terpisah di **`artifacts/logs/game-<tanggal-jam>.log`**; log persiapan aset memakai awalan `import-`. Jika menemukan bug, sertakan log sesi terkait dan langkah untuk mengulang masalahnya. Folder log tidak di-push ke GitHub.

`Mainkan.cmd` juga mengarah ke launcher source yang sama. Untuk memainkan hasil export tertentu, buka `build/DuniaMinecraft.exe` secara langsung. Launcher menjalankan source lokal saat ini; untuk mengambil perbaikan dari GitHub, lakukan `git pull` terlebih dahulu.

## Fitur versi 0.2.0

- Dunia berbukit 96 × 96 blok, tinggi maksimum 40 blok, dengan pohon dan area berpasir.
- Kamera orang pertama; berjalan, berlari, melompat, dan jongkok.
- Menghancurkan dan memasang blok hingga jarak 6 blok, dengan penanda sasaran.
- **177 bahan kreatif**: batu/deepslate, 11 keluarga kayu, kuarsa, bata, beton, terakota, wol, kaca, lampu, dan logam. Lihat [katalog lengkap](docs/CATALOG.md).
- Tekstur orisinal **32 × 32 piksel** (sebelumnya 16 × 16): serat/end-grain kayu, sambungan bata, batu pahat, anyaman wol, serta variasi permukaan tiap bahan.
- Bayangan sudut antarblok (ambient occlusion), mipmap dan filter anisotropik; ikon inventori dan blok di tangan memakai tekstur sebenarnya.
- Kaca transparan yang tetap bisa ditabrak/ditargetkan; glowstone, lentera laut, dan shroomlight memancarkan cahaya lokal.
- Inventori berkategori dan berpencarian, 18 bahan per halaman, serta delapan slot hotbar yang bisa diisi ulang dan tersimpan.
- Inventori, menu jeda, pengaturan sensitivitas kamera, kembali ke titik awal, dan layar penuh.
- Save otomatis setiap 30 detik bermain, saat kehilangan fokus, dan saat keluar secara normal.
- Cadangan save sebelumnya, pemulihan jika save utama rusak, dan pesan jika penyimpanan gagal.
- Suara interaksi, getaran controller jika didukung, serta jeda otomatis ketika controller terlepas.
- Tekstur piksel dan suara dibuat lewat kode, tanpa aset Minecraft.

Ini masih prototipe kreatif: belum ada survival, crafting, mob, multiplayer, pemilihan banyak dunia, atau dunia tak terbatas. Tidak membutuhkan server maupun koneksi internet untuk bermain.

![Contoh tekstur dan material di dalam engine](docs/materials.png)

Adegan di atas adalah galeri pengujian visual, bukan bangunan yang otomatis dimasukkan ke save pemain. Semua bahan masih berupa kubus penuh; belum ada slab, tangga, pintu, cairan, atau mekanik redstone. Varian tembaga dipilih manual, bukan beroksidasi otomatis. Cahaya lokal dibatasi delapan lampu terdekat agar tetap ringan, tanpa bayangan dinamis lampu.

### Mengganti isi hotbar

Pilih slot dengan LB/RB atau 1–8, buka inventori dengan **Back / E**, lalu pilih bahan dengan **A / klik**. Bahan itu menggantikan isi slot aktif dan Anda kembali bermain. **Y tetap menghancurkan; X tetap memasang.**

Di inventori: D-pad/analog kiri atau panah untuk navigasi, **LB/RB** atau **PgUp/PgDn** untuk halaman, **LT/RT** untuk kategori, dan **B/Back/E/Esc** untuk kembali. Klik kolom pencarian untuk mengetik nama Indonesia atau Inggris; mengetik huruf E di kolom ini tidak menutup inventori.

![Inventori bahan berkategori](docs/inventory.png)

## Kontrol

| Aksi | Xbox 360 | Keyboard / mouse |
| --- | --- | --- |
| Bergerak | Analog kiri | WASD |
| Melihat | Analog kanan | Mouse |
| Lompat | A | Space |
| Jongkok (tahan) | B | Ctrl |
| Lari (tahan) | Klik analog kiri | Shift |
| Hancurkan blok | Y | Klik kiri |
| Pasang blok | X | Klik kanan |
| Pilih blok | LB/RB atau D-pad | 1–8 atau scroll |
| Inventori | Back | E |
| Menu jeda | Start | Esc |
| Simpan | — | F5 |
| Navigasi menu | D-pad / analog kiri; A pilih; B kembali | Panah / Tab / Enter / mouse |
| Layar penuh | — | F11 |

Sensitivitas kamera dapat diubah melalui menu jeda. Analog memakai deadzone agar drift kecil tidak menggerakkan kamera. Tombol B menurunkan badan saat bermain dan kembali saat berada di menu.

Controller harus dikenali Windows. Untuk Xbox 360 wireless diperlukan receiver yang sesuai. Validasi pemetaan dan navigasi menu memakai input sintetis; rasa analog, trigger, getaran, dan koneksi perangkat fisik perlu dicoba pada controller pengguna.

## Penyimpanan

Save: `%APPDATA%\DuniaMinecraft\world.json`. Cadangan: `world.json.bak`. Simpan salinan file ini untuk memindahkan dunia ke komputer lain. Save menyimpan seed, perubahan blok, posisi, arah kamera, slot pilihan, dan delapan isi hotbar. Sensitivitas kamera berlaku selama sesi berjalan.

Save v0.1 tetap terbaca: ID blok 0–9 dan generator terrain tidak diubah. Saat disimpan oleh v0.2, format naik ke versi 2. Simpan salinan sebelum mencoba kembali EXE v0.1, karena EXE lama tidak memahami format maupun blok baru.

Jika save utama rusak, game mencoba cadangan. Save rusak diarsipkan dengan akhiran `.corrupt-...` sebelum diganti. Jika kedua save tidak dapat dibaca, game membuka dunia awal dan menampilkan pemberitahuan. Uji otomatis memakai file sementara terpisah dan tidak menulis save permainan.

## Pengembangan dan build Windows

Buka `project.godot` dengan **Godot 4.6.1 Standard**. Tidak memerlukan .NET maupun plugin tambahan. Untuk bootstrap, test, export, dan paket ZIP dari PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build.ps1
```

Script mengunduh Godot portabel (~80 MB) dan export templates resmi (~1,25 GB, hanya pertama kali), memverifikasi SHA-512, menjalankan tes, lalu menghasilkan `build/DuniaMinecraft.exe` dengan PCK tertanam dan ZIP distribusi. Alat tersimpan di `.tools/`; tidak ada instalasi sistem. Setelah alat tersedia, tambahkan `-SkipSetup` untuk membangun tanpa unduhan.

Pengujian langsung:

```powershell
& .\.tools\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path . --script tests/test_core.gd
& .\.tools\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path . -- --smoke-test
& .\.tools\godot\Godot_v4.6.1-stable_win64_console.exe --path . -- --capture
```

Tes inti memeriksa 430 kondisi: seluruh 177 bahan bisa dipasang/dihancurkan, ID lama, pencarian, kaca/mesh/collision, AO, batas lampu, save v1/v2/hotbar/backup, raycast, determinisme, dan input. Smoke test memeriksa gerak, tabrakan, interaksi, serta navigasi inventori/jeda lewat input controller sintetis, termasuk halaman, trigger kategori, pencarian, dan pemasangan bahan baru. Perintah `--capture` menghasilkan empat PNG di `artifacts/`: gameplay, menu, inventori, dan galeri material. Semua mode otomatis memakai dunia terpisah tanpa membaca/menulis save pemain.

Uji tampilan awal pada Intel UHD Graphics 620, 1280 × 720: 60 FPS setelah pemuatan. Ini pengukuran pada satu adegan, bukan jaminan performa di semua perangkat atau dunia yang telah banyak diubah. Diperlukan Windows 64-bit dan driver yang mendukung OpenGL 3.3.

## Struktur

- `scripts/voxel_world.gd`: generator deterministik, data voxel, raycast grid, mesh permukaan terbuka, dan collision per chunk 16 × 16.
- `scripts/player.gd`: gerak orang pertama, analog, gravitasi, lompat, dan jongkok.
- `scripts/main.gd`: alur permainan, antarmuka, interaksi, audio, dan integrasi save.
- `scripts/blocks.gd`, `block_textures.gd`: registry dengan ID permanen, atlas 32px, material, dan ikon.
- `scripts/inventory.gd`, `hud.gd`: perpustakaan bahan, pencarian, paging, dan hotbar.
- `scripts/game_input.gd`, `save_store.gd`: pemetaan input dan penyimpanan kompatibel v1/v2.
- `scripts/material_showcase.gd`: galeri visual deterministik, hanya untuk mode `--capture`.
- `tests/test_core.gd`, `tools/build.ps1`: validasi dan build yang dapat diulang.
- `Mainkan.bat`, `Debug.bat`, `tools/run.ps1`: launcher source, bootstrap editor, dan log per sesi.

Godot menggunakan lisensi MIT; lihat `LICENSE-Godot.txt` dan `THIRD-PARTY-Godot.txt`. Referensi: [dokumentasi controller](https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html), [export Windows](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_windows.html), [material, transparansi, sRGB, dan emission](https://docs.godotengine.org/en/4.6/classes/class_basematerial3d.html).

Proyek independen; tidak berafiliasi dengan atau didukung Mojang/Microsoft. Minecraft adalah merek pemiliknya masing-masing.
