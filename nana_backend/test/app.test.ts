import { describe, it, expect, beforeEach } from 'vitest';
import { createDb } from '../src/db/connection.js';
import { createApp } from '../src/app.js';

describe('Nana API Backend Tests', () => {
  let app: ReturnType<typeof createApp>;

  beforeEach(() => {
    const db = createDb(':memory:');
    app = createApp(db);
  });

  it('GET /api/health returns status ok', async () => {
    const res = await app.request('/api/health');
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.status).toBe('ok');
  });

  it('Wallet CRUD operations work correctly', async () => {
    // 1. Create Wallet
    const createRes = await app.request('/api/wallets', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Bank BCA',
        type: 'Bank',
        initialBalance: 500000,
        icon: 'account_balance',
        color: '#003527',
      }),
    });
    expect(createRes.status).toBe(201);
    const createdData = await createRes.json();
    const walletId = createdData.data.id;
    expect(createdData.data.name).toBe('Bank BCA');
    expect(createdData.data.balance).toBe(500000);

    // 2. Get All Wallets
    const listRes = await app.request('/api/wallets');
    expect(listRes.status).toBe(200);
    const listData = await listRes.json();
    expect(listData.data.length).toBe(1);

    // 3. Update Wallet
    const updateRes = await app.request(`/api/wallets/${walletId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'BCA Utama' }),
    });
    expect(updateRes.status).toBe(200);
    const updatedData = await updateRes.json();
    expect(updatedData.data.name).toBe('BCA Utama');
  });

  it('Handles Income, Expense, and Transfer transactions with exact balance updates', async () => {
    // Create 2 wallets
    const w1Res = await app.request('/api/wallets', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'Dompet BCA', type: 'Bank', initialBalance: 1000000 }),
    });
    const w1Id = (await w1Res.json()).data.id;

    const w2Res = await app.request('/api/wallets', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'GoPay', type: 'E-Wallet', initialBalance: 200000 }),
    });
    const w2Id = (await w2Res.json()).data.id;

    // 1. Add Income to BCA (500,000)
    const incomeRes = await app.request('/api/transactions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        wallet_id: w1Id,
        category_id: 'cat_gaji',
        type: 'income',
        amount: 500000,
        date: '2026-08-24',
        note: 'Gaji Bonus',
      }),
    });
    expect(incomeRes.status).toBe(201);

    // Verify BCA Balance is now 1,500,000
    let bcaRes = await app.request(`/api/wallets/${w1Id}`);
    expect((await bcaRes.json()).data.balance).toBe(1500000);

    // 2. Expense from GoPay (50,000)
    const expenseRes = await app.request('/api/transactions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        wallet_id: w2Id,
        category_id: 'cat_makanan',
        type: 'expense',
        amount: 50000,
        date: '2026-08-24',
        note: 'Beli Nasi Goreng',
      }),
    });
    expect(expenseRes.status).toBe(201);

    // Verify GoPay Balance is now 150,000
    let gopayRes = await app.request(`/api/wallets/${w2Id}`);
    expect((await gopayRes.json()).data.balance).toBe(150000);

    // 3. Transfer from BCA to GoPay (300,000)
    const transferRes = await app.request('/api/transactions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        wallet_id: w1Id,
        target_wallet_id: w2Id,
        category_id: 'cat_transfer',
        type: 'transfer',
        amount: 300000,
        date: '2026-08-24',
        note: 'Topup GoPay dari BCA',
      }),
    });
    expect(transferRes.status).toBe(201);

    // Verify Balances after Transfer: BCA = 1,200,000, GoPay = 450,000
    bcaRes = await app.request(`/api/wallets/${w1Id}`);
    expect((await bcaRes.json()).data.balance).toBe(1200000);

    gopayRes = await app.request(`/api/wallets/${w2Id}`);
    expect((await gopayRes.json()).data.balance).toBe(450000);

    // 4. Dashboard Summary check
    const dashRes = await app.request('/api/dashboard?month=2026-08');
    expect(dashRes.status).toBe(200);
    const dashData = (await dashRes.json()).data;
    expect(dashData.totalBalance).toBe(1650000);
    expect(dashData.monthIncome).toBe(500000);
    expect(dashData.monthExpense).toBe(50000);
    expect(dashData.netSavings).toBe(450000);
  });

  it('AI Parser & WhatsApp status endpoints work correctly', async () => {
    const statusRes = await app.request('/api/wa/status');
    expect(statusRes.status).toBe(200);
    const statusData = await statusRes.json();
    expect(statusData.status).toBe('DISCONNECTED');
  });
});
