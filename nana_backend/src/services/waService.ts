import makeWASocket, {
  DisconnectReason,
  useMultiFileAuthState,
  fetchLatestBaileysVersion,
} from '@whiskeysockets/baileys';
import qrcode from 'qrcode-terminal';
import type Database from 'better-sqlite3';
import { WalletService } from './walletService.js';
import { CategoryService } from './categoryService.js';
import { TransactionService } from './transactionService.js';
import { AiParserService } from './aiParserService.js';

export type WaStatus = 'DISCONNECTED' | 'CONNECTING' | 'CONNECTED';

export interface WaSessionStatus {
  status: WaStatus;
  qrCode: string | null;
  connectedNumber: string | null;
}

/**
 * Manages the WhatsApp socket for a single user.
 * One WaService instance per user — isolated session, isolated state.
 */
export class WaService {
  private db: Database.Database;
  private walletService: WalletService;
  private categoryService: CategoryService;
  private transactionService: TransactionService;
  private aiParserService: AiParserService;

  private sock: any = null;
  private qrCode: string | null = null;
  private status: WaStatus = 'DISCONNECTED';
  private connectedUserJid: string | null = null;
  private isPairingCodePending = false;
  private pendingPairingResolve: ((code: string) => void) | null = null;
  private pendingPairingReject: ((err: Error) => void) | null = null;

  readonly userId: string;
  readonly sessionDir: string;

  constructor(
    userId: string,
    sessionDir: string,
    db: Database.Database,
    walletService: WalletService,
    categoryService: CategoryService,
    transactionService: TransactionService,
    aiParserService: AiParserService,
  ) {
    this.userId = userId;
    this.sessionDir = sessionDir;
    this.db = db;
    this.walletService = walletService;
    this.categoryService = categoryService;
    this.transactionService = transactionService;
    this.aiParserService = aiParserService;
  }

  public getStatus(): WaSessionStatus {
    let connectedNumber: string | null = null;
    if (this.connectedUserJid) {
      const numOnly = this.connectedUserJid.split('@')[0].split(':')[0];
      connectedNumber = `+${numOnly}`;
    }
    return {
      status: this.status,
      qrCode: this.qrCode,
      connectedNumber,
    };
  }

  /**
   * Start or restart the WhatsApp socket.
   * If `forPairingCode` is true, the socket will NOT wait for QR —
   * requestPairingCode() should be called immediately after.
   */
  public async startSocket(forPairingCode = false): Promise<void> {
    // Close existing socket cleanly if any
    if (this.sock) {
      try {
        this.sock.ev.removeAllListeners();
        await this.sock.logout().catch(() => {});
        this.sock.end();
      } catch (_) {}
      this.sock = null;
    }

    try {
      this.status = 'CONNECTING';
      this.qrCode = null;

      const { state, saveCreds } = await useMultiFileAuthState(this.sessionDir);
      const { version } = await fetchLatestBaileysVersion();

      this.sock = makeWASocket({
        version,
        auth: state,
        printQRInTerminal: false,
        // When using pairing code, we skip browser QR flow
        ...(forPairingCode ? { browser: ['Nana Bot', 'Chrome', '1.0.0'] } : {}),
      });

      this.sock.ev.on('creds.update', saveCreds);

      this.sock.ev.on('connection.update', (update: any) => {
        const { connection, lastDisconnect, qr } = update;

        if (qr && !forPairingCode) {
          this.qrCode = qr;
          console.log(`\n[WA:${this.userId}] QR Code ready`);
          qrcode.generate(qr, { small: true });
        }

        if (connection === 'close') {
          const statusCode = (lastDisconnect?.error as any)?.output?.statusCode;
          const shouldReconnect = statusCode !== DisconnectReason.loggedOut;
          this.status = 'DISCONNECTED';
          this.qrCode = null;
          this.isPairingCodePending = false;
          this.connectedUserJid = null;

          // Reject pending pairing code promise if any
          if (this.pendingPairingReject) {
            this.pendingPairingReject(new Error('Connection closed before pairing code was received'));
            this.pendingPairingResolve = null;
            this.pendingPairingReject = null;
          }

          this._persistStatus('DISCONNECTED', null);
          console.log(`[WA:${this.userId}] Connection closed. shouldReconnect=${shouldReconnect}`);

          if (shouldReconnect) {
            setTimeout(() => this.startSocket(), 5000);
          }
        } else if (connection === 'open') {
          this.status = 'CONNECTED';
          this.qrCode = null;
          this.isPairingCodePending = false;
          this.connectedUserJid = this.sock?.user?.id || null;

          if (this.connectedUserJid) {
            const numOnly = this.connectedUserJid.split('@')[0].split(':')[0];
            const formattedNum = `+${numOnly}`;
            // Save connected number to user profile
            this.db.prepare('UPDATE users SET wa_number = ? WHERE id = ?').run(formattedNum, this.userId);
            this._persistStatus('CONNECTED', formattedNum);
            console.log(`[WA:${this.userId}] Connected as ${formattedNum}`);
          }
        }
      });

      this.sock.ev.on('messages.upsert', async (m: any) => {
        if (m.type !== 'notify') return;
        for (const msg of m.messages) {
          await this.handleIncomingMessage(msg);
        }
      });
    } catch (err) {
      console.error(`[WA:${this.userId}] Failed to start socket:`, err);
      this.status = 'DISCONNECTED';
    }
  }

  /**
   * Request an 8-character pairing code for the given phone number.
   * This restarts the socket in pairing-code mode.
   * The phone number must be in E.164 format without '+': e.g. "628123456789"
   */
  public async requestPairingCode(phoneNumber: string): Promise<string> {
    if (this.isPairingCodePending) {
      throw new Error('Permintaan kode pairing sedang dalam proses. Tunggu sebentar.');
    }

    // Normalize phone number: strip all non-digits
    const normalized = phoneNumber.replace(/\D/g, '');
    if (!normalized || normalized.length < 7) {
      throw new Error('Nomor telepon tidak valid');
    }

    this.isPairingCodePending = true;

    try {
      // Start fresh socket in pairing-code mode (no QR)
      await this.startSocket(true);

      // Wait for socket to be ready (connection.update fires with partial state first)
      // Baileys requires requestPairingCode to be called after socket init
      await new Promise<void>((resolve) => setTimeout(resolve, 1500));

      if (!this.sock) {
        throw new Error('Socket tidak tersedia');
      }

      const code: string = await this.sock.requestPairingCode(normalized);
      this.isPairingCodePending = false;

      // Format code with dash for readability: ABCD1234 → ABCD-1234
      const formatted = code.length === 8 ? `${code.slice(0, 4)}-${code.slice(4)}` : code;
      console.log(`[WA:${this.userId}] Pairing code issued: ${formatted}`);
      return formatted;
    } catch (err) {
      this.isPairingCodePending = false;
      throw err;
    }
  }

  /**
   * Disconnect and clean up the socket (e.g. on user logout).
   */
  public async disconnect(): Promise<void> {
    this.status = 'DISCONNECTED';
    this.qrCode = null;
    this.connectedUserJid = null;
    if (this.sock) {
      try {
        this.sock.ev.removeAllListeners();
        await this.sock.logout().catch(() => {});
        this.sock.end();
      } catch (_) {}
      this.sock = null;
    }
    this._persistStatus('DISCONNECTED', null);
  }

  private _persistStatus(status: WaStatus, phoneNumber: string | null) {
    try {
      this.db.prepare(`
        INSERT INTO wa_sessions (user_id, phone_number, status, session_dir, updated_at)
        VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(user_id) DO UPDATE SET
          status = excluded.status,
          phone_number = COALESCE(excluded.phone_number, wa_sessions.phone_number),
          updated_at = CURRENT_TIMESTAMP,
          connected_at = CASE WHEN excluded.status = 'CONNECTED' THEN CURRENT_TIMESTAMP ELSE wa_sessions.connected_at END
      `).run(this.userId, phoneNumber, status, this.sessionDir);
    } catch (err) {
      console.error(`[WA:${this.userId}] Failed to persist session status:`, err);
    }
  }

  private async handleIncomingMessage(msg: any) {
    if (!msg.message) return;

    const text =
      msg.message.conversation ||
      msg.message.extendedTextMessage?.text ||
      msg.message.imageMessage?.caption;

    if (!text || typeof text !== 'string') return;

    const profile = this.db.prepare('SELECT * FROM users WHERE id = ?').get(this.userId) as any;
    if (!profile || profile.wa_bot_enabled !== 1) return;

    const fromJid = msg.key.remoteJid;
    const isFromMe = msg.key.fromMe;

    const cleanOwnerNum = (profile.wa_number || '').replace(/\D/g, '');
    const cleanFromJid = (fromJid || '').replace(/\D/g, '');

    const isSelfChat = isFromMe && cleanFromJid.includes(cleanOwnerNum);
    const isDirectFromOwner = !isFromMe && cleanFromJid.includes(cleanOwnerNum);

    if (!isSelfChat && !isDirectFromOwner) return;

    // Ignore bot's own replies to prevent infinite loop
    if (text.startsWith('✅ *Transaksi Berhasil Dicatat!*') || text.startsWith('❌')) return;

    console.log(`[WA:${this.userId}] Received: "${text}"`);

    const wallets = this.walletService.getAll(this.userId);
    const categories = this.categoryService.getAll(this.userId);

    const parsed = await this.aiParserService.parseTransactionText(
      text,
      wallets.map((w) => ({ id: w.id, name: w.name })),
      categories.map((c) => ({ id: c.id, name: c.name, type: c.type }))
    );

    if (!parsed || parsed.amount <= 0) return;

    let wallet = wallets.find(
      (w) => parsed.wallet_name && w.name.toLowerCase() === parsed.wallet_name.toLowerCase()
    );
    if (!wallet) wallet = wallets[0];

    let category = categories.find(
      (c) => parsed.category_name && c.name.toLowerCase() === parsed.category_name.toLowerCase()
    );

    try {
      const tx = this.transactionService.create(this.userId, {
        wallet_id: wallet.id,
        target_wallet_id: undefined,
        category_id: category?.id,
        type: parsed.type,
        amount: parsed.amount,
        date: parsed.date || new Date().toISOString().split('T')[0],
        note: parsed.note,
      });

      const formattedAmount = new Intl.NumberFormat('id-ID', {
        style: 'currency',
        currency: 'IDR',
        maximumFractionDigits: 0,
      }).format(tx.amount);

      const replyText = `✅ *Transaksi Berhasil Dicatat!*\n\n📌 *Jenis:* ${tx.type === 'expense' ? 'Pengeluaran' : tx.type === 'income' ? 'Pemasukan' : 'Transfer'}\n💵 *Nominal:* ${formattedAmount}\n💳 *Dompet:* ${wallet.name}\n📁 *Kategori:* ${category?.name || 'Umum'}\n📝 *Catatan:* ${tx.note || '-'}`;

      await this.sock.sendMessage(fromJid, { text: replyText });
    } catch (err: any) {
      console.error(`[WA:${this.userId}] Failed to create transaction:`, err);
      await this.sock.sendMessage(fromJid, {
        text: `❌ *Gagal Mencatat Transaksi*\nReason: ${err.message || 'Error internal'}`,
      });
    }
  }
}
