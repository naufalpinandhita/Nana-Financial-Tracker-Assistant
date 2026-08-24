## **PRODUCT REQUIREMENT DOCUMENT (PRD)** 

# **NANA** 

#### _Personal Multi-Wallet Financial Tracker & WA AI Assistant_ 

Design System: Luminous Ledger | Version 1.0 | Tanggal: 24 August 2026 | Author: Naufal Pinandhita (Nopal🐐) 

### **1. Executive Summary** 

Nana adalah aplikasi pencatat keuangan personal (Personal Financial Tracker) modern, serba gratis, dan privat dengan desain visual 'Luminous Ledger' — perpaduan canggih antara Hyper-Smooth Glassmorphism dan Neumorphism lembut. Aplikasi ini dirancang untuk menjawab keterbatasan aplikasi catatan keuangan populer di Play Store yang umumnya membatasi fitur vital (seperti multi-wallet, laporan tanpa batas, atau pencatatan AI) di balik sistem berlangganan (paywall). Nana mengusung arsitektur hybrid: aplikasi Flutter mobile yang super halus berbasis Deep Emerald Green (#003527) & Soft Mint background (#f8faf6) dengan dukungan backend self-hosted di Proxmox home server dan integrasi 9Router AI Gateway serta WhatsApp Bot. 

### **2. Problem Statement** 

Banyak aplikasi manajer keuangan di pasaran (seperti Money Manager, Wallet, dll) memiliki beberapa kendala utama bagi pengguna individual / solo developer: 

- **Fitur Terkunci (Paywall):** Fitur dasar seperti membuat lebih dari 2 dompet, ekspor data, atau analisis kategori mendalam membutuhkan langganan bulanan/tahunan. 

- **Input Manual yang Membosankan:** Proses mencatat transaksi harian terasa lambat jika harus membuka aplikasi, memilih dompet, memilih kategori, dan memasukkan nominal setiap kali bertransaksi. 

- **Privasi & Ketergantungan Cloud Luar:** Data keuangan sensitif tersimpan di server pihak ketiga tanpa kontrol penuh dari pengguna. 

### **3. Target Audience** 

Pengguna utama Nana adalah solo user / pengembang pribadi (Nopal🐐) serta pengguna tingkat lanjut yang menginginkan kontrol penuh atas data keuangan mereka tanpa 

biaya berlangganan. Persona pengguna mencakup: 

- **Solo Gamer / Student / Freelancer:** Mempunyai beberapa rekening & e-wallet (BCA, GoPay, OVO, Cash) dan ingin memantau pengeluaran harian dengan cepat. 

- **Home-Lab Enthusiast:** Menyukai solusi self-hosted yang memanfaatkan Proxmox & AI gateway lokal (9Router) untuk privasi dan efisiensi biaya. 

### **4. Product Overview & Core Features** 

#### **4.1 Fitur Utama (Core Features)** 

|**#**|**Fitur**|**Deskripsi**|**Prioritas**|
|---|---|---|---|
|1|Multi-Wallet<br>Management|Membuat &<br>mengelola dompet<br>tanpa batas (Cash,<br>Bank BCA/Mandiri, E-<br>Wallet<br>GoPay/OVO/Dana)<br>dengan saldo<br>terpisah.|P0 (MVP)|
|2|Pencatatan Transaksi|Input cepat<br>pemasukan,<br>pengeluaran, dan<br>transfer antardompet<br>lengkap dengan<br>tanggal, kategori, dan<br>catatan.|P0 (MVP)|
|3|Visualisasi<br>Dashboard & Chart|Grafk pengeluaran<br>bulanan, pie chart<br>per kategori, dan tren<br>saldo menggunakan<br>f_chart Flutter yang<br>halus.|P0 (MVP)|
|4|Luminous Ledger UI<br>Design|Antarmuka Hyper-<br>Smooth Glassmorphic|P0 (MVP)|
|||(Deep Emerald Green<br>#003527, Soft Mint<br>#f8faf6, dual-light<br>shadows, JetBrains<br>Mono font).||
|5|WhatsApp Bot<br>Logging|Catat transaksi instan<br>via chat WA (misal:<br>'Beli nasi goreng 15rb<br>pake gopay')<br>langsung masuk ke<br>database Nana.|P1 (High)|
|6|AI Financial Advisor<br>& Insights|Integrasi 9Router AI<br>Gateway untuk<br>analisis kebiasaan<br>boros dengan<br>komponen khusus<br>berpendar Indigo.|P1 (High)|
|7|Self-Hosted Sync &<br>Tunnel|Koneksi aman mobile<br>app ke Proxmox<br>home server via<br>Cloudfare Tunnel<br>tanpa perlu IP publik<br>statis.|P1 (High)|



#### **4.2 Non-Goals (Out of Scope MVP)** 

- Integrasi otomatis Open Banking (OAUTH Bank Direct API) — karena kendala izin & birokrasi perbankan Indonesia. 

- Multi-user / Multi-family sharing — MVP dirancang khusus untuk penggunaan personal (solo user). 

### **5. Technical Requirements & Design System Specification** 

#### **5.1 Specification Design System (Luminous Ledger)** 

Nana menerapkan sistem desain Luminous Ledger — kombinasi Glassmorphism dan soft-surface Neumorphism dengan nuansa Deep Emerald Green yang melambangkan 

stabilitas finansial: 

- **Warna Utama:** Primary Emerald (#003527), Primary Container (#064e3b), Surface Tint (#2b6954), Soft Mint Background (#f8faf6), On-Surface text (#191c1b), Error (#ba1a1a). 

- **Warna Aksesori & AI:** Mint (#c3ecd7) untuk Pemasukan, Amber untuk Alert Pengeluaran, dan Indigo pendar khusus untuk panel AI Insights. 

- **Tipografi Dual-Font:** Inter untuk UI general & headline. JetBrains Mono untuk seluruh nominal finansial, saldo, angka tabel, dan data kuantitatif. 

- **Glassmorphism & Depth:** Kartu utama menggunakan fill putih transparan (80% opacity), backdrop-blur 20px, 1px border putih 50% opacity, serta rounded radius 24px (rounded-xl). 

- **Dual-Light Shadows:** Elemen interaktif menggunakan bayangan ganda (dark shadow di kanan-bawah + subtle white highlight di kiri-atas) untuk impresi fisik tactile. 

#### **5.2 Arsitektur Sistem** 

Nana menggunakan arsitektur Decoupled Client-Server: 

- Frontend: Flutter App (Android) dengan state management modern (Riverpod/Provider), fl_chart, dan Luminous Ledger design tokens. 

- Backend API: Node.js (Hono / Fastify) berjalan di LXC Container Proxmox (192.168.18.42 / 192.168.18.27). 

- Public Gateway: Cloudflare Tunnel untuk mengekspos endpoint REST API ke mobile app secara aman dan gratis. 

- AI Subsystem: 9Router Proxy (192.168.18.27:20128) untuk inference LLM 

- (Gemini/DeepSeek) dalam menganalisis data keuangan. 

- Database: PostgreSQL / SQLite untuk penyimpanan transaksi & dompet. 

#### **5.3 Tech Stack Table** 

|**Layer**|**Teknologi**|**Keterangan / Alasan**|
|---|---|---|
|Mobile Client|Flutter (Dart)|UI super smooth, komponen<br>chart bawaan mantap<br>(f_chart), menerapkan<br>Luminous Ledger UI.|
|Backend API|Node.js (Hono / Fastify)|Ringan, responsif, mudah di-<br>deploy di LXC Proxmox.|
|Database|PostgreSQL / SQLite|Penyimpanan relational yang<br>cepat dan andal untuk data<br>saldo & transaksi.|
|Public Network|Cloudfare Tunnel|Gratis, mengamankan<br>endpoint tanpa expose IP<br>publik rumah.|
|AI Integration|9Router Proxy|Memanfaatkan gateway AI<br>lokal yang sudah berjalan di<br>http://192.168.18.27:20128.|
|WA Bot|Baileys / WA Cloud API|Menerima pesan transaksi<br>dari WhatsApp dan<br>mengubahnya jadi JSON<br>transaksi.|



### **6. Success Metrics** 

- **Performa UI:** Waktu muat dashboard & render chart under 1 detik di perangkat Android dengan 60 FPS smooth animation. 

- **Kecepatan Pencatatan:** Waktu untuk mencatat 1 transaksi manual < 5 detik; via WhatsApp Bot < 3 detik. 

- **Ketersediaan System:** Backend dapat diakses 24/7 dari jaringan luar melalui Cloudflare Tunnel di home server Proxmox. 

### **7. Milestones & Timeline** 

|**Fase**|**Target Output**|**Durasi Estimasi**|
|---|---|---|
|Fase 1: Setup & Theme|Inisialisasi Flutter project<br>(Nana), setup Luminous<br>Ledger design tokens,<br>SQLite/Postgres DB & Hono<br>API.|Minggu 1|
|Fase 2: Mobile Core UI|Implementasi Glassmorphic<br>UI, Dual-light shadows, Wallet<br>Management, & Form<br>Transaksi.|Minggu 2|
|Fase 3: Charts & Dashboard|Integrasi f_chart (JetBrains<br>Mono numbers) untuk<br>visualisasi pengeluaran<br>bulanan & tren saldo.|Minggu 3|
|Fase 4: WA Bot & 9Router|Integrasi Baileys WA Bot +<br>9Router AI Proxy + AI Insights<br>Panel berpendar Indigo.|Minggu 4|
|Fase 5: Proxmox Deploy|Deploy backend ke LXC<br>Proxmox & konfgurasi<br>Cloudfare Tunnel.|Minggu 5|



### **8. Risks & Mitigations** 

|**Potensi Risiko**|**Tingkat Risiko**|**Strategi Mitigasi**|
|---|---|---|
|Home Server Down / Mati<br>Listrik|Sedang|Sediakan opsi ofine-frst di<br>Flutter (simpan di local<br>SQLite HP, sync saat server<br>online kembali).|
|Nomor WhatsApp Terblokir<br>(Baileys)|Sedang|Gunakan WhatsApp Cloud<br>API resmi atau batasi rate-<br>limit pesan bot WA khusus<br>nomor sendiri.|
|Skema Data Transaksi Salah|Rendah|Buat validasi ketat di Hono<br>API dan gunakan skema<br>database relational yang<br>terstruktur.|



### **9. Competitive Landscape** 

|**Aplikasi / Platform**|**Model Bisnis**|**Kelebihan**|**Kekurangan / Gap**<br>**vs Nana**|
|---|---|---|---|
|Money Manager<br>(PlayStore)|Freemium / Paywall|UI kaya ftur,<br>populer.|Multi-wallet dibatasi,<br>iklan mengganggu,<br>tidak ada AI/WA<br>integration.|
|Wallet by<br>BudgetBakers|Subscription|Konek bank otomatis.|Mahal<br>(berlangganan), ftur<br>pro banyak terkunci<br>di versi gratis.|
|Nana (Our Product)|Self-Hosted / Free|Gratis selamanya,<br>Luminous Ledger<br>Glassmorphism UI,<br>WA bot input, AI<br>9Router.|Perlu setup awal di<br>home server<br>(Proxmox).|



### **10. Appendix** 

#### **10.1 Design System Specification (Design Tokens)** 

|**Category**|**Key / Name**|**Value / Spec**|
|---|---|---|
|Color - Core|primary|#003527 (Deep Emerald<br>Green)|
|Color - Core|primary-container|#064e3b|
|Color - Core|background|#f8faf6 (White Smoke / Soft<br>Mint)|
|Color - Core|on-surface|#191c1b (Dark Slate)|
|Color - Accent|secondary-container (Income)|#c3ecd7 (Soft Mint)|
|Color - Accent|error (Expense/Alert)|#ba1a1a (Amber/Red)|
|Color - Special|AI Insights Glow|Indigo Translucent Outer<br>Glow|
|Typography|General / Headings|Inter (48px Display, 32px<br>Headline, 16px Body)|
|Typography|Financial Figures|JetBrains Mono (14px, 500<br>Weight, 0.02em Tracking)|
|Shapes|Card Radius|rounded-xl (24px / 1.5rem)|
|Shapes|Input / Buttons Radius|rounded-md (8px) / rounded-<br>full|
|Elevation|Glass Base Card|Fill #FFFFFF (80% opacity),<br>Blur 20px, Border #FFFFFF<br>(50% opacity)|
|Elevation|Dual-Light Shadows|Bottom-right dark shadow<br>(10% opacity) + Top-left white<br>highlight|



#### **10.2 Gelosarium / Istilah Branded** 

- **9Router Proxy:** AI Gateway lokal yang berjalan di port 20128 home server Proxmox untuk menyalurkan prompt ke model LLM. 

- **Proxmox VE:** Virtualization environment di 192.168.18.42 yang meng-host container backend Nana. 

