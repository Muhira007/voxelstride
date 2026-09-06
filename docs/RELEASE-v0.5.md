# voxelstride v0.5.0 — Kota Harmoni & Katalog Dunia

Tutup game lama lalu jalankan **Mainkan.bat** lagi. Pilih kartu **Kota Harmoni → Buka dunia**. Controller: **A** untuk buka, **LB/RB** untuk halaman, **LT/RT** untuk kategori. Launcher source tetap sama; ZIP menyediakan EXE mandiri.

- Dunia kota baru **384 × 384 × 80** dengan 40 gedung, boulevard bermarka, trotoar, zebra cross, dua taman, terminal, pertokoan, hunian, dan depot. Gedung memiliki pintu terbuka dan tangga blok hingga atap.
- **22 kendaraan**: 12 mobil, 5 bus dan 5 van. Sepuluh berkeliling pada dua rute tetap; dua belas parkir. Ada collision, roda bergerak, mengalah pada pemain/penghalang, pause, dan penyimpanan kemajuan rute.
- Katalog template layar penuh: tiga kartu per halaman, kategori, pencarian, detail lingkungan, indikator save, dan navigasi yang mengikuti jumlah template. Dunia Klasik berada di halaman kedua atau kategori Alam.
- Tujuh tekstur kota orisinal baru; total **194 bahan**. Pemandangan jauh kota juga menampilkan pola fasad sederhana.
- Save empat dunia terpisah; generator/ID lama tetap. **Y menghancurkan, X memasang.**

Validasi: 1.165 pemeriksaan otomatis, smoke test empat dunia pada source/EXE, uji launcher, dan inspeksi visual. Semua pengujian memakai save sementara, bukan file permainan pengguna. Adegan diam kota di Intel UHD Graphics 620, 1280 × 720 menunjukkan 60 FPS setelah pemuatan; perpindahan chunk tetap dapat tersendat.

Batas prototipe: kendaraan **belum dapat dikendarai** atau ditambang, lalu lintas belum memakai lampu/pencarian rute, interior gedung sederhana, belum ada NPC/ekonomi, survival atau multiplayer. Satu template masih memakai satu slot save tetap. Perangkat Xbox fisik dan sesi panjang tetap perlu diuji pengguna. Panduan: `docs/KOTA-HARMONI.md` dan `docs/TEMPLATE-DUNIA.md`.
