import { describe, it, expect, beforeEach } from 'vitest';
import { createDb } from '../src/db/connection.js';
import { createApp } from '../src/app.js';

describe('Nana API Backend Tests', () => {
  let app: ReturnType<typeof createApp>;
  let token: string;
  let token2: string;

  beforeEach(async () => {
    const db = createDb(':memory:');
    app = createApp(db);

    // Register user 1
    const reg1 = await app.request('/api/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'Budi Santoso', email: 'budi@test.com', password: 'password123' }),
    });
    const reg1Data = await reg1.json();
    token = reg1Data.data.token;

    // Register user 2
    const reg2 = await app.request('/api/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'Siti Rahma', email: 'siti@test.com', password: 'secret456' }),
    });
    const reg2Data = await reg2.json();
    token2 = reg2Data.data.token;
  });

  it('GET /api/health returns status ok', async () => {
    const res = await app.request('/api/health');
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.status).toBe('ok');
  });

  it('Register returns 201 with token and user', async () => {
    const db = createDb(':memory:');
    const freshApp = createApp(db);
    const res = await freshApp.request('/api/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'Tono', email: 'tono@test.com', password: 'pass123' }),
    });
    expect(res.status).toBe(201);
    const body = await res.json();
    expect(body.data.token).toBeTruthy();
    expect(body.data.user.email).toBe('tono@test.com');
  });

  it('Duplicate email registration returns 400', async () => {
    const res = await app.request('/api/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'Another Budi', email: 'budi@test.com', password: 'pass123' }),
    });
    expect(res.status).toBe(400);
    const body = await res.json();
    expect(body.error).toContain('terdaftar');
  });

  it('Login with correct credentials returns token', async () => {
    const res = await app.request('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identifier: 'budi@test.com', password: 'password123' }),
    });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.data.token).toBeTruthy();
  });

  it('Login with wrong password returns 401', async () => {
    const res = await app.request('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identifier: 'budi@test.com', password: 'wrongpass' }),
    });
    expect(res.status).toBe(401);
  });

  it('Protected route requires auth token', async () => {
    const res = await app.request('/api/wallets');
    expect(res.status).toBe(401);
  });

  it('Wallet CRUD operations work correctly with Auth Header', async () => {
    // Create Wallet
    const createRes = await app.request('/api/wallets', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
      body: JSON.stringify({ name: 'Bank BCA', type: 'Bank', initialBalance: 500000 }),
    });
    expect(createRes.status).toBe(201);
    const createdData = await createRes.json();
    const walletId = createdData.data.id;
    expect(createdData.data.name).toBe('Bank BCA');
    expect(createdData.data.balance).toBe(500000);

    // Get All Wallets
    const listRes = await app.request('/api/wallets', {
      headers: { 'Authorization': `Bearer ${token}` },
    });
    expect(listRes.status).toBe(200);
    const listData = await listRes.json();
    expect(listData.data.length).toBe(1);

    // Update Wallet
    const updateRes = await app.request(`/api/wallets/${walletId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
      body: JSON.stringify({ name: 'BCA Utama' }),
    });
    expect(updateRes.status).toBe(200);
    expect((await updateRes.json()).data.name).toBe('BCA Utama');
  });

  it('Multi-user data isolation: User1 wallets not visible to User2', async () => {
    // User1 creates a wallet
    await app.request('/api/wallets', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
      body: JSON.stringify({ name: 'Dompet Budi', type: 'Bank', initialBalance: 1000000 }),
    });

    // User2 creates a wallet
    await app.request('/api/wallets', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token2}` },
      body: JSON.stringify({ name: 'Dompet Siti', type: 'E-Wallet', initialBalance: 250000 }),
    });

    // User1 should see only their wallet
    const u1Wallets = await (await app.request('/api/wallets', {
      headers: { 'Authorization': `Bearer ${token}` },
    })).json();
    expect(u1Wallets.data.length).toBe(1);
    expect(u1Wallets.data[0].name).toBe('Dompet Budi');

    // User2 should see only their wallet
    const u2Wallets = await (await app.request('/api/wallets', {
      headers: { 'Authorization': `Bearer ${token2}` },
    })).json();
    expect(u2Wallets.data.length).toBe(1);
    expect(u2Wallets.data[0].name).toBe('Dompet Siti');
  });

  it('User cannot access another user\'s wallet by ID', async () => {
    // User1 creates wallet
    const createRes = await app.request('/api/wallets', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
      body: JSON.stringify({ name: 'Secret Wallet', type: 'Bank', initialBalance: 999999 }),
    });
    const walletId = (await createRes.json()).data.id;

    // User2 tries to access User1's wallet
    const res = await app.request(`/api/wallets/${walletId}`, {
      headers: { 'Authorization': `Bearer ${token2}` },
    });
    expect(res.status).toBe(404);
  });

  it('Handles Income, Expense, and Transfer transactions with exact balance updates', async () => {
    // Create 2 wallets
    const w1Id = (await (await app.request('/api/wallets', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
      body: JSON.stringify({ name: 'Dompet BCA', type: 'Bank', initialBalance: 1000000 }),
    })).json()).data.id;

    const w2Id = (await (await app.request('/api/wallets', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
      body: JSON.stringify({ name: 'GoPay', type: 'E-Wallet', initialBalance: 200000 }),
    })).json()).data.id;

    const categories = (await (await app.request('/api/categories', {
      headers: { 'Authorization': `Bearer ${token}` },
    })).json()).data;
    const incomeCat = categories.find((c: any) => c.type === 'income');
    const expenseCat = categories.find((c: any) => c.type === 'expense');

    // Income
    const incomeRes = await app.request('/api/transactions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
      body: JSON.stringify({ wallet_id: w1Id, category_id: incomeCat.id, type: 'income', amount: 500000, date: '2026-08-24', note: 'Gaji' }),
    });
    expect(incomeRes.status).toBe(201);
    expect((await (await app.request(`/api/wallets/${w1Id}`, { headers: { 'Authorization': `Bearer ${token}` } })).json()).data.balance).toBe(1500000);

    // Expense
    const expenseRes = await app.request('/api/transactions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
      body: JSON.stringify({ wallet_id: w2Id, category_id: expenseCat.id, type: 'expense', amount: 50000, date: '2026-08-24', note: 'Makan' }),
    });
    expect(expenseRes.status).toBe(201);
    expect((await (await app.request(`/api/wallets/${w2Id}`, { headers: { 'Authorization': `Bearer ${token}` } })).json()).data.balance).toBe(150000);

    // Transfer
    const transferRes = await app.request('/api/transactions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
      body: JSON.stringify({ wallet_id: w1Id, target_wallet_id: w2Id, type: 'transfer', amount: 300000, date: '2026-08-24' }),
    });
    expect(transferRes.status).toBe(201);
    expect((await (await app.request(`/api/wallets/${w1Id}`, { headers: { 'Authorization': `Bearer ${token}` } })).json()).data.balance).toBe(1200000);
    expect((await (await app.request(`/api/wallets/${w2Id}`, { headers: { 'Authorization': `Bearer ${token}` } })).json()).data.balance).toBe(450000);

    // Dashboard
    const dashData = (await (await app.request('/api/dashboard?month=2026-08', {
      headers: { 'Authorization': `Bearer ${token}` },
    })).json()).data;
    expect(dashData.totalBalance).toBe(1650000);
    expect(dashData.monthIncome).toBe(500000);
    expect(dashData.monthExpense).toBe(50000);
    expect(dashData.netSavings).toBe(450000);
  });

  it('WA status returns DISCONNECTED for authenticated user with no WA session', async () => {
    const res = await app.request('/api/wa/status', {
      headers: { 'Authorization': `Bearer ${token}` },
    });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.data.status).toBe('DISCONNECTED');
    expect(body.data.qrCode).toBeNull();
  });

  it('WA connect returns 503 when waManager not provided', async () => {
    const res = await app.request('/api/wa/connect', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
    });
    // waManager is undefined in test — expect 503
    expect(res.status).toBe(503);
  });

  it('WA request-pairing-code requires auth', async () => {
    const res = await app.request('/api/wa/request-pairing-code', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phoneNumber: '628123456789' }),
    });
    expect(res.status).toBe(401);
  });

  it('WA request-pairing-code returns 503 when waManager not provided', async () => {
    const res = await app.request('/api/wa/request-pairing-code', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
      body: JSON.stringify({ phoneNumber: '628123456789' }),
    });
    expect(res.status).toBe(503);
  });

  it('System status is scoped to authenticated user', async () => {
    // User1 creates a wallet
    await app.request('/api/wallets', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
      body: JSON.stringify({ name: 'BCA User1', type: 'Bank', initialBalance: 100000 }),
    });

    // User1 system status shows wallet_count=1
    const s1 = await (await app.request('/api/system/status', {
      headers: { 'Authorization': `Bearer ${token}` },
    })).json();
    expect(s1.data.wallet_count).toBe(1);

    // User2 system status shows wallet_count=0
    const s2 = await (await app.request('/api/system/status', {
      headers: { 'Authorization': `Bearer ${token2}` },
    })).json();
    expect(s2.data.wallet_count).toBe(0);
  });
});
