import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_providers.dart';
import '../theme/luminous_ledger_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/custom_app_bar.dart';
import '../models/dashboard_summary.dart';
import '../utils/currency_formatter.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'wallet_management_screen.dart';

import 'package:intl/intl.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  final int _selectedBottomNavIndex = 2; // Active: Analytics

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedAnalyticsMonthProvider);
    final monthStr = DateFormat('yyyy-MM').format(selectedDate);
    final dashboardSummaryAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      backgroundColor: LuminousLedgerColors.background,
      body: Stack(
        children: [
          // Scrollable Canvas Area
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardSummaryProvider);
              ref.invalidate(aiAdviceProvider(monthStr));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 90.0,
                bottom: 110.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Title & Date Picker Filter Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Analytics & Reports',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: LuminousLedgerColors.primary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Your financial overview and insights.',
                            style: TextStyle(
                              fontSize: 14,
                              color: LuminousLedgerColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Date Picker Pill Filter Button (Interactive Month Selector)
                  GestureDetector(
                    onTap: () => _selectMonthPicker(context),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      borderRadius: 24,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: 18,
                            color: LuminousLedgerColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMMM yyyy').format(selectedDate),
                            style: LuminousLedgerTheme.financialStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: LuminousLedgerColors.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.expand_more,
                            size: 18,
                            color: LuminousLedgerColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Donut Chart Card (Spending by Category)
                  dashboardSummaryAsync.when(
                    data: (summary) => _buildDonutChartCard(context, summary),
                    loading: () => const GlassCard(
                      child: SizedBox(
                        height: 280,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (err, st) => _buildDonutChartCard(context, null),
                  ),
                  const SizedBox(height: 20),

                  // Monthly Trend Chart Section
                  _buildMonthlyTrendCard(context, dashboardSummaryAsync),
                  const SizedBox(height: 20),

                  // AI Insights Panel Card (Glowing & Gradient)
                  _buildAIInsightsPanel(context, dashboardSummaryAsync),
                ],
              ),
            ),
          ),

                  // Custom Glassmorphic Top App Bar
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CustomAppBar(title: 'Analytics'),
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
                                icon: Icons.home_outlined,
                                label: 'Home',
                                isActive: _selectedBottomNavIndex == 0,
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                                  );
                                },
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
                                icon: Icons.insights,
                                label: 'Analytics',
                                isActive: _selectedBottomNavIndex == 2,
                                onTap: () {},
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
            );
          }

  Widget _buildDonutChartCard(BuildContext context, DashboardSummary? summary) {
    final expenseCategories = summary?.expenseByCategory ?? [];
    final totalExpense = summary?.monthExpense ?? 0.0;

    final defaultColors = [
      LuminousLedgerColors.primary,
      LuminousLedgerColors.surfaceTint,
      const Color(0xFF80BEA6),
      LuminousLedgerColors.incomeMint,
      LuminousLedgerColors.alertRed,
      Colors.orange,
    ];

    List<PieChartSectionData> sections = [];

    if (expenseCategories.isEmpty) {
      sections = [
        PieChartSectionData(
          color: LuminousLedgerColors.outlineVariant.withValues(alpha: 0.5),
          value: 100,
          showTitle: false,
          radius: 25,
        ),
      ];
    } else {
      sections = expenseCategories.asMap().entries.map((entry) {
        final idx = entry.key;
        final cat = entry.value;
        final colorHex = cat.categoryColor.replaceFirst('#', '0xFF');
        final color = Color(int.tryParse(colorHex) ?? defaultColors[idx % defaultColors.length].toARGB32());
        final val = totalExpense > 0 ? (cat.totalAmount / totalExpense) * 100 : 0.0;

        return PieChartSectionData(
          color: color,
          value: val > 0 ? val : 1,
          showTitle: false,
          radius: 25,
        );
      }).toList();
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pengeluaran per Kategori',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: LuminousLedgerColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 190,
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 65,
                      sections: sections,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Total Pengeluaran',
                        style: TextStyle(
                          fontSize: 11,
                          color: LuminousLedgerColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(totalExpense),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: LuminousLedgerColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (expenseCategories.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              itemCount: expenseCategories.length,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, idx) {
                final cat = expenseCategories[idx];
                final colorHex = cat.categoryColor.replaceFirst('#', '0xFF');
                final color = Color(int.tryParse(colorHex) ?? defaultColors[idx % defaultColors.length].toARGB32());
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: _LegendItem(color: color, label: '${cat.categoryName} (${CurrencyFormatter.format(cat.totalAmount)})'),
                );
              },
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Belum ada data pengeluaran bulan ini',
                  style: TextStyle(fontSize: 12, color: LuminousLedgerColors.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendCard(BuildContext context, AsyncValue<DashboardSummary> summaryAsync) {
    double income = 0;
    double expense = 0;

    summaryAsync.whenData((s) {
      income = s.monthIncome;
      expense = s.monthExpense;
    });

    double maxVal = (income > expense ? income : expense);
    if (maxVal == 0) maxVal = 1;

    double incomeRatio = (income / maxVal).clamp(0.05, 1.0);
    double expenseRatio = (expense / maxVal).clamp(0.05, 1.0);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tren Bulanan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: LuminousLedgerColors.onSurfaceVariant,
                ),
              ),
              Row(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: LuminousLedgerColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Pemasukan',
                        style: TextStyle(fontSize: 12, color: LuminousLedgerColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: LuminousLedgerColors.alertRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Pengeluaran',
                        style: TextStyle(fontSize: 12, color: LuminousLedgerColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDoubleBar('Bulan Ini', incomeRatio, expenseRatio),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoubleBar(String weekLabel, double incomeRatio, double expenseRatio) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 24,
          height: 140,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Income outer bar
              Container(
                width: 24,
                height: 140 * incomeRatio,
                decoration: BoxDecoration(
                  color: LuminousLedgerColors.primary.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
              // Expense inner overlay bar
              Container(
                width: 24,
                height: 140 * expenseRatio,
                decoration: BoxDecoration(
                  color: LuminousLedgerColors.alertRed.withValues(alpha: 0.4),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          weekLabel,
          style: LuminousLedgerTheme.financialStyle(
            fontSize: 11,
            color: LuminousLedgerColors.outlineVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _selectMonthPicker(BuildContext context) async {
    final currentSelected = ref.read(selectedAnalyticsMonthProvider);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentSelected,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'PILIH BULAN LOKASI LAPORAN',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      ref.read(selectedAnalyticsMonthProvider.notifier).state = picked;
      ref.invalidate(dashboardSummaryProvider);
    }
  }

  Widget _buildAIInsightsPanel(BuildContext context, AsyncValue<DashboardSummary> summaryAsync) {
    final selectedDate = ref.watch(selectedAnalyticsMonthProvider);
    final monthStr = DateFormat('yyyy-MM').format(selectedDate);
    final aiAdviceAsync = ref.watch(aiAdviceProvider(monthStr));

    String topCategory = 'Belum Ada';
    double topAmount = 0.0;
    double savingsRate = 0.0;

    summaryAsync.whenData((s) {
      if (s.expenseByCategory.isNotEmpty) {
        topCategory = s.expenseByCategory.first.categoryName;
        topAmount = s.expenseByCategory.first.totalAmount;
      }
      if (s.monthIncome > 0) {
        savingsRate = ((s.monthIncome - s.monthExpense) / s.monthIncome) * 100;
        if (savingsRate < 0) savingsRate = 0.0;
      }
    });

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            LuminousLedgerColors.background.withValues(alpha: 0.9),
            const Color(0xFF6366F1).withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Color(0xFF6366F1),
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Financial Advisor (LLM)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: LuminousLedgerColors.primary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF6366F1)),
                onPressed: () => ref.invalidate(aiAdviceProvider(monthStr)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dynamic Narrative Advice Card from AI Gateway
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
            ),
            child: aiAdviceAsync.when(
              data: (advice) => Text(
                advice,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: LuminousLedgerColors.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              loading: () => const Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1))),
                  SizedBox(width: 10),
                  Text('Menghasilkan nasihat AI personal...', style: TextStyle(fontSize: 12, color: LuminousLedgerColors.onSurfaceVariant)),
                ],
              ),
              error: (err, _) => Text(
                'AI Advisor siap menganalisis keuangan kamu.',
                style: TextStyle(fontSize: 12, color: LuminousLedgerColors.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Top Expense Category Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kategori Pengeluaran Tertinggi',
                  style: TextStyle(
                    fontSize: 13,
                    color: LuminousLedgerColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      topCategory,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: LuminousLedgerColors.primary,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(topAmount),
                      style: LuminousLedgerTheme.financialStyle(
                        fontSize: 14,
                        color: LuminousLedgerColors.alertRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Savings Rate Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rasio Tabungan Bulan Ini',
                  style: TextStyle(
                    fontSize: 13,
                    color: LuminousLedgerColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${savingsRate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: LuminousLedgerColors.primary,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          savingsRate >= 20 ? Icons.thumb_up : Icons.info_outline,
                          size: 16,
                          color: savingsRate >= 20 ? LuminousLedgerColors.primary : LuminousLedgerColors.alertRed,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          savingsRate >= 20 ? 'Kondisi Sehat' : 'Perlu Dihemat',
                          style: LuminousLedgerTheme.financialStyle(
                            fontSize: 12,
                            color: savingsRate >= 20 ? LuminousLedgerColors.primary : LuminousLedgerColors.alertRed,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Progress Bar
                Container(
                  width: double.infinity,
                  height: 8,
                  decoration: BoxDecoration(
                    color: LuminousLedgerColors.secondaryFixed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (savingsRate / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: LuminousLedgerColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: LuminousLedgerColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}