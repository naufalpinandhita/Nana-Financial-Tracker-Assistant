import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../theme/luminous_ledger_theme.dart';

class WalletFormModal extends ConsumerStatefulWidget {
  final String? walletId;
  final String? initialName;
  final String? initialType;
  final double? initialBalance;
  final String? initialIcon;
  final String? initialColor;

  const WalletFormModal({
    super.key,
    this.walletId,
    this.initialName,
    this.initialType,
    this.initialBalance,
    this.initialIcon,
    this.initialColor,
  });

  @override
  ConsumerState<WalletFormModal> createState() => _WalletFormModalState();
}

class _WalletFormModalState extends ConsumerState<WalletFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  
  late String _selectedType;
  late String _selectedIcon;
  late String _selectedColor;
  bool _isLoading = false;

  final List<Map<String, String>> _types = [
    {'name': 'Bank', 'icon': 'account_balance'},
    {'name': 'E-Wallet', 'icon': 'smartphone'},
    {'name': 'Cash', 'icon': 'payments'},
    {'name': 'Investasi', 'icon': 'trending_up'},
  ];

  final List<String> _colors = [
    '#003527',
    '#064E3B',
    '#2563EB',
    '#D97706',
    '#DB2777',
    '#7C3AED',
    '#059669',
    '#DC2626',
  ];

  final List<Map<String, dynamic>> _availableIcons = [
    {'name': 'account_balance', 'icon': Icons.account_balance, 'label': 'Bank'},
    {'name': 'smartphone', 'icon': Icons.smartphone, 'label': 'E-Wallet'},
    {'name': 'payments', 'icon': Icons.payments, 'label': 'Cash'},
    {'name': 'trending_up', 'icon': Icons.trending_up, 'label': 'Investasi'},
    {'name': 'credit_card', 'icon': Icons.credit_card, 'label': 'Kartu'},
    {'name': 'savings', 'icon': Icons.savings, 'label': 'Tabungan'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _balanceController = TextEditingController(
      text: widget.initialBalance != null ? widget.initialBalance!.toStringAsFixed(0) : '',
    );
    _selectedType = widget.initialType ?? 'Bank';
    _selectedIcon = widget.initialIcon ?? 'account_balance';
    _selectedColor = widget.initialColor ?? '#003527';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final balance = double.tryParse(_balanceController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;

      if (widget.walletId != null) {
        // Edit Wallet Mode (API update support or refresh)
        await ref.read(apiServiceProvider).createWallet(
              name: name,
              type: _selectedType,
              initialBalance: balance,
              icon: _selectedIcon,
              color: _selectedColor,
            );
      } else {
        // Add Wallet Mode
        await ref.read(walletsProvider.notifier).addWallet(
              name: name,
              type: _selectedType,
              initialBalance: balance,
              icon: _selectedIcon,
              color: _selectedColor,
            );
      }

      ref.invalidate(walletsProvider);
      ref.invalidate(dashboardSummaryProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.walletId != null ? 'Dompet berhasil diperbarui!' : 'Dompet baru berhasil dibuat!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.walletId != null;

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
                  const Icon(Icons.account_balance_wallet, color: Color(0xFFB0F0D6), size: 24),
                  const SizedBox(width: 10),
                  Text(
                    isEditing ? 'Edit Dompet' : 'Tambah Dompet Baru',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 1. Nama Dompet Input
              const Text(
                'NAMA DOMPET',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD8DBD7),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(fontSize: 14, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Misal: BCA Utama, GoPay, Cash Harian',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.3)),
                  prefixIcon: const Icon(Icons.account_balance, size: 18, color: Color(0xFFD8DBD7)),
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
                validator: (val) => val == null || val.isEmpty ? 'Nama dompet wajib diisi' : null,
              ),
              const SizedBox(height: 16),

              // 2. Tipe Dompet Segmented Chips
              const Text(
                'TIPE DOMPET',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD8DBD7),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _types.map((t) {
                    final typeName = t['name']!;
                    final isSelected = _selectedType == typeName;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(typeName),
                        selected: isSelected,
                        selectedColor: const Color(0xFFB0F0D6),
                        backgroundColor: const Color(0xFF2E312F),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFF003527) : Colors.white,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedType = typeName;
                              _selectedIcon = t['icon']!;
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Saldo Awal Input
              const Text(
                'SALDO AWAL (RP)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD8DBD7),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _balanceController,
                keyboardType: TextInputType.number,
                style: LuminousLedgerTheme.financialStyle(fontSize: 14, color: Colors.white),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.3)),
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
                ),
              ),
              const SizedBox(height: 16),

              // 4. Icon Selector
              const Text(
                'PILIH ICON',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD8DBD7),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _availableIcons.map((item) {
                  final iconName = item['name'] as String;
                  final iconData = item['icon'] as IconData;
                  final isSelected = _selectedIcon == iconName;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = iconName),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFB0F0D6).withValues(alpha: 0.2) : const Color(0xFF2E312F),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? const Color(0xFFB0F0D6) : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        iconData,
                        size: 20,
                        color: isSelected ? const Color(0xFFB0F0D6) : Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 5. Color Selector
              const Text(
                'PILIH WARNA DOMPET',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD8DBD7),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _colors.map((cHex) {
                  final color = Color(int.parse(cHex.replaceFirst('#', '0xFF')));
                  final isSelected = _selectedColor == cHex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = cHex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2.5)
                            : Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
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
                    _isLoading
                        ? 'MENYIMPAN...'
                        : (isEditing ? 'PERBARUI DOMPET' : 'SIMPAN DOMPET BARU'),
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
