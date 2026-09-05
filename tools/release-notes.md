Desa Pertanian & Pilihan Dunia — voxelstride 0.3.0 untuk Windows 10/11 64-bit.

Unduh **voxelstride-Windows-x64.zip**, ekstrak, lalu buka **voxelstride.exe**. Tidak perlu Godot, server, atau internet saat bermain.

- **Pilihan dunia**: Dunia Klasik 96 × 96 dan Desa Pertanian **192 × 192**, tepat 4× luasnya, dengan save terpisah.
- Desa berisi **6 rumah**, sumur, dua kios, lumbung, gudang, kincir dekoratif, empat ladang beririgasi, kebun apel, kolam/jembatan, dan jalan pedesaan.
- **20 ternak hidup**: 5 sapi, 5 domba, 4 babi, 6 ayam; berjalan/diam, collision, animasi kaki, batas kandang, serta posisi tersimpan.
- **187 bahan kreatif** termasuk tanaman berbentuk khusus, pagar, tanah ladang, jerami, labu, daun apel, dan air dekoratif. Tekstur 32px dan inventori berkategori/pencarian tetap tersedia.
- Pemuatan chunk bertahap dan AI hewan berdasarkan jarak. Menu jeda menghentikan ternak.
- Save v0.1/v0.2 dapat dilanjutkan sebagai Dunia Klasik. Sebelum save klasik lama dibuka, salinan satu kali `world.json.pre-v0.3.bak` dibuat. Save baru berformat v3 dan tidak kompatibel dengan EXE versi lama.
- Kontrol Xbox 360: **Y menghancurkan blok**, **X memasang blok**, dan **Back membuka inventori**; keyboard/mouse, menu jeda, serta save otomatis dan cadangan tetap tersedia.

Tetap bisa dimainkan dari repo dengan **Mainkan.bat**. Pilih dunia pada menu awal; saat bermain, gunakan **Start/Esc → Simpan & pilih dunia**. Kegagalan save membatalkan perpindahan. File desa berada di `%APPDATA%\voxelstride\worlds\desa-pertanian.json`; dunia lama tetap `world.json`.

Validasi: **450 pemeriksaan inti + 95 pemeriksaan dunia**, smoke test source dan EXE, termasuk save terpisah, world switching, gerak/jeda/pemulihan ternak, serta proteksi ketika save gagal. Uji adegan awal Intel UHD Graphics 620, 1280 × 720, sekitar 59–60 FPS. Ini bukan jaminan performa ketika melintasi chunk atau setelah banyak perubahan; controller fisik masih perlu dicoba pengguna.

Batas versi pertama: belum ada panen/pertumbuhan tanaman, memberi makan, breeding, perdagangan, kincir bergerak, simulasi aliran air, survival, crafting, multiplayer, atau slot dunia bebas. Hewan tetap dibatasi kandang asal. Pemuatan area dapat menyebabkan jeda singkat; batas render bisa terlihat dari ketinggian. Panduan lengkap tersedia di README dan `docs/DESA-PERTANIAN.md` dalam ZIP.

Proyek independen, tidak berafiliasi dengan Mojang/Microsoft.
