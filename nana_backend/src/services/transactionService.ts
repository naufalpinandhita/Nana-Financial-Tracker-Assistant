import type Database from 'better-sqlite3';
import { cryptoNative } from '../utils/crypto.js';

export interface Transaction {
  id: string;
  wallet_id: string;
  target_wallet_id?: string | null;
  category_id?: string | null;
  type: 'income' | 'expense' | 'transfer';
  amount: number;
  date: string;
  note?: string | null;
  created_at: string;
  wallet_name?: string;
  target_wallet_name?: string;
  category_name?: string;
}

export class TransactionService {
  constructor(private db: Database.Database) {}

  getAll(filter?: { wallet_id?: string; startDate?: string; endDate?: string }): Transaction[] {
    let sql = `
      SELECT t.*, 
             w.name as wallet_name, 
             tw.name as target_wallet_name, 
             c.name as category_name
      FROM transactions t
      LEFT JOIN wallets w ON t.wallet_id = w.id
      LEFT JOIN wallets tw ON t.target_wallet_id = tw.id
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE 1=1
    `;
    const params: any[] = [];

    if (filter?.wallet_id) {
      sql += ` AND (t.wallet_id = ? OR t.target_wallet_id = ?)`;
      params.push(filter.wallet_id, filter.wallet_id);
    }
    if (filter?.startDate) {
      sql += ` AND t.date >= ?`;
      params.push(filter.startDate);
    }
    if (filter?.endDate) {
      sql += ` AND t.date <= ?`;
      params.push(filter.endDate);
    }

    sql += ` ORDER BY t.date DESC, t.created_at DESC`;

    return this.db.prepare(sql).all(...params) as Transaction[];
  }

  getById(id: string): Transaction | null {
    const sql = `
      SELECT t.*, 
             w.name as wallet_name, 
             tw.name as target_wallet_name, 
             c.name as category_name
      FROM transactions t
      LEFT JOIN wallets w ON t.wallet_id = w.id
      LEFT JOIN wallets tw ON t.target_wallet_id = tw.id
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.id = ?
    `;
    const res = this.db.prepare(sql).get(id);
    return (res as Transaction) || null;
  }

  create(data: {
    wallet_id: string;
    target_wallet_id?: string | null;
    category_id?: string | null;
    type: 'income' | 'expense' | 'transfer';
    amount: number;
    date: string;
    note?: string | null;
  }): Transaction {
    if (data.amount <= 0) {
      throw new Error('Jumlah transaksi harus lebih besar dari 0');
    }

    const wallet = this.db.prepare('SELECT * FROM wallets WHERE id = ?').get(data.wallet_id);
    if (!wallet) {
      throw new Error('Dompet tidak ditemukan');
    }

    if (data.type === 'transfer') {
      if (!data.target_wallet_id) {
        throw new Error('Dompet tujuan wajib diisi untuk transaksi transfer');
      }
      if (data.wallet_id === data.target_wallet_id) {
        throw new Error('Dompet asal dan tujuan tidak boleh sama');
      }
      const targetWallet = this.db.prepare('SELECT * FROM wallets WHERE id = ?').get(data.target_wallet_id);
      if (!targetWallet) {
        throw new Error('Dompet tujuan tidak ditemukan');
      }
    }

    const id = 'tx_' + cryptoNative();

    // Use SQLite transaction to ensure atomicity
    const executeTransaction = this.db.transaction(() => {
      this.db.prepare(`
        INSERT INTO transactions (id, wallet_id, target_wallet_id, category_id, type, amount, date, note)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        id,
        data.wallet_id,
        data.target_wallet_id || null,
        data.category_id || null,
        data.type,
        data.amount,
        data.date,
        data.note || null
      );

      // Balance adjustment logic
      if (data.type === 'income') {
        this.db.prepare('UPDATE wallets SET balance = balance + ? WHERE id = ?').run(data.amount, data.wallet_id);
      } else if (data.type === 'expense') {
        this.db.prepare('UPDATE wallets SET balance = balance - ? WHERE id = ?').run(data.amount, data.wallet_id);
      } else if (data.type === 'transfer') {
        this.db.prepare('UPDATE wallets SET balance = balance - ? WHERE id = ?').run(data.amount, data.wallet_id);
        this.db.prepare('UPDATE wallets SET balance = balance + ? WHERE id = ?').run(data.amount, data.target_wallet_id);
      }
    });

    executeTransaction();

    return this.getById(id)!;
  }

  delete(id: string): boolean {
    const tx = this.getById(id);
    if (!tx) return false;

    const executeDelete = this.db.transaction(() => {
      // Reverse balance adjustment
      if (tx.type === 'income') {
        this.db.prepare('UPDATE wallets SET balance = balance - ? WHERE id = ?').run(tx.amount, tx.wallet_id);
      } else if (tx.type === 'expense') {
        this.db.prepare('UPDATE wallets SET balance = balance + ? WHERE id = ?').run(tx.amount, tx.wallet_id);
      } else if (tx.type === 'transfer') {
        this.db.prepare('UPDATE wallets SET balance = balance + ? WHERE id = ?').run(tx.amount, tx.wallet_id);
        if (tx.target_wallet_id) {
          this.db.prepare('UPDATE wallets SET balance = balance - ? WHERE id = ?').run(tx.amount, tx.target_wallet_id);
        }
      }

      this.db.prepare('DELETE FROM transactions WHERE id = ?').run(id);
    });

    executeDelete();
    return true;
  }

  getDashboardSummary(monthStr?: string) {
    // Current month filter (e.g., '2026-08')
    const currentMonth = monthStr || new Date().toISOString().substring(0, 7);

    const wallets = this.db.prepare('SELECT * FROM wallets').all() as any[];
    const totalBalance = wallets.reduce((acc, w) => acc + w.balance, 0);

    const monthIncome = (this.db.prepare(`
      SELECT SUM(amount) as total FROM transactions
      WHERE type = 'income' AND date LIKE ?
    `).get(`${currentMonth}%`) as any).total || 0;

    const monthExpense = (this.db.prepare(`
      SELECT SUM(amount) as total FROM transactions
      WHERE type = 'expense' AND date LIKE ?
    `).get(`${currentMonth}%`) as any).total || 0;

    // Expenses grouped by category for donut/pie chart
    const expenseByCategory = this.db.prepare(`
      SELECT c.name as category_name, c.color as category_color, SUM(t.amount) as total_amount
      FROM transactions t
      JOIN categories c ON t.category_id = c.id
      WHERE t.type = 'expense' AND t.date LIKE ?
      GROUP BY c.id
      ORDER BY total_amount DESC
    `).all(`${currentMonth}%`);

    return {
      totalBalance,
      monthIncome,
      monthExpense,
      netSavings: monthIncome - monthExpense,
      expenseByCategory,
      walletCount: wallets.length,
    };
  }
}
