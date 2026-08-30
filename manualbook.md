# 📘 BUKU PANDUAN PENGGUNAAN APLIKASI MOBILE EPIC
### (Eco-Cultural Pattern Integrated Canvas)
**Panduan Lengkap Operasional, Fitur, Menu, Tombol, dan Alur Kerja Aplikasi untuk Murid & Guru**

---

## 📑 DAFTAR ISI

1. [BAB 1: ALUR AWAL, LOGIN, & SETUP PROFIL](#bab-1-alur-awal-login--setup-profil)
   - 1.1 Layar Pembuka (*Splash Screen*)
   - 1.2 Layar Orientasi (*Onboarding Screen*)
   - 1.3 Layar Masuk Akun (*Auth / Login Screen*)
   - 1.4 Layar Lengkapi Profil (*Profile Setup Screen* — Murid & Guru)
   - 1.5 Layar Menunggu Verifikasi Guru (*Guru Pending Screen*)
   - 1.6 Layar Penolakan Verifikasi Guru (*Guru Rejected Screen*)
   - 1.7 Layar Penangguhan Akun (*Suspended Screen*)
2. [BAB 2: PANDUAN LENGKAP PENGGUNA — PERAN MURID (STUDENT)](#bab-2-panduan-lengkap-pengguna--peran-murid-student)
   - 2.1 Navigasi Utama Murid (*Bottom Navigation Bar 5 Tab*)
   - 2.2 Tab 1: Beranda (*Home Tab*)
   - 2.3 Pusat Pilihan Game (*Games Tab*)
   - 2.4 Pusat Kategori Menggambar (*Menggambar Screen*)
   - 2.5 Layar Pemilihan Level (*Level Select Screen*)
   - 2.6 Studio Game Menggambar: **Kategori Keris Madura**
   - 2.7 Studio Game Menggambar: **Kategori Batik Madura**
   - 2.8 Studio Game Anyaman: **Kategori Anyaman Grid Madura**
   - 2.9 Layar Hasil & Penilaian Juri AI (*Drawing Result Screen*)
   - 2.10 Tab 2: Papan Peringkat (*Ranking Screen*)
   - 2.11 Tab 3: Galeri Karya Saya (*Galeri Tab & Detail Karya Screen*)
   - 2.12 Tab 4: Toko Avatar & Koleksi Karakter (*Karakter Tab*)
   - 2.13 Fitur Bergabung ke Kelas Guru (*Gabung Kelas & Scan QR*)
3. [BAB 3: PANDUAN LENGKAP PENGGUNA — PERAN GURU (TEACHER)](#bab-3-panduan-lengkap-pengguna--peran-guru-teacher)
   - 3.1 Navigasi Utama Guru (*Bottom Navigation Bar 4 Tab*)
   - 3.2 Tab 1: Beranda Guru (*Guru Home Tab*)
   - 3.3 Tab 2: Manajemen Kelas (*Guru Dashboard Screen*)
   - 3.4 Layar Buat Kelas Baru (*Buat Kelas Screen*)
   - 3.5 Pusat Kendali Kelas Guru (*Kelas Detail Guru Screen* — 4 Sub-Tab)
     - 3.5.1 Sub-Tab Murid (Daftar Siswa, Detail, & Keluarkan Murid)
     - 3.5.2 Sub-Tab Karya & Penilaian Manual Guru (Review Audio & Asesmen Rubrik)
     - 3.5.3 Sub-Tab Ranking (Leaderboard Internal Kelas)
     - 3.5.4 Sub-Tab Info & Pengaturan Kelas (QR Code, Ekspor Excel/PDF, Arsipkan, & Nonaktifkan)
   - 3.6 Tab 3: Direktori Seluruh Murid (*Guru Murid Tab & Profil Murid Screen*)
4. [BAB 4: PUSAT PENGATURAN & KEAMANAN AKUN (GURU & MURID)](#bab-4-pusat-pengaturan--keamanan-akun-guru--murid)
   - 4.1 Layar Profil (*Profile Screen*)
   - 4.2 Ubah Data Pribadi (*Edit Profile Screen*)
   - 4.3 Ubah Data Sekolah & Domisili (*Edit School Screen*)
   - 4.4 Pengaturan Suara & Musik (*Game Settings Screen*)
   - 4.5 Pusat Keamanan Akun Guru (*Keamanan Akun Screen*)
   - 4.6 Pengelolaan Kelas Nonaktif (*Guru Inactive Classes Screen*)
   - 4.7 Dialog Tentang EPIC & Keluar Akun (*Logout*)
5. [BAB 5: PANDUAN PEMECAHAN MASALAH (TROUBLESHOOTING & FAQ)](#bab-5-panduan-pemecahan-masalah-troubleshooting--faq)

---

# BAB 1: ALUR AWAL, LOGIN, & SETUP PROFIL

---

## 1.1 Layar Pembuka (*Splash Screen*)

### Gambaran Layar (Screen Wireframe):
```
+-------------------------------------------------------------+
|                                                             |
|                                                             |
|                        [ LOGO EPIC ]                        |
|                                                             |
|             Belajar Budaya, Jadi Juara!                     |
|                                                             |
|                                                             |
|                   [==========           ]                   |
|                      (Pemuatan Sesi)                        |
+-------------------------------------------------------------+
```

### Panduan & Fungsi Tombol/Alur:
- **Tujuan**: Memeriksa sesi login secara otomatis saat aplikasi dibuka.
- **Alur Sistem**:
  1. Jika pengguna **belum pernah login** $\rightarrow$ Otomatis diarahkan ke **Layar Onboarding**.
  2. Jika pengguna **sudah login tapi profil belum lengkap** $\rightarrow$ Diarahkan ke **Layar Setup Profil**.
  3. Jika pengguna **adalah Guru dengan status verifikasi pending** $\rightarrow$ Diarahkan ke **Layar Guru Pending**.
  4. Jika akun **ditangguhkan** $\rightarrow$ Diarahkan ke **Layar Suspended**.
  5. Jika pengguna **sudah lengkap dan aktif** $\rightarrow$ Langsung masuk ke **Beranda (Home)**.

---

## 1.2 Layar Orientasi (*Onboarding Screen*)

### Gambaran Layar (Screen Wireframe):
```
+-------------------------------------------------------------+
|                                            [ Lewati > ]     |
|                                                             |
|                   [ ILUSTRASI VISUAL SLIDE ]                |
|                                                             |
|                  Belajar Matematika & Budaya                |
|           Eksplorasi konsep geometri lewat seni             |
|                  tradisional khas Madura.                   |
|                                                             |
|                          ( o  .  . )                        |
|                                                             |
|                   [     L A N J U T     ]                   |
+-------------------------------------------------------------+
```

### Panduan & Fungsi Tombol:
1. **Tombol "Lewati >" (Pojok Kanan Atas)**:
   - **Fungsi**: Melewati seluruh slide penjelasan dan langsung membuka Layar Login (*Auth Screen*).
2. **Slide Interaktif (Geser Kiri/Kanan)**:
   - **Slide 1**: Penjelasan konsep geometri dan etnomatematika.
   - **Slide 2**: Penjelasan media budaya (Batik, Keris, Anyaman).
   - **Slide 3**: Penjelasan fitur evaluasi otomatis oleh Juri AI.
3. **Indikator Titik `( o . . )`**: Menunjukkan urutan slide aktif (1, 2, atau 3).
4. **Tombol "LANJUT" / "MULAI SEKARANG"**:
   - Pada Slide 1 & 2: Berfungsi untuk berpindah ke slide berikutnya.
   - Pada Slide 3: Berubah menjadi **"MULAI SEKARANG"** untuk masuk ke Layar Login.

---

## 1.3 Layar Masuk Akun (*Auth / Login Screen*)

### Gambaran Layar (Screen Wireframe):
```
+-------------------------------------------------------------+
|                                                             |
|                        [ LOGO EPIC ]                        |
|                 Belajar Budaya, Jadi Juara!                 |
|                                                             |
|                    Selamat Datang di EPIC!                  |
|          Masuk untuk mulai petualangan seru belajar         |
|               matematika & budaya Madura.                   |
|                                                             |
|         +-----------------------------------------+         |
|         |  [G]  Masuk dengan Google               |         |
|         +-----------------------------------------+         |
|                                                             |
|         🛡️ Daftar otomatis saat pertama kali login          |
+-------------------------------------------------------------+
```

### Panduan & Fungsi Tombol:
1. **Tombol "Masuk dengan Google"**:
   - **Cara Menggunakan**: Sentuh tombol putih berlogo Google.
   - **Hasil**: Sistem akan menampilkan jendela pemilih akun Google (*Google Account Picker*). Pilih akun email Google Anda.
   - **Proses**: Aplikasi melakukan proses login satu pintu (*Single Sign-On*). Jika login pertama kali, akun baru otomatis terdaftar.

---

## 1.4 Layar Lengkapi Profil (*Profile Setup Screen*)

Layar ini wajib diisi oleh setiap pengguna baru setelah login Google berhasil.

### Gambaran Layar (Screen Wireframe):
```
+-------------------------------------------------------------+
|                      [ Foto Avatar Google ]                 |
|                       Lengkapi Profilmu!                    |
|                                                             |
| Nama Lengkap *                                              |
| [ 👤 Masukkan nama lengkap...                             ] |
|                                                             |
| Username *                                                  |
| [ @ contoh: rizky_cool                      (✓ Tersedia)  ] |
|                                                             |
| Nama Sekolah *                                              |
| [ 🏫 Contoh: SDN 1 Bangkalan                              ] |
|                                                             |
| Saya adalah *                                               |
| +-------------------------+     +-------------------------+ |
| | [👦] Murid (Terpilih)   |     | [👨‍🏫] Guru              | |
| +-------------------------+     +-------------------------+ |
|                                                             |
| --- JIKA MEMILIH MURID ---                                  |
| Kelas: [ Pilih Kelas (1 SD - 6 SD)                      v ] |
| Provinsi: [ Jawa Timur                                    ] |
| Kabupaten/Kota: [ Bangkalan                               ] |
| Kecamatan: [ Socah                                        ] |
|                                                             |
| --- JIKA MEMILIH GURU ---                                   |
| Upload Bukti Mengajar * (SK Guru / GTK)                     |
| +---------------------------------------------------------+ |
| | [☁️] Tap untuk upload bukti (JPG/PNG, Maks 5MB)         | |
| +---------------------------------------------------------+ |
| Mata Pelajaran: [ Matematika                              ] |
|                                                             |
|                [ S I M P A N  &  M U L A I ! ]              |
+-------------------------------------------------------------+
```

### Panduan Pengisian Kolom & Tombol:
1. **Kolom "Nama Lengkap" (\*)**: Ketik nama lengkap Anda (wajib diisi).
2. **Kolom "Username" (\*)**:
   - Ketik username tanpa spasi (hanya huruf, angka, underscore).
   - **Indikator Otomatis**:
     - Ikon Loading: Sistem sedang mengecek ketersediaan ke database.
     - Ikon Centang Hijau `(✓)`: Username tersedia.
     - Ikon Silang Merah `(X)`: Username sudah dipakai orang lain, ganti dengan yang lain.
3. **Kolom "Nama Sekolah" (\*)**: Ketik nama sekolah/madrasah Anda.
4. **Pilihan Peran ("Saya adalah")**:
   - **Pilih "Murid"**: Jika Anda adalah siswa sekolah dasar.
   - **Pilih "Guru"**: Jika Anda adalah guru pengajar.
5. **Form Khusus Murid**:
   - **Dropdown Kelas**: Pilih tingkat kelas (1 SD s.d 6 SD).
   - **Provinsi, Kabupaten, Kecamatan**: Ketik domisili wilayah sekolah Anda.
6. **Form Khusus Guru**:
   - **Upload Bukti Mengajar (\*)**: Ketuk area unggah untuk memilih foto berkas SK Guru/Surat Tugas/Kartu GTK (format JPG/PNG, maksimal 5 MB). Setelah dipilih, foto akan muncul sebagai pratinjau dengan tombol **"Ganti"** dan **"Hapus"**.
   - **Mata Pelajaran**: Ketik mata pelajaran yang diampu.
7. **Tombol "Simpan & Mulai!"**:
   - Jika memilih Murid $\rightarrow$ Langsung masuk ke Beranda Murid.
   - Jika memilih Guru $\rightarrow$ Berkas dikirim ke Admin dan diarahkan ke Layar Menunggu Verifikasi.

---

## 1.5 Layar Menunggu Verifikasi Guru (*Guru Pending Screen*)

### Gambaran Layar (Screen Wireframe):
```
+-------------------------------------------------------------+
|                                                             |
|                         [ ⏳ Jam Pasir ]                    |
|                  Akun Guru Sedang Diverifikasi              |
|                                                             |
|  Halo, Bpk/Ibu Guru! Bukti mengajarmu sedang diproses oleh  |
|                     tim Administrator EPIC.                 |
|                                                             |
|  +-------------------------------------------------------+  |
|  |  📋 DETAIL PENGAJUAN                                  |  |
|  |  Nama    : Budi Santoso, S.Pd.                        |  |
|  |  Sekolah : SDN 1 Bangkalan                            |  |
|  |  Dikirim : 27 Agustus 2026                            |  |
|  |  Status  : ⏳ Menunggu Verifikasi (Est. 1x24 Jam)     |  |
|  +-------------------------------------------------------+  |
|                                                             |
|               [ 🔄  R E F R E S H   S T A T U S ]           |
|                                                             |
|               [ ✉️  H U B U N G I   A D M I N ]             |
|                                                             |
|                    [ 🚪 Keluar Akun ]                       |
+-------------------------------------------------------------+
```

### Panduan & Fungsi Tombol:
1. **Sistem Auto-Redirect**: Saat Admin menyetujui akun Anda dari dashboard admin, layar ini akan otomatis beralih ke Beranda Guru tanpa perlu login ulang.
2. **Tombol "Refresh Status"**: Menghubungi server secara manual untuk memeriksa apakah akun Anda sudah disetujui.
3. **Tombol "Hubungi Admin"**: Membuka email ke `ecoculturalpattern@gmail.com` jika membutuhkan bantuan verifikasi cepat.
4. **Tombol "Keluar Akun"**: Keluar dari akun.

---

## 1.6 Layar Penolakan Verifikasi Guru (*Guru Rejected Screen*)

### Gambaran Layar (Screen Wireframe):
```
+-------------------------------------------------------------+
|                                                             |
|                         [ ❌ Tanda Silang ]                 |
|                         Verifikasi Ditolak                  |
|                                                             |
|  +-------------------------------------------------------+  |
|  |  ℹ️ ALASAN PENOLAKAN DARI ADMIN:                       |  |
|  |  "Foto SK mengajar buram dan tidak terbaca jelas.      |  |
|  |   Silakan upload ulang dengan dokumen asli yang jelas"|  |
|  +-------------------------------------------------------+  |
|                                                             |
|               [ 📤  U P L O A D   B U K T I   B A R U ]     |
|                                                             |
|                    [ 🚪 Keluar Akun ]                       |
+-------------------------------------------------------------+
```

### Panduan & Fungsi Tombol:
1. **Membaca Alasan Penolakan**: Perhatikan catatan yang diberikan oleh Admin pada kotak merah.
2. **Tombol "Upload Bukti Baru"**: Membuka kembali formulir profil agar Anda dapat mengunggah foto dokumen yang baru dan jelas.
3. **Tombol "Keluar Akun"**: Logout dari akun.

---

## 1.7 Layar Penangguhan Akun (*Suspended Screen*)

### Gambaran Layar (Screen Wireframe):
```
+-------------------------------------------------------------+
|                                                             |
|                        [ 🔒 Ikon Gembok ]                    |
|                     Akses Akun Ditangguhkan                 |
|                                                             |
|  Akun Anda ditangguhkan oleh Administrator karena melanggar |
|            pedoman komunitas atau aktivitas mencurigakan.   |
|                                                             |
|        [ 🎧  H U B U N G I   D U K U N G A N / B A N D I N G ] |
|                                                             |
|                    [ 🚪 Keluar Akun ]                       |
+-------------------------------------------------------------+
```

### Panduan & Fungsi Tombol:
1. **Tombol "Hubungi Dukungan / Banding"**: Membuka aplikasi email dengan draf pengajuan banding resmi ke tim support EPIC.
2. **Tombol "Keluar Akun"**: Keluar dari aplikasi.

---

# BAB 2: PANDUAN LENGKAP PENGGUNA — PERAN MURID (STUDENT)

---

## 2.1 Navigasi Utama Murid (*Bottom Navigation Bar*)
Di bagian bawah layar murid, terdapat bilah navigasi dengan 5 menu:
```
+-------------------------------------------------------------+
|  [ 🏠 Home ]  [ 🏆 Ranking ]  [ 🖼️ Galeri ]  [ 🎭 Avatar ]  [ 👤 Profil ] |
+-------------------------------------------------------------+
```
- **Home**: Beranda aktivitas, misi harian, draf gambar, dan tombol mulai bermain.
- **Ranking**: Peringkat nilai murid (Global & Ruang Kelas).
- **Galeri**: Katalog seluruh karya seni yang pernah dibuat murid.
- **Avatar**: Toko karakter untuk menukar poin dengan kostum/maskot baru.
- **Profil**: Pengaturan akun, data sekolah, dan pengaturan suara game.

---

## 2.2 Tab 1: Beranda (*Home Tab*)

### Gambaran Layar (Screen Wireframe):
```
+-------------------------------------------------------------+
| [Avatar] Ahmad Rizky (SDN 1)          [ ⭐ 1.4k ]  [ ❤️ 5 ]   |
+-------------------------------------------------------------+
|                                                             |
|                      [ Panggung Budaya ]                    |
|                     (Maskot Ksatria Madura)                 |
|                                                             |
|                ===============================              |
|                ▶   M U L A I   B E R M A I N                |
|                ===============================              |
|                                                             |
+-------------------------------------------------------------+
| 🏫 Belum Gabung Kelas? [ Gabung Kelas Gurumu Sekarang > ]   |
|                                                             |
| 🎯 MISI HARIAN                              [ 1/3 Selesai ] |
| +---------------------------------------------------------+ |
| | ⭐ Gambar 1 Motif Keris               [ Klaim +50 Poin ]| |
| | ⏳ Mainkan Game Anyaman Level 1       (Progres: 0/1)    | |
| | ⏳ Selesaikan Karya dengan Nilai > 80 (Progres: 0/1)    | |
| +---------------------------------------------------------+ |
|                                                             |
| 💾 LANJUTKAN DRAF GAMBAR                                    |
| +----------------------+  +----------------------+          |
| | 🗡️ Keris Madura      |  | 🧺 Anyaman           |          |
| | Level 2              |  | Level 1              |          |
| | Sisa Waktu: 07:35    |  | Sisa Waktu: 04:12    |          |
| | [ ▶ Lanjutkan ]      |  | [ ▶ Lanjutkan ]      |          |
| +----------------------+  +----------------------+          |
+-------------------------------------------------------------+
```

### Panduan Penggunaan Menu & Tombol:
1. **Header Poin `[ ⭐ 1.4k ]`**: Menampilkan total saldo poin bintang yang dimiliki murid.
2. **Header Nyawa `[ ❤️ 5 ]`**: Menampilkan sisa nyawa bermain hari ini (Maksimal 5 nyawa per hari). Setiap kali masuk game, 1 nyawa berkurang. Nyawa reset penuh otomatis setiap jam 00:00 malam.
3. **Tombol Besar "MULAI BERMAIN"**:
   - **Cara Pakai**: Tekan tombol oranye ini di tengah layar.
   - **Hasil**: Membuka Pusat Pilihan Game (*Games Tab*).
4. **Banner "Belum Gabung Kelas?"**:
   - Muncul jika murid belum terdaftar di kelas guru manapun.
   - Ketuk banner ini untuk langsung membuka layar **Gabung Kelas**.
5. **Daftar Misi Harian (*Daily Missions*)**:
   - Menampilkan 3 target misi harian.
   - Jika misi selesai, tombol **"Klaim +xx Poin"** akan menyala. Tekan tombol untuk mengambil hadiah poin ke saldo Anda.
6. **Daftar Draf Tersimpan (*Lanjutkan*)**:
   - Menampilkan gambar/anyaman yang belum selesai dikerjakan sebelumnya.
   - Tekan tombol **"Lanjutkan"** pada kartu untuk melanjutkan pembuatan karya tepat di kondisi terakhir beserta sisa waktu yang ada.

---

## 2.3 Pusat Pilihan Game (*Games Tab*)

### Gambaran Layar (Screen Wireframe):
```
+-------------------------------------------------------------+
| Pilih Game                                                  |
| Yuk, main dan kumpulkan Poin!                               |
|                                                             |
| +---------------------------------------------------------+ |
| | [🎨] Menggambar Keris & Batik                           | |
| |      Gambar keris, batik, atau anyaman.                 | |
| |      ⭐ 3 Kategori  •  4 Level               [ > ]      | |
| +---------------------------------------------------------+ |
|                                                             |
| +---------------------------------------------------------+ |
| | [🎮] Game Etnomatematika Tambahan                       | |
| |      Tantangan matematika budaya lanjutan.  [ > ]      | |
| +---------------------------------------------------------+ |
+-------------------------------------------------------------+
```

### Panduan Penggunaan:
- Ketuk kartu **"Menggambar"** untuk masuk ke menu pemilihan media seni budaya (Keris, Batik, Anyaman).

---

## 2.4 Pusat Kategori Menggambar (*Menggambar Screen*)

### Gambaran Layar (Screen Wireframe):
```
+-------------------------------------------------------------+
| [ < ] Game Menggambar                             [STUDIO]  |
|                                                             |
| Pilih Kategori                                              |
| Pilih media untuk mahakarya Anda:                           |
|                                                             |
| +---------------------------------------------------------+ |
| | [🗡️] Keris Madura                                        | |
| |      Gambar gagang, bilah, dan wadah keris.             | |
| |      Progres: [===         ] 1/4 Level Selesai    [ > ] | |
| +---------------------------------------------------------+ |
|                                                             |
| +---------------------------------------------------------+ |
| | [🌺] Batik Madura                                        | |
| |      Rancang motif batik tradisional simetris.          | |
| |      Progres: [======      ] 2/4 Level Selesai    [ > ] | |
| +---------------------------------------------------------+ |
|                                                             |
| +---------------------------------------------------------+ |
| | [🧺] Anyaman Madura                                      | |
| |      Ciptakan pola anyaman kisi bambu tradisional.      | |
| |      Progres: [============] 4/4 Level Selesai    [ > ] | |
| +---------------------------------------------------------+ |
+-------------------------------------------------------------+
```

### Panduan Pemilihan Kategori:
1. **Kategori Keris Madura**: Fokus pada konsep geometri sudut, bangun datar warangka (trapesium/segitiga), dan lekukan bilah (*luk*).
2. **Kategori Batik Madura**: Fokus pada ornamen simetri cermin (*mirror symmetry*), pola rotasi, dan pengulangan bangun datar.
3. **Kategori Anyaman Madura**: Fokus pada matriks kotak (*grid*), kombinasi warna baris-kolom, dan simetri sel anyam.

---

## 2.5 Layar Pemilihan Level (*Level Select Screen*)

### Gambaran Layar (Screen Wireframe):
```
+-------------------------------------------------------------+
| [ < ] Level Keris Madura                       ⭐ Total: 6  |
|                                                             |
|       < Geser Kartu Horizontal >                            |
|       +---------------------------------------------+       |
|       |                 LEVEL 2                     |       |
|       |            [ Gambar Bilah Keris ]           |       |
|       |                                             |       |
|       | ⭐⭐⭐ Nilai Tertinggi: 92                   |       |
|       | ⏱️ Waktu: 10 Menit                           |       |
|       | Target: Gambar luk bilah simetris           |       |
|       |                                             |       |
|       |            [ ▶  M A I N K A N ]             |       |
|       +---------------------------------------------+       |
|                                                             |
|       ( .  O  .  . ) -> Indikator Level 1, 2, 3, 4          |
+-------------------------------------------------------------+
```

### Panduan & Mekanika Level:
- **Level 1**: Selalu terbuka untuk semua murid.
- **Level 2, 3, 4**: Terbuka otomatis setelah murid menyelesaikan level sebelumnya dengan minimal perolehan 1 Bintang.
- **Tombol "MAINKAN"**: Mengurangi 1 Nyawa dan langsung membuka Studio Canvas.

---

## 2.6 Studio Game Menggambar: Kategori Keris Madura

Panduan khusus saat memilih game **Keris Madura** (Level 1 s.d Level 4).

### Rincian Target Pembelajaran Keris:
- **Level 1 (Gagang / Hulu Keris)**: Menggambar ukiran hulu keris Madura (*Dongkokan*) dengan kombinasi lengkung geometri.
- **Level 2 (Bilah Keris Berkelok / Luk)**: Menggambar bilah keris berkelok simetris dengan jumlah lekukan ganjil (3, 5, atau 7 luk).
- **Level 3 (Warangka / Sarung Keris)**: Merancang sarung keris (*Gandrung/Gayaman*) menggunakan bangun datar trapesium, segitiga, dan oval.
- **Level 4 (Keris Utuh Lengkap)**: Menggabungkan Hulu, Bilah, dan Warangka menjadi satu kesatuan mahakarya utuh.

### Gambaran Layar Studio Keris (Screen Wireframe):
```
+-------------------------------------------------------------+
| [X] Keluar   ⏱️ 09:45   [📐 Template]   [🎤 Rekam]  [✅ Selesai]|
+-------------------------------------------------------------+
|                                                             |
|                                                             |
|                   AREA CANVAS MENGGAMBAR                    |
|                 (Kerangka Template Aktif)                   |
|                   - - - - - - - - - - -                     |
|                  /                     \                    |
|                 |     Goresan Keris     |                   |
|                  \                     /                    |
|                   - - - - - - - - - - -                     |
|                                                             |
+-------------------------------------------------------------+
| Garis: [---o---------] 8px   | Transparansi: [-------o] 100%|
+-------------------------------------------------------------+
| [📐Kerangka] [✋Geser] [🖌️Kuas] [🎨Warna] [🧹Hapus] [🔺Bentuk]|
+-------------------------------------------------------------+
```

### Panduan Alat & Tombol Studio Keris:
1. **Tombol "Keluar" [X] (Kiri Atas)**:
   - Menampilkan dialog konfirmasi. Progres gambar Anda otomatis tersimpan di draf beranda.
2. **Timer `[ ⏱️ 09:45 ]`**: Sisa waktu pengerjaan. Jika waktu habis, sistem otomatis mengirimkan karya yang ada ke Juri AI.
3. **Tombol "[📐 Template]"**:
   - Membuka katalog cetak biru (*outline guide*) keris: Pilihan pola Gagang Keris, Bilah Luk 3/5/7, atau Warangka Gayaman.
   - Garis panduan akan tampil transparan di canvas untuk memandu goresan tangan Anda.
4. **Tombol "[🎤 Rekam]" (Mikrofon)**:
   - Tekan sekali untuk mulai merekam suara penjelasan Anda (misal: *"Saya membuat keris luk 5 dengan warangka trapesium..."*).
   - Tekan lagi untuk menghentikan rekaman (Maksimal 60 detik).
5. **Tombol "[✅ Selesai]"**:
   - Mengakhiri sesi menggambar dan mengirimkan hasil karya ke Juri AI untuk dinilai.
6. **Slider Ketebalan Garis (`1 px - 40 px`)**:
   - Geser slider untuk memperbesar/memperkecil goresan.
   - Ketuk tombol angka di samping slider untuk mengetik ukuran spesifik.
7. **Slider Transparansi (`1% - 100%`)**:
   - Geser untuk mengatur kepekatan tinta.
8. **Tombol "[✋ Geser]" (Pan & Zoom)**:
   - Gunakan alat ini untuk menggeser posisi canvas atau mencubit layar (*pinch to zoom*) untuk memperbesar detail ukiran tanpa mencoret canvas.
9. **Tombol "[🖌️ Kuas]" (Brush Picker)**:
   - **Bolpoin (🖊️)**: Garis halus dan tegas untuk detail ukiran keris.
   - **Pensil (✏️)**: Tekstur sketsa alami untuk rancangan awal.
   - **Spidol (🖍️)**: Garis tebal pekat untuk garis tepi (*outline*).
   - **Cat Air (🎨)**: Sapuan semi-transparan untuk pewarnaan bilah logam emas/perak.
10. **Tombol "[🎨 Warna]"**:
    - Pilih dari 12 warna preset cepat, atau ketuk lingkaran warna untuk membuka **Full Spectrum Color Picker** (Hex, RGB, HSV).
11. **Tombol "[🧹 Hapus]"**:
    - Mengubah kuas menjadi penghapus untuk menghapus goresan yang salah.
12. **Tombol "[🔺 Bentuk]" (Stempel Geometri & Keris)**:
    - Menyisipkan bangun geometri instan: Segitiga, Persegi, Trapesium, Oval, Lingkaran, Belah Ketupat.
    - Menyisipkan stempel ukiran: Gagang Keris, Bilah Keris, Ukiran Hulu.
    - Bentuk yang disisipkan dapat diputar (*rotate*), diperbesar/perkecil (*scale*), dan dipindahkan posisinya di canvas.
13. **Tombol Asisten Simetri (Cermin)**:
    - Menyalakan garis simetri vertikal di tengah canvas. Setiap goresan di sisi kiri akan otomatis tercermin di sisi kanan secara presisi.

---

## 2.7 Studio Game Menggambar: Kategori Batik Madura

Panduan khusus saat memilih game **Batik Madura** (Level 1 s.d Level 4).

### Rincian Target Pembelajaran Batik:
- **Level 1 (Garis & Isen-isen Dasar)**: Menggambar motif titik (*cecek-cecek*), garis sejajar, dan belah ketupat berulang.
- **Level 2 (Motif Simetri Cermin)**: Membuat motif bunga tanjung atau daun tembakau yang seimbang sempurna dengan sumbu simetri.
- **Level 3 (Komposisi Bangun Datar)**: Merancang motif batik dengan mengombinasikan minimal 3 bangun datar berbeda (misal: lingkaran, belah ketupat, dan segitiga).
- **Level 4 (Mahakarya Batik Pesisir)**: Eksplorasi motif batik Madura lengkap (*Sekar Jagad, Tumpal, Manuk Gunting*) dengan warna cerah kontras (merah, kuning, biru, hijau).

### Gambaran Layar Studio Batik (Screen Wireframe):
```
+-------------------------------------------------------------+
| [X] Keluar   ⏱️ 09:30   [📐 Template]   [🎤 Rekam]  [✅ Selesai]|
+-------------------------------------------------------------+
|                                                             |
|                   | (Sumbu Simetri Cermin)                  |
|              \    |    /                                    |
|               O---+---O   Motif Bunga Batik                 |
|              /    |    \  Tercermin Otomatis                |
|                   |                                         |
|                                                             |
+-------------------------------------------------------------+
| Garis: [---o---------] 6px   | Transparansi: [-------o] 100%|
+-------------------------------------------------------------+
| [📐Kerangka] [✋Geser] [🖌️Kuas] [🎨Warna] [🧹Hapus] [🌺Stempel]|
+-------------------------------------------------------------+
```

### Panduan Khusus Fitur Batik:
1. **Fitur Asisten Simetri Lipat (Mirror Symmetry)**:
   - Sangat dianjurkan diaktifkan pada pembuatan motif batik.
   - Garis biru putus-putus akan membelah canvas. Murid cukup menggambar separuh motif di sisi kiri, dan sisi kanan akan terbentuk otomatis dengan sempurna.
2. **Katalog Stempel Batik (`[🌺 Stempel]`)**:
   - Pilihan motif instan: *Bunga Melati Madura*, *Daun Tembakau*, *Ornamen Tumpal*, *Bintang Madura*, *Cecek Pitu*.
3. **Template Kerangka Batik (`[📐 Template]`)**:
   - Panduan motif dasar: Pola Kotak Berulang, Pola Diagonal Parang, Pola Daun Pesisir.

---

## 2.8 Studio Game Anyaman: Kategori Anyaman Grid Madura

Panduan khusus saat memilih game **Anyaman Madura** (Level 1 s.d Level 4).

### Rincian Target Grid & Level:
- **Level 1**: Kisi Anyaman Ukuran **8 x 8 Kotak** (Minimal menggunakan 2 warna berbeda).
- **Level 2**: Kisi Anyaman Ukuran **10 x 10 Kotak** (Minimal menggunakan 3 warna berbeda).
- **Level 3**: Kisi Anyaman Ukuran **12 x 12 Kotak** (Minimal menggunakan 4 warna berbeda).
- **Level 4**: Kisi Anyaman Ukuran **14 x 14 Kotak** (Eksplorasi multi-warna & Asisten Simetri 4 Kuadran).

### Gambaran Layar Studio Anyaman (Screen Wireframe):
```
+-------------------------------------------------------------+
| [X] Keluar   Level 2 (Grid 10x10)   ⏱️ 08:15    [🎤]  [✅ Selesai]|
+-------------------------------------------------------------+
| Progress Waktu: [==========================                 ] |
+-------------------------------------------------------------+
|                                                             |
|           +---+---+---+---+---+---+---+---+---+---+         |
|           | 🟨 | 🟥 | 🟨 | 🟥 | 🟨 | 🟥 | 🟨 | 🟥 | 🟨 | 🟥 |         |
|           +---+---+---+---+---+---+---+---+---+---+         |
|           | 🟥 | 🟨 | 🟥 | 🟨 | 🟥 | 🟨 | 🟥 | 🟨 | 🟥 | 🟨 |         |
|           +---+---+---+---+---+---+---+---+---+---+         |
|           | 🟨 | 🟥 | 🟦 | 🟦 | 🟨 | 🟨 | 🟦 | 🟦 | 🟨 | 🟥 |         |
|           +---+---+---+---+---+---+---+---+---+---+         |
|           | (Area Kisi Anyaman Bambu Interaktif)  |         |
|           +---+---+---+---+---+---+---+---+---+---+         |
|                                                             |
+-------------------------------------------------------------+
| [🖌️ Warna Kotak]  [🪣 Isi Baris/Area]  [💉 Pipet]  [✨ Simetri] |
| Palet Warna: ( 🟨 ) ( 🟥 ) ( 🟦 ) ( 🟩 ) ( 🟫 ) ( ⬛ ) [🎨+ ]     |
+-------------------------------------------------------------+
```

### Panduan Alat & Tombol Studio Anyaman:
1. **Mode Kuas Kotak `[🖌️]`**:
   - Pilih warna dari palet di bawah, lalu sentuh kotak anyaman yang diinginkan untuk mewarnainya.
2. **Mode Ember / Fill `[🪣]`**:
   - Memungkinkan mewarnai satu baris penuh, satu kolom penuh, atau area kotak yang terhubung hanya dengan 1 ketukan.
3. **Mode Pipet / Eyedropper `[💉]`**:
   - Ketuk alat pipet, lalu ketuk kotak di canvas yang warnanya ingin Anda tiru/salin.
4. **Mode Simetri Anyaman `[✨]`**:
   - Mengaktifkan simetri 4 kuadran. Jika Anda mewarnai kotak di sudut kiri atas, 3 sudut lainnya otomatis terisi warna yang sama secara simetris.
5. **Palet Warna Anyaman**:
   - Pilihan warna serat bambu alami (Kuning Bambu, Merah Alami, Biru Pesisir, Hijau Daun, Cokelat Kayu, Hitam).
   - Tombol `[🎨+]` untuk membuka palet warna custom tak terbatas.

---

## 2.9 Layar Hasil & Penilaian Juri AI (*Drawing Result Screen*)

Setelah menekan tombol **"[✅ Selesai]"**, sistem Juri AI (Google Gemini Multimodal) akan menganalisis gambar Anda.

### Gambaran Layar Hasil (Screen Wireframe):
```
+-------------------------------------------------------------+
|                     🎉 LUAR BIASA! 🎉                       |
|                       ⭐⭐⭐ (Grade A+)                      |
|                                                             |
|           +-------------------------------------+           |
|           |                                     |           |
|           |     [ FOTO HASIL KARYA MURID ]      |           |
|           |                                     |           |
|           +-------------------------------------+           |
|                                                             |
|  ⭐ Total Nilai : 94 / 100               🏆 Poin : +120 Poin |
|                                                             |
|  📊 RINCIAN RUBRIK PENILAIAN AI:                            |
|  • Akurasi Pola & Geometri   : [====================] 95    |
|  • Kerapian Garis            : [==================  ] 90    |
|  • Komposisi & Warna         : [====================] 96    |
|  • Kreativitas Motif         : [=================== ] 95    |
|                                                             |
|  💬 ULASAN JURI AI:                                         |
|  "Bilah keris yang kamu gambar sangat simetris dan rapi!   |
|   Pilihan warna emas menunjukkan pemahaman geometri..."     |
|                                                             |
|  🎵 REKAMAN SUARA: [ ▶ Play ] [====o==============] 00:28   |
|                                                             |
|  +---------------------+  +-------------------------------+ |
|  | 📥 Simpan ke Galeri |  | ⏭️  Lanjut Level Berikutnya   | |
|  +---------------------+  +-------------------------------+ |
|                    [ 🔄 Main Ulang Level ]                  |
+-------------------------------------------------------------+
```

### Panduan Rincian Nilai & Tombol:
1. **Grade & Bintang**:
   - **Grade S / A+ / A**: Mendapatkan **3 Bintang** (Membuka level berikutnya).
   - **Grade B**: Mendapatkan **2 Bintang** (Membuka level berikutnya).
   - **Grade C**: Mendapatkan **1 Bintang** (Membuka level berikutnya).
   - **Grade D**: Butuh perbaikan (Disarankan mengulang level).
2. **Rincian 4 Rubrik Nilai**:
   - **Akurasi Pola & Geometri (30%)**: Ketepatan bangun datar & simetri.
   - **Kerapian Garis (25%)**: Kemulusan garis dan sambungan kurva.
   - **Komposisi Warna (25%)**: Keserasian kombinasi warna budaya.
   - **Kreativitas (20%)**: Keunikan modifikasi motif.
3. **Pemutar Rekaman Suara**: Tekan tombol `[ ▶ Play ]` untuk mendengarkan kembali suara narasi yang Anda rekam.
4. **Tombol "Simpan ke Galeri"**: Mengunduh berkas gambar HD langsung ke memori HP (Album `EPIC App`).
5. **Tombol "Lanjut Level Berikutnya"**: Melangkah ke tantangan level di atasnya.
6. **Tombol "Main Ulang Level"**: Mengulang level ini untuk mengejar skor 100.

---

## 2.10 Tab 2: Papan Peringkat (*Ranking Screen*)

### Gambaran Layar (Screen Wireframe):
```
+-------------------------------------------------------------+
|                      🏆 Papan Peringkat                     |
|                                                             |
|             +---------------------------------+             |
|             |  [ Global ]  |  [ Kelas 4A ]    |             |
|             +---------------------------------+             |
|                                                             |
|                          🥇 [Juara 1]                       |
|                          Siti Aminah                        |
|                          ⭐ 2.450 Poin                      |
|                                                             |
|           🥈 [Juara 2]                  🥉 [Juara 3]        |
|           Budi Pratama                  Dewi Lestari        |
|           ⭐ 2.100 Poin                 ⭐ 1.950 Poin       |
|                                                             |
| 4. Ahmad Rizky (Kamu) ------------------------- ⭐ 1.400 Poin|
| 5. Fajar Maulana ------------------------------ ⭐ 1.250 Poin|
| 6. Nurul Hidayah ------------------------------ ⭐ 1.100 Poin|
|                                                             |
| +---------------------------------------------------------+ |
| | Posisi Kamu: Peringkat #4             Total: 1.400 Poin | |
| +---------------------------------------------------------+ |
+-------------------------------------------------------------+
```

### Panduan Penggunaan:
1. **Pilihan Tab "Global" vs "Kelas"**:
   - **Global**: Peringkat seluruh siswa pengguna EPIC dari berbagai sekolah.
   - **Kelas**: Peringkat khusus teman sekelas Anda.
2. **Podium Juara (1, 2, 3)**: Menampilkan 3 siswa dengan perolehan poin terbanyak.
3. **Bilah Posisi Pribadi (Paling Bawah)**: Menunjukkan posisi peringkat Anda dan jarak poin dengan peringkat di atas Anda.

---

## 2.11 Tab 3: Galeri Karya Saya (*Galeri Tab & Detail Karya Screen*)

### Gambaran Layar Galeri (Screen Wireframe):
```
+-------------------------------------------------------------+
| Galeri Karya                                                |
| Koleksi hasil karya terbaikmu!                              |
|                                                             |
| Filter: [ Semua (Terpilih) ] [ Keris ] [ Batik ] [ Anyaman ]|
|                                                             |
| +-----------------------+       +-----------------------+   |
| | [Gambar Keris Luk 5]  |       | [Gambar Batik Madura] |   |
| | ⭐ 94 (Grade A+)      |       | ⭐ 88 (Grade A)       |   |
| | 27 Agu 2026           |       | 26 Agu 2026           |   |
| +-----------------------+       +-----------------------+   |
|                                                             |
| +-----------------------+       +-----------------------+   |
| | [Gambar Anyaman 10x10]|       | [Gambar Hulu Keris]   |   |
| | ⭐ 96 (Grade S)       |       | ⭐ 82 (Grade A)       |   |
| | 25 Agu 2026           |       | 24 Agu 2026           |   |
| +-----------------------+       +-----------------------+   |
+-------------------------------------------------------------+
```

### Panduan Menggunakan Galeri & Melihat Detail Karya:
1. **Filter Kategori**: Ketuk tombol chip (*Semua, Keris, Batik, Anyaman*) untuk memfilter tampilan.
2. **Membuka Detail Karya**: Ketuk salah satu kartu gambar untuk membuka **Layar Detail Karya**.
3. **Fitur di Dalam Layar Detail Karya**:
   - Melihat gambar resolusi penuh.
   - Melihat Skor Evaluasi Juri AI dan Nilai Koreksi Guru.
   - Membaca Catatan/Ulasan Guru (*Teacher Feedback*).
   - **Tombol "Unduh ke Galeri HP"**: Menyimpan berkas gambar ke memori smartphone.
   - **Tombol "Hapus Karya"**: Menghapus karya dari portofolio (dengan konfirmasi keamanan).

---

## 2.12 Tab 4: Toko Avatar & Koleksi Karakter (*Karakter Tab*)

### Gambaran Layar (Screen Wireframe):
```
+-------------------------------------------------------------+
| Karakter Aktif: Ksatria Madura                Saldo: ⭐ 1.4k |
|                                                             |
|                  [ PRATINJAU MASKOT AKTIF ]                 |
|                   "Halo, siap belajar lagi?"                |
|                                                             |
| Koleksi Avatar                                              |
| +------------+  +------------+  +------------+  +---------+ |
| | [Avatar 1] |  | [Avatar 2] |  | [Avatar 3] |  | [Avatar]| |
| | Ksatria    |  | Putri      |  | Penenun    |  | Pendekar| |
| | (Dipakai)  |  | 500 Poin   |  | 800 Poin   |  | 1000 Poin |
| +------------+  +------------+  +------------+  +---------+ |
|                                                             |
|             [ 🛒  B E L I   A V A T A R  (500 Poin) ]       |
+-------------------------------------------------------------+
```

### Panduan Menggunakan Toko Avatar:
1. **Melihat Koleksi**: Geser daftar kartu karakter secara horizontal.
2. **Membeli Avatar**: Pilih avatar yang terkunci, lalu tekan tombol **"Beli Avatar (xxx Poin)"**. Poin Anda akan dipotong sesuai harga.
3. **Menggunakan Avatar**: Pada avatar yang sudah dibeli, tekan tombol **"Gunakan Avatar Ini"** untuk mengganti maskot utama di beranda.

---

## 2.13 Fitur Bergabung ke Kelas Guru (*Gabung Kelas & Scan QR*)

### Gambaran Layar Gabung Kelas (Screen Wireframe):
```
+-------------------------------------------------------------+
| [ < ] Gabung Kelas                                          |
|                                                             |
| Masukkan Kode Kelas                                         |
| Minta 6 digit kode kelas kepada gurumu:                     |
|                                                             |
|         +-----------------------------------------+         |
|         |               E P I C 4 A               |         |
|         +-----------------------------------------+         |
|                                                             |
|               [ G A B U N G   K E L A S ]                   |
|                                                             |
| ------------------------- ATAU ---------------------------- |
|                                                             |
|         [ 📷  P I N D A I   Q R   C O D E   G U R U ]       |
+-------------------------------------------------------------+
```

### Panduan Bergabung ke Kelas:
- **Cara 1 (Ketik Kode)**: Masukkan 6 digit kode kelas dari guru (misal: `EPIC4A`), lalu tekan tombol **"GABUNG KELAS"**.
- **Cara 2 (Pindai QR)**: Tekan tombol **"PINDAI QR CODE GURU"**, arahkan kamera HP Anda ke layar/kertas QR Code yang ditunjukkan oleh guru Anda.
- **Hasil**: Setelah berhasil, nama kelas dan nama guru Anda akan muncul, dan karya Anda otomatis masuk ke dashboard guru.

---

# BAB 3: PANDUAN LENGKAP PENGGUNA — PERAN GURU (TEACHER)

---

## 3.1 Navigasi Utama Guru (*Bottom Navigation Bar*)
Guru memiliki 4 menu navigasi utama di bagian bawah layar:
```
+-------------------------------------------------------------+
|  [ 🏠 Home Guru ]   [ 🏫 Kelas Saya ]   [ 👥 Murid ]   [ 👤 Profil ] |
+-------------------------------------------------------------+
```
- **Home Guru**: Statistik ringkas, pintasan kelas, feed karya terbaru siswa, dan top murid.
- **Kelas Saya**: Manajemen ruang kelas (buat kelas, kelas aktif, kelas nonaktif, arsip).
- **Murid**: Direktori seluruh siswa, pantauan keaktifan, dan portofolio individu.
- **Profil**: Pengaturan akun guru, ganti nama sekolah, dan pusat keamanan akun.

---

## 3.2 Tab 1: Beranda Guru (*Guru Home Tab*)

### Gambaran Layar (Screen Wireframe):
```
+-------------------------------------------------------------+
| Selamat Pagi 🌅                                             |
| Bpk. Budi Santoso, S.Pd.                [ Avatar Guru Glow ]|
| 🏫 SDN 1 Bangkalan                                          |
+-------------------------------------------------------------+
| 📊 RINGKASAN AKTIVITAS                                      |
| +-------------------------+     +-------------------------+ |
| | 🏫 3 Kelas Aktif        |     | 👥 84 Total Murid       | |
| +-------------------------+     +-------------------------+ |
| | ⭐ 89.2 Rata-rata Nilai |     | 🎨 16 Karya Hari Ini    | |
| +-------------------------+     +-------------------------+ |
|                                                             |
| 🏫 KELAS SAYA                                               |
| +---------------------------------------------------------+ |
| | [🏫] Kelas 4A - Seni Budaya Madura       [ 28 Murid ]   | |
| |      KODE: EPIC4A [Salin] • Rerata: 91.2 • 42 Karya     | |
| +---------------------------------------------------------+ |
|                                                             |
| 🎨 KARYA TERBARU MURID                     [ Lihat Semua >] |
| +---------------------------------------------------------+ |
| | [Foto] Keris Luk 5 - Oleh: Siti Aminah (Kelas 4A)       | |
| | Skor AI: 94 • Belum Dinilai Guru       [ Nilai Sekarang]| |
| +---------------------------------------------------------+ |
|                                                             |
| 🏆 TOP MURID BERPRESTASI                                    |
| 1. Siti Aminah (Kelas 4A) -------------------- ⭐ 2.450 Poin|
| 2. Budi Pratama (Kelas 4B) ------------------- ⭐ 2.100 Poin|
+-------------------------------------------------------------+
```

### Panduan Penggunaan:
1. **Kartu Statistik 4 Metrik**:
   - **Kelas Aktif**: Jumlah ruang kelas yang sedang berjalan.
   - **Total Murid**: Jumlah seluruh siswa di semua kelas Anda.
   - **Rata-rata Nilai**: Nilai rerata gabungan seluruh tugas murid.
   - **Karya Hari Ini**: Jumlah tugas baru yang dikumpulkan hari ini.
2. **Kartu Kelas Saya**:
   - Ketuk tombol **"[Salin]"** untuk menyalin kode kelas ke clipboard (siap dibagikan ke WhatsApp wali murid).
   - Ketuk kartu kelas untuk langsung membuka **Pusat Kendali Kelas**.
3. **Karya Terbaru Murid**:
   - Menampilkan kiriman tugas murid secara live.
   - Tekan tombol **"Nilai Sekarang"** untuk langsung membuka modal rubrik penilaian guru.
   - Tekan tombol **"Lihat Semua >"** untuk membuka bottom sheet daftar seluruh karya masuk.

---

## 3.3 Tab 2: Manajemen Kelas (*Guru Dashboard Screen*)

### Gambaran Layar (Screen Wireframe):
```
+-------------------------------------------------------------+
| Kelas Saya                               [ + Buat Kelas ]   |
|                                                             |
| Filter: [ Aktif (3) (Terpilih) ]   [ Nonaktif (1) ]         |
|                                                             |
| -- KELAS AKTIF (3) --                                       |
| +---------------------------------------------------------+ |
| | (• Hijau) Kelas 4A - Seni Budaya Madura                 | |
| | Kode: EPIC4A [Salin] • 28 Murid • Avg: 91.2 • 42 Karya  | |
| | Dibuat: 10 Jul 2026                           [ Lihat >]| |
| +---------------------------------------------------------+ |
|                                                             |
| +---------------------------------------------------------+ |
| | (• Hijau) Kelas 4B - Matematika Etnik                   | |
| | Kode: EPIC4B [Salin] • 30 Murid • Avg: 88.0 • 35 Karya  | |
| | Dibuat: 12 Jul 2026                           [ Lihat >]| |
| +---------------------------------------------------------+ |
+-------------------------------------------------------------+
```

### Panduan Tombol & Aksi:
1. **Tombol "[ + Buat Kelas ]" (Pojok Kanan Atas)**: Membuka formulir pembuatan kelas baru.
2. **Filter Chip "Aktif" vs "Nonaktif"**:
   - **Aktif**: Menampilkan kelas yang aktif menerima murid.
   - **Nonaktif**: Menampilkan kelas yang dinonaktifkan (misal saat libur semester).
3. **Aksi pada Tab "Nonaktif"**:
   - **Tombol "Aktifkan Kembali"**: Membuka kembali akses kelas.
   - **Tombol "Hapus Permanen"**: Menghapus kelas dan seluruh riwayatnya secara permanen.

---

## 3.4 Layar Buat Kelas Baru (*Buat Kelas Screen*)

### Gambaran Layar (Screen Wireframe):
```
+-------------------------------------------------------------+
| [ < ] Buat Kelas Baru                                       |
|                                                             |
| Nama Kelas *                                                |
| [ Contoh: Kelas 4A - Etnomatematika                       ] |
|                                                             |
| Nama Sekolah *                                              |
| [ SDN 1 Bangkalan                                         ] |
|                                                             |
| Tingkat Kelas                                               |
| [ Kelas 4 SD                                            v ] |
|                                                             |
| Tahun Ajaran *                                              |
| [ Contoh: 2026/2027                                       ] |
|                                                             |
| Deskripsi Kelas (Opsional)                                  |
| [ Pembelajaran geometri berbasis budaya batik & keris...  ] |
|                                                             |
|             [  B U A T   R U A N G   K E L A S  ]           |
+-------------------------------------------------------------+
```

### Panduan Pembuatan:
1. Isi Nama Kelas, Nama Sekolah, Tingkat Kelas SD, dan Tahun Ajaran.
2. Tekan tombol **"BUAT RUANG KELAS"**.
3. Sistem otomatis membuat **6 Digit Kode Kelas** dan **QR Code Kelas**.

---

## 3.5 Pusat Kendali Kelas Guru (*Kelas Detail Guru Screen*)

Layar pusat pengelolaan satu ruang kelas spesifik yang terbagi menjadi **4 Sub-Tab**:

---

### 3.5.1 Sub-Tab 1: Murid

```
+-------------------------------------------------------------+
| [ < ] Kelas 4A - Seni Budaya Madura                         |
|       SDN 1 Bangkalan                                       |
+-------------------------------------------------------------+
| [ 👥 Murid (28) ]  [ 🎨 Karya ]  [ 🏆 Ranking ]  [ ⚙️ Info ] |
+-------------------------------------------------------------+
| [ 🔍 Cari nama atau username murid...                     ] |
|                                                             |
| Daftar Siswa Aktif:                                         |
| +---------------------------------------------------------+ |
| | [Avatar] Siti Aminah (@siti_a)            [ ⭐ 2.450 ]  | |
| |          Level 4 • 6 Karya • Avg Nilai: 94.5            | |
| |          [ Lihat Profil Siswa ]     [ Keluarkan Siswa ] | |
| +---------------------------------------------------------+ |
| +---------------------------------------------------------+ |
| | [Avatar] Budi Pratama (@budi_p)           [ ⭐ 2.100 ]  | |
| |          Level 3 • 5 Karya • Avg Nilai: 88.0            | |
| |          [ Lihat Profil Siswa ]     [ Keluarkan Siswa ] | |
| +---------------------------------------------------------+ |
+-------------------------------------------------------------+
```

#### Panduan Penggunaan:
1. **Kotak Pencarian Murid**: Ketik nama/username untuk menyaring murid tertentu.
2. **Tombol "Lihat Profil Siswa"**: Membuka portofolio lengkap dan seluruh karya siswa tersebut.
3. **Tombol "Keluarkan Siswa"**:
   - Membuka dialog konfirmasi untuk mengeluarkan siswa yang salah masuk kelas.
   - Guru dapat memilih alasan pengeluaran (misal: *Pindah kelas / Bukan siswa kelas ini*).

---

### 3.5.2 Sub-Tab 2: Karya & Penilaian Manual Guru (Asesmen Rubrik)

```
+-------------------------------------------------------------+
| [ 👥 Murid ]  [ 🎨 Karya (42) ]  [ 🏆 Ranking ]  [ ⚙️ Info ] |
+-------------------------------------------------------------+
| Filter Kategori: [ Semua ] [ Keris ] [ Batik ] [ Anyaman ]  |
| Filter Status  : [ Semua ] [ Belum Dinilai ] [ Sudah Dinilai|
|                                                             |
| +---------------------------------------------------------+ |
| | [Foto Karya] Keris Luk 5                                | |
| |              Oleh: Siti Aminah (27 Agu 2026)            | |
| |              Skor AI: 94 (Grade A+)                     | |
| |              Status : ⏳ Belum Dinilai Guru             | |
| |              [ 📝  B E R I K A N   N I L A I  G U R U ] | |
| +---------------------------------------------------------+ |
+-------------------------------------------------------------+
```

#### Modal Penilaian Manual Guru (Saat tombol "Berikan Nilai Guru" ditekan):
```
+-------------------------------------------------------------+
| 📝 Evaluasi & Penilaian Guru                                |
|                                                             |
| [ FOTO HASIL KARYA MURID RESOLUSI PENUH ]                   |
|                                                             |
| 🎵 REKAMAN SUARA MURID:                                     |
| [ ▶ Play ] [=======o==============] 00:28                   |
|                                                             |
| 🤖 Skor Referensi Juri AI: 94 / 100 (Grade A+)              |
|                                                             |
| 📊 RUBRIK PENILAIAN GURU (Skala 1 - 100):                   |
| 1. Akurasi Pola & Geometri   : [ 95 ]  (Bobot 30%)          |
| 2. Kerapian Garis            : [ 90 ]  (Bobot 25%)          |
| 3. Komposisi & Harmoni Warna : [ 95 ]  (Bobot 25%)          |
| 4. Kreativitas Motif         : [ 92 ]  (Bobot 20%)          |
|                                                             |
| Nilai Akhir Guru: 93.1 / 100                                |
|                                                             |
| Catatan / Masukan Guru untuk Siswa:                         |
| [ Goresan bilah keris sangat rapi, pertahankan!          ] |
|                                                             |
|             [ 💾  S I M P A N   P E N I L A I A N ]         |
+-------------------------------------------------------------+
```

#### Panduan Melakukan Penilaian:
1. **Dengarkan Narasi Suara Murid**: Tekan tombol `[ ▶ Play ]` pada pemutar suara untuk mendengarkan penjelasan murid mengenai karyanya.
2. **Isi Skor pada 4 Kolom Rubrik**: Ketik nilai angka (1 s.d 100) untuk masing-masing kriteria.
3. **Ketik Catatan/Umpan Balik**: Berikan motivasi atau saran perbaikan di kolom teks.
4. **Tekan "SIMPAN PENILAIAN"**: Nilai guru resmi tersimpan dan langsung memperbarui rapor nilai siswa.

---

### 3.5.3 Sub-Tab 3: Ranking Internal Kelas

- Menampilkan klasemen peringkat khusus siswa di dalam kelas tersebut berdasarkan akumulasi nilai dan poin karya.

---

### 3.5.4 Sub-Tab 4: Info & Pengaturan Kelas (Ekspor Excel/PDF)

```
+-------------------------------------------------------------+
| [ 👥 Murid ]  [ 🎨 Karya ]  [ 🏆 Ranking ]  [ ⚙️ Info (v) ] |
+-------------------------------------------------------------+
|                                                             |
|                   KODE KELAS: [ EPIC4A ]                    |
|                      [ 📋 Salin Kode ]                      |
|                                                             |
|                   +-----------------------+                 |
|                   |     [ QR CODE ]       |                 |
|                   |     KELAS GURU        |                 |
|                   +-----------------------+                 |
|                                                             |
|          [ 📥  S I M P A N   Q R   K E   G A L E R I ]      |
|                                                             |
|          [ 📤  B A G I K A N   K O D E   K E L A S ]        |
|                                                             |
| 📄 EKSPOR LAPORAN AKADEMIK:                                 |
| +---------------------------------------------------------+ |
| | [📊] Ekspor Rekap Nilai ke Excel (.xlsx)                | |
| +---------------------------------------------------------+ |
| | [📑] Ekspor Rapor Karya Siswa ke PDF (.pdf)             | |
| +---------------------------------------------------------+ |
|                                                             |
| ⚙️ MANAJEMEN STATUS KELAS:                                  |
| • [ ⏸️ Nonaktifkan Kelas ]  • [ 📦 Arsipkan Kelas ]        |
| • [ 🗑️ Hapus Kelas Permanen ]                               |
+-------------------------------------------------------------+
```

#### Panduan Fitur Ekspor & Pengaturan:
1. **Tombol "Simpan QR ke Galeri"**: Menyimpan gambar QR Code kelas ke galeri HP guru (siap dicetak untuk ditempel di kelas fisik).
2. **Tombol "Bagikan Kode Kelas"**: Membagikan teks undangan kelas ke WhatsApp/Telegram.
3. **Tombol "Ekspor Rekap Nilai ke Excel (.xlsx)"**:
   - **Hasil**: Mengunduh berkas spreadsheet Excel lengkap berisi daftar murid, rincian skor tiap tugas, dan total poin.
4. **Tombol "Ekspor Rapor Karya ke PDF (.pdf)"**:
   - **Hasil**: Mengunduh dokumen Rapor Digital Etnomatematika resmi berlogo EPIC siap cetak/bagikan ke wali murid.
5. **Tombol "Nonaktifkan Kelas"**: Menutup sementara kelas saat masa libur sekolah.
6. **Tombol "Arsipkan Kelas"**: Mengunci kelas menjadi dokumen arsip historis (*read-only*).

---

## 3.6 Tab 3: Direktori Seluruh Murid (*Guru Murid Tab & Profil Murid Screen*)

### Gambaran Layar Direktori (Screen Wireframe):
```
+-------------------------------------------------------------+
| Daftar Murid                                Total: 84 Murid |
|                                                             |
| [ 🔍 Cari nama atau username murid...                     ] |
|                                                             |
| Filter Kelas: [ Semua Kelas (v) ] [ Kelas 4A ] [ Kelas 4B ] |
|                                                             |
| +---------------------------------------------------------+ |
| | [Avatar] Siti Aminah (@siti_a)          • Aktif Hari ini| |
| |          SDN 1 Bangkalan • Kelas 4A     ⭐ 2.450 Poin   | |
| |          Keris Lv 4 • Batik Lv 3 • Anyaman Lv 4   [ > ] | |
| +---------------------------------------------------------+ |
| +---------------------------------------------------------+ |
| | [Avatar] Budi Pratama (@budi_p)         • 2 hari lalu   | |
| |          SDN 1 Bangkalan • Kelas 4B     ⭐ 2.100 Poin   | |
| |          Keris Lv 3 • Batik Lv 2 • Anyaman Lv 3   [ > ] | |
| +---------------------------------------------------------+ |
+-------------------------------------------------------------+
```

### Panduan Membuka Profil Murid Mendalam:
- Ketuk salah satu kartu siswa untuk membuka **Layar Profil Murid**:
  - Melihat akumulasi poin, rekor nilai tertinggi, dan level yang sudah dituntaskan siswa.
  - Melihat galeri seluruh karya gambar yang pernah dibuat oleh siswa tersebut.

---

# BAB 4: PUSAT PENGATURAN & KEAMANAN AKUN (GURU & MURID)

---

## 4.1 Layar Profil (*Profile Screen*)

### Gambaran Layar (Screen Wireframe):
```
+-------------------------------------------------------------+
|                         Profil Saya                         |
|                                                             |
|                   [ Foto Avatar + Ring Glow ]               |
|                   [ 📷 Ganti Foto Profil ]                  |
|                                                             |
|                      Budi Santoso, S.Pd.                    |
|                        @budi_santoso                        |
|                  🎓 Guru Terverifikasi / SDN 1              |
|                                                             |
| +---------------------------------------------------------+ |
| | 🏫 3 Kelas Aktif               | 👥 84 Total Murid       | |
| +---------------------------------------------------------+ |
|                                                             |
| ⚙️ PENGATURAN                                               |
| +---------------------------------------------------------+ |
| | 👤 Edit Profil (Nama, Username)                   [ > ] | |
| | 🏫 Data Sekolah & Domisili                        [ > ] | |
| | 🎮 Pengaturan Suara & Musik Game                  [ > ] | |
| | ⏸️ Kelas Nonaktif (Khusus Guru)                   [ > ] | |
| +---------------------------------------------------------+ |
|                                                             |
| 🔑 AKUN & KEAMANAN                                          |
| +---------------------------------------------------------+ |
| | 🛡️ Keamanan Akun & Riwayat Sesi (Khusus Guru)     [ > ] | |
| | ℹ️ Tentang Aplikasi EPIC                          [ > ] | |
| +---------------------------------------------------------+ |
|                                                             |
|                   [ 🚪  K E L U A R   A K U N ]             |
+-------------------------------------------------------------+
```

---

## 4.2 Ubah Data Pribadi (*Edit Profile Screen*)
- **Fungsi**: Mengubah Nama Lengkap, Nama Panggilan, Username, dan Foto Avatar dari Kamera HP / Galeri.
- Tekan tombol **"Simpan Perubahan"** untuk menerapkan pembaruan.

---

## 4.3 Ubah Data Sekolah & Domisili (*Edit School Screen*)
- **Fungsi**: Memperbarui Nama Sekolah Asal, Tingkat Kelas SD, Provinsi, Kabupaten/Kota, dan Kecamatan.

---

## 4.4 Pengaturan Suara & Musik (*Game Settings Screen*)
```
+-------------------------------------------------------------+
| [ < ] Pengaturan Game                                       |
|                                                             |
| Efek Suara (SFX)                                            |
| Suara tombol, denting bintang, dan perayaan      [ ON / OFF ]|
|                                                             |
| Musik Latar (BGM)                                           |
| Musik gamelan instrumen Madura saat bermain      [ ON / OFF ]|
+-------------------------------------------------------------+
```
- **Toggle Efek Suara**: Mengaktifkan atau mematikan bunyi klik dan efek suara gamifikasi.
- **Toggle Musik Latar**: Mengaktifkan atau mematikan alunan musik instrumen gamelan tradisional Madura saat berada di canvas studio.

---

## 4.5 Pusat Keamanan Akun Guru (*Keamanan Akun Screen*)
- **Info Akun Google**: Menampilkan alamat email yang tertaut dan User ID unik.
- **Riwayat Perangkat (*Device Tracker*)**: Menampilkan daftar tipe smartphone dan riwayat waktu login.
- **Tombol "Hapus Akun Permanen"**: Menghapus akun dan seluruh data terkait dari cloud database secara permanen.

---

## 4.6 Pengelolaan Kelas Nonaktif (*Guru Inactive Classes Screen*)
- Menampilkan seluruh kelas yang dinonaktifkan.
- Guru dapat mengaktifkan kembali kelas saat tahun ajaran baru atau menghapusnya secara permanen.

---

## 4.7 Dialog Tentang EPIC & Keluar Akun (*Logout*)
- **Dialog "Tentang EPIC"**: Memuat informasi tim riset pengembang, versi rilis aplikasi, dan misi integrasi etnomatematika budaya Madura.
- **Tombol "Keluar Akun"**: Menghapus sesi login pada perangkat smartphone dan kembali ke Layar Login awal.

---

# BAB 5: PANDUAN PEMECAHAN MASALAH (TROUBLESHOOTING & FAQ)

### ❓ 1. Mengapa saya tidak bisa menekan tombol "MULAI BERMAIN" di Beranda?
> **Solusi**: Periksa sisa Nyawa Anda pada header `[ ❤️ ]`. Jika nyawa bernilai `0`, Anda harus menunggu kuota nyawa terisi kembali penuh secara otomatis pada pukul 00:00 tengah malam.

---

### ❓ 2. Apakah hasil gambar saya hilang jika aplikasi keluar mendadak saat menggambar?
> **Solusi**: **Tidak hilang**. Aplikasi EPIC memiliki fitur *Auto-Save Draft*. Buka kembali aplikasi, lalu pada halaman Beranda lihat modul **"Lanjutkan Draf Gambar"** dan tekan tombol **"Lanjutkan"**.

---

### ❓ 3. Mengapa rekaman suara murid tidak bisa dimulai di Studio Canvas?
> **Solusi**: Pastikan Anda telah memberikan izin akses Mikrofon pada pengaturan smartphone Anda (*Settings $\rightarrow$ Apps $\rightarrow$ EPIC $\rightarrow$ Permissions $\rightarrow$ Microphone $\rightarrow$ Allow*).

---

### ❓ 4. Mengapa saat menekan tombol "Simpan ke Galeri", gambar tidak muncul di galeri HP?
> **Solusi**:
> 1. Pastikan izin akses Penyimpanan/Galeri (*Photos and Videos*) telah diizinkan.
> 2. Buka aplikasi Galeri / Google Photos di HP Anda, lalu cari folder album bernama **`EPIC App`**.

---

### ❓ 5. Sebagai Guru, bagaimana cara membagikan hasil nilai ke orang tua murid?
> **Solusi**:
> 1. Masuk ke tab **Kelas Saya** $\rightarrow$ Pilih kelas yang dituju.
> 2. Buka tab **Info (Pengaturan Kelas)**.
> 3. Tekan tombol **"Ekspor Rapor Karya Siswa ke PDF (.pdf)"**.
> 4. Berkas PDF rapor digital resmi siap dibagikan melalui WhatsApp ke wali murid.

---

### ❓ 6. Layanan Bantuan & Kontak Dukungan Resmi
Jika mengalami kendala teknis lebih lanjut, Anda dapat menghubungi tim pengembang melalui:
- 📧 **Email Layanan Dukungan**: `ecoculturalpattern@gmail.com`
- 🏛️ **Lembaga Pengembang**: Tim Pengembang EPIC (Eco-Cultural Pattern Integrated Canvas)

---

*© 2026 EPIC App - Eco-Cultural Pattern Integrated Canvas. Seluruh Hak Cipta Dilindungi Undang-Undang.*
