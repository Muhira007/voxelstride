# voxelstride v0.4.0 — Lembah & Air Terjun

Jalankan kembali **Mainkan.bat**, lalu pilih **Lembah & Air Terjun** di menu awal. Launcher source tidak berubah. Untuk distribusi tanpa repo, unduh dan ekstrak ZIP lalu buka EXE.

- Dunia ketiga 384 × 384 × 80: empat kali luas Desa Pertanian dan 16 kali luas Dunia Klasik.
- Desa lembah dengan 20 ternak, bukit berhutan, air terjun animasi setinggi 35 blok, suara air lokal, sungai terhubung ke danau, kebun bertingkat, pondok, menara pandang, jembatan, serta jalur ke puncak.
- Pemandangan jauh sederhana di luar chunk detail, dengan pemuatan collision dekat pemain. Save tiga dunia terpisah; generator dan ID blok lama tetap dipertahankan.
- Kontrol tetap **Y menghancurkan / X memasang**. Panduan lokasi tersedia di `docs/LEMBAH-AIR-TERJUN.md`.
- 618 pemeriksaan otomatis, smoke test tiga dunia pada source/EXE, serta uji launcher. Pengujian tidak membaca atau menulis save pemain.

Uji kamera diam setelah pemuatan pada Intel UHD Graphics 620, 1280 × 720: 60 FPS pada adegan desa dan air terjun. Ini bukan jaminan performa penjelajahan. Pembuatan chunk dapat menyebabkan jeda, terutama saat berlari.

Batas prototipe: dunia terbatas; pemandangan jauh lebih kasar dan pergantian detail terlihat; air terjun dekoratif tetap, bukan simulasi aliran/berenang; belum ada survival, pertumbuhan tanaman, feeding/breeding, atau multiplayer. Perangkat Xbox fisik dan sesi panjang masih perlu diuji pengguna.
