# 🌿 Nana — Personal Multi-Wallet Financial Tracker & WA AI Assistant

**Nana** adalah aplikasi pencatat keuangan personal modern, privat, dan serba gratis dengan desain visual **Luminous Ledger** (Hyper-Smooth Glassmorphism & Soft Neumorphism). Dilengkapi dengan pencatatan instan via **WhatsApp Bot**, analisis kebiasaan finansial berbasis **AI (via 9Router Gateway)**, serta arsitektur **Self-Hosted** di Proxmox home server.

---

## 🚀 Fitur Utama

- **Multi-Wallet Unlimited:** Kelola dompet tunai, rekening bank (BCA, Mandiri), dan e-wallet (GoPay, OVO, Dana) tanpa batasan.
- **Pencatatan Instan via WhatsApp Bot:** Catat transaksi hanya dengan mengirim pesan chat (misal: `"Beli nasi goreng 15rb pake gopay"`).
- **AI Financial Insights:** Integrasi 9Router AI Gateway untuk analisis pengeluaran & saran finansial cerdas.
- **Luminous Ledger UI:** Antarmuka Flutter modern dengan skema warna Deep Emerald Green (`#003527`), Soft Mint (`#f8faf6`), backdrop glassmorphism, serta tipografi *JetBrains Mono* untuk nominal keuangan.
- **Self-Hosted & Private:** Data tersimpan penuh di infrastructure milik sendiri (Node.js API + Database + Cloudflare Tunnel).

---

## 🛠️ Prasyarat (Prerequisites)

Sebelum memulainya, pastikan lingkungan pengembangan Anda telah terinstal:

- **Git**
- **Node.js** (v18.x atau lebih baru) & **npm**
- **Flutter SDK** (v3.19.x atau lebih baru) & **Dart SDK**
- **Android Studio** / **VS Code** (dengan ekstensi Flutter & Dart)

---

## 📥 Panduan Clone Repository

Jalankan perintah berikut di terminal Anda untuk mengkloning repository:

```bash
git clone https://github.com/username/nana.git
cd nana
```

---

## ⚙️ Panduan Instalasi & Pengembangan

Struktur repository ini terdiri dari dua bagian utama:
1. `nana_backend/` — Backend Rest API (Node.js & TypeScript) + WA Bot Integration
2. `nana_mobile/` — Frontend App (Flutter / Dart)

### 1. Setup Backend (`nana_backend`)

1. Masuk ke direktori backend:
   ```bash
   cd nana_backend
   ```

2. Instal dependencies:
   ```bash
   npm install
   ```

3. Buat file konfigurasinya `.env` (salin dari `.env.example` jika tersedia atau buat baru):
   ```env
   PORT=3000
   DATABASE_URL="file:./nana.db"
   AI_GATEWAY_URL="http://192.168.18.27:20128"
   ```

4. Jalankan backend dalam mode pengembangan (development):
   ```bash
   npm run dev
   ```
   *Backend akan berjalan di `http://localhost:3000`.*

---

### 2. Setup Mobile App (`nana_mobile`)

1. Buka terminal baru dan masuk ke direktori mobile:
   ```bash
   cd nana_mobile
   ```

2. Unduh dependencies Flutter:
   ```bash
   flutter pub get
   ```

3. Pastikan perangkat Android terhubung (atau jalankan Emulator Android / Chrome):
   ```bash
   flutter devices
   ```

4. Jalankan aplikasi dalam mode pengembangan:
   ```bash
   flutter run
   ```

---

## 📂 Struktur Proyek

```text
nana/
├── PRD.md                 # Product Requirement Document
├── .gitignore             # Root Git ignore rules
├── nana_backend/          # REST API Node.js & Baileys WA Bot
│   ├── src/               # Core source code backend
│   ├── nana.db            # Local SQLite database (ignored by git)
│   └── package.json
└── nana_mobile/           # Flutter Mobile Application
    ├── lib/               # App views, models, providers, UI tokens
    ├── pubspec.yaml       # Flutter dependencies
    └── android/           # Native Android configuration
```

---

## 📄 Lisensi

Dikembangkan untuk penggunaan personal & open-source oleh **Naufal Pinandhita (Nopal🐐)**.
