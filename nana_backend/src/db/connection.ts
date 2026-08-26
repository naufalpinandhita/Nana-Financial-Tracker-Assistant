import Database from 'better-sqlite3';

export function createDb(dbPath: string = ':memory:') {
  const db = new Database(dbPath);
  db.pragma('foreign_keys = ON');
  
  // Create users table
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      username TEXT,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT,
      google_id TEXT UNIQUE,
      avatar_url TEXT DEFAULT 'https://api.dicebear.com/7.x/bottts/svg?seed=Nana',
      wa_number TEXT DEFAULT '',
      wa_bot_enabled INTEGER NOT NULL DEFAULT 1,
      ai_provider_type TEXT NOT NULL DEFAULT '9router',
      ai_base_url TEXT NOT NULL DEFAULT 'http://192.168.18.27:20128/v1',
      ai_api_key TEXT NOT NULL DEFAULT '',
      ai_model TEXT NOT NULL DEFAULT 'gpt-3.5-turbo',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS wallets (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL DEFAULT 'user_default',
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      balance REAL NOT NULL DEFAULT 0.0,
      icon TEXT NOT NULL DEFAULT 'account_balance_wallet',
      color TEXT NOT NULL DEFAULT '#003527',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS categories (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL DEFAULT 'user_default',
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      icon TEXT NOT NULL DEFAULT 'category',
      color TEXT NOT NULL DEFAULT '#064e3b',
      is_default INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS transactions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL DEFAULT 'user_default',
      wallet_id TEXT NOT NULL,
      target_wallet_id TEXT,
      category_id TEXT,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      note TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
      FOREIGN KEY (wallet_id) REFERENCES wallets (id) ON DELETE CASCADE,
      FOREIGN KEY (target_wallet_id) REFERENCES wallets (id) ON DELETE SET NULL,
      FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
    );

    CREATE TABLE IF NOT EXISTS ai_chat_messages (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL DEFAULT 'user_default',
      sender TEXT NOT NULL,
      text TEXT NOT NULL,
      model_used TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS wa_sessions (
      user_id TEXT PRIMARY KEY,
      phone_number TEXT,
      status TEXT NOT NULL DEFAULT 'DISCONNECTED',
      session_dir TEXT NOT NULL,
      connected_at DATETIME,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
    );
  `);

  // Schema migrations for existing SQLite databases
  try { db.exec(`ALTER TABLE wallets ADD COLUMN user_id TEXT NOT NULL DEFAULT 'user_default'`); } catch (_) {}
  try { db.exec(`ALTER TABLE categories ADD COLUMN user_id TEXT NOT NULL DEFAULT 'user_default'`); } catch (_) {}
  try { db.exec(`ALTER TABLE transactions ADD COLUMN user_id TEXT NOT NULL DEFAULT 'user_default'`); } catch (_) {}
  try { db.exec(`ALTER TABLE ai_chat_messages ADD COLUMN user_id TEXT NOT NULL DEFAULT 'user_default'`); } catch (_) {}
  // wa_sessions created via CREATE TABLE IF NOT EXISTS above

  return db;
}

export function seedDefaultCategories(db: Database.Database, userId: string) {
  const categoryCount = (db.prepare('SELECT COUNT(*) as count FROM categories WHERE user_id = ?').get(userId) as { count: number }).count;
  if (categoryCount === 0) {
    const insertCat = db.prepare('INSERT INTO categories (id, user_id, name, type, icon, color, is_default) VALUES (?, ?, ?, ?, ?, ?, 1)');
    const defaultCategories = [
      { id: `cat_makanan_${userId}`, name: 'Makanan & Minuman', type: 'expense', icon: 'restaurant', color: '#ba1a1a' },
      { id: `cat_transport_${userId}`, name: 'Transportasi', type: 'expense', icon: 'directions_car', color: '#d97706' },
      { id: `cat_belanja_${userId}`, name: 'Belanja', type: 'expense', icon: 'shopping_bag', color: '#2563eb' },
      { id: `cat_tagihan_${userId}`, name: 'Tagihan & Utilitas', type: 'expense', icon: 'receipt_long', color: '#7c3aed' },
      { id: `cat_hiburan_${userId}`, name: 'Hiburan', type: 'expense', icon: 'sports_esports', color: '#db2777' },
      { id: `cat_gaji_${userId}`, name: 'Gaji & Pendapatan', type: 'income', icon: 'payments', color: '#059669' },
      { id: `cat_investasi_${userId}`, name: 'Investasi & Passive', type: 'income', icon: 'trending_up', color: '#10b981' },
      { id: `cat_transfer_${userId}`, name: 'Transfer Antar Dompet', type: 'transfer', icon: 'swap_horiz', color: '#6b7280' },
    ];
    for (const c of defaultCategories) {
      insertCat.run(c.id, userId, c.name, c.type, c.icon, c.color);
    }
  }
}
