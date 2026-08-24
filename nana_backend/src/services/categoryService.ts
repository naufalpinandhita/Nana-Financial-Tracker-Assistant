import type Database from 'better-sqlite3';
import { cryptoNative } from '../utils/crypto.js';

export interface Category {
  id: string;
  name: string;
  type: 'income' | 'expense' | 'transfer';
  icon: string;
  color: string;
  is_default: number;
}

export class CategoryService {
  constructor(private db: Database.Database) {}

  getAll(): Category[] {
    return this.db.prepare('SELECT * FROM categories ORDER BY name ASC').all() as Category[];
  }

  getById(id: string): Category | null {
    const res = this.db.prepare('SELECT * FROM categories WHERE id = ?').get(id);
    return (res as Category) || null;
  }

  create(data: { name: string; type: 'income' | 'expense' | 'transfer'; icon?: string; color?: string }): Category {
    const id = 'cat_' + cryptoNative();
    const icon = data.icon ?? 'category';
    const color = data.color ?? '#064e3b';

    this.db.prepare(`
      INSERT INTO categories (id, name, type, icon, color, is_default)
      VALUES (?, ?, ?, ?, ?, 0)
    `).run(id, data.name, data.type, icon, color);

    return this.getById(id)!;
  }
}
