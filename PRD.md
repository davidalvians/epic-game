



PRODUCT REQUIREMENTS DOCUMENT
EPIC
Ecocultural Pattern Innovation Creator
Game Edukasi Matematika Berbasis Budaya Madura
Versi	1.0.0
Tanggal	30 Mei 2026
Status	Draft - In Development
Platform	Android (Flutter)
Tech Stack	Flutter + Firebase + Gemini AI
 
1. Ringkasan Eksekutif

1.1 Deskripsi Produk
EPIC (Ecocultural Pattern Innovation Creator) adalah aplikasi game edukasi mobile berbasis Android yang menggabungkan pembelajaran matematika dasar dengan pengenalan budaya dan lingkungan Madura. Aplikasi ini dirancang khusus untuk siswa Sekolah Dasar (SD) dengan menghadirkan pengalaman belajar yang menyenangkan, interaktif, dan kontekstual.

1.2 Tujuan Produk
•	Meningkatkan pemahaman matematika dasar anak SD melalui pendekatan gamifikasi
•	Memperkenalkan budaya dan lingkungan Madura secara menarik dan kontekstual
•	Menyediakan platform monitoring bagi guru untuk memantau perkembangan murid
•	Menghadirkan pengalaman belajar yang adaptif dan personal melalui penilaian AI

1.3 Target Pengguna
Segmen	Deskripsi	Kebutuhan Utama
Murid SD	Anak usia 6-12 tahun, kelas 1-6 SD	Game yang fun, mudah digunakan, dan memotivasi
Guru SD	Pengajar SD yang ingin memantau progress murid	Dashboard monitoring nilai dan aktivitas murid
Admin EPIC	Tim pengelola platform (developer)	Manajemen user, konten, dan konfigurasi AI

1.4 Proposisi Nilai
•	Satu-satunya game edukasi matematika yang terintegrasi dengan budaya lokal Madura
•	Penilaian karya menggunakan AI (Google Gemini) yang personal per siswa
•	Sistem kelas digital yang memudahkan guru memantau progress murid secara real-time
•	Leaderboard kompetitif per kelas yang memotivasi siswa untuk berprestasi
 
2. Arsitektur Sistem

2.1 Komponen Sistem
Komponen	Teknologi	Fungsi
Mobile App	Flutter (Android)	Aplikasi utama untuk murid dan guru
Admin Panel	Flutter Web	Dashboard monitoring dan manajemen konten
Backend	Firebase (Firestore, Auth, Storage)	Database, autentikasi, penyimpanan file
AI Scoring	Google Gemini API (per-user OAuth)	Penilaian karya digital secara otomatis
Cloud Function	Firebase Functions	Re-scoring otomatis dan notifikasi

2.2 Model User — Hybrid (Model C)
Sistem menggunakan model hierarki tiga tingkat:
•	Admin EPIC: Akses penuh ke admin panel web, verifikasi guru, kelola konten dan konfigurasi AI
•	Guru: Akun terverifikasi, bisa membuat kelas, memantau murid, melihat laporan
•	Murid: Akun dasar, main game, submit karya, join kelas (opsional)

Catatan Penting
Bergabung ke kelas bersifat OPSIONAL untuk murid. Murid tetap bisa memainkan semua game dan submit karya tanpa bergabung ke kelas manapun. Namun fitur Leaderboard Kelas hanya tersedia bagi murid yang telah bergabung ke setidaknya satu kelas.

2.3 Struktur Database Firebase
Koleksi utama di Firestore:
•	users/{uid}: Data profil lengkap semua user (murid, guru, admin)
•	usernames/{username}: Index username untuk validasi keunikan real-time
•	kelas/{kelasId}: Data kelas beserta daftar murid dan guru pengampu
•	guru_verifikasi/{requestId}: Permohonan verifikasi guru beserta bukti
•	artworks/{artworkId}: Semua karya yang telah disubmit beserta nilai AI
•	leaderboard_global/{userId}: Data poin untuk leaderboard global
•	leaderboard_kelas/{kelasId}/members/{userId}: Data poin per kelas
•	app_config/game_settings: Konfigurasi instrumen penilaian AI per game/level
•	app_config/templates/{kategori}_{level}: URL template gambar per level
 
3. Sistem Autentikasi & Onboarding

3.1 Metode Login
Aplikasi EPIC HANYA menggunakan Google Sign-In sebagai metode autentikasi. Login email dan password tidak tersedia. Keputusan ini diambil karena:
•	Memungkinkan integrasi Gemini AI per-user tanpa biaya server (OAuth Google)
•	Lebih mudah untuk anak SD (tidak perlu ingat password)
•	Keamanan lebih tinggi (dikelola Google)
•	Hampir semua anak SD sudah memiliki akun Google/Gmail

Perubahan dari Versi Saat Ini
Form registrasi email+password yang sudah ada (Nama Lengkap, Email, Password, Konfirmasi Password, Nama Sekolah, Provinsi, Kabupaten/Kota, Kecamatan) akan DIGANTIKAN sepenuhnya dengan alur Google Sign-In + Onboarding Screen.

3.2 Tiga Metode Login
EPIC menyediakan tiga metode login yang saling melengkapi:
Metode	Cara Kerja	Cocok Untuk	Aktifkan Gemini AI
1. Google Sign-In	Tap tombol Google lalu pilih akun	HP sendiri, penggunaan sehari-hari	Otomatis saat daftar
2. Scan QR Code	Generate QR di HP utama, scan di HP lain	Anak SD, HP tanpa akun Google aktif	Token sudah tersimpan
3. Kode 6 Digit	Generate kode di HP utama, ketik di HP lain	HP tanpa kamera, situasi darurat	Token sudah tersimpan

Penting
Mendaftar akun baru HANYA bisa dengan Google Sign-In. QR Code dan Kode 6 Digit hanya untuk LOGIN ke akun yang sudah ada di perangkat lain.

3.3 Alur Autentikasi Lengkap
A. Pengguna Baru — Daftar Pertama Kali
1.	User tap tombol Masuk dengan Google
2.	Google OAuth popup muncul — user pilih akun Google
3.	Google meminta izin scope tambahan: email, profile, dan generativelanguage untuk Gemini AI
4.	User klik Izinkan — wajib untuk fitur penilaian AI
5.	Firebase membuat akun baru secara otomatis
6.	Sistem deteksi isProfileComplete = false, redirect ke Onboarding Screen
7.	User mengisi data tambahan di Onboarding Screen
8.	Data disimpan ke Firestore, isProfileComplete = true, geminiPermission = true
9.	Redirect ke Home Screen

B. Login dengan Google di HP Lama
10.	User tap Masuk dengan Google
11.	Google silent sign-in — tidak perlu ketik password jika akun sudah ada di HP
12.	Sistem cek isProfileComplete = true, langsung ke Home

C. Login dengan QR Code di HP Lain
13.	Di HP utama: buka Profil, tap Buat Kode Masuk
14.	Firebase generate token unik, simpan di Firestore dengan expiry 10 menit
15.	HP utama tampilkan QR Code dan kode 6 digit secara bersamaan
16.	Di HP lain: buka EPIC, tap Scan QR Code
17.	Izinkan akses kamera, arahkan ke QR Code di HP utama
18.	Aplikasi decode QR, ekstrak token, validasi ke Firebase
19.	Firebase konfirmasi token valid dan belum expired, login berhasil
20.	Token langsung di-invalidate (single use), tidak bisa dipakai lagi
21.	Redirect ke Home Screen

D. Login dengan Kode 6 Digit di HP Lain
22.	Di HP utama: buka Profil, tap Buat Kode Masuk
23.	Tampil QR Code dan kode 6 digit (format: XXX-XXX)
24.	Di HP lain: buka EPIC, tap Masuk dengan Kode
25.	Ketik 6 digit yang terlihat di HP utama
26.	Firebase validasi kode, login berhasil
27.	Kode langsung expired setelah digunakan (single use)
28.	Redirect ke Home Screen

3.4 Spesifikasi Teknis Sistem Kode Masuk
Aspek	Spesifikasi
Format Kode	6 digit numerik, format tampilan XXX-XXX, contoh: 472-193
Masa Berlaku	10 menit sejak digenerate
Penggunaan	Single use — langsung expired setelah 1x dipakai
Batas Generate	Maksimal 3 kode aktif per user per jam (anti-spam)
Penyimpanan	Firestore collection: login_codes/{code} dengan field uid, expiredAt, used
QR Content	JSON: type=epic_login, code=472193, uid=abc123
Package QR Generate	qr_flutter: ^4.1.0
Package QR Scan	mobile_scanner: ^5.0.0
Keamanan	Code di-hash sebelum simpan di Firestore, validasi server-side

3.5 Tampilan Layar Login
Halaman Login Utama
•	Tombol Masuk dengan Google — menonjol, warna primary EPIC
•	Divider atau
•	Tombol Scan QR Code — dengan ikon kamera
•	Tombol Masuk dengan Kode — dengan ikon angka
•	Teks: Belum punya akun? Daftar otomatis saat login dengan Google!

Halaman Scan QR (di HP Lain)
•	Layar kamera aktif dengan overlay frame persegi untuk arahkan QR
•	Teks panduan: Arahkan kamera ke QR Code di HP utama kamu
•	Tombol Ketik Kode Manual di bagian bawah sebagai alternatif
•	Animasi scanning yang responsif

Halaman Ketik Kode 6 Digit (di HP Lain)
•	6 kotak input terpisah (3-3) dengan auto-focus ke kotak berikutnya
•	Keyboard numerik otomatis muncul
•	Tombol Scan QR Sebagai Gantinya di bagian atas
•	Teks panduan: Lihat kode di HP utama kamu: Profil > Buat Kode Masuk

Halaman Buat Kode Masuk (di HP Utama)
•	QR Code besar di tengah menggunakan package qr_flutter
•	Kode 6 digit besar di bawah QR dalam format XXX-XXX
•	Countdown timer yang terus berkurang
•	Progress bar visual yang mengecil seiring waktu
•	Tombol Buat Kode Baru untuk regenerate
•	Peringatan: Jangan tunjukkan kode ini ke orang yang tidak kamu kenal!

3.3 Onboarding Screen
Muncul HANYA untuk pengguna baru, setelah Google Sign-In berhasil. Data profil yang diambil otomatis dari Google: email dan foto profil.

Data Wajib Diisi (Semua User)
Field	Tipe	Validasi	Keterangan
Nama Lengkap	Text Input	Wajib, min 3 karakter	Pre-fill dari nama Google, bisa diedit
Username	Text Input	Wajib, unik, 4-20 karakter, alphanumeric + underscore	Cek real-time ke Firestore
Nama Sekolah	Text Input	Wajib, min 5 karakter	Contoh: SDN 1 Bangkalan
Role	Toggle/Chips	Wajib pilih salah satu	Murid atau Guru

Data Tambahan (Khusus Murid, Opsional)
Field	Tipe	Keterangan
Kelas	Dropdown	1 SD sampai 6 SD
Provinsi	Text Input	Provinsi asal sekolah
Kabupaten/Kota	Text Input	Kabupaten/kota asal sekolah
Kecamatan	Text Input	Kecamatan asal sekolah

Data Tambahan (Khusus Guru — Wajib untuk Verifikasi)
Field	Tipe	Keterangan
Upload Bukti Mengajar	File Upload (JPG/PDF)	SK Guru, Kartu GTK, atau ID resmi guru
Mata Pelajaran	Text Input	Opsional: mata pelajaran yang diajarkan

Status Guru Pending
Setelah guru mengirim permohonan verifikasi, akun guru akan ditandai status "pending". Guru tetap bisa menggunakan aplikasi sebagai murid biasa sambil menunggu verifikasi. Notifikasi akan dikirim via email setelah admin memproses permohonan (estimasi 1x24 jam).

3.4 Izin Gemini AI (Wajib)
Saat Google OAuth, aplikasi meminta scope tambahan untuk Gemini AI. Jika user menolak:
•	User tetap bisa bermain semua game
•	User TIDAK bisa submit karya (karya tidak akan dinilai)
•	Setiap kali menekan tombol "Kumpulkan", akan muncul dialog penjelasan dan tombol untuk memberikan izin
•	Izin bisa diberikan kapan saja melalui menu Pengaturan
 
4. Kategori Game & Sistem Level

4.1 Gambaran Umum Kategori Game
EPIC memiliki 3 kategori game utama, masing-masing dengan 4 level yang semakin menantang. Setiap kategori menggabungkan konsep matematika dengan elemen budaya Madura yang otentik.
Kategori	Tema Budaya	Konsep Matematika	Jenis Game
Keris	Keris Madura — senjata tradisional khas Madura	Geometri dasar, garis, pola, bangun datar	Menggambar Digital
Batik	Batik Madura — kain tradisional berwarna cerah	Pola berulang, simetri, geometri	Menggambar Digital
Anyaman	Anyaman Madura — kerajinan tangan tradisional	Bilangan genap/ganjil, kelipatan, pola grid	Mewarnai Grid

4.2 Detail Level — Kategori Keris
Level	Judul	Materi Matematika	Deskripsi Tugas	Ketatness
1	Gagang Keris	Garis & bangun datar sederhana	Gambar dan hias gagang keris menggunakan alat geometri. Template gagang tersedia sebagai panduan.	KETAT (80% kriteria)
2	Bilah Keris	Pola berulang & garis berkelok	Gambar bilah keris dengan luk (kelok) menggunakan panduan template. Hias dengan pola berulang.	KETAT (75% kriteria)
3	Warangka (Sarung)	Geometri & kombinasi bangun	Gambar warangka keris menggunakan minimal 3 jenis bangun datar berbeda. Ada referensi motif.	SEDANG (60% kriteria)
4	Keris Sempurna	Semua konsep + kreativitas	Buat keris Madura lengkap dan original. Bebas berekspresi dengan panduan minimal.	BEBAS (40% kriteria)

4.3 Detail Level — Kategori Batik
Level	Judul	Materi Matematika	Deskripsi Tugas	Ketatness
1	Pola Garis Berulang	Pola bilangan & pengulangan	Buat motif batik dengan pola garis berulang (contoh: merah-biru-merah-biru). Ikuti pola yang diberikan.	KETAT (80% kriteria)
2	Simetri Cermin	Simetri & pencerminan	Sisi kiri kanvas sudah terisi. Lengkapi sisi kanan secara simetris cermin.	KETAT (75% kriteria)
3	Motif Geometri Madura	Bangun datar & kombinasi	Buat motif batik Madura menggunakan minimal 3 jenis bangun datar (stempel). Ada referensi motif asli.	SEDANG (60% kriteria)
4	Batik Madura Originalku	Semua konsep + kreativitas	Buat batik Madura original. Wajib pakai warna khas Madura (merah, hitam, kuning emas).	BEBAS (40% kriteria)

4.4 Detail Level — Kategori Anyaman
Level	Judul	Materi Matematika	Deskripsi Tugas	Grid	Ketatness
1	Ganjil & Genap	Bilangan ganjil & genap	Isi sel bernomor GENAP dengan merah, sel GANJIL dengan biru. Nomor tampil di setiap sel.	8x8	KETAT (80%)
2	Kelipatan Warna	Kelipatan bilangan	Warnai grid: kelipatan 2 = merah, kelipatan 3 = kuning, kelipatan 5 = biru, sisanya putih.	10x10	KETAT (75%)
3	Pola Diagonal	Pola diagonal & berulang	Buat pola diagonal dengan warna berulang setiap 3 diagonal. Diagonal pertama sudah diisi.	12x12	SEDANG (60%)
4	Anyaman Bebas Madura	Kreativitas + semua konsep	Buat anyaman Madura original. Minimal 3 warna khas Madura, isi minimal 60% grid.	14x14	BEBAS (40%)
 
5. Mekanisme Game

5.1 Sistem Timer
•	Durasi pengerjaan: 15 menit per level
•	Timer countdown ditampilkan di header layar game
•	Warna timer berubah: hijau (>2 menit), kuning (1-2 menit), merah (<1 menit)
•	Timer otomatis PAUSE saat aplikasi di-minimize atau ditutup (background state)
•	Timer LANJUT dari posisi terakhir saat aplikasi dibuka kembali
•	Jika waktu habis: tampil dialog tawaran penambahan waktu menggunakan nyawa

5.2 Sistem Nyawa
•	Setiap pemain memiliki maksimal 3 nyawa (ditampilkan sebagai ikon hati ❤️)
•	Nyawa dapat digunakan untuk menambah waktu +15 menit saat waktu habis
•	1 nyawa = +15 menit tambahan (bisa digunakan berkali-kali selama masih ada nyawa)
•	Nyawa di-reset menjadi penuh (3) setiap hari pukul 00:00 WIB secara otomatis
•	Jumlah nyawa tersisa selalu terlihat di header layar game

5.3 Sistem Draft & Lanjutkan
Setiap sesi permainan yang belum selesai tersimpan otomatis sebagai draft:
•	Draft disimpan setiap 30 detik dan saat aplikasi di-background
•	Draft muncul di section "Lanjutkan" di halaman Home, posisi DI BAWAH "Misi Harian"
•	Klik draft: lanjut dari posisi terakhir dengan sisa waktu sebelumnya
•	Jika user masuk ke level yang memiliki draft: muncul dialog pilihan Lanjutkan atau Mulai Baru
•	Pilih Mulai Baru: draft lama dihapus, timer reset 15 menit, template dipilih ulang
•	Draft terhapus otomatis setelah karya berhasil disubmit

5.4 Tools Menggambar (Game Keris & Batik)
Tools Keris
Tool	Deskripsi	Fitur Tambahan
Pensil	4 jenis: Bolpoin, Pensil, Spidol, Cat Air	Ketebalan bisa diatur (slider 1-30px), opacity berbeda per jenis
Bangun Datar	Insert bentuk geometri ke canvas	Select, resize (handle kanan/bawah/pojok), pindah posisi, ubah warna, ubah ketebalan, duplikat, hapus
Penghapus	Hapus coretan di canvas	Ketebalan bisa diatur
Garis Lurus	Gambar garis lurus presisi	Drag untuk tentukan arah dan panjang

Tools Batik
Tool	Deskripsi	Fitur Tambahan
Pensil	4 jenis: Bolpoin, Pensil, Spidol, Cat Air	Sama seperti tools Keris
Stempel Motif	Insert simbol/motif batik ke canvas	Pilihan: Bintang, Bunga, Daun, Air, Awan, Api, Petir, Hati, Bulan Sabit, Silang, Ceklis, Panah. Bisa resize, pindah, duplikat, hapus, ubah warna
Penghapus	Hapus coretan di canvas	Ketebalan bisa diatur
Garis Lurus	Gambar garis lurus presisi	Drag untuk tentukan arah dan panjang

Canvas Menggambar
•	Rasio A4 (1:1.414) untuk output yang bisa dicetak
•	Zoom in/out dengan gestur 2 jari (InteractiveViewer)
•	Template PNG transparan
•	Bisa ganti template selama game berlangsung
•	Undo/Redo untuk coretan pensil
•	Hapus semua dengan konfirmasi dialog

5.5 Tools Anyaman (Game Anyaman)
•	Grid interaktif — tap atau drag untuk mewarnai sel
•	Pilihan ukuran grid: 8x8, 10x10, 12x12, 16x16
•	Palet warna 12 warna utama + color picker kustom
•	Mode penghapus untuk menghapus warna sel
•	Pola dasar otomatis: Catur, Vertikal, Horizontal, Zig-zag
•	Progress pengisian ditampilkan dalam persentase (0-100%)
•	Nomor sel ditampilkan di grid untuk level 1 dan 2

5.6 Sistem Submit & Penilaian
29.	User selesai dan menekan tombol "Kumpulkan"
30.	Muncul dialog konfirmasi submit
31.	Sistem capture canvas menjadi gambar PNG
32.	Gambar di-compress (max 512x512px, quality 70%) untuk efisiensi token AI
33.	Sistem ambil token OAuth Gemini milik user (refresh otomatis jika expired)
34.	Sistem ambil instrumen penilaian dari Firebase sesuai kategori & level
35.	Panggil Gemini API menggunakan token user (quota milik user, bukan server)
36.	Gemini mengembalikan: skor (0-100), grade, dan feedback teks
37.	Karya + nilai disimpan ke Firestore
38.	Poin user di-update di leaderboard global dan kelas (jika bergabung kelas)
39.	Draft dihapus dari penyimpanan lokal
40.	Navigasi ke halaman hasil karya
 
6. Sistem Penilaian AI (Google Gemini)

6.1 Arsitektur AI Scoring
Sistem menggunakan Google Gemini API dengan model OAuth per-user. Setiap pengguna menggunakan kuota Gemini miliknya sendiri yang diperoleh melalui izin OAuth saat login Google.

Keunggulan Model Per-User
Dengan model OAuth per-user, setiap pengguna mendapatkan kuota gratis Gemini sendiri (1.000 request/hari untuk Flash-Lite). Ini berarti platform EPIC tidak mengeluarkan biaya AI meskipun jumlah pengguna terus bertambah. Sistem ini dapat menskalakan ke jutaan pengguna tanpa biaya tambahan.

6.2 Spesifikasi Teknis AI
Aspek	Spesifikasi
Model AI	Google Gemini 2.5 Flash-Lite (default), Flash untuk level 3-4
Kuota per User	1.000 request/hari (gratis, dari akun Google user)
Input	Gambar PNG ter-compress (max 512x512px) + prompt instrumen penilaian
Output	JSON: {skor: 0-100, grade: S/A/B/C/D, feedback: string}
Latency	Estimasi 2-5 detik per penilaian
Fallback	Mock scoring + flag "pending_rescore" jika token expired atau quota habis

6.3 Sistem Grade
Grade	Rentang Skor	Label	Warna Badge
S	90 - 100	Luar Biasa! 🌟	Emas (#FFD700)
A	80 - 89	Hebat! 🎉	Hijau (#22C55E)
B	70 - 79	Bagus! 👍	Biru (#3B82F6)
C	60 - 69	Cukup 😊	Oranye (#F97316)
D	50 - 59	Perlu Latihan 💪	Merah (#EF4444)
E	0 - 49	Coba Lagi! 🔄	Abu (#6B7280)

6.4 Instrumen Penilaian per Kategori/Level
Setiap kombinasi kategori + level memiliki instrumen penilaian tersendiri yang dapat dikonfigurasi melalui Admin Panel. Instrumen menggunakan template prompt dinamis dengan variabel:
•	konteks_budaya: Penjelasan budaya Madura yang relevan
•	materi_matematika: Konsep matematika yang diajarkan di level ini
•	kriteria_1, kriteria_2, kriteria_3: Kriteria penilaian spesifik
•	bobot_1, bobot_2, bobot_3: Bobot persentase tiap kriteria (total harus 100%)

Contoh Instrumen — Keris Level 1
Komponen	Nilai
Konteks Budaya	Gagang keris Madura memiliki ukiran khas yang mencerminkan keberanian dan ketangguhan budaya Madura
Materi Matematika	Geometri dasar: garis lurus, garis lengkung, dan pola sederhana
Kriteria 1	Kerapian dan ketepatan garis (40%)
Kriteria 2	Kreativitas penggunaan warna (30%)
Kriteria 3	Kelengkapan mengisi kanvas (30%)

6.5 Skenario Error & Fallback
Skenario Error	Penanganan
Token OAuth expired	Refresh token otomatis → coba lagi. Jika gagal: tampilkan dialog login ulang
Quota harian habis (429)	Gunakan mock score → flag karya sebagai "pending_rescore" → re-score esok hari
Koneksi internet terputus	Tampilkan pesan error → tombol coba lagi
Gemini API error	Log error → gunakan mock score → flag pending_rescore → notifikasi admin
User tidak grant izin	Blokir submit → tampilkan dialog penjelasan → tombol berikan izin
 
7. Galeri Karya

7.1 Halaman Galeri
•	Menampilkan semua karya yang telah disubmit oleh user yang login
•	Layout grid 2 kolom dengan childAspectRatio 0.6
•	Filter berdasarkan kategori: Semua, Keris, Batik, Anyaman
•	Setiap kartu menampilkan: thumbnail karya, badge grade, judul, level, tanggal, poin
•	Empty state khusus jika galeri masih kosong

7.2 Halaman Detail Karya
•	Gambar karya tampil penuh dengan zoom interaktif (2 jari)
•	Header: tombol back, tombol download, tombol hapus
•	Info panel bawah: judul, kategori, level, tanggal
•	Badge grade menonjol di pojok kanan
•	Chips statistik: skor, waktu pengerjaan, poin didapat, nyawa digunakan
•	Kotak "Komentar Juri AI" menampilkan feedback dari Gemini
•	Tombol "Unduh ke Galeri HP" — simpan karya sebagai PNG ke galeri HP
•	Efek confetti otomatis muncul untuk karya Grade S
•	Karya yang sudah disubmit tidak bisa diedit kembali
 
8. Sistem Kelas & Fitur Guru

8.1 Fitur Kelas untuk Murid
•	Bergabung ke kelas bersifat opsional
•	Masuk kelas menggunakan kode unik dari guru (format: EPIC-XXXX)
•	Satu murid bisa bergabung ke beberapa kelas sekaligus
•	Menu "Kelas Saya" menampilkan daftar kelas yang diikuti
•	Setelah bergabung kelas: poin dari setiap karya yang disubmit otomatis masuk ke leaderboard kelas tersebut

8.2 Tampilan Guru di Aplikasi Mobile
Setelah terverifikasi, guru mendapat tampilan khusus berbeda dari murid:
Halaman Home Guru
•	Ringkasan: jumlah kelas, total murid, rata-rata nilai kelas
•	Daftar kelas yang dimiliki beserta kode kelas
•	Karya terbaru dari murid-murid
•	Top 3 murid minggu ini berdasarkan poin

Bottom Navigation Guru
•	Home: ringkasan dashboard guru
•	Kelas: manajemen semua kelas
•	Ranking: leaderboard global dan per kelas
•	Profil: pengaturan akun guru

8.3 Fitur Manajemen Kelas (Guru)
•	Buat kelas baru: nama kelas, tingkat/kelas, mata pelajaran
•	Kode kelas unik digenerate otomatis (format EPIC-XXXX)
•	Lihat daftar murid yang bergabung
•	Hapus murid dari kelas
•	Arsipkan kelas yang sudah tidak aktif
•	Lihat nilai dan progress per murid dalam kelas
•	Leaderboard kelas real-time
•	Export laporan kelas (nilai per murid) — link ke admin panel web

8.4 Verifikasi Guru
Status	Deskripsi	Akses
Pending	Baru mendaftar sebagai guru, belum diverifikasi	Hanya bisa akses sebagai murid biasa
Approved	Sudah diverifikasi oleh admin EPIC	Akses penuh fitur guru (buat kelas, monitor murid)
Rejected	Permohonan ditolak admin (bukti tidak valid)	Bisa submit ulang dengan bukti yang benar
 
9. Sistem Leaderboard & Poin

9.1 Perhitungan Poin
Poin didapat dari nilai AI saat submit karya. Poin yang diterima sama dengan skor AI (0-100) per karya yang disubmit. Tidak ada pengurangan poin.

9.2 Leaderboard Global
•	Menampilkan ranking semua user EPIC berdasarkan total poin
•	Update real-time setiap ada submit karya baru
•	Tidak pernah di-reset
•	Menampilkan: foto profil, nama, username, total poin, ranking
•	User bisa lihat posisi rankingnya sendiri di bagian bawah (sticky)

9.3 Leaderboard Kelas
•	Hanya tersedia untuk murid yang sudah bergabung ke minimal 1 kelas
•	Update real-time setiap ada submit karya baru dari anggota kelas
•	Pilih kelas mana yang ingin dilihat leaderboard-nya (jika ikut beberapa kelas)
•	Menampilkan: ranking, foto profil, nama, username, total poin dalam kelas
•	Guru dan murid yang bergabung kelas sama dapat melihat leaderboard kelas yang sama
 
10. Admin Panel (Web)

10.1 Spesifikasi Teknis
Aspek	Spesifikasi
Platform	Flutter Web
Project	Proyek Flutter terpisah dari mobile app (epic_admin/)
Database	Firebase yang sama dengan mobile app
Deploy	Firebase Hosting (gratis)
URL	admin.epic-app.web.app (atau custom domain)
Akses	Hanya akun dengan role "admin" di Firestore

10.2 Dashboard Utama
Halaman pertama setelah login admin, menampilkan statistik real-time:
•	Total user terdaftar (murid + guru)
•	Total karya yang disubmit (hari ini dan keseluruhan)
•	Total kelas aktif
•	Guru yang menunggu verifikasi (notifikasi jika ada)
•	Grafik aktivitas pengguna 7 hari terakhir
•	Distribusi grade karya (pie chart: S, A, B, C, D, E)
•	Game/kategori paling banyak dimainkan (bar chart)
•	Log aktivitas terbaru (karya baru, user baru, guru baru)
•	Status AI scoring: jumlah berhasil, error rate, karya pending re-score

10.3 Manajemen User
Tab Murid
•	Tabel daftar semua murid dengan kolom: Nama, Username, Email, Sekolah, Total Poin, Karya Disubmit, Kelas (jumlah), Terakhir Aktif, Aksi
•	Filter: cari nama/username/email, filter by kelas, filter by rentang poin
•	Aksi: Lihat Detail, Suspend Akun
•	Halaman Detail Murid: profil lengkap, semua karya + nilai, progress per kategori/level, grafik aktivitas, riwayat poin

Tab Guru
•	Tabel daftar semua guru dengan kolom: Nama, Username, Email, Sekolah, Jumlah Kelas, Jumlah Murid, Status Verifikasi, Aksi
•	Aksi: Verifikasi (Approve/Reject), Lihat Kelas, Suspend Akun
•	Halaman Verifikasi: lihat bukti yang diupload, input catatan, tombol Approve/Reject
•	Notifikasi email otomatis ke guru setelah admin memproses permohonan

10.4 Manajemen Kelas
•	Tabel semua kelas: Nama Kelas, Kode, Nama Guru, Jumlah Murid, Sekolah, Rata-rata Nilai, Status, Aksi
•	Aksi: Lihat Detail, Arsipkan
•	Halaman Detail Kelas: info kelas, leaderboard real-time, daftar murid + nilai, karya terbaru, tombol export laporan

10.5 Monitoring AI Scoring
•	Statistik: jumlah karya dinilai hari ini, error rate, jumlah user yang sudah grant izin Gemini
•	Error log: timestamp, user, jenis error, status penanganan
•	Tab "Karya Pending Re-Score": daftar karya yang gagal dinilai AI
•	Tombol "Re-Score Semua" dan "Re-Score Pilih" — admin bisa trigger penilaian ulang menggunakan API key server

10.6 Manajemen Konten (Konfigurasi Game)
A. Template Menggambar per Level
•	Tampilkan semua template yang ada per kategori dan level
•	Upload template baru: wajib PNG dengan background transparan
•	Setiap level bisa memiliki beberapa pilihan template (pemain pilih saat mulai)
•	Aktifkan/nonaktifkan template tanpa menghapus
•	Preview template sebelum diaktifkan

B. Instrumen Penilaian AI
•	Form konfigurasi per kombinasi kategori + level
•	Field yang bisa diisi: konteks budaya, materi matematika, kriteria 1-3, bobot 1-3
•	Validasi: total bobot harus 100%
•	Preview prompt lengkap yang akan dikirim ke Gemini
•	Fitur "Test dengan Gambar Sample": upload gambar → lihat hasil penilaian AI → validasi sebelum simpan ke production
•	Riwayat perubahan instrumen (audit log)

C. Konfigurasi Teks Game
•	Deskripsi setiap level (ditampilkan saat memilih level)
•	Petunjuk pengerjaan per level
•	Pesan motivasi per grade (ditampilkan di halaman hasil)

10.7 Laporan & Export
Jenis Laporan	Data yang Dicakup	Format Export
Nilai Semua User	Nama, username, total poin, rata-rata nilai, karya per kategori	Excel (.xlsx) & PDF
Nilai Per Kelas	Nama murid, nilai per game, total poin, ranking kelas	Excel (.xlsx) & PDF
Aktivitas User	User aktif per hari/minggu/bulan, game terpopuler	PDF
Karya & Nilai AI	Semua karya beserta skor AI, grade, kategori, level, tanggal	Excel (.xlsx)
Guru & Kelas	Daftar guru, kelas yang dimiliki, jumlah murid	Excel (.xlsx)
•	Filter laporan berdasarkan: rentang tanggal, kategori game, kelas, sekolah
•	Export langsung dari admin panel tanpa perlu tools tambahan
 
11. Fitur Aplikasi Lainnya
11.1 Halaman Profil tambahan
•	Foto profil (dari Google, bisa diganti)
•	Nama lengkap, username, email
•	Nama sekolah, kelas, lokasi
•	Statistik: total karya, rata-rata skor, grade terbanyak
•	Riwayat poin
•	Pengaturan: izin Gemini AI, notifikasi, tentang aplikasi
•	Tombol logout

11.3 Karakter & Avatar (Roadmap)
Fitur karakter profil yang bisa dibeli dengan poin (dikembangkan di versi mendatang): 
12. Roadmap Development

12.1 Status Saat Ini (Sudah Selesai)
Fase	Fitur	Status
Fase 1	Canvas A4, InteractiveViewer zoom/pan, template selector	Selesai ✅
Fase 2	Game anyaman — grid interaktif, warna, pola	Selesai ✅
Fase 3	Stempel/bangun datar — select, move, resize, hapus, duplikat	Selesai ✅
Fase 4	Timer 15 menit, sistem nyawa, reset harian	Selesai ✅
Fase 5	Sistem draft & lanjutkan, DraftService, pause otomatis	Selesai ✅
Fase 6	Submit karya, AI mock scoring, galeri redesign, confetti	Selesai ✅

12.2 Rencana Selanjutnya
Fase	Fitur	Estimasi	Prioritas
Fase 7A	Update autentikasi: wajib Google Login + onboarding screen	1 minggu	Tinggi
Fase 7B	Gemini AI real scoring via OAuth per-user	1 minggu	Tinggi
Fase 7C	Sistem kelas di mobile app (join kelas, leaderboard kelas)	1 minggu	Tinggi
Fase 7D	Fitur guru di mobile app (dashboard, manajemen kelas)	1 minggu	Tinggi
Fase 8A	Admin panel web — fondasi, login, dashboard	1 minggu	Tinggi
Fase 8B	Admin panel — manajemen user & verifikasi guru	1 minggu	Tinggi
Fase 8C	Admin panel — manajemen kelas & leaderboard	1 minggu	Sedang
Fase 8D	Admin panel — manajemen konten & instrumen AI	1 minggu	Sedang
Fase 8E	Admin panel — laporan & export Excel/PDF	1 minggu	Sedang
Fase 9	Core gameplay batik (pola berulang, simetri, geometri)	2 minggu	Sedang
Fase 10	Core gameplay anyaman (tantangan matematika per level)	2 minggu	Sedang
Fase 11	Sistem karakter & avatar (toko poin)	Roadmap	Rendah
Fase 12	Misi harian & sistem reward	Roadmap	Rendah
Fase 13	Testing menyeluruh & bug fixing	2 minggu	Tinggi
Fase 14	Launch ke Google Play Store	1 minggu	Tinggi
 
13. Persyaratan Non-Fungsional

13.1 Performa
•	Waktu loading halaman utama: < 3 detik pada koneksi 4G
•	Waktu penilaian AI: < 5 detik per karya
•	Canvas menggambar: minimal 60 FPS tanpa lag
•	Ukuran APK: < 50 MB untuk download pertama

13.2 Keamanan
•	Semua komunikasi menggunakan HTTPS/TLS
•	Firebase Security Rules: user hanya bisa baca/edit data miliknya sendiri
•	Token OAuth Gemini disimpan secara aman (tidak di SharedPreferences biasa)
•	Admin panel hanya bisa diakses oleh akun dengan role "admin"
•	Rate limiting untuk mencegah spam submit karya

13.3 Kompatibilitas
•	Android: minimum API level 21 (Android 5.0 Lollipop)
•	Target SDK: Android 14 (API 34)
•	Ukuran layar: 4.7 inch - 6.7 inch
•	RAM minimum: 2 GB

13.4 Aksesibilitas
•	Teks minimum 14sp untuk keterbacaan anak SD
•	Tombol minimum 44x44dp untuk kemudahan tap
•	Kontras warna memenuhi standar WCAG AA
•	Bahasa Indonesia sepenuhnya (tidak ada teks Inggris yang terlihat user)
 
14. Lampiran

14.1 Struktur Folder Project
Mobile App (epic_app/)
•	lib/core/: constants, routes, middleware, services, theme, utils
•	lib/data/: models, repositories, services, game_config (roadmap)
•	lib/features/auth/: login & onboarding (update)
•	lib/features/games/menggambar/: drawing game + widgets/
•	lib/features/games/anyaman/: anyaman game + widgets/
•	lib/features/galeri/: galeri tab & detail screen
•	lib/features/kelas/: sistem kelas murid & guru (baru)
•	lib/features/home/: home tab murid & guru
•	lib/features/ranking/: leaderboard global & kelas
•	lib/features/profile/: profil & pengaturan
•	lib/shared/: session controller, widgets global

Admin Panel (epic_admin/)
•	lib/features/dashboard/: halaman utama & statistik
•	lib/features/users/: manajemen murid & guru
•	lib/features/kelas/: manajemen kelas
•	lib/features/ai_monitoring/: monitoring AI & re-score
•	lib/features/konten/: template, instrumen AI, teks game
•	lib/features/laporan/: export laporan Excel & PDF

14.2 Daftar Package Flutter
Package	Versi	Fungsi
google_sign_in	^6.x	Google OAuth + Gemini scope
firebase_core	^2.x	Firebase initialization
firebase_auth	^4.x	Autentikasi
cloud_firestore	^4.x	Database
firebase_storage	^11.x	Penyimpanan gambar karya
get	^4.x	State management & routing
cached_network_image	^3.x	Caching gambar dari network
confetti	^0.7	Efek confetti grade S
gal	^1.x	Simpan gambar ke galeri HP
flutter_colorpicker	^1.x	Color picker kustom
http	^1.x	HTTP request ke Gemini API
path_provider	^2.x	Akses direktori lokal (draft)
shared_preferences	^2.x	Penyimpanan lokal sederhana
intl	^0.x	Format tanggal & angka



EPIC — Ecocultural Pattern Innovation Creator
Product Requirements Document v1.0.0 | 30 Mei 2026 | Confidential
