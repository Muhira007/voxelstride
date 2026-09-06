# Katalog bahan v0.5

194 bahan yang bisa dipasang, dibagi menjadi tujuh kategori; tab **Semua** menampilkan seluruhnya. Semuanya tersedia tak terbatas dalam mode kreatif. Nama Inggris pada key juga dapat dicari di inventori. ID 0–188 dari versi sebelumnya tidak berubah.

| Kategori | Jumlah | Isi |
| --- | ---: | --- |
| Alam | 31 | Tanah, vegetasi, pasir, salju, es, tanaman, air dekoratif |
| Batu | 27 | Batuan mentah, poles, bata, dan pahat |
| Kayu | 35 | 11 keluarga batang/papan/kupas, mosaik bambu, pagar |
| Bangunan | 25 | Bata, sandstone, kuarsa, purpur, resin, bal jerami, dan tujuh bahan kota |
| Warna | 48 | Beton, terakota, wol; masing-masing 16 warna |
| Kaca & Cahaya | 20 | Kaca bening + 16 warna; tiga lampu |
| Logam | 8 | Empat kondisi tembaga dan empat blok mineral |

## Alam

Rumput, tanah, daun oak, pasir, tanah kasar, podzol, lumpur, lempung, pasir merah, kerikil, salju, lumut, es padat, es biru; daun spruce, birch, dark oak, cherry, mangrove, jungle, acacia; blok nether wart dan warped wart.

## Batu

Batu, cobblestone, cobble berlumut, batu halus, bata batu, bata batu berlumut, bata batu retak, batu pahat; granit/diorit/andesit dan masing-masing versi poles; deepslate, cobble deepslate, deepslate poles, bata deepslate, ubin deepslate; tuff, bata tuff, kalsit, basalt, basalt halus, blackstone, blackstone poles, obsidian.

## Kayu

Oak, spruce, birch, dark oak, cherry, mangrove, jungle, acacia, bambu, crimson, dan warped. Setiap keluarga menyediakan batang, papan, dan batang kupas; bambu juga memiliki mosaik. Batang menampilkan end-grain pada sisi atas/bawah dan kulit kayu di sisi samping.

## Bangunan

Bata merah, bata lumpur, bata nether, bata nether merah; batu pasir, batu pasir potong, batu pasir halus, batu pasir pahat, batu pasir merah, pasir merah halus; kuarsa, kuarsa halus, bata kuarsa, pilar kuarsa; purpur, bata end stone, bata resin.

Tambahan kota (ID 189–195): **Aspal Jalan**, **Paving Trotoar**, **Marka Putih**, **Marka Kuning**, **Panel Jendela Biru**, **Panel Jendela Hangat**, dan **Ventilasi Atap**. Tekstur 32px orisinal menampilkan butiran aspal, sambungan paving, cat marka, kisi fasad, dan bilah ventilasi. Marka berupa satu kubus penuh; panel jendela adalah blok opak bertekstur, bukan kaca tembus pandang atau lampu.

## Warna

Beton, terakota, dan wol masing-masing tersedia dalam putih, jingga, magenta, biru muda, kuning, hijau muda, merah muda, abu gelap, abu muda, sian, ungu, biru, cokelat, hijau, merah, dan hitam. Beton berpermukaan halus, terakota bernuansa tanah, wol berpola anyaman.

## Kaca & Cahaya

Kaca bening dan kaca dalam 16 warna di atas. Glowstone, lentera laut, dan shroomlight memiliki tekstur emissive serta cahaya lokal; hanya delapan lampu terdekat dalam radius 24 blok yang mengaktifkan penerangan sekeliling. Kaca tetap memiliki collision dan bisa dihancurkan.

## Logam

Tembaga, tembaga terpapar, tembaga lapuk, tembaga teroksidasi; blok besi, emas, berlian, dan zamrud.

## Batas implementasi dan kompatibilitas

Tambahan v0.3, ID 179–188: tanah ladang (`farm_soil`), air kolam (`water`), bal jerami (`hay_bale`), labu (`pumpkin`), daun apel (`apple_leaves`), gandum (`wheat_crop`), wortel (`carrot_crop`), kentang (`potato_crop`), pagar (`oak_fence`), bunga (`meadow_flower`). Tanaman dan pagar memakai bentuk khusus; air tidak memiliki collision solid. Pertumbuhan/panen otomatis dan simulasi cairan belum tersedia.

Ini material kreatif yang terinspirasi kategori Minecraft, bukan salinan aset atau implementasi seluruh mekaniknya. Semua tekstur dibuat secara orisinal melalui kode. Daun masih kubus opak, es tidak licin, pasir tidak jatuh, tembaga tidak berubah otomatis, dan lampu tidak memakai redstone. Belum tersedia slab, stairs khusus, door interaktif, aliran cairan, atau orientasi batang horizontal. Kaca memakai alpha blending sederhana; lapisan kaca bertumpuk bisa memiliki keterbatasan pengurutan transparansi.

Generator setiap dunia terpisah; generator dunia lama tidak diubah oleh penambahan kota. ID 0 adalah udara, 1–8 adalah delapan blok awal, dan 9 adalah bedrock yang dilindungi. Bahan tambahan menggunakan ID 10–195. Jangan mengubah urutan registry yang sudah dirilis; tambahkan bahan berikutnya di bagian akhir agar save tetap kompatibel. Penyimpanan voxel saat ini memakai satu byte: batas teknis 256 ID termasuk udara/bedrock.
