import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../theme/luminous_ledger_theme.dart';
import '../utils/currency_formatter.dart';

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

  final List<Map<String, String>> _types = [
    {'type': 'expense', 'label': 'Pengeluaran'},
    {'type': 'income', 'label': 'Pemasukan'},
    {'type': 'transfer', 'label': 'Transfer'},
  ];

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

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF191C1B).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 25,
            spreadRadius: 2,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
                  const Icon(Icons.receipt_long, color: Color(0xFFB0F0D6), size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'Catat Transaksi',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 1. Tipe Transaksi Chips
              const Text(
                'TIPE TRANSAKSI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD8DBD7),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: _types.map((t) {
                  final typeKey = t['type']!;
                  final label = t['label']!;
                  final isSelected = _txType == typeKey;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFF003527) : Colors.white,
                            ),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFFB0F0D6),
                        backgroundColor: const Color(0xFF2E312F),
                        showCheckmark: false,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _txType = typeKey;
                              _selectedCategoryId = null;
                            });
                          }
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 2. Nominal Input
              const Text(
                'NOMINAL (RP)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD8DBD7),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                style: LuminousLedgerTheme.financialStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.3)),
                  prefixIcon: const Icon(Icons.attach_money, size: 18, color: Color(0xFFD8DBD7)),
                  filled: true,
                  fillColor: const Color(0xFF2E312F),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFB0F0D6)),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Nominal wajib diisi';
                  final parsed = double.tryParse(val.replaceAll('.', '').replaceAll(',', ''));
                  if (parsed == null || parsed <= 0) return 'Nominal harus lebih dari 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 3. Wallet Selection
              walletsAsync.when(
                data: (wallets) {
                  if (wallets.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Belum ada dompet. Buat dompet dulu!',
                        style: TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    );
                  }
                  _selectedWalletId ??= wallets.first.id;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _txType == 'transfer' ? 'DARI DOMPET' : 'PILIH DOMPET',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD8DBD7),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedWalletId,
                        dropdownColor: const Color(0xFF2E312F),
                        style: const TextStyle(fontSize: 14, color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.account_balance_wallet, size: 18, color: Color(0xFFD8DBD7)),
                          filled: true,
                          fillColor: const Color(0xFF2E312F),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFB0F0D6)),
                          ),
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
                        const SizedBox(height: 16),
                        const Text(
                          'KE DOMPET TUJUAN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD8DBD7),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedTargetWalletId,
                          dropdownColor: const Color(0xFF2E312F),
                          style: const TextStyle(fontSize: 14, color: Colors.white),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.swap_horiz, size: 18, color: Color(0xFFD8DBD7)),
                            filled: true,
                            fillColor: const Color(0xFF2E312F),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFB0F0D6)),
                            ),
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
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
                error: (err, _) => Text('Gagal memuat dompet: ${err.toString()}', style: const TextStyle(color: Colors.redAccent)),
              ),
              const SizedBox(height: 16),

              // 4. Category Selection (Only for Income / Expense)
              if (_txType != 'transfer') ...[
                const Text(
                  'KATEGORI TRANSAKSI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD8DBD7),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                categoriesAsync.when(
                  data: (categories) {
                    final filtered = categories.where((c) => c.type == _txType).toList();
                    if (filtered.isNotEmpty) {
                      _selectedCategoryId ??= filtered.first.id;
                    }

                    return DropdownButtonFormField<String>(
                      initialValue: _selectedCategoryId,
                      dropdownColor: const Color(0xFF2E312F),
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.category, size: 18, color: Color(0xFFD8DBD7)),
                        filled: true,
                        fillColor: const Color(0xFF2E312F),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFB0F0D6)),
                        ),
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
                  error: (err, _) => Text('Gagal memuat kategori: ${err.toString()}', style: const TextStyle(color: Colors.redAccent)),
                ),
                const SizedBox(height: 16),
              ],

              // 5. Note Input
              const Text(
                'CATATAN (OPSIONAL)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD8DBD7),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _noteController,
                style: const TextStyle(fontSize: 14, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Misal: Beli kopi, Gaji bulanan',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.3)),
                  prefixIcon: const Icon(Icons.notes, size: 18, color: Color(0xFFD8DBD7)),
                  filled: true,
                  fillColor: const Color(0xFF2E312F),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFB0F0D6)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB0F0D6),
                    foregroundColor: const Color(0xFF003527),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF003527)))
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    _isLoading ? 'MENYIMPAN...' : 'SIMPAN TRANSAKSI',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

extension DateTimeExt on DateTime {
  String toISOStringDate() {
    return "${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
  }
}
