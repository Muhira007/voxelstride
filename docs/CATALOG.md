# Katalog bahan v0.2

177 bahan yang bisa dipasang, dibagi menjadi tujuh kategori; tab **Semua** menampilkan seluruhnya. Semuanya tersedia tak terbatas dalam mode kreatif. Nama Inggris pada key juga dapat dicari di inventori.

| Kategori | Jumlah | Isi |
| --- | ---: | --- |
| Alam | 23 | Tanah, vegetasi, pasir, salju, es |
| Batu | 27 | Batuan mentah, poles, bata, dan pahat |
| Kayu | 34 | 11 keluarga batang/papan/kupas, serta mosaik bambu |
| Bangunan | 17 | Bata, sandstone, kuarsa, purpur, resin |
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

## Warna

Beton, terakota, dan wol masing-masing tersedia dalam putih, jingga, magenta, biru muda, kuning, hijau muda, merah muda, abu gelap, abu muda, sian, ungu, biru, cokelat, hijau, merah, dan hitam. Beton berpermukaan halus, terakota bernuansa tanah, wol berpola anyaman.

## Kaca & Cahaya

Kaca bening dan kaca dalam 16 warna di atas. Glowstone, lentera laut, dan shroomlight memiliki tekstur emissive serta cahaya lokal; hanya delapan lampu terdekat dalam radius 24 blok yang mengaktifkan penerangan sekeliling. Kaca tetap memiliki collision dan bisa dihancurkan.

## Logam

Tembaga, tembaga terpapar, tembaga lapuk, tembaga teroksidasi; blok besi, emas, berlian, dan zamrud.

## Batas implementasi dan kompatibilitas

Ini material kreatif yang terinspirasi kategori Minecraft, bukan salinan aset atau implementasi seluruh mekaniknya. Semua tekstur dibuat secara orisinal melalui kode. Daun masih kubus opak, es tidak licin, pasir tidak jatuh, tembaga tidak berubah otomatis, dan lampu tidak memakai redstone. Belum tersedia slab, stairs, door, cairan, atau orientasi batang horizontal. Kaca memakai alpha blending sederhana; lapisan kaca bertumpuk bisa memiliki keterbatasan pengurutan transparansi.

Generator dunia tidak berubah; bahan tambahan dipilih melalui inventori, bukan otomatis mengganti terrain/bangunan lama. ID 0 adalah udara, 1–8 adalah delapan blok awal, dan 9 adalah bedrock yang dilindungi. Bahan baru menggunakan ID 10–178. Jangan mengubah urutan registry yang sudah dirilis; tambahkan bahan berikutnya di bagian akhir agar save tetap kompatibel. Penyimpanan voxel saat ini memakai satu byte: batas teknis 256 ID termasuk udara/bedrock.
