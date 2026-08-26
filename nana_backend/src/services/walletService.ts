import type Database from 'better-sqlite3';
import { cryptoNative } from '../utils/crypto.js';

export interface Wallet {
  id: string;
  user_id: string;
  name: string;
  type: string;
  balance: number;
  icon: string;
  color: string;
  created_at: string;
  updated_at: string;
}

export class WalletService {
  constructor(private db: Database.Database) {}

  getAll(userId: string): Wallet[] {
    return this.db.prepare('SELECT * FROM wallets WHERE user_id = ? ORDER BY created_at ASC').all(userId) as Wallet[];
  }

  getById(id: string, userId: string): Wallet | null {
    const res = this.db.prepare('SELECT * FROM wallets WHERE id = ? AND user_id = ?').get(id, userId);
    return (res as Wallet) || null;
  }

  create(userId: string, data: { name: string; type: string; initialBalance?: number; icon?: string; color?: string }): Wallet {
    const id = 'w_' + cryptoNative();
    const balance = data.initialBalance ?? 0;
    const icon = data.icon ?? 'account_balance_wallet';
    const color = data.color ?? '#003527';

    this.db.prepare(`
      INSERT INTO wallets (id, user_id, name, type, balance, icon, color)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(id, userId, data.name, data.type, balance, icon, color);

    return this.getById(id, userId)!;
  }

  update(id: string, userId: string, data: Partial<{ name: string; type: string; icon: string; color: string }>): Wallet | null {
    const wallet = this.getById(id, userId);
    if (!wallet) return null;

    const name = data.name ?? wallet.name;
    const type = data.type ?? wallet.type;
    const icon = data.icon ?? wallet.icon;
    const color = data.color ?? wallet.color;

    this.db.prepare(`
      UPDATE wallets SET name = ?, type = ?, icon = ?, color = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND user_id = ?
    `).run(name, type, icon, color, id, userId);

    return this.getById(id, userId);
  }

  delete(id: string, userId: string): boolean {
    const res = this.db.prepare('DELETE FROM wallets WHERE id = ? AND user_id = ?').run(id, userId);
    return res.changes > 0;
  }
}
