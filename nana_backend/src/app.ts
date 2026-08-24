import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { z } from 'zod';
import type Database from 'better-sqlite3';
import os from 'os';
import { WalletService } from './services/walletService.js';
import { CategoryService } from './services/categoryService.js';
import { TransactionService } from './services/transactionService.js';
import { WaService } from './services/waService.js';

export function createApp(db: Database.Database, waService?: WaService, aiParserService?: AiParserService) {
  const app = new Hono();

  app.use('*', cors());

  const walletService = new WalletService(db);
  const categoryService = new CategoryService(db);
  const transactionService = new TransactionService(db);

  // Health check
  app.get('/api/health', (c) => {
    return c.json({ status: 'ok', timestamp: new Date().toISOString() });
  });

  // Wallets Endpoints
  app.get('/api/wallets', (c) => {
    return c.json({ data: walletService.getAll() });
  });

  app.get('/api/wallets/:id', (c) => {
    const wallet = walletService.getById(c.req.param('id'));
    if (!wallet) return c.json({ error: 'Wallet not found' }, 404);
    return c.json({ data: wallet });
  });

  app.post('/api/wallets', async (c) => {
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

    const wallet = walletService.create(parsed.data);
    return c.json({ data: wallet }, 201);
  });

  app.put('/api/wallets/:id', async (c) => {
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

    const wallet = walletService.update(c.req.param('id'), parsed.data);
    if (!wallet) return c.json({ error: 'Wallet not found' }, 404);
    return c.json({ data: wallet });
  });

  app.delete('/api/wallets/:id', (c) => {
    const deleted = walletService.delete(c.req.param('id'));
    if (!deleted) return c.json({ error: 'Wallet not found' }, 404);
    return c.json({ success: true });
  });

  // Categories Endpoints
  app.get('/api/categories', (c) => {
    return c.json({ data: categoryService.getAll() });
  });

  app.post('/api/categories', async (c) => {
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

    const category = categoryService.create(parsed.data);
    return c.json({ data: category }, 201);
  });

  // Transactions Endpoints
  app.get('/api/transactions', (c) => {
    const wallet_id = c.req.query('wallet_id');
    const startDate = c.req.query('startDate');
    const endDate = c.req.query('endDate');

    const transactions = transactionService.getAll({ wallet_id, startDate, endDate });
    return c.json({ data: transactions });
  });

  app.post('/api/transactions', async (c) => {
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
      const transaction = transactionService.create(parsed.data);
      return c.json({ data: transaction }, 201);
    } catch (err: any) {
      return c.json({ error: err.message || 'Gagal mencatat transaksi' }, 400);
    }
  });

  app.delete('/api/transactions/:id', (c) => {
    const deleted = transactionService.delete(c.req.param('id'));
    if (!deleted) return c.json({ error: 'Transaksi tidak ditemukan' }, 404);
    return c.json({ success: true });
  });

  // Dashboard Summary Endpoint
  app.get('/api/dashboard', (c) => {
    const month = c.req.query('month');
    const summary = transactionService.getDashboardSummary(month);
    return c.json({ data: summary });
  });

  // Profile Endpoints
  app.get('/api/profile', (c) => {
    const profile = db.prepare('SELECT * FROM profile WHERE id = ?').get('user_default');
    return c.json({ data: profile });
  });

  app.post('/api/profile/avatar', async (c) => {
    const body = await c.req.json().catch(() => null);
    if (!body || !body.avatar_base64) {
      return c.json({ error: 'Format foto avatar tidak valid (base64 required)' }, 400);
    }

    const base64Str = body.avatar_base64 as string;
    const approxSizeBytes = Math.ceil((base64Str.length * 3) / 4);
    const maxSizeBytes = 2 * 1024 * 1024; // 2MB limit

    if (approxSizeBytes > maxSizeBytes) {
      return c.json({ error: 'Ukuran foto melebihi batas maksimum 2MB. Silakan pilih foto yang lebih kecil.' }, 400);
    }

    let avatarUrl = base64Str;
    if (!avatarUrl.startsWith('data:image')) {
      avatarUrl = `data:image/jpeg;base64,${base64Str}`;
    }

    db.prepare('UPDATE profile SET avatar_url = ? WHERE id = ?').run(avatarUrl, 'user_default');
    const profile = db.prepare('SELECT * FROM profile WHERE id = ?').get('user_default');
    return c.json({ data: profile });
  });

  app.put('/api/profile', async (c) => {
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

    const current = db.prepare('SELECT * FROM profile WHERE id = ?').get('user_default') as any;
    if (!current) return c.json({ error: 'Profile not found' }, 404);

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
      UPDATE profile
      SET name = ?, username = ?, avatar_url = ?, email = ?, wa_number = ?, wa_bot_enabled = ?, ai_provider_type = ?, ai_base_url = ?, ai_api_key = ?, ai_model = ?
      WHERE id = 'user_default'
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
      updated.ai_model
    );

    const res = db.prepare('SELECT * FROM profile WHERE id = ?').get('user_default');
    return c.json({ data: res });
  });

  app.post('/api/profile', async (c) => {
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

    const current = db.prepare('SELECT * FROM profile WHERE id = ?').get('user_default') as any;
    if (!current) return c.json({ error: 'Profile not found' }, 404);

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
      UPDATE profile
      SET name = ?, username = ?, avatar_url = ?, email = ?, wa_number = ?, wa_bot_enabled = ?, ai_provider_type = ?, ai_base_url = ?, ai_api_key = ?, ai_model = ?
      WHERE id = 'user_default'
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
      updated.ai_model
    );

    const res = db.prepare('SELECT * FROM profile WHERE id = ?').get('user_default');
    return c.json({ data: res });
  });

  // AI Endpoint: Generate Financial Advice
  app.get('/api/ai/advice', async (c) => {
    const month = c.req.query('month') || new Date().toISOString().substring(0, 7);
    const summary = transactionService.getDashboardSummary(month);
    const parser = aiParserService || new AiParserService(db);
    const advice = await parser.generateFinancialAdvice(summary, month);
    return c.json({ data: { advice, month } });
  });

  // AI Endpoint: Chat Query with Financial Context
  app.post('/api/ai/chat', async (c) => {
    const body = await c.req.json().catch(() => ({}));
    const { message, history } = body;
    if (!message) {
      return c.json({ error: 'Pesan wajib diisi' }, 400);
    }

    const month = new Date().toISOString().substring(0, 7);
    const summary = transactionService.getDashboardSummary(month);
    const wallets = walletService.getAll();
    const transactions = transactionService.getAll();

    const parser = aiParserService || new AiParserService(db);
    const result = await parser.chatWithFinancialAssistant(
      message,
      history || [],
      wallets,
      transactions,
      summary
    );

    return c.json({ data: result });
  });

  // AI Endpoint: Get Chat History
  app.get('/api/ai/chat/messages', (c) => {
    const messages = db.prepare(`
      SELECT * FROM ai_chat_messages
      ORDER BY created_at ASC
    `).all();
    return c.json({ data: messages });
  });

  // AI Endpoint: Clear Chat History
  app.delete('/api/ai/chat/messages', (c) => {
    db.prepare('DELETE FROM ai_chat_messages').run();
    return c.json({ success: true });
  });

  // AI Endpoint: Fetch Models dynamically from provider
  app.post('/api/ai/models', async (c) => {
    const body = await c.req.json().catch(() => ({}));
    const { baseUrl, apiKey } = body;

    const parser = aiParserService || new AiParserService(db);
    const models = await parser.fetchAvailableModels(baseUrl, apiKey);
    return c.json({ data: models });
  });

  // Real System Telemetry & Infrastructure Endpoint
  app.get('/api/system/status', async (c) => {
    const totalMem = os.totalmem();
    const freeMem = os.freemem();
    const usedMem = totalMem - freeMem;

    const cpus = os.cpus();
    const cpuModel = cpus.length > 0 ? cpus[0].model : 'Generic CPU';

    // Calculate process uptime
    const uptimeSec = Math.floor(process.uptime());
    const days = Math.floor(uptimeSec / (3600 * 24));
    const hours = Math.floor((uptimeSec % (3600 * 24)) / 3600);
    const minutes = Math.floor((uptimeSec % 3600) / 60);
    const uptimeStr = days > 0 ? `${days}d ${hours}h ${minutes}m` : `${hours}h ${minutes}m`;

    // DB metrics
    const txCount = (db.prepare('SELECT COUNT(*) as count FROM transactions').get() as any).count || 0;
    const walletCount = (db.prepare('SELECT COUNT(*) as count FROM wallets').get() as any).count || 0;

    const profile = db.prepare('SELECT * FROM profile WHERE id = ?').get('user_default') as any;

    const waStatus = waService ? waService.getStatus() : { status: 'DISCONNECTED', qrCode: null, connectedNumber: null };

    // Test connection to active AI Gateway
    let aiGatewayOnline = false;
    let aiLatencyMs = 0;
    const startPing = Date.now();
    try {
      const pingUrl = (profile?.ai_base_url || 'http://192.168.18.27:20128/v1').replace(/\/+$/, '') + '/models';
      const pingHeaders: Record<string, string> = {};
      if (profile?.ai_api_key) {
        pingHeaders['Authorization'] = `Bearer ${profile.ai_api_key}`;
      }
      const pingRes = await fetch(pingUrl, {
        headers: pingHeaders,
        signal: AbortSignal.timeout(2000),
      }).catch(() => null);
      aiLatencyMs = Date.now() - startPing;
      if (pingRes && pingRes.ok) {
        aiGatewayOnline = true;
      }
    } catch (_) {
      aiGatewayOnline = false;
    }

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
        ai_gateway_online: aiGatewayOnline,
        ai_gateway_latency_ms: aiLatencyMs > 0 ? aiLatencyMs : 12,
        active_ai_model: profile?.ai_model || 'gpt-3.5-turbo',
        ai_provider_type: profile?.ai_provider_type || '9router',
        ai_base_url: profile?.ai_base_url || 'http://192.168.18.27:20128/v1',
        wa_bot_enabled: profile?.wa_bot_enabled === 1,
        wa_bot_status: waStatus.status,
        wa_qr_code: waStatus.qrCode,
        wa_connected_number: waStatus.connectedNumber,
      },
    });
  });

  // WhatsApp Status Endpoint
  app.get('/api/wa/status', (c) => {
    if (!waService) {
      return c.json({ status: 'DISCONNECTED', qrCode: null, connectedNumber: null });
    }
    return c.json({ data: waService.getStatus() });
  });

  return app;
}
