import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/app_providers.dart';
import '../theme/luminous_ledger_theme.dart';
import '../widgets/glass_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _waNumberController;

  bool _isInit = false;
  bool _isLoading = false;

  String _selectedAvatarUrl = '';

  final List<Map<String, String>> _avatarPresets = [
    {'name': 'Bot (Default)', 'url': 'https://api.dicebear.com/7.x/bottts/svg?seed=Nana'},
    {'name': 'Cat', 'url': 'https://api.dicebear.com/7.x/bottts/svg?seed=NopalCat'},
    {'name': 'Emerald Goat', 'url': 'https://api.dicebear.com/7.x/bottts/svg?seed=NopalGoat'},
    {'name': 'Cyberpunk', 'url': 'https://api.dicebear.com/7.x/bottts/svg?seed=NanaCyber'},
    {'name': 'Minimal', 'url': 'https://api.dicebear.com/7.x/bottts/svg?seed=Minimalist'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _waNumberController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _waNumberController.dispose();
    super.dispose();
  }

  void _populateFields(dynamic profile) {
    if (!_isInit && profile != null) {
      _nameController.text = profile.name;
      _usernameController.text = profile.username;
      _emailController.text = profile.email;
      _waNumberController.text = profile.waNumber;
      _selectedAvatarUrl = profile.avatarUrl;
      _isInit = true;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(profileProvider.notifier).updateProfile({
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'wa_number': _waNumberController.text.trim(),
        'avatar_url': _selectedAvatarUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan profil: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportData(BuildContext context, String format) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final transactions = await ref.read(apiServiceProvider).getTransactions();
      if (transactions.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('Belum ada transaksi untuk diekspor.')));
        return;
      }

      String content = '';
      if (format == 'CSV') {
        content = 'ID,Tanggal,Tipe,Nominal,Dompet,Kategori,Catatan\n';
        for (final tx in transactions) {
          content += '"${tx.id}","${tx.date}","${tx.type}",${tx.amount},"${tx.walletName ?? ''}","${tx.categoryName ?? ''}","${tx.note ?? ''}"\n';
        }
      } else {
        content = jsonEncode(transactions.map((t) => {
          'id': t.id,
          'date': t.date,
          'type': t.type,
          'amount': t.amount,
          'walletName': t.walletName,
          'categoryName': t.categoryName,
          'note': t.note,
        }).toList());
      }

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Text('Ekspor Data ($format) Berhasil'),
          content: SingleChildScrollView(
            child: SelectableText(
              content.length > 500 ? '${content.substring(0, 500)}...\n\n[Data Lengkap ${transactions.length} Transaksi]' : content,
              style: LuminousLedgerTheme.financialStyle(fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('TUTUP'),
            ),
          ],
        ),
      );
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal ekspor data: ${err.toString()}')));
    }
  }

  ImageProvider? _getAvatarImageProvider(String url) {
    if (url.startsWith('data:image')) {
      try {
        final base64Content = url.split(',').last;
        final bytes = base64Decode(base64Content);
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    } else if (url.startsWith('http')) {
      return NetworkImage(url);
    }
    return null;
  }

  Future<void> _pickImage(ImageSource source, BuildContext modalCtx) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image == null) return;

      final file = File(image.path);
      final bytes = await file.readAsBytes();
      const maxSizeBytes = 2 * 1024 * 1024; // 2MB

      if (bytes.length > maxSizeBytes) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Ukuran foto melebihi batas 2MB. Silakan pilih foto lain.')),
        );
        return;
      }

      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      setState(() {
        _selectedAvatarUrl = base64Str;
      });

      if (modalCtx.mounted) {
        Navigator.pop(modalCtx);
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Foto kustom dipilih! Klik "Simpan Perubahan" untuk menyimpan.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal memilih gambar: ${e.toString()}')),
      );
    }
  }

  void _showAvatarPickerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
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
              const Text(
                'Ubah Foto Profil',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Unggah foto sesukamu (Maksimum 2MB) atau pilih preset avatar:',
                style: TextStyle(fontSize: 12, color: Color(0xFFD8DBD7)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery, modalCtx),
                      icon: const Icon(Icons.photo_library, size: 18, color: Color(0xFF003527)),
                      label: const Text('DARI GALERI', style: TextStyle(color: Color(0xFF003527), fontWeight: FontWeight.bold, fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB0F0D6),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera, modalCtx),
                      icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                      label: const Text('AMBIL FOTO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'ATAU PILIH PRESET AVATAR',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD8DBD7), letterSpacing: 0.8),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _avatarPresets.map((preset) {
                    final isSelected = _selectedAvatarUrl == preset['url'];
                    final initial = preset['name']![0];

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedAvatarUrl = preset['url']!;
                        });
                        Navigator.pop(modalCtx);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFB0F0D6).withValues(alpha: 0.2) : const Color(0xFF2E312F),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFB0F0D6) : Colors.white.withValues(alpha: 0.1),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: LuminousLedgerColors.primaryContainer,
                              child: Text(
                                initial,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFB0F0D6)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              preset['name']!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? const Color(0xFFB0F0D6) : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: LuminousLedgerColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: LuminousLedgerColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profil Saya',
          style: TextStyle(
            color: LuminousLedgerColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: profileAsync.when(
        data: (profile) {
          _populateFields(profile);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Center(
                  child: GestureDetector(
                    onTap: () => _showAvatarPickerModal(context),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: LuminousLedgerColors.primaryContainer,
                          backgroundImage: _getAvatarImageProvider(_selectedAvatarUrl),
                          onBackgroundImageError: (_, _) {},
                          child: (_getAvatarImageProvider(_selectedAvatarUrl) == null)
                              ? Text(
                                  profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'N',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: LuminousLedgerColors.secondaryFixed,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: LuminousLedgerColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                GlassCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informasi Pengguna',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: LuminousLedgerColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nama Lengkap',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Nama wajib diisi' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username / Panggilan',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _waNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Nomor WhatsApp Terhubung',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: LuminousLedgerColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isLoading ? null : _save,
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    'Simpan Perubahan',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Data Export Card
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.download, color: LuminousLedgerColors.primary, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Ekspor & Backup Laporan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: LuminousLedgerColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Unduh seluruh data transaksi dan saldo dalam format terstruktur CSV / JSON.',
                        style: TextStyle(fontSize: 12, color: LuminousLedgerColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _exportData(context, 'CSV'),
                              icon: const Icon(Icons.description_outlined, size: 18, color: LuminousLedgerColors.primary),
                              label: const Text('EKSPOR CSV', style: TextStyle(color: LuminousLedgerColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: LuminousLedgerColors.primary),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _exportData(context, 'JSON'),
                              icon: const Icon(Icons.code, size: 18, color: LuminousLedgerColors.primary),
                              label: const Text('EKSPOR JSON', style: TextStyle(color: LuminousLedgerColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: LuminousLedgerColors.primary),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Gagal memuat profil: ${err.toString()}')),
      ),
    );
  }
}
