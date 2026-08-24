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

export class WaService {
  private db: Database.Database;
  private walletService: WalletService;
  private categoryService: CategoryService;
  private transactionService: TransactionService;
  private aiParserService: AiParserService;
  
  private sock: any = null;
  private qrCode: string | null = null;
  private status: 'DISCONNECTED' | 'CONNECTING' | 'CONNECTED' = 'DISCONNECTED';
  private sessionDir: string;

  private connectedUserJid: string | null = null;

  constructor(
    db: Database.Database,
    walletService: WalletService,
    categoryService: CategoryService,
    transactionService: TransactionService,
    aiParserService: AiParserService,
    sessionDir: string = './wa_session'
  ) {
    this.db = db;
    this.walletService = walletService;
    this.categoryService = categoryService;
    this.transactionService = transactionService;
    this.aiParserService = aiParserService;
    this.sessionDir = sessionDir;
  }

  public getStatus() {
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

  public async startSocket() {
    try {
      this.status = 'CONNECTING';
      const { state, saveCreds } = await useMultiFileAuthState(this.sessionDir);
      const { version } = await fetchLatestBaileysVersion();

      this.sock = makeWASocket({
        version,
        auth: state,
        printQRInTerminal: false,
      });

      this.sock.ev.on('creds.update', saveCreds);

      this.sock.ev.on('connection.update', (update: any) => {
        const { connection, lastDisconnect, qr } = update;

        if (qr) {
          this.qrCode = qr;
          console.log('\n================ WA BOT QR CODE ================');
          qrcode.generate(qr, { small: true });
          console.log('================================================\n');
        }

        if (connection === 'close') {
          const shouldReconnect =
            (lastDisconnect?.error as any)?.output?.statusCode !== DisconnectReason.loggedOut;
          this.status = 'DISCONNECTED';
          this.qrCode = null;
          console.log('❌ WA Connection closed. Reconnecting status:', shouldReconnect);
          if (shouldReconnect) {
            setTimeout(() => this.startSocket(), 3000);
          }
        } else if (connection === 'open') {
          this.status = 'CONNECTED';
          this.qrCode = null;
          this.connectedUserJid = this.sock?.user?.id || null;
          if (this.connectedUserJid) {
            const numOnly = this.connectedUserJid.split('@')[0].split(':')[0];
            const formattedNum = `+${numOnly}`;
            // Update user profile wa_number automatically with real connected number
            this.db.prepare('UPDATE profile SET wa_number = ? WHERE id = ?').run(formattedNum, 'user_default');
            console.log(`📱 Real WA Number connected & saved to profile: ${formattedNum}`);
          }
          console.log('✅ WA Bot Connection OPEN & ready for self-chat transactions!');
        }
      });

      this.sock.ev.on('messages.upsert', async (m: any) => {
        if (m.type !== 'notify') return;

        for (const msg of m.messages) {
          // Process messages
          await this.handleIncomingMessage(msg);
        }
      });
    } catch (err) {
      console.error('Failed to start WhatsApp socket:', err);
      this.status = 'DISCONNECTED';
    }
  }

  private async handleIncomingMessage(msg: any) {
    if (!msg.message) return;

    // Extract text content
    const text =
      msg.message.conversation ||
      msg.message.extendedTextMessage?.text ||
      msg.message.imageMessage?.caption;

    if (!text || typeof text !== 'string') return;

    // Check profile for WA bot setting
    const profile = this.db.prepare('SELECT * FROM profile WHERE id = ?').get('user_default') as any;
    if (!profile || profile.wa_bot_enabled !== 1) return;

    const fromJid = msg.key.remoteJid;
    const isFromMe = msg.key.fromMe;

    // Check if message is Self-Chat (Message Yourself) or direct chat from owner wa_number
    const cleanOwnerNum = (profile.wa_number || '').replace(/\D/g, '');
    const cleanFromJid = (fromJid || '').replace(/\D/g, '');

    const isSelfChat = isFromMe && cleanFromJid.includes(cleanOwnerNum);
    const isDirectFromOwner = !isFromMe && cleanFromJid.includes(cleanOwnerNum);

    if (!isSelfChat && !isDirectFromOwner) {
      // Ignore chats from other people or group chats
      return;
    }

    // Ignore bot's own responses to prevent infinite loop
    if (text.startsWith('✅ *Transaksi Berhasil Dicatat!*') || text.startsWith('❌')) {
      return;
    }

    console.log(`📩 WA Received transaction prompt: "${text}" from ${fromJid}`);

    // Fetch wallets and categories
    const wallets = this.walletService.getAll();
    const categories = this.categoryService.getAll();

    // Parse transaction using AI service
    const parsed = await this.aiParserService.parseTransactionText(
      text,
      wallets.map((w) => ({ id: w.id, name: w.name })),
      categories.map((c) => ({ id: c.id, name: c.name, type: c.type }))
    );

    if (!parsed || parsed.amount <= 0) {
      // Could not parse transaction
      return;
    }

    // Find wallet
    let wallet = wallets.find(
      (w) => parsed.wallet_name && w.name.toLowerCase() === parsed.wallet_name.toLowerCase()
    );
    if (!wallet) {
      wallet = wallets[0]; // Default to first wallet if unassigned
    }

    // Find category
    let category = categories.find(
      (c) => parsed.category_name && c.name.toLowerCase() === parsed.category_name.toLowerCase()
    );

    try {
      // Create transaction
      const tx = this.transactionService.create({
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

      const replyText = `✅ *Transaksi Berhasil Dicatat!*

📌 *Jenis:* ${tx.type === 'expense' ? 'Pengeluaran' : tx.type === 'income' ? 'Pemasukan' : 'Transfer'}
💵 *Nominal:* ${formattedAmount}
💳 *Dompet:* ${wallet.name}
📁 *Kategori:* ${category?.name || 'Umum'}
📝 *Catatan:* ${tx.note || '-'}`;

      await this.sock.sendMessage(fromJid, { text: replyText });
    } catch (err: any) {
      console.error('Failed to create transaction from WA:', err);
      const errorReply = `❌ *Gagal Mencatat Transaksi*\nReason: ${err.message || 'Error internal'}`;
      await this.sock.sendMessage(fromJid, { text: errorReply });
    }
  }
}
