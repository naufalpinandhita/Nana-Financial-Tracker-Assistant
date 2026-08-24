import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../theme/luminous_ledger_theme.dart';
import '../widgets/glass_card.dart';

class TransactionFormModal extends ConsumerStatefulWidget {
  const TransactionFormModal({super.key});

  @override
  ConsumerState<TransactionFormModal> createState() => _TransactionFormModalState();
}

class _TransactionFormModalState extends ConsumerState<TransactionFormModal> {
  final _formKey = GlobalKey<FormState>();
  String _txType = 'expense'; // 'income' | 'expense' | 'transfer'
  
  String? _selectedWalletId;
  String? _selectedTargetWalletId;
  String? _selectedCategoryId;

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih dompet terlebih dahulu')),
      );
      return;
    }
    if (_txType == 'transfer' && _selectedTargetWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih dompet tujuan transfer')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.tryParse(_amountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
      final dateStr = _selectedDate.toISOStringDate();

      await ref.read(transactionsProvider.notifier).addTransaction(
            walletId: _selectedWalletId!,
            targetWalletId: _txType == 'transfer' ? _selectedTargetWalletId : null,
            categoryId: _txType == 'transfer' ? 'cat_transfer' : _selectedCategoryId,
            type: _txType,
            amount: amount,
            date: dateStr,
            note: _noteController.text.trim(),
          );

      // Refresh wallets & dashboard summary
      ref.read(walletsProvider.notifier).fetchWallets();
      ref.invalidate(dashboardSummaryProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi berhasil dicatat!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: GlassCard(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Catat Transaksi',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                
                // Transaction Type Selector
                Row(
                  children: [
                    _buildTypeChip('expense', 'Pengeluaran', LuminousLedgerColors.alertRed),
                    const SizedBox(width: 8),
                    _buildTypeChip('income', 'Pemasukan', LuminousLedgerColors.incomeText),
                    const SizedBox(width: 8),
                    _buildTypeChip('transfer', 'Transfer', Colors.blue.shade700),
                  ],
                ),
                const SizedBox(height: 16),

                // Amount Input
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: LuminousLedgerTheme.financialStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'Nominal (Rp)',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Nominal wajib diisi';
                    final parsed = double.tryParse(val.replaceAll('.', '').replaceAll(',', ''));
                    if (parsed == null || parsed <= 0) return 'Nominal harus lebih dari 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Wallet Selection
                walletsAsync.when(
                  data: (wallets) {
                    if (wallets.isEmpty) {
                      return const Text('Belum ada dompet. Buat dompet dulu!');
                    }
                    _selectedWalletId ??= wallets.first.id;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _selectedWalletId,
                          decoration: InputDecoration(
                            labelText: _txType == 'transfer' ? 'Dari Dompet' : 'Pilih Dompet',
                            border: const OutlineInputBorder(),
                          ),
                          items: wallets
                              .map((w) => DropdownMenuItem(
                                    value: w.id,
                                    child: Text('${w.name} (${w.type})'),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedWalletId = val);
                          },
                        ),
                        if (_txType == 'transfer') ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedTargetWalletId,
                            decoration: const InputDecoration(
                              labelText: 'Ke Dompet Tujuan',
                              border: OutlineInputBorder(),
                            ),
                            items: wallets
                                .where((w) => w.id != _selectedWalletId)
                                .map((w) => DropdownMenuItem(
                                      value: w.id,
                                      child: Text('${w.name} (${w.type})'),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedTargetWalletId = val);
                            },
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (err, _) => Text('Gagal memuat dompet: ${err.toString()}'),
                ),
                const SizedBox(height: 12),

                // Category Selection (Only for Income / Expense)
                if (_txType != 'transfer')
                  categoriesAsync.when(
                    data: (categories) {
                      final filtered = categories.where((c) => c.type == _txType).toList();
                      if (filtered.isNotEmpty) {
                        _selectedCategoryId ??= filtered.first.id;
                      }

                      return DropdownButtonFormField<String>(
                        initialValue: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Kategori Transaksi',
                          border: OutlineInputBorder(),
                        ),
                        items: filtered
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategoryId = val);
                        },
                      );
                    },
                    loading: () => const SizedBox(),
                    error: (err, _) => Text('Gagal memuat kategori: ${err.toString()}'),
                  ),
                const SizedBox(height: 12),

                // Note Input
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (Opsional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LuminousLedgerColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Simpan Transaksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type, String label, Color color) {
    final isSelected = _txType == type;
    return Expanded(
      child: ChoiceChip(
        label: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : LuminousLedgerColors.onSurface,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        selected: isSelected,
        selectedColor: color,
        backgroundColor: Colors.white,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _txType = type;
              _selectedCategoryId = null;
            });
          }
        },
      ),
    );
  }
}

extension DateTimeExt on DateTime {
  String toISOStringDate() {
    return "${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
  }
}
