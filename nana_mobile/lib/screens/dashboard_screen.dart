import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../theme/luminous_ledger_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/custom_app_bar.dart';
import '../utils/currency_formatter.dart';
import '../models/dashboard_summary.dart';

import 'wallet_form_modal.dart';
import 'transaction_form_modal.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'wallet_management_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final int _selectedBottomNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    final dashboardSummaryAsync = ref.watch(dashboardSummaryProvider);
    final walletsAsync = ref.watch(walletsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      backgroundColor: LuminousLedgerColors.background,
      body: Stack(
        children: [
          // Scrollable Content
          RefreshIndicator(
            onRefresh: () async {
              ref.read(walletsProvider.notifier).fetchWallets();
              ref.read(transactionsProvider.notifier).fetchTransactions();
              ref.invalidate(dashboardSummaryProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 90.0, // Space for custom top app bar
                bottom: 110.0, // Space for bottom navbar
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Server Status Badge
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: LuminousLedgerColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: LuminousLedgerColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Server: Online',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: LuminousLedgerColors.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.dns, size: 16, color: LuminousLedgerColors.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Total Balance Glassmorphic Card
                  dashboardSummaryAsync.when(
                    data: (summary) => _buildTotalBalanceGlassCard(context, summary),
                    loading: () => const GlassCard(
                      child: SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (err, _) => GlassCard(
                      child: Text('Gagal memuat ringkasan: ${err.toString()}'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Wallets Header & Scroll List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Wallets',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      IconButton(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const WalletFormModal(),
                          );
                        },
                        icon: const Icon(Icons.add_circle_outline, color: LuminousLedgerColors.surfaceTint),
                        tooltip: 'Tambah Dompet',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  walletsAsync.when(
                    data: (wallets) {
                      if (wallets.isEmpty) {
                        return const GlassCard(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text('Belum ada dompet. Klik "+" di atas untuk menambah.'),
                            ),
                          ),
                        );
                      }
                      return SizedBox(
                        height: 124,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: wallets.length,
                          itemBuilder: (context, index) {
                            final w = wallets[index];
                            IconData walletIcon = Icons.account_balance;
                            Color iconColor = LuminousLedgerColors.surfaceTint;

                            final typeLower = w.type.toLowerCase();
                            if (typeLower.contains('wallet') || typeLower.contains('e-wallet')) {
                              walletIcon = Icons.smartphone;
                              iconColor = const Color(0xFF416656);
                            } else if (typeLower.contains('cash') || typeLower.contains('tunai')) {
                              walletIcon = Icons.payments;
                              iconColor = const Color(0xFF4F1F19);
                            }

                            return Container(
                              width: 200,
                              margin: const EdgeInsets.only(right: 14),
                              child: GlassCard(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Icon(walletIcon, color: iconColor, size: 22),
                                        Text(
                                          w.name.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: LuminousLedgerColors.onSurfaceVariant,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      CurrencyFormatter.format(w.balance),
                                      style: LuminousLedgerTheme.financialStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: LuminousLedgerColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Text('Error: ${err.toString()}'),
                  ),
                  const SizedBox(height: 24),

                  // Main Content Grid (Weekly Spending & Recent Transactions)
                  _buildWeeklySpendingCard(context, transactionsAsync),
                  const SizedBox(height: 24),

                  _buildRecentTransactionsSection(context, transactionsAsync),
                ],
              ),
            ),
          ),

          // Custom Glassmorphic Top App Bar
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CustomAppBar(title: 'Nana'),
          ),

          // Custom Bottom Navigation Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: EdgeInsets.only(
                    top: 10,
                    bottom: MediaQuery.of(context).padding.bottom + 8,
                    left: 16,
                    right: 16,
                  ),
                  decoration: BoxDecoration(
                    color: LuminousLedgerColors.background.withValues(alpha: 0.85),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        offset: const Offset(0, -4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(
                        index: 0,
                        icon: Icons.home,
                        label: 'Home',
                        isActive: _selectedBottomNavIndex == 0,
                        onTap: () {},
                      ),
                      _buildNavItem(
                        index: 1,
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Wallet',
                        isActive: _selectedBottomNavIndex == 1,
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const WalletManagementScreen()),
                          );
                        },
                      ),
                      _buildNavItem(
                        index: 2,
                        icon: Icons.insights_outlined,
                        label: 'Analytics',
                        isActive: _selectedBottomNavIndex == 2,
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                          );
                        },
                      ),
                      _buildNavItem(
                        index: 3,
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        isActive: _selectedBottomNavIndex == 3,
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70.0),
        child: FloatingActionButton(
          heroTag: 'add_tx_fab',
          backgroundColor: LuminousLedgerColors.primary,
          elevation: 4,
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const TransactionFormModal(),
            );
          },
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildTotalBalanceGlassCard(BuildContext context, DashboardSummary summary) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          // Background ambient light circle
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LuminousLedgerColors.secondaryFixed.withValues(alpha: 0.35),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TOTAL BALANCE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: LuminousLedgerColors.onSurfaceVariant,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                CurrencyFormatter.format(summary.totalBalance),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: LuminousLedgerColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.arrow_downward, size: 14, color: LuminousLedgerColors.incomeText),
                      const SizedBox(width: 4),
                      Text(
                        'Masuk: ${CurrencyFormatter.format(summary.monthIncome)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: LuminousLedgerColors.incomeText,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.arrow_upward, size: 14, color: LuminousLedgerColors.alertRed),
                      const SizedBox(width: 4),
                      Text(
                        'Keluar: ${CurrencyFormatter.format(summary.monthExpense)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: LuminousLedgerColors.alertRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklySpendingCard(BuildContext context, AsyncValue transactionsAsync) {
    // Calculate last 7 days spending dynamically from transactions
    final days = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    final now = DateTime.now();
    
    // Map of day index (0..6) to total expense amount
    final Map<int, double> dailyExpenses = {for (var i = 0; i < 7; i++) i: 0.0};
    
    transactionsAsync.whenData((txs) {
      for (final tx in txs) {
        if (tx.type == 'expense') {
          try {
            final txDate = DateTime.parse(tx.date);
            final difference = now.difference(txDate).inDays;
            if (difference >= 0 && difference < 7) {
              dailyExpenses[txDate.weekday % 7] = (dailyExpenses[txDate.weekday % 7] ?? 0.0) + tx.amount;
            }
          } catch (_) {}
        }
      }
    });

    double maxExpense = dailyExpenses.values.fold(0.0, (prev, curr) => curr > prev ? curr : prev);
    if (maxExpense == 0) maxExpense = 1.0; // avoid division by zero

    // Show last 5 days up to today
    final List<int> daysToDisplay = [];
    for (int i = 4; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      daysToDisplay.add(d.weekday % 7);
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pengeluaran Mingguan',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Icon(Icons.bar_chart, color: LuminousLedgerColors.surfaceTint),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: daysToDisplay.map((dayIdx) {
                final expense = dailyExpenses[dayIdx] ?? 0.0;
                final heightRatio = (expense / maxExpense).clamp(0.05, 1.0);
                final isToday = dayIdx == (now.weekday % 7);
                final amountText = expense >= 1000000
                    ? '${(expense / 1000000).toStringAsFixed(1)}M'
                    : (expense >= 1000 ? '${(expense / 1000).toStringAsFixed(0)}K' : '${expense.toInt()}');

                return _buildBarItem(days[dayIdx], heightRatio, amountText, isToday);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarItem(String day, double heightRatio, String amountText, bool isSelected) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF2E312F),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            amountText,
            style: LuminousLedgerTheme.financialStyle(
              fontSize: 10,
              color: const Color(0xFFEFF1EE),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 32,
          height: 100 * heightRatio,
          decoration: BoxDecoration(
            color: isSelected ? LuminousLedgerColors.primary : LuminousLedgerColors.surfaceContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: LuminousLedgerColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? LuminousLedgerColors.primary : LuminousLedgerColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactionsSection(BuildContext context, AsyncValue transactionsAsync) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              GestureDetector(
                onTap: () {
                  ref.read(transactionsProvider.notifier).fetchTransactions();
                },
                child: const Text(
                  'REFRESH',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: LuminousLedgerColors.surfaceTint,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          transactionsAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Belum ada transaksi.',
                      style: TextStyle(color: LuminousLedgerColors.onSurfaceVariant),
                    ),
                  ),
                );
              }
              final displayList = transactions.take(5).toList();
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final tx = displayList[index];
                  final isIncome = tx.type == 'income';
                  final isTransfer = tx.type == 'transfer';

                  IconData icon = Icons.receipt_long;
                  Color iconBg = LuminousLedgerColors.primaryContainer.withValues(alpha: 0.2);
                  Color iconColor = LuminousLedgerColors.primaryContainer;

                  if (isIncome) {
                    icon = Icons.south_west;
                    iconBg = LuminousLedgerColors.secondaryContainer.withValues(alpha: 0.3);
                    iconColor = LuminousLedgerColors.incomeText;
                  } else if (isTransfer) {
                    icon = Icons.swap_horiz;
                    iconBg = Colors.blue.shade100;
                    iconColor = Colors.blue.shade800;
                  } else {
                    icon = Icons.north_east;
                    iconBg = LuminousLedgerColors.tertiaryContainer.withValues(alpha: 0.2);
                    iconColor = LuminousLedgerColors.alertRed;
                  }

                  String amountStr = '${isIncome ? '+' : (isTransfer ? '' : '-')}${CurrencyFormatter.format(tx.amount)}';

                  return Dismissible(
                    key: Key(tx.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: LuminousLedgerColors.alertRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      ref.read(transactionsProvider.notifier).deleteTransaction(tx.id);
                      ref.invalidate(dashboardSummaryProvider);
                      ref.read(walletsProvider.notifier).fetchWallets();
                    },
                    child: GestureDetector(
                      onTap: () => _showTransactionDetailModal(context, tx),
                      child: _buildTransactionTile(
                        icon: icon,
                        iconBg: iconBg,
                        iconColor: iconColor,
                        title: tx.note != null && tx.note!.isNotEmpty
                            ? tx.note!
                            : (tx.categoryName ?? (isTransfer ? 'Transfer Dompet' : 'Transaksi')),
                        category: isTransfer
                            ? '${tx.walletName ?? "Dompet"} ➔ ${tx.targetWalletName ?? "Tujuan"}'
                            : '${tx.walletName ?? "Dompet"} • ${tx.date}',
                        amount: amountStr,
                        isIncome: isIncome,
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error: ${err.toString()}'),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetailModal(BuildContext context, dynamic tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF191C1B).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: Color(0xFFB0F0D6), size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Detail Transaksi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tx.type == 'income'
                          ? const Color(0xFFB0F0D6).withValues(alpha: 0.2)
                          : (tx.type == 'expense' ? Colors.red.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tx.type == 'income' ? 'PEMASUKAN' : (tx.type == 'expense' ? 'PENGELUARAN' : 'TRANSFER'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: tx.type == 'income'
                            ? const Color(0xFFB0F0D6)
                            : (tx.type == 'expense' ? Colors.redAccent : Colors.blueAccent),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                CurrencyFormatter.format(tx.amount),
                style: LuminousLedgerTheme.financialStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Tanggal', tx.date),
              _buildDetailRow('Dompet Asal', tx.walletName ?? '-'),
              if (tx.type == 'transfer') _buildDetailRow('Dompet Tujuan', tx.targetWalletName ?? '-'),
              _buildDetailRow('Kategori', tx.categoryName ?? 'Umum'),
              _buildDetailRow('Catatan', tx.note ?? '-'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ref.read(transactionsProvider.notifier).deleteTransaction(tx.id);
                    ref.invalidate(dashboardSummaryProvider);
                    ref.read(walletsProvider.notifier).fetchWallets();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaksi berhasil dihapus!')),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  label: const Text('HAPUS TRANSAKSI INI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFFD8DBD7))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildTransactionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String category,
    required String amount,
    bool isIncome = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: LuminousLedgerColors.onSurface,
                  ),
                ),
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 12,
                    color: LuminousLedgerColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: LuminousLedgerTheme.financialStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isIncome ? LuminousLedgerColors.incomeText : LuminousLedgerColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: isActive
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 6)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: isActive
            ? BoxDecoration(
                color: LuminousLedgerColors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive
                  ? LuminousLedgerColors.secondaryFixed
                  : LuminousLedgerColors.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? LuminousLedgerColors.secondaryFixed
                    : LuminousLedgerColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
