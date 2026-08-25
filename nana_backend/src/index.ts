import { serve } from '@hono/node-server';
import { createDb } from './db/connection.js';
import { createApp } from './app.js';
import { WalletService } from './services/walletService.js';
import { CategoryService } from './services/categoryService.js';
import { TransactionService } from './services/transactionService.js';
import { AiParserService } from './services/aiParserService.js';
import { WaServiceManager } from './services/waServiceManager.js';

const dbPath = process.env.DATABASE_PATH || 'nana.db';
const port = parseInt(process.env.PORT || '3000', 10);

const db = createDb(dbPath);

const walletService = new WalletService(db);
const categoryService = new CategoryService(db);
const transactionService = new TransactionService(db);
const aiParserService = new AiParserService(db);

const waManager = new WaServiceManager(
  db,
  walletService,
  categoryService,
  transactionService,
  aiParserService,
);

// Restore previously connected WA sessions on boot
waManager.restoreConnectedSessions().catch((err) => {
  console.error('Failed to restore WA sessions:', err);
});

const app = createApp(db, waManager, aiParserService);

console.log(`🚀 Nana Backend API listening on http://localhost:${port}`);
serve({
  fetch: app.fetch,
  port,
});
