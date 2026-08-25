import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { z } from 'zod';
import type Database from 'better-sqlite3';
import os from 'os';
import { OAuth2Client } from 'google-auth-library';
import { WalletService } from './services/walletService.js';
import { CategoryService } from './services/categoryService.js';
import { TransactionService } from './services/transactionService.js';
import { WaServiceManager } from './services/waServiceManager.js';
import { AiParserService } from './services/aiParserService.js';
import { seedDefaultCategories } from './db/connection.js';
import { generateToken, verifyToken, hashPassword, comparePassword } from './utils/auth.js';
import { cryptoNative } from './utils/crypto.js';

const googleClient = new OAuth2Client();

export function createApp(db: Database.Database, waManager?: WaServiceManager, aiParserService?: AiParserService) {
  const app = new Hono();

  app.use('*', cors());

  const walletService = new WalletService(db);
  const categoryService = new CategoryService(db);
  const transactionService = new TransactionService(db);

  // Auth Middleware
  const authMiddleware = async (c: any, next: any) => {
    const authHeader = c.req.header('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return c.json({ error: 'Akses ditolak. Token otentikasi tidak ditemukan.' }, 401);
    }
    const token = authHeader.substring(7);
    const payload = verifyToken(token);
    if (!payload) {
      return c.json({ error: 'Token otentikasi tidak valid atau telah kedaluwarsa.' }, 401);
    }
    c.set('userId', payload.userId);
    await next();
  };

  // Global 404 handler
  app.notFound((c) => {
    return c.json({ error: `Route not found: ${c.req.method} ${c.req.url}` }, 404);
  });

  // Health check (Public)
  const registerAuthRoutes = (pathPrefix: string) => {
    app.post(`${pathPrefix}/register`, async (c) => {
      const schema = z.object({
        name: z.string().min(1, 'Nama lengkap wajib diisi'),
        email: z.string().email('Format email tidak valid'),
        password: z.string().min(6, 'Kata sandi minimal 6 karakter'),
      });

      const body = await c.req.json().catch(() => null);
      const parsed = schema.safeParse(body);
      if (!parsed.success) {
        return c.json({ error: parsed.error.issues[0].message }, 400);
      }

      const { name, email, password } = parsed.data;

      const existing = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
      if (existing) {
        return c.json({ error: 'Email sudah terdaftar. Silakan gunakan email lain atau login.' }, 400);
      }

      const userId = 'u_' + cryptoNative();
      const passwordHash = await hashPassword(password);

      db.prepare(`
        INSERT INTO users (id, name, email, password_hash)
        VALUES (?, ?, ?, ?)
      `).run(userId, name, email, passwordHash);

      seedDefaultCategories(db, userId);

      const token = generateToken({ userId, email });
      const user = db.prepare('SELECT id, name, username, email, avatar_url, wa_number, wa_bot_enabled, ai_provider_type, ai_base_url, ai_model FROM users WHERE id = ?').get(userId);

      return c.json({ data: { token, user } }, 201);
    });

    app.post(`${pathPrefix}/login`, async (c) => {
      const schema = z.object({
        identifier: z.string().min(1, 'Email atau nama pengguna wajib diisi'),
        password: z.string().min(1, 'Kata sandi wajib diisi'),
      });

      const body = await c.req.json().catch(() => null);
      const parsed = schema.safeParse(body);
      if (!parsed.success) {
        return c.json({ error: parsed.error.issues[0].message }, 400);
      }

      const { identifier, password } = parsed.data;

      const user = db.prepare('SELECT * FROM users WHERE email = ? OR username = ?').get(identifier, identifier) as any;
      if (!user || !user.password_hash) {
        return c.json({ error: 'Email/Username atau kata sandi salah' }, 401);
      }

      const match = await comparePassword(password, user.password_hash);
      if (!match) {
        return c.json({ error: 'Email/Username atau kata sandi salah' }, 401);
      }

      const token = generateToken({ userId: user.id, email: user.email });
      delete user.password_hash;

      return c.json({ data: { token, user } });
    });

    app.post(`${pathPrefix}/google`, async (c) => {
      const schema = z.object({
        idToken: z.string().optional(),
        email: z.string().email().optional(),
        name: z.string().optional(),
        googleId: z.string().optional(),
        avatarUrl: z.string().optional(),
      });

      const body = await c.req.json().catch(() => null);
      const parsed = schema.safeParse(body);
      if (!parsed.success) {
        return c.json({ error: parsed.error.issues[0].message }, 400);
      }

      let { idToken, email, name, googleId, avatarUrl } = parsed.data;

      if (idToken) {
        try {
          const ticket = await googleClient.verifyIdToken({
            idToken,
          });
          const payload = ticket.getPayload();
          if (payload) {
            email = payload.email;
            name = payload.name;
            googleId = payload.sub;
            avatarUrl = payload.picture;
          }
        } catch (e) {}
      }

      if (!email) {
        return c.json({ error: 'Gagal mendapatkan data akun Google' }, 400);
      }

      let user = db.prepare('SELECT * FROM users WHERE email = ? OR google_id = ?').get(email, googleId || '') as any;

      if (!user) {
        const userId = 'u_' + cryptoNative();
        name = name || email.split('@')[0];
        avatarUrl = avatarUrl || 'https://api.dicebear.com/7.x/bottts/svg?seed=' + encodeURIComponent(name);

        db.prepare(`
          INSERT INTO users (id, name, email, google_id, avatar_url)
          VALUES (?, ?, ?, ?, ?)
        `).run(userId, name, email, googleId || null, avatarUrl);

        seedDefaultCategories(db, userId);
        user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId) as any;
      } else if (googleId && !user.google_id) {
        db.prepare('UPDATE users SET google_id = ? WHERE id = ?').run(googleId, user.id);
      }

      const token = generateToken({ userId: user.id, email: user.email });
      delete user.password_hash;

      return c.json({ data: { token, user } });
    });

    app.get(`${pathPrefix}/me`, authMiddleware, (c: any) => {
      const userId = c.get('userId');
      const user = db.prepare('SELECT id, name, username, email, avatar_url, wa_number, wa_bot_enabled, ai_provider_type, ai_base_url, ai_model FROM users WHERE id = ?').get(userId);
      if (!user) return c.json({ error: 'User not found' }, 404);
      return c.json({ data: user });
    });

    // Step 2 of registration: set username + avatar
    app.post(`${pathPrefix}/setup-profile`, authMiddleware, async (c: any) => {
      const userId = c.get('userId');

      const schema = z.object({
        username: z.string()
          .min(3, 'Username minimal 3 karakter')
          .max(30, 'Username maksimal 30 karakter')
          .regex(/^[a-z0-9_.]+$/, 'Username hanya boleh huruf kecil, angka, titik, dan underscore'),
        avatar_url: z.string().optional(),
      });

      const body = await c.req.json().catch(() => null);
      const parsed = schema.safeParse(body);
      if (!parsed.success) {
        return c.json({ error: parsed.error.issues[0].message }, 400);
      }

      const { username, avatar_url } = parsed.data;

      // Check username uniqueness (excluding current user)
      const existing = db.prepare('SELECT id FROM users WHERE username = ? AND id != ?').get(username, userId);
      if (existing) {
        return c.json({ error: 'Username sudah dipakai. Coba username lain.' }, 400);
      }

      db.prepare('UPDATE users SET username = ?, avatar_url = COALESCE(?, avatar_url) WHERE id = ?')
        .run(username, avatar_url ?? null, userId);

      const user = db.prepare('SELECT id, name, username, email, avatar_url, wa_number, wa_bot_enabled, ai_provider_type, ai_base_url, ai_model FROM users WHERE id = ?').get(userId);
      return c.json({ data: user });
    });

    // Check username availability (public, no auth needed)
    app.get(`${pathPrefix}/check-username/:username`, async (c) => {
      const username = c.req.param('username');
      if (!username || username.length < 3) {
        return c.json({ available: false, error: 'Username terlalu pendek' });
      }
      const existing = db.prepare('SELECT id FROM users WHERE username = ?').get(username);
      return c.json({ available: !existing });
    });
  };

  registerAuthRoutes('/api/auth');
  registerAuthRoutes('/auth');

  app.get('/api/health', (c) => {
    return c.json({ status: 'ok', timestamp: new Date().toISOString() });
  });
  app.get('/health', (c) => {
    return c.json({ status: 'ok', timestamp: new Date().toISOString() });
  });

  // --- PROTECTED APIS (Requires JWT) ---
  
  // Wallets Endpoints
  app.get('/api/wallets', authMiddleware, (c: any) => {
    const userId = c.get('userId');
    return c.json({ data: walletService.getAll(userId) });
  });

  app.get('/api/wallets/:id', authMiddleware, (c: any) => {
    const userId = c.get('userId');
    const wallet = walletService.getById(c.req.param('id'), userId);
    if (!wallet) return c.json({ error: 'Wallet not found' }, 404);
    return c.json({ data: wallet });
  });

  app.post('/api/wallets', authMiddleware, async (c: any) => {
    const userId = c.get('userId');
    const schema = z.object({
      name: z.string().min(1, 'Nama dompet wajib diisi'),
      type: z.string().min(1, 'Tipe dompet wajib diisi'),
      initialBalance: z.number().optional(),
      icon: z.string().optional(),
      color: z.string().optional(),
    });

    const body = await c.req.json().catch(() => null);
    const parsed = schema.safeParse(body);
    if (!parsed.success) {
      return c.json({ error: parsed.error.issues[0].message }, 400);
    }

    const wallet = walletService.create(userId, parsed.data);
    return c.json({ data: wallet }, 201);
  });

  app.put('/api/wallets/:id', authMiddleware, async (c: any) => {
    const userId = c.get('userId');
    const schema = z.object({
      name: z.string().optional(),
      type: z.string().optional(),
      icon: z.string().optional(),
      color: z.string().optional(),
    });

    const body = await c.req.json().catch(() => null);
    const parsed = schema.safeParse(body);
    if (!parsed.success) {
      return c.json({ error: parsed.error.issues[0].message }, 400);
    }

    const wallet = walletService.update(c.req.param('id'), userId, parsed.data);
    if (!wallet) return c.json({ error: 'Wallet not found' }, 404);
    return c.json({ data: wallet });
  });

  app.delete('/api/wallets/:id', authMiddleware, (c: any) => {
    const userId = c.get('userId');
    const deleted = walletService.delete(c.req.param('id'), userId);
    if (!deleted) return c.json({ error: 'Wallet not found' }, 404);
    return c.json({ success: true });
  });

  // Categories Endpoints
  app.get('/api/categories', authMiddleware, (c: any) => {
    const userId = c.get('userId');
    return c.json({ data: categoryService.getAll(userId) });
  });

  app.post('/api/categories', authMiddleware, async (c: any) => {
    const userId = c.get('userId');
    const schema = z.object({
      name: z.string().min(1, 'Nama kategori wajib diisi'),
      type: z.enum(['income', 'expense', 'transfer']),
      icon: z.string().optional(),
      color: z.string().optional(),
    });

    const body = await c.req.json().catch(() => null);
    const parsed = schema.safeParse(body);
    if (!parsed.success) {
      return c.json({ error: parsed.error.issues[0].message }, 400);
    }

    const category = categoryService.create(userId, parsed.data);
    return c.json({ data: category }, 201);
  });

  // Transactions Endpoints
  app.get('/api/transactions', authMiddleware, (c: any) => {
    const userId = c.get('userId');
    const wallet_id = c.req.query('wallet_id');
    const startDate = c.req.query('startDate');
    const endDate = c.req.query('endDate');

    const transactions = transactionService.getAll(userId, { wallet_id, startDate, endDate });
    return c.json({ data: transactions });
  });

  app.post('/api/transactions', authMiddleware, async (c: any) => {
    const userId = c.get('userId');
    const schema = z.object({
      wallet_id: z.string().min(1, 'Dompet asal wajib diisi'),
      target_wallet_id: z.string().optional().nullable(),
      category_id: z.string().optional().nullable(),
      type: z.enum(['income', 'expense', 'transfer']),
      amount: z.number().gt(0, 'Jumlah harus lebih besar dari 0'),
      date: z.string().min(1, 'Tanggal wajib diisi'),
      note: z.string().optional().nullable(),
    });

    const body = await c.req.json().catch(() => null);
    const parsed = schema.safeParse(body);
    if (!parsed.success) {
      return c.json({ error: parsed.error.issues[0].message }, 400);
    }

    try {
      const transaction = transactionService.create(userId, parsed.data);
      return c.json({ data: transaction }, 201);
    } catch (err: any) {
      return c.json({ error: err.message || 'Gagal mencatat transaksi' }, 400);
    }
  });

  app.delete('/api/transactions/:id', authMiddleware, (c: any) => {
    const userId = c.get('userId');
    const deleted = transactionService.delete(c.req.param('id'), userId);
    if (!deleted) return c.json({ error: 'Transaksi tidak ditemukan' }, 404);
    return c.json({ success: true });
  });

  // Dashboard Summary Endpoint
  app.get('/api/dashboard', authMiddleware, (c: any) => {
    const userId = c.get('userId');
    const month = c.req.query('month');
    const summary = transactionService.getDashboardSummary(userId, month);
    return c.json({ data: summary });
  });

  // Profile Endpoints
  app.get('/api/profile', authMiddleware, (c: any) => {
    const userId = c.get('userId');
    const profile = db.prepare('SELECT id, name, username, email, avatar_url, wa_number, wa_bot_enabled, ai_provider_type, ai_base_url, ai_model FROM users WHERE id = ?').get(userId);
    return c.json({ data: profile });
  });

  app.post('/api/profile/avatar', authMiddleware, async (c: any) => {
    const userId = c.get('userId');
    const body = await c.req.json().catch(() => null);
    if (!body || !body.avatar_base64) {
      return c.json({ error: 'Format foto avatar tidak valid (base64 required)' }, 400);
    }

    const base64Str = body.avatar_base64 as string;
    const approxSizeBytes = Math.ceil((base64Str.length * 3) / 4);
    const maxSizeBytes = 2 * 1024 * 1024;

    if (approxSizeBytes > maxSizeBytes) {
      return c.json({ error: 'Ukuran foto melebihi batas maksimum 2MB.' }, 400);
    }

    let avatarUrl = base64Str;
    if (!avatarUrl.startsWith('data:image')) {
      avatarUrl = `data:image/jpeg;base64,${base64Str}`;
    }

    db.prepare('UPDATE users SET avatar_url = ? WHERE id = ?').run(avatarUrl, userId);
    const profile = db.prepare('SELECT id, name, username, email, avatar_url, wa_number, wa_bot_enabled, ai_provider_type, ai_base_url, ai_model FROM users WHERE id = ?').get(userId);
    return c.json({ data: profile });
  });

  app.put('/api/profile', authMiddleware, async (c: any) => {
    const userId = c.get('userId');
    const schema = z.object({
      name: z.string().optional(),
      username: z.string().optional(),
      avatar_url: z.string().optional(),
      email: z.string().optional(),
      wa_number: z.string().optional(),
      wa_bot_enabled: z.number().optional(),
      ai_provider_type: z.string().optional(),
      ai_base_url: z.string().optional(),
      ai_api_key: z.string().optional(),
      ai_model: z.string().optional(),
    });

    const body = await c.req.json().catch(() => null);
    const parsed = schema.safeParse(body);
    if (!parsed.success) {
      return c.json({ error: parsed.error.issues[0].message }, 400);
    }

    const current = db.prepare('SELECT * FROM users WHERE id = ?').get(userId) as any;
    if (!current) return c.json({ error: 'User not found' }, 404);

    const updated = {
      name: parsed.data.name ?? current.name,
      username: parsed.data.username ?? current.username,
      avatar_url: parsed.data.avatar_url ?? current.avatar_url,
      email: parsed.data.email ?? current.email,
      wa_number: parsed.data.wa_number ?? current.wa_number,
      wa_bot_enabled: parsed.data.wa_bot_enabled ?? current.wa_bot_enabled,
      ai_provider_type: parsed.data.ai_provider_type ?? current.ai_provider_type ?? '9router',
      ai_base_url: parsed.data.ai_base_url ?? current.ai_base_url ?? 'http://192.168.18.27:20128/v1',
      ai_api_key: parsed.data.ai_api_key ?? current.ai_api_key ?? '',
      ai_model: parsed.data.ai_model ?? current.ai_model ?? 'gpt-3.5-turbo',
    };

    db.prepare(`
      UPDATE users
      SET name = ?, username = ?, avatar_url = ?, email = ?, wa_number = ?, wa_bot_enabled = ?, ai_provider_type = ?, ai_base_url = ?, ai_api_key = ?, ai_model = ?
      WHERE id = ?
    `).run(
      updated.name,
      updated.username,
      updated.avatar_url,
      updated.email,
      updated.wa_number,
      updated.wa_bot_enabled,
      updated.ai_provider_type,
      updated.ai_base_url,
      updated.ai_api_key,
      updated.ai_model,
      userId
    );

    const res = db.prepare('SELECT id, name, username, email, avatar_url, wa_number, wa_bot_enabled, ai_provider_type, ai_base_url, ai_model FROM users WHERE id = ?').get(userId);
    return c.json({ data: res });
  });

  // POST alias for profile update (Flutter client uses _postWithFallback)
  app.post('/api/profile', authMiddleware, async (c: any) => {
    const userId = c.get('userId');
    const schema = z.object({
      name: z.string().optional(),
      username: z.string().optional(),
      avatar_url: z.string().optional(),
      email: z.string().optional(),
      wa_number: z.string().optional(),
      wa_bot_enabled: z.number().optional(),
      ai_provider_type: z.string().optional(),
      ai_base_url: z.string().optional(),
      ai_api_key: z.string().optional(),
      ai_model: z.string().optional(),
    });

    const body = await c.req.json().catch(() => null);
    const parsed = schema.safeParse(body);
    if (!parsed.success) {
      return c.json({ error: parsed.error.issues[0].message }, 400);
    }

    const current = db.prepare('SELECT * FROM users WHERE id = ?').get(userId) as any;
    if (!current) return c.json({ error: 'User not found' }, 404);

    const updated = {
      name: parsed.data.name ?? current.name,
      username: parsed.data.username ?? current.username,
      avatar_url: parsed.data.avatar_url ?? current.avatar_url,
      email: parsed.data.email ?? current.email,
      wa_number: parsed.data.wa_number ?? current.wa_number,
      wa_bot_enabled: parsed.data.wa_bot_enabled ?? current.wa_bot_enabled,
      ai_provider_type: parsed.data.ai_provider_type ?? current.ai_provider_type ?? '9router',
      ai_base_url: parsed.data.ai_base_url ?? current.ai_base_url ?? 'http://192.168.18.27:20128/v1',
      ai_api_key: parsed.data.ai_api_key ?? current.ai_api_key ?? '',
      ai_model: parsed.data.ai_model ?? current.ai_model ?? 'gpt-3.5-turbo',
    };

    db.prepare(`
      UPDATE users
      SET name = ?, username = ?, avatar_url = ?, email = ?, wa_number = ?, wa_bot_enabled = ?, ai_provider_type = ?, ai_base_url = ?, ai_api_key = ?, ai_model = ?
      WHERE id = ?
    `).run(
      updated.name,
      updated.username,
      updated.avatar_url,
      updated.email,
      updated.wa_number,
      updated.wa_bot_enabled,
      updated.ai_provider_type,
      updated.ai_base_url,
      updated.ai_api_key,
      updated.ai_model,
      userId
    );

    const res = db.prepare('SELECT id, name, username, email, avatar_url, wa_number, wa_bot_enabled, ai_provider_type, ai_base_url, ai_model FROM users WHERE id = ?').get(userId);
    return c.json({ data: res });
  });

  // AI Endpoints
  app.get('/api/ai/advice', authMiddleware, async (c: any) => {
    const userId = c.get('userId');
    const month = c.req.query('month') || new Date().toISOString().substring(0, 7);
    const summary = transactionService.getDashboardSummary(userId, month);
    const parser = aiParserService || new AiParserService(db);
    const advice = await parser.generateFinancialAdvice(summary as any, month, userId);
    return c.json({ data: { advice, month } });
  });

  app.post('/api/ai/chat', authMiddleware, async (c: any) => {
    const userId = c.get('userId');
    const body = await c.req.json().catch(() => ({}));
    const { message, history } = body;
    if (!message) {
      return c.json({ error: 'Pesan wajib diisi' }, 400);
    }

    const month = new Date().toISOString().substring(0, 7);
    const summary = transactionService.getDashboardSummary(userId, month);
    const wallets = walletService.getAll(userId);
    const transactions = transactionService.getAll(userId);

    const parser = aiParserService || new AiParserService(db);
    const result = await parser.chatWithFinancialAssistant(
      userId,
      message,
      history || [],
      wallets,
      transactions as any,
      summary as any
    );

    return c.json({ data: result });
  });

  app.get('/api/ai/chat/messages', authMiddleware, (c: any) => {
    const userId = c.get('userId');
    const messages = db.prepare(`
      SELECT * FROM ai_chat_messages
      WHERE user_id = ?
      ORDER BY created_at ASC
    `).all(userId);
    return c.json({ data: messages });
  });

  app.delete('/api/ai/chat/messages', authMiddleware, (c: any) => {
    const userId = c.get('userId');
    db.prepare('DELETE FROM ai_chat_messages WHERE user_id = ?').run(userId);
    return c.json({ success: true });
  });

  app.post('/api/ai/models', authMiddleware, async (c: any) => {
    const body = await c.req.json().catch(() => ({}));
    const { baseUrl, apiKey } = body;

    const parser = aiParserService || new AiParserService(db);
    const models = await parser.fetchAvailableModels(baseUrl, apiKey);
    return c.json({ data: models });
  });

  // System status (authenticated — per-user WA status)
  app.get('/api/system/status', authMiddleware, async (c: any) => {
    const userId = c.get('userId');
    const totalMem = os.totalmem();
    const freeMem = os.freemem();
    const usedMem = totalMem - freeMem;

    const cpus = os.cpus();
    const cpuModel = cpus.length > 0 ? cpus[0].model : 'Generic CPU';

    const uptimeSec = Math.floor(process.uptime());
    const days = Math.floor(uptimeSec / (3600 * 24));
    const hours = Math.floor((uptimeSec % (3600 * 24)) / 3600);
    const minutes = Math.floor((uptimeSec % 3600) / 60);
    const uptimeStr = days > 0 ? `${days}d ${hours}h ${minutes}m` : `${hours}h ${minutes}m`;

    const txCount = (db.prepare('SELECT COUNT(*) as count FROM transactions WHERE user_id = ?').get(userId) as any).count || 0;
    const walletCount = (db.prepare('SELECT COUNT(*) as count FROM wallets WHERE user_id = ?').get(userId) as any).count || 0;

    const waStatus = waManager
      ? waManager.getStatus(userId)
      : { status: 'DISCONNECTED', qrCode: null, connectedNumber: null };

    return c.json({
      data: {
        server_status: 'online',
        hostname: os.hostname(),
        platform: `${os.type()} ${os.release()}`,
        cpu_model: cpuModel,
        cpu_cores: cpus.length,
        cpu_usage_percent: Math.min(95, Math.floor(os.loadavg()[0] * 10) + 15),
        ram_used_bytes: usedMem,
        ram_total_bytes: totalMem,
        ram_used_gb: (usedMem / (1024 * 1024 * 1024)).toFixed(1),
        ram_total_gb: (totalMem / (1024 * 1024 * 1024)).toFixed(1),
        uptime: uptimeStr,
        tx_count: txCount,
        wallet_count: walletCount,
        wa_bot_status: waStatus.status,
        wa_qr_code: waStatus.qrCode,
        wa_connected_number: waStatus.connectedNumber,
      },
    });
  });

  // --- WhatsApp Endpoints (all require auth) ---

  // Get WA status for the authenticated user
  app.get('/api/wa/status', authMiddleware, (c: any) => {
    const userId = c.get('userId');
    const status = waManager
      ? waManager.getStatus(userId)
      : { status: 'DISCONNECTED', qrCode: null, connectedNumber: null };
    return c.json({ data: status });
  });

  // Start WA socket for the authenticated user (initiates QR flow)
  app.post('/api/wa/connect', authMiddleware, async (c: any) => {
    const userId = c.get('userId');
    if (!waManager) {
      return c.json({ error: 'WhatsApp service tidak tersedia' }, 503);
    }

    const current = waManager.getStatus(userId);
    if (current.status === 'CONNECTED') {
      return c.json({ error: 'WhatsApp sudah terhubung' }, 400);
    }

    const service = waManager.getOrCreate(userId);
    // Start in background — QR will be available via GET /api/wa/status
    service.startSocket(false).catch((err) => {
      console.error(`[WA:${userId}] startSocket error:`, err);
    });

    return c.json({ data: { message: 'Memulai koneksi WhatsApp. Ambil QR via GET /api/wa/status.' } });
  });

  // Request pairing code (alternative to QR, for single-device use)
  app.post('/api/wa/request-pairing-code', authMiddleware, async (c: any) => {
    const userId = c.get('userId');
    if (!waManager) {
      return c.json({ error: 'WhatsApp service tidak tersedia' }, 503);
    }

    const schema = z.object({
      phoneNumber: z.string().min(7, 'Nomor telepon tidak valid'),
    });

    const body = await c.req.json().catch(() => null);
    const parsed = schema.safeParse(body);
    if (!parsed.success) {
      return c.json({ error: parsed.error.issues[0].message }, 400);
    }

    const current = waManager.getStatus(userId);
    if (current.status === 'CONNECTED') {
      return c.json({ error: 'WhatsApp sudah terhubung. Disconnect dulu sebelum pairing ulang.' }, 400);
    }

    try {
      const service = waManager.getOrCreate(userId);
      const code = await service.requestPairingCode(parsed.data.phoneNumber);
      return c.json({ data: { code } });
    } catch (err: any) {
      console.error(`[WA:${userId}] requestPairingCode error:`, err);
      return c.json({ error: err.message || 'Gagal mendapatkan kode pairing' }, 500);
    }
  });

  // Disconnect WA for the authenticated user
  app.post('/api/wa/disconnect', authMiddleware, async (c: any) => {
    const userId = c.get('userId');
    if (!waManager) {
      return c.json({ error: 'WhatsApp service tidak tersedia' }, 503);
    }
    await waManager.disconnectUser(userId);
    return c.json({ data: { message: 'WhatsApp berhasil diputus.' } });
  });

  return app;
}
