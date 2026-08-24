import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../theme/luminous_ledger_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/custom_app_bar.dart';
import '../utils/currency_formatter.dart';
import '../models/wallet.dart';
import 'wallet_form_modal.dart';
import 'dashboard_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';

class WalletManagementScreen extends ConsumerStatefulWidget {
  const WalletManagementScreen({super.key});

  @override
  ConsumerState<WalletManagementScreen> createState() => _WalletManagementScreenState();
}

class _WalletManagementScreenState extends ConsumerState<WalletManagementScreen> {
  final int _selectedBottomNavIndex = 1; // Active: Wallet
  String _selectedFilter = 'Semua';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<bool?> _showDeleteConfirmDialog(String walletName) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Dompet'),
        content: Text('Apakah Anda yakin ingin menghapus dompet "$walletName"? Seluruh riwayat transaksi di dompet ini akan terhapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletsProvider);

    return Scaffold(
      backgroundColor: LuminousLedgerColors.background,
      body: Stack(
        children: [
          // Scrollable Body Canvas
          RefreshIndicator(
            onRefresh: () async {
              ref.read(walletsProvider.notifier).fetchWallets();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 90.0, // Space for top bar
                bottom: 110.0, // Space for bottom navbar
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Title Header & Global Balance Card
                  _buildHeaderAndTotalBalance(walletsAsync),
                  const SizedBox(height: 20),

                  // Filter Chips & Search Bar
                  _buildFilterAndSearchBar(),
                  const SizedBox(height: 20),

                  // Wallets Grid / List
                  walletsAsync.when(
                    data: (wallets) => _buildWalletsGrid(wallets),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => GlassCard(
                      child: Center(child: Text('Gagal memuat dompet: ${err.toString()}')),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Custom Top App Bar (Mobile Profile Header)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CustomAppBar(title: 'Wallets'),
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
                        icon: Icons.account_balance_wallet,
                        label: 'Wallet',
                        isActive: _selectedBottomNavIndex == 1,
                        onTap: () {},
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
          backgroundColor: LuminousLedgerColors.primary,
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const WalletFormModal(),
            );
          },
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildHeaderAndTotalBalance(AsyncValue<List<Wallet>> walletsAsync) {
    double totalBalance = 0;
    if (walletsAsync.hasValue && walletsAsync.value != null) {
      totalBalance = walletsAsync.value!.fold(0, (sum, w) => sum + w.balance);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Semua Dompet',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: LuminousLedgerColors.onSurface,
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Kelola dan pantau seluruh aset keuangan Anda dalam satu tempat.',
          style: TextStyle(
            fontSize: 14,
            color: LuminousLedgerColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),

        // Global Balance Card
        GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL SALDO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: LuminousLedgerColors.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(totalBalance),
                    style: LuminousLedgerTheme.financialStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: LuminousLedgerColors.primary,
                    ),
                  ),
                ],
              ),
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: LuminousLedgerColors.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: LuminousLedgerColors.onSecondaryContainer,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterAndSearchBar() {
    final filters = [
      {'label': 'Semua', 'icon': Icons.apps},
      {'label': 'Bank', 'icon': Icons.account_balance},
      {'label': 'Investasi', 'icon': Icons.trending_up},
      {'label': 'Tunai', 'icon': Icons.payments},
    ];

    return Column(
      children: [
        // Horizontal Filter Chips
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            itemBuilder: (context, idx) {
              final f = filters[idx];
              final label = f['label'] as String;
              final icon = f['icon'] as IconData;
              final isSelected = _selectedFilter == label;

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: isSelected
                            ? LuminousLedgerColors.secondaryFixed
                            : LuminousLedgerColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(label),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFilter = label;
                      });
                    }
                  },
                  selectedColor: LuminousLedgerColors.primaryContainer,
                  backgroundColor: LuminousLedgerColors.surfaceContainerLow,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? LuminousLedgerColors.secondaryFixed
                        : LuminousLedgerColors.onSurfaceVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : LuminousLedgerColors.outlineVariant,
                    ),
                  ),
                  showCheckmark: false,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Recessed Search Input
        Container(
          decoration: BoxDecoration(
            color: LuminousLedgerColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val.toLowerCase();
              });
            },
            decoration: const InputDecoration(
              hintText: 'Cari dompet...',
              hintStyle: TextStyle(fontSize: 14, color: LuminousLedgerColors.outline),
              prefixIcon: Icon(Icons.search, size: 20, color: LuminousLedgerColors.onSurfaceVariant),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWalletsGrid(List<Wallet> wallets) {
    // Apply filters & search query
    List<Wallet> displayWallets = wallets.where((w) {
      final matchesSearch = w.name.toLowerCase().contains(_searchQuery);
      if (_selectedFilter == 'Semua') return matchesSearch;
      if (_selectedFilter == 'Bank') return matchesSearch && w.type.toLowerCase().contains('bank');
      if (_selectedFilter == 'Investasi') return matchesSearch && (w.type.toLowerCase().contains('invest') || w.type.toLowerCase().contains('reksa'));
      if (_selectedFilter == 'Tunai') return matchesSearch && (w.type.toLowerCase().contains('cash') || w.type.toLowerCase().contains('tunai'));
      return matchesSearch;
    }).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        mainAxisExtent: 150,
        mainAxisSpacing: 14,
      ),
      itemCount: displayWallets.length + 1, // +1 for "Tambah Dompet" card
      itemBuilder: (context, index) {
        if (index == displayWallets.length) {
          // Add New Wallet Card
          return _buildAddWalletButtonCard();
        }

        final w = displayWallets[index];
        return Dismissible(
          key: Key(w.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Hapus Dompet?'),
                    content: Text('Apakah Anda yakin ingin menghapus dompet "${w.name}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ) ??
                false;
          },
          onDismissed: (_) {
            ref.read(walletsProvider.notifier).deleteWallet(w.id);
            ref.invalidate(dashboardSummaryProvider);
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: LuminousLedgerColors.alertRed,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.delete, color: Colors.white, size: 28),
          ),
          child: _buildWalletCardItem(w),
        );
      },
    );
  }

  Widget _buildWalletCardItem(Wallet w) {
    IconData typeIcon = Icons.account_balance;
    String typeLabel = w.type;

    final tLower = w.type.toLowerCase();
    if (tLower.contains('invest') || tLower.contains('reksa')) {
      typeIcon = Icons.show_chart;
      typeLabel = 'Investasi';
    } else if (tLower.contains('wallet') || tLower.contains('gopay') || tLower.contains('ovo')) {
      typeIcon = Icons.smartphone;
      typeLabel = 'E-Wallet';
    } else if (tLower.contains('cash') || tLower.contains('tunai')) {
      typeIcon = Icons.payments;
      typeLabel = 'Tunai';
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Stack(
        children: [
          // Blur Glow in top right corner
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LuminousLedgerColors.secondaryFixed.withValues(alpha: 0.3),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: LuminousLedgerColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: LuminousLedgerColors.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(typeIcon, color: LuminousLedgerColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: LuminousLedgerColors.onSurface,
                            ),
                          ),
                          const Text(
                            '**** 4589',
                            style: TextStyle(
                              fontSize: 12,
                              color: LuminousLedgerColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: LuminousLedgerColors.outline,
                    ),
                    onSelected: (action) async {
                      if (action == 'edit') {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => WalletFormModal(
                            walletId: w.id,
                            initialName: w.name,
                            initialType: w.type,
                            initialBalance: w.balance,
                            initialIcon: w.icon,
                            initialColor: w.color,
                          ),
                        );
                      } else if (action == 'delete') {
                        final confirm = await _showDeleteConfirmDialog(w.name);
                        if (confirm == true) {
                          try {
                            await ref.read(walletsProvider.notifier).deleteWallet(w.id);
                            ref.invalidate(dashboardSummaryProvider);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Dompet berhasil dihapus!')),
                              );
                            }
                          } catch (err) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Gagal menghapus: ${err.toString()}')),
                              );
                            }
                          }
                        }
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18, color: LuminousLedgerColors.primary),
                            SizedBox(width: 8),
                            Text('Edit Dompet'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Hapus Dompet', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CurrencyFormatter.format(w.balance),
                    style: LuminousLedgerTheme.financialStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: LuminousLedgerColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.sync, size: 14, color: LuminousLedgerColors.onSurfaceVariant),
                          SizedBox(width: 4),
                          Text(
                            'Baru saja',
                            style: TextStyle(
                              fontSize: 11,
                              color: LuminousLedgerColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: LuminousLedgerColors.secondaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          typeLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: LuminousLedgerColors.onSecondaryContainer,
                          ),
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

  Widget _buildAddWalletButtonCard() {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const WalletFormModal(),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: LuminousLedgerColors.outlineVariant,
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: LuminousLedgerColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: LuminousLedgerColors.outline),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tambah Dompet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: LuminousLedgerColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
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