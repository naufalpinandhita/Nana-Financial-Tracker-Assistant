import path from 'path';
import fs from 'fs';
import type Database from 'better-sqlite3';
import { WaService, type WaSessionStatus } from './waService.js';
import { WalletService } from './walletService.js';
import { CategoryService } from './categoryService.js';
import { TransactionService } from './transactionService.js';
import { AiParserService } from './aiParserService.js';

/**
 * WaServiceManager — manages one WaService instance per user.
 * Handles lifecycle: create, restore on boot, retrieve, disconnect.
 */
export class WaServiceManager {
  private sessions = new Map<string, WaService>();
  private readonly sessionsBaseDir: string;

  private db: Database.Database;
  private walletService: WalletService;
  private categoryService: CategoryService;
  private transactionService: TransactionService;
  private aiParserService: AiParserService;

  constructor(
    db: Database.Database,
    walletService: WalletService,
    categoryService: CategoryService,
    transactionService: TransactionService,
    aiParserService: AiParserService,
    sessionsBaseDir: string = './wa_sessions',
  ) {
    this.db = db;
    this.walletService = walletService;
    this.categoryService = categoryService;
    this.transactionService = transactionService;
    this.aiParserService = aiParserService;
    this.sessionsBaseDir = sessionsBaseDir;

    // Ensure base sessions directory exists
    fs.mkdirSync(sessionsBaseDir, { recursive: true });
  }

  /**
   * Get or create a WaService for a given user.
   * Does NOT start the socket — call startSocket() separately.
   */
  public getOrCreate(userId: string): WaService {
    if (this.sessions.has(userId)) {
      return this.sessions.get(userId)!;
    }

    const sessionDir = path.join(this.sessionsBaseDir, userId);
    fs.mkdirSync(sessionDir, { recursive: true });

    const service = new WaService(
      userId,
      sessionDir,
      this.db,
      this.walletService,
      this.categoryService,
      this.transactionService,
      this.aiParserService,
    );

    this.sessions.set(userId, service);
    return service;
  }

  /**
   * Get an existing WaService for a user. Returns null if not initialized.
   */
  public get(userId: string): WaService | null {
    return this.sessions.get(userId) ?? null;
  }

  /**
   * Get the WA status for a user. Returns disconnected state if no session.
   */
  public getStatus(userId: string): WaSessionStatus {
    const service = this.sessions.get(userId);
    if (!service) {
      return { status: 'DISCONNECTED', qrCode: null, connectedNumber: null };
    }
    return service.getStatus();
  }

  /**
   * Disconnect and remove a user's WA session from memory.
   */
  public async disconnectUser(userId: string): Promise<void> {
    const service = this.sessions.get(userId);
    if (service) {
      await service.disconnect();
      this.sessions.delete(userId);
    }
  }

  /**
   * On server boot, restore sessions for all users who were previously CONNECTED.
   * Called from index.ts after DB and services are initialized.
   */
  public async restoreConnectedSessions(): Promise<void> {
    if (process.env.DISABLE_WA === 'true') {
      console.log('[WaManager] WA disabled via DISABLE_WA env. Skipping restore.');
      return;
    }

    try {
      const connectedSessions = this.db.prepare(`
        SELECT user_id, session_dir FROM wa_sessions
        WHERE status = 'CONNECTED'
      `).all() as Array<{ user_id: string; session_dir: string }>;

      console.log(`[WaManager] Restoring ${connectedSessions.length} connected WA session(s)...`);

      for (const row of connectedSessions) {
        // Only restore if session directory actually exists (has auth files)
        if (fs.existsSync(row.session_dir)) {
          const service = this.getOrCreate(row.user_id);
          service.startSocket().catch((err) => {
            console.error(`[WaManager] Failed to restore session for ${row.user_id}:`, err);
          });
        }
      }
    } catch (err) {
      console.error('[WaManager] Failed to restore sessions:', err);
    }
  }
}
