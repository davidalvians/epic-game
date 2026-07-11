# Implementation Plan: Admin Panel Web EPIC — Final


   **`admin_colors.dart`:**
   ```
   sidebar:        #1E293B  (dark slate)
   sidebarHover:   #334155
   sidebarActive:  #3B82F6
   background:     #F1F5F9
   surface:        #FFFFFF
   primary:        #3B82F6  (biru)
   success:        #22C55E  (hijau)
   warning:        #F59E0B  (kuning)
   danger:         #EF4444  (merah)
   textPrimary:    #0F172A
   textSecondary:  #64748B
   border:         #E2E8F0
   ```

   **`admin_fonts.dart`:** Google Fonts Inter (400, 500, 600, 700)

   **`admin_sizes.dart`:**
   ```
   sidebarWidth:     240px
   headerHeight:     64px
   paddingPage:      32px
   paddingCard:      24px
   borderRadius:     12px
   ```

---

Autentikasi Admin

### Screen: `AdminLoginScreen`

**URL:** `/login`

**Tampilan:**
```
┌────────────────────────────────────────────────────┐
│                                                    │
│         [Logo EPIC + teks "Admin Panel"]           │
│                                                    │
│   ┌────────────────────────────────────────┐       │
│   │                                        │       │
│   │   Selamat Datang, Admin EPIC           │       │
│   │   Masuk untuk mengelola platform       │       │
│   │                                        │       │
│   │   ┌──────────────────────────────┐     │       │
│   │   │  [G] Masuk dengan Google     │     │       │
│   │   └──────────────────────────────┘     │       │
│   │                                        │       │
│   │   ⚠️ Hanya untuk akun admin EPIC       │       │
│   └────────────────────────────────────────┘       │
│                                                    │
└────────────────────────────────────────────────────┘
```

Layout Shell (Navigasi Utama)

### Komponen: `AdminLayout`

**Struktur layout keseluruhan:**
```
┌──────────────────────────────────────────────────────────┐
│ SIDEBAR (240px)    │ HEADER (64px tinggi, full width)    │
│                    │──────────────────────────────────── │
│ [Logo EPIC]        │ KONTEN HALAMAN                      │
│                    │                                     │
│ [Menu navigasi]    │ (area scrollable)                   │
│                    │                                     │
│                    │                                     │
│ [Info admin]       │                                     │
└────────────────────┴─────────────────────────────────────┘
```

### Komponen: `AdminSidebar`

**Tampilan:**
```
┌─────────────────────────┐
│  ⚡ EPIC Admin Panel     │
├─────────────────────────┤
│                         │
│  MENU UTAMA             │
│  ▣ Dashboard            │← /dashboard
│  👥 Pengguna            │← /users
│  ✅ Verifikasi Guru  [3]│← /verifikasi (badge merah jika ada pending)
│  🏫 Kelas               │← /kelas
│                         │
│  KONTEN & AI            │
│  🤖 AI Monitoring       │← /ai-monitoring
│  📝 Konten Game         │← /konten
│                         │
│  LAPORAN                │
│  📊 Laporan & Export    │← /laporan
│                         │
├─────────────────────────┤
│  [Foto] Nama Admin      │
│         admin@epic.com  │
│  [Logout]               │
└─────────────────────────┘
```

### Komponen: `AdminHeader`

**Tampilan:**
```
┌─────────────────────────────────────────────────────────┐
│  [≡ toggle sidebar]  Judul Halaman    [🔔] [Foto Admin] │
└─────────────────────────────────────────────────────────┘
```


Dashboard Utama

### Screen: `DashboardScreen`

**URL:** `/dashboard`

**Tampilan Lengkap:**
```
┌─────────────────────────────────────────────────────────────┐
│ Dashboard                              [Refresh] [Tanggal]  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  STATISTIK UTAMA (6 card)                                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                    │
│  │ 👨‍🎓 Murid │ │ 👨‍🏫 Guru  │ │⚠️ Pending│                    │
│  │   1.234  │ │   89     │ │    3     │ ← merah jika > 0   │
│  │ terdaftar│ │ aktif    │ │ verifikasi│                    │
│  └──────────┘ └──────────┘ └──────────┘                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                    │
│  │ 🎨 Karya │ │🤖 Pending│ │ 🏫 Kelas │                    │
│  │  5.678   │ │ Re-Score │ │   234    │                    │
│  │ total    │ │   12     │ │ aktif    │                    │
│  └──────────┘ └──────────┘ └──────────┘                    │
│                                                             │
│  ┌────────────────────────┐  ┌──────────────────────────┐  │
│  │ Distribusi Grade Karya │  │ Game Terpopuler          │  │
│  │                        │  │                          │  │
│  │  [Donut Chart]         │  │  [Bar Chart Horizontal]  │  │
│  │  S: 234 (12%)          │  │  Batik    ████████ 2.1k  │  │
│  │  A: 567 (28%)          │  │  Keris    ██████   1.8k  │  │
│  │  B: 890 (44%)          │  │  Anyaman  ████     1.2k  │  │
│  │  C, D, E: ...          │  │                          │  │
│  └────────────────────────┘  └──────────────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Aktivitas Terbaru                              [→]  │   │
│  ├─────────────────────────────────────────────────────┤   │
│  │ [Foto] Budi Santoso submit Batik Level 2 - Grade A  │   │
│  │ [Foto] Siti Rahayu submit Keris Level 1 - Grade B   │   │
│  │ [Foto] Ahmad Fauzi bergabung ke EPIC                │   │
│  │ [Foto] Pak Amir mendaftar sebagai guru              │   │
│  │ [Foto] ...                                          │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```
---

Manajemen User & Verifikasi Guru

### Screen: `UsersScreen`

**URL:** `/users`

**Tampilan — 2 Tab:**

**Tab 1: MURID**
```
┌──────────────────────────────────────────────────────────────┐
│  Pengguna             [Tab: MURID ●] [Tab: GURU]             │
├──────────────────────────────────────────────────────────────┤
│  🔍 Cari nama/username/email...    [Filter Sekolah ▼] [Reset]│
├──────────────────────────────────────────────────────────────┤
│  Nama          │ Username   │ Sekolah    │ Poin  │ Karya │Aksi│
├──────────────────────────────────────────────────────────────┤
│  [Foto] Budi S.│ @budi_s    │ SDN 1 Bdg │  890  │  12   │ 👁 │
│  [Foto] Siti R.│ @siti_r    │ SDN 2 Sby │  760  │   9   │ 👁 │
│  ...                                                         │
├──────────────────────────────────────────────────────────────┤
│  Menampilkan 1-20 dari 1.234 murid     [< Prev] [Next >]     │
└──────────────────────────────────────────────────────────────┘
```

**Tab 2: GURU**
```
┌──────────────────────────────────────────────────────────────┐
│  Pengguna             [Tab: MURID] [Tab: GURU ●]             │
├──────────────────────────────────────────────────────────────┤
│  🔍 Cari nama/username/email...    [Status ▼]    [Reset]     │
├──────────────────────────────────────────────────────────────┤
│  Nama       │ Sekolah    │ Kelas │ Murid │ Status      │ Aksi │
├──────────────────────────────────────────────────────────────┤
│  [F] Pak A. │ SDN 1 Bdg  │  3   │  87  │ ✅ Approved  │ 👁 ✅│
│  [F] Bu B.  │ SDN 2 Mdr  │  0   │   0  │ ⏳ Pending   │ 👁 ✅│
│  [F] Pak C. │ SDN 3 Sby  │  2   │  45  │ ❌ Rejected  │ 👁 ✅│
│  ...                                                         │
└──────────────────────────────────────────────────────────────┘
```

**Badge status:** Approved (hijau), Pending (kuning), Rejected (merah), None (abu)

---

### Screen: `MuridDetailScreen`

**URL:** `/users/murid/:uid`

```
┌──────────────────────────────────────────────────────────────┐
│  ← Kembali    Detail Murid                                   │
├──────────────────────────────────────────────────────────────┤
│  ┌──────────┐  Budi Santoso                                  │
│  │[Foto 80x]│  @budi_santoso                                 │
│  │          │  budi@gmail.com                                │
│  └──────────┘  SDN 1 Bandung, Kelas 4 SD                    │
│                Bergabung: 12 Jan 2026  │ Aktif: 3 hari lalu  │
│                                                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │ Total    │ │ Rata-rata│ │ Grade    │ │ Kelas    │       │
│  │ 890 poin │ │ Nilai 78 │ │ Terbanyak│ │ Diikuti  │       │
│  │          │ │          │ │    B     │ │    2     │       │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘       │
│                                                             │
│  KARYA MURID (12 karya)                    [Filter ▼]       │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                       │
│  │[Gbr] │ │[Gbr] │ │[Gbr] │ │[Gbr] │                       │
│  │Batik1│ │Keris2│ │Btwk3 │ │Any1  │                       │
│  │Grade A│ │GradeB│ │GradeS│ │GradeC│                       │
│  └──────┘ └──────┘ └──────┘ └──────┘                       │
└──────────────────────────────────────────────────────────────┘
```

---

Route /users/guru/:uid 


Screen: GuruDetailScreen

┌─────────────────────────────────────┐
│  ← Kembali    Detail Guru           │
├─────────────────────────────────────┤
│  [Foto] Bu Siti Nuraini             │
│         @siti_guru                  │
│         SDN 1 Bangkalan             │
│         Status: ✅ Approved          │
│         Terverifikasi: 10 Jan 2026  │
├─────────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐          │
│  │ 2 Kelas  │ │ 45 Murid │          │
│  │ Aktif    │ │ Total    │          │
│  └──────────┘ └──────────┘          │
├─────────────────────────────────────┤
│  KELAS YANG DIMILIKI                │
│  Kelas 4A • 23 murid • Aktif        │
│  Kelas 5B • 22 murid • Nonaktif     │
├─────────────────────────────────────┤
│  BUKTI MENGAJAR                     │
│  [Preview gambar bukti]             │
│  [🔗 Buka di tab baru]              │
└─────────────────────────────────────┘

### Screen: `VerifikasiListScreen`

**URL:** `/verifikasi`

```
┌──────────────────────────────────────────────────────────────┐
│  Verifikasi Guru                   3 permohonan menunggu     │
├──────────────────────────────────────────────────────────────┤
│  [Tab: PENDING (3) ●] [Tab: APPROVED] [Tab: REJECTED]        │
├──────────────────────────────────────────────────────────────┤
│  [Foto] Pak Ahmad Fauzi                                      │
│         SDN 1 Bangkalan · Mendaftar 3 hari lalu              │
│         ⏳ Menunggu verifikasi                   [Review →]   │
├──────────────────────────────────────────────────────────────┤
│  [Foto] Bu Siti Nuraini                                      │
│         SDN 2 Pamekasan · Mendaftar 1 hari lalu              │
│         ⏳ Menunggu verifikasi                   [Review →]   │
├──────────────────────────────────────────────────────────────┤
│  ...                                                         │
└──────────────────────────────────────────────────────────────┘
```

---

### Screen: `VerifikasiDetailScreen`

**URL:** `/verifikasi/:requestId`

```
┌──────────────────────────────────────────────────────────────┐
│  ← Kembali    Review Permohonan Guru                         │
├───────────────────────────────┬──────────────────────────────┤
│  INFO GURU                    │  BUKTI MENGAJAR              │
│                               │                              │
│  [Foto profil 100px]          │  ┌────────────────────────┐  │
│  Pak Ahmad Fauzi              │  │                        │  │
│  pak.ahmad@gmail.com          │  │  [Preview Gambar /     │  │
│  SDN 1 Bangkalan              │  │   PDF Viewer]          │  │
│  Matematika                   │  │                        │  │
│  Mendaftar: 1 Juni 2026       │  │  bukti_sk_ahmad.jpg    │  │
│                               │  │  [🔗 Buka di Tab Baru] │  │
│                               │  └────────────────────────┘  │
├───────────────────────────────┴──────────────────────────────┤
│  CATATAN ADMIN (wajib diisi jika Reject)                     │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Tulis catatan untuk guru...                         │    │
│  └──────────────────────────────────────────────────────┘    │
├──────────────────────────────────────────────────────────────┤
│  [✅ Setujui (Approve)]              [❌ Tolak (Reject)]      │
│                                                              │
│  * Email notifikasi akan dikirim otomatis ke guru            │
└──────────────────────────────────────────────────────────────┘
```

---
 Manajemen Kelas

### Screen: `KelasListScreen`

**URL:** `/kelas`

```
┌──────────────────────────────────────────────────────────────┐
│  Manajemen Kelas                             [Filter Status ▼]│
├──────────────────────────────────────────────────────────────┤
│  🔍 Cari nama kelas / kode / nama guru...                    │
├──────────────────────────────────────────────────────────────┤
│  Nama Kelas   │ Kode     │ Guru       │ Murid │Status │ Aksi  │
├──────────────────────────────────────────────────────────────┤
│  Kelas 4A     │ EPIC-7X2K│ Pak Ahmad  │  32  │🟢Aktif│  👁   │
│  Kelas 5B     │ EPIC-9M3N│ Bu Siti    │  28  │🟡Nona │  👁   │
│  Kelas 3C     │ EPIC-4P1Q│ Pak Budi   │  25  │🔵Arsip│  👁   │
│  ...                                                         │
└──────────────────────────────────────────────────────────────┘
```

### Screen: `KelasDetailScreen`

**URL:** `/kelas/:kelasId`

```
┌──────────────────────────────────────────────────────────────┐
│  ← Kembali    Kelas 4A — EPIC-7X2K                           │
├──────────────────────────────────────────────────────────────┤
│  Guru: Pak Ahmad   Sekolah: SDN 1 Bangkalan   Status: Aktif  │
│  Dibuat: 10 Jan 2026  │  Murid: 32  │  Rata-rata: 74.5       │
├───────────────────────┬──────────────────────────────────────┤
│  LEADERBOARD KELAS    │  KARYA TERBARU                       │
│                       │                                      │
│  🥇 Budi S.    890 poin│  [Gbr] Batik L2 - Siti - Grade A    │
│  🥈 Siti R.    760 poin│  [Gbr] Keris L1 - Budi - Grade B    │
│  🥉 Ahmad F.   650 poin│  [Gbr] Anyaman L3 - Ahmad - Grade S │
│  4. Dewi K.   580 poin│  ...                                 │
│  5. ...               │                                      │
├───────────────────────┴──────────────────────────────────────┤
│  DAFTAR MURID (32)                    [Export Laporan Kelas] │
│  Nama       │ Poin  │ Karya │ Grade Terbanyak │ Aktif        │
│  Budi S.    │  890  │  12   │       B         │ 2 hari lalu  │
│  ...                                                         │
└──────────────────────────────────────────────────────────────┘
```

---

AI Monitoring + Manajemen Konten

### Screen: `AiMonitoringScreen`

**URL:** `/ai-monitoring`

```
┌──────────────────────────────────────────────────────────────┐
│  AI Monitoring                                               │
├──────────────────────────────────────────────────────────────┤
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐      │
│  │ Dinilai AI    │ │ Mock Score    │ │ Pending       │      │
│  │ hari ini      │ │ (fallback)    │ │ Re-Score      │      │
│  │    234        │ │    12         │ │    12      🔴  │      │
│  └───────────────┘ └───────────────┘ └───────────────┘      │
├──────────────────────────────────────────────────────────────┤
│  KARYA PENDING RE-SCORE (12)              [Re-Score Semua]   │
├──────────────────────────────────────────────────────────────┤
│  [Gbr]│ Batik L2  │ Budi S.   │ 2 Mei 2026 │ Mock B │ [↻]  │
│  [Gbr]│ Keris L1  │ Siti R.   │ 1 Mei 2026 │ Mock C │ [↻]  │
│  ...                                                         │
│  Keterangan: [↻] = Trigger re-score ulang via Cloud Function │
└──────────────────────────────────────────────────────────────┘
```


---

### Screen: `KontenScreen`

**URL:** `/konten`

**Tab 1: INSTRUMEN PENILAIAN AI**
```
┌──────────────────────────────────────────────────────────────┐
│  Konten Game      [Tab: INSTRUMEN ●] [Tab: TEMPLATE]         │
├──────────────────────────────────────────────────────────────┤
│  Instrumen Penilaian AI per Kategori & Level                 │
│                                                              │
│           Level 1    Level 2    Level 3    Level 4           │
│  Keris   [Edit →]   [Edit →]   [Edit →]   [Edit →]          │
│  Batik   [Edit →]   [Edit →]   [Edit →]   [Edit →]          │
│  Anyaman [Edit →]   [Edit →]   [Edit →]   [Edit →]          │
│                                                              │
│  Setiap card menampilkan preview singkat:                    │
│  ┌────────────────────────────┐                              │
│  │ Batik Level 1              │                              │
│  │ Model: gemini-2.5-flash-lite│                             │
│  │ Kriteria: Pola, Simetri,  │                              │
│  │           Kreativitas     │                              │
│  │ Bobot: 40% / 30% / 30%   │                              │
│  │                  [Edit →] │                              │
│  └────────────────────────────┘                              │
└──────────────────────────────────────────────────────────────┘
```

**Tab 2: TEMPLATE GAMBAR**
```
┌──────────────────────────────────────────────────────────────┐
│  Konten Game      [Tab: INSTRUMEN] [Tab: TEMPLATE ●]         │
├──────────────────────────────────────────────────────────────┤
│  Filter: [Semua ▼] [Keris ▼] [Batik ▼] [Anyaman ▼]         │
│                                         [+ Upload Template]  │
├──────────────────────────────────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│  │ [Preview]│ │ [Preview]│ │ [Preview]│ │[+Upload] │        │
│  │ Keris L1A│ │ Keris L1B│ │ Batik L1A│ │          │        │
│  │ ✅ Aktif  │ │ ✅ Aktif  │ │ ❌ Nonakt│ │          │        │
│  │ [Toggle] │ │ [Toggle] │ │ [Toggle] │ │          │        │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘        │
└──────────────────────────────────────────────────────────────┘
```

**Tab 3: MISI HARIAN (di halaman Konten)**

┌─────────────────────────────────────┐
│  Template Misi Harian               │
│  3 misi aktif per hari              │
│                      [+ Tambah Misi]│
├─────────────────────────────────────┤
│  🎮 Mainkan 2 game hari ini         │
│     Target: 2 │ Reward: 20 poin     │
│     Tipe: play_game  │ ✅ Aktif      │
│     [Edit] [Nonaktifkan]            │
├─────────────────────────────────────┤
│  🎨 Kirim 1 karya                   │
│     Target: 1 │ Reward: 30 poin     │
│     Tipe: submit_artwork │ ✅ Aktif  │
│     [Edit] [Nonaktifkan]            │
└─────────────────────────────────────┘
---

### Screen: `InstrumentFormScreen`

**URL:** `/konten/instrumen/:id`

```
┌──────────────────────────────────────────────────────────────┐
│  ← Kembali    Edit Instrumen: Batik Level 1                  │
├──────────────────────────────────────────────────────────────┤
│  Model AI:  [gemini-2.5-flash-lite ▼]                        │
│                                                              │
│  Konteks Budaya:                                             │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ Batik Madura memiliki motif khas dengan warna...     │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  Materi Matematika:                                          │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ Pola bilangan berulang dan pengulangan geometris...  │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  KRITERIA PENILAIAN           BOBOT    (Total: 100%)         │
│  ┌───────────────────────────┐  [40] %                       │
│  │ Kerapian pola berulang    │                               │
│  └───────────────────────────┘                               │
│  ┌───────────────────────────┐  [30] %                       │
│  │ Kreativitas warna         │                               │
│  └───────────────────────────┘                               │
│  ┌───────────────────────────┐  [30] %                       │
│  │ Kelengkapan kanvas        │                               │
│  └───────────────────────────┘                               │
│  ⚠️ Total bobot: 100% ✅                                      │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ PREVIEW PROMPT LENGKAP                               │    │
│  │ Kamu adalah penilai karya seni digital...            │    │
│  │ KONTEKS BUDAYA: Batik Madura...                      │    │
│  │ ...                                                  │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  [Batal]                              [💾 Simpan Perubahan]  │
└──────────────────────────────────────────────────────────────┘
```
catatan:  KRITERIA PENILAIAN bisa di tambah bisa di kurangi 
---

## FASE 8: Laporan & Export + Cloud Functions

### Screen: `LaporanScreen`

**URL:** `/laporan`

```
┌──────────────────────────────────────────────────────────────┐
│  Laporan & Export                                            │
├──────────────────────────────────────────────────────────────┤
│  Jenis Laporan:  [Nilai Semua User ▼]                        │
│  Rentang Waktu:  [Dari: 01/01/2026] - [Sampai: 31/05/2026]  │
│  Filter Kelas:   [Semua Kelas ▼]                            │
│  Filter Sekolah: [Semua Sekolah ▼]                          │
│                                    [🔍 Tampilkan Preview]    │
├──────────────────────────────────────────────────────────────┤
│  PREVIEW DATA (500 baris pertama)                           │
│  Nama       │ Username │ Total Poin │ Rata-rata │ Karya      │
│  Budi S.    │ @budi_s  │    890     │   78.5    │   12       │
│  ...                                                         │
├──────────────────────────────────────────────────────────────┤
│  [📥 Export Excel (.xlsx)]    [📄 Export PDF]                │
└──────────────────────────────────────────────────────────────┘
```
---
Dari ArtworkModel:
static double multiplierForLevel(int level) {
  case 1: return 1.0;
  case 2: return 1.5;
  case 3: return 2.0;
  case 4: return 3.0;
}

Saat ini multiplier HARDCODE di app!
Kalau mau ubah reward poin per level,
harus update kode dan build ulang APK.

Sebaiknya ada di admin panel:
Tab: KONFIGURASI SISTEM

┌─────────────────────────────────────┐
│  Multiplier Poin per Level          │
│  Level 1: [1.0] x skor AI           │
│  Level 2: [1.5] x skor AI           │
│  Level 3: [2.0] x skor AI           │
│  Level 4: [3.0] x skor AI           │
│                                     │
│  Nyawa Maksimal: [3]                │
│  Durasi Timer:  [900] detik         │
│  Min Skor Unlock Level: [60]        │
│                                     │
│  [Simpan Konfigurasi]               │
└─────────────────────────────────────┘

Disimpan di: app_config/system_settings
Dibaca oleh mobile app saat startup

### Setiap Screen Wajib Memiliki
- ✅ **Loading state** (shimmer atau CircularProgressIndicator)
- ✅ **Empty state** (ilustrasi + teks deskriptif)
- ✅ **Error state** (ikon error + tombol retry)
- ✅ **Konfirmasi dialog** untuk semua aksi destruktif (approve/reject/delete)
- ✅ **Snackbar feedback** setelah setiap aksi berhasil/gagal

### Design Consistency
- Semua teks **Bahasa Indonesia**
- Semua aksi write Firestore harus punya **dialog konfirmasi** dahulu
- Warna badge status konsisten di seluruh app:
  - `pending` = #F59E0B (kuning)
  - `approved` = #22C55E (hijau)
  - `rejected` = #EF4444 (merah)
  - `arsip` = #6366F1 (ungu)
  - `aktif` = #22C55E (hijau)
  - `nonaktif` = #94A3B8 (abu)

---

