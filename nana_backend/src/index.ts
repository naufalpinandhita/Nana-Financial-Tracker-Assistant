import { serve } from '@hono/node-server';
import { createDb } from './db/connection.js';
import { createApp } from './app.js';
import { WalletService } from './services/walletService.js';
import { CategoryService } from './services/categoryService.js';
import { TransactionService } from './services/transactionService.js';
import { AiParserService } from './services/aiParserService.js';
import { WaService } from './services/waService.js';

const dbPath = process.env.DATABASE_PATH || 'nana.db';
const port = parseInt(process.env.PORT || '3000', 10);

const db = createDb(dbPath);

const walletService = new WalletService(db);
const categoryService = new CategoryService(db);
const transactionService = new TransactionService(db);
const aiParserService = new AiParserService(db);

const waService = new WaService(
  db,
  walletService,
  categoryService,
  transactionService,
  aiParserService
);

// Start WA socket in background
if (process.env.DISABLE_WA !== 'true') {
  waService.startSocket().catch((err) => {
    console.error('Failed to start WhatsApp Service:', err);
  });
}

const app = createApp(db, waService, aiParserService);

console.log(`🚀 Nana Backend API listening on http://localhost:${port}`);
serve({
  fetch: app.fetch,
  port,
});
