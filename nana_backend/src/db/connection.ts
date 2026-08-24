import Database from 'better-sqlite3';

export function createDb(dbPath: string = ':memory:') {
  const db = new Database(dbPath);
  db.pragma('foreign_keys = ON');
  
  // Create tables
  db.exec(`
    CREATE TABLE IF NOT EXISTS wallets (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL, -- 'Bank', 'E-Wallet', 'Cash', etc.
      balance REAL NOT NULL DEFAULT 0.0,
      icon TEXT NOT NULL DEFAULT 'account_balance_wallet',
      color TEXT NOT NULL DEFAULT '#003527',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS categories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL, -- 'income' | 'expense'
      icon TEXT NOT NULL DEFAULT 'category',
      color TEXT NOT NULL DEFAULT '#064e3b',
      is_default INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS transactions (
      id TEXT PRIMARY KEY,
      wallet_id TEXT NOT NULL,
      target_wallet_id TEXT, -- For transfer type
      category_id TEXT,
      type TEXT NOT NULL, -- 'income' | 'expense' | 'transfer'
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      note TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (wallet_id) REFERENCES wallets (id) ON DELETE CASCADE,
      FOREIGN KEY (target_wallet_id) REFERENCES wallets (id) ON DELETE SET NULL,
      FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
    );

    CREATE TABLE IF NOT EXISTS profile (
      id TEXT PRIMARY KEY DEFAULT 'user_default',
      name TEXT NOT NULL DEFAULT 'Naufal Pinandhita',
      username TEXT NOT NULL DEFAULT 'Nopal🐐',
      avatar_url TEXT NOT NULL DEFAULT 'https://api.dicebear.com/7.x/bottts/svg?seed=Nana',
      email TEXT NOT NULL DEFAULT 'naufal@nana.home',
      wa_number TEXT NOT NULL DEFAULT '+6281234567890',
      wa_bot_enabled INTEGER NOT NULL DEFAULT 1,
      ai_provider_type TEXT NOT NULL DEFAULT '9router',
      ai_base_url TEXT NOT NULL DEFAULT 'http://192.168.18.27:20128/v1',
      ai_api_key TEXT NOT NULL DEFAULT '',
      ai_model TEXT NOT NULL DEFAULT 'gpt-3.5-turbo'
    );

    CREATE TABLE IF NOT EXISTS ai_chat_messages (
      id TEXT PRIMARY KEY,
      sender TEXT NOT NULL, -- 'user' | 'ai'
      text TEXT NOT NULL,
      model_used TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  `);

  // Seed default profile if empty
  const profileCount = (db.prepare('SELECT COUNT(*) as count FROM profile').get() as { count: number }).count;
  if (profileCount === 0) {
    db.prepare(`
      INSERT INTO profile (id, name, username, avatar_url, email, wa_number, wa_bot_enabled, ai_provider_type, ai_base_url, ai_api_key, ai_model)
      VALUES ('user_default', 'Naufal Pinandhita', 'Nopal🐐', 'https://api.dicebear.com/7.x/bottts/svg?seed=Nana', 'naufal@nana.home', '+6281234567890', 1, '9router', 'http://192.168.18.27:20128/v1', '', 'gpt-3.5-turbo')
    `).run();
  } else {
    // Migration helper for existing sqlite db file
    try {
      db.exec(`
        ALTER TABLE profile ADD COLUMN ai_provider_type TEXT NOT NULL DEFAULT '9router';
      `);
    } catch (_) {}
    try {
      db.exec(`
        ALTER TABLE profile ADD COLUMN ai_base_url TEXT NOT NULL DEFAULT 'http://192.168.18.27:20128/v1';
      `);
    } catch (_) {}
    try {
      db.exec(`
        ALTER TABLE profile ADD COLUMN ai_api_key TEXT NOT NULL DEFAULT '';
      `);
    } catch (_) {}
    try {
      db.exec(`
        CREATE TABLE IF NOT EXISTS ai_chat_messages (
          id TEXT PRIMARY KEY,
          sender TEXT NOT NULL,
          text TEXT NOT NULL,
          model_used TEXT,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
      `);
    } catch (_) {}
  }

  // Seed default categories if empty
  const categoryCount = (db.prepare('SELECT COUNT(*) as count FROM categories').get() as { count: number }).count;
  if (categoryCount === 0) {
    const insertCat = db.prepare('INSERT INTO categories (id, name, type, icon, color, is_default) VALUES (?, ?, ?, ?, ?, 1)');
    const defaultCategories = [
      { id: 'cat_makanan', name: 'Makanan & Minuman', type: 'expense', icon: 'restaurant', color: '#ba1a1a' },
      { id: 'cat_transport', name: 'Transportasi', type: 'expense', icon: 'directions_car', color: '#d97706' },
      { id: 'cat_belanja', name: 'Belanja', type: 'expense', icon: 'shopping_bag', color: '#2563eb' },
      { id: 'cat_tagihan', name: 'Tagihan & Utilitas', type: 'expense', icon: 'receipt_long', color: '#7c3aed' },
      { id: 'cat_hiburan', name: 'Hiburan', type: 'expense', icon: 'sports_esports', color: '#db2777' },
      { id: 'cat_gaji', name: 'Gaji & Pendapatan', type: 'income', icon: 'payments', color: '#059669' },
      { id: 'cat_investasi', name: 'Investasi & Passive', type: 'income', icon: 'trending_up', color: '#10b981' },
      { id: 'cat_transfer', name: 'Transfer Antar Dompet', type: 'transfer', icon: 'swap_horiz', color: '#6b7280' },
    ];
    for (const c of defaultCategories) {
      insertCat.run(c.id, c.name, c.type, c.icon, c.color);
    }
  }

  return db;
}
