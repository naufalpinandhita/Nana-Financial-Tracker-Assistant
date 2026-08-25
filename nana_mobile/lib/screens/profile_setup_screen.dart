import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/app_providers.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();

  bool _isCheckingUsername = false;
  bool? _usernameAvailable;
  String? _usernameError;
  Timer? _debounce;

  Uint8List? _avatarBytes;
  String? _avatarBase64;

  @override
  void initState() {
    super.initState();
    // Pre-fill username with name-derived default
    final authState = ref.read(authProvider);
    final name = authState.user?.name ?? '';
    final defaultUsername = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    _usernameController.text = defaultUsername;
    _validateUsernameDebounced(defaultUsername);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    setState(() {
      _usernameAvailable = null;
      _usernameError = null;
    });
    _validateUsernameDebounced(value);
  }

  void _validateUsernameDebounced(String value) {
    _debounce?.cancel();
    if (value.length < 3) return;
    _debounce = Timer(const Duration(milliseconds: 500), () => _checkUsername(value));
  }

  Future<void> _checkUsername(String username) async {
    final regex = RegExp(r'^[a-z0-9_.]+$');
    if (!regex.hasMatch(username)) {
      setState(() {
        _usernameAvailable = false;
        _usernameError = 'Hanya huruf kecil, angka, titik, dan underscore';
      });
      return;
    }

    setState(() => _isCheckingUsername = true);
    try {
      final available = await ref.read(apiServiceProvider).checkUsernameAvailable(username);
      if (mounted) {
        setState(() {
          _usernameAvailable = available;
          _usernameError = available ? null : 'Username sudah dipakai';
          _isCheckingUsername = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingUsername = false);
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 512);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      setState(() {
        _avatarBytes = bytes;
        _avatarBase64 = base64Str;
      });
    } catch (_) {}
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_usernameAvailable == false) return;

    final username = _usernameController.text.trim();

    // Run availability check if not done yet
    if (_usernameAvailable == null) {
      await _checkUsername(username);
      if (_usernameAvailable != true) return;
    }

    final success = await ref.read(authProvider.notifier).setupProfile(
      username: username,
      avatarUrl: _avatarBase64,
    );

    if (!success && mounted) {
      final err = ref.read(authProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Gagal menyimpan profil'), backgroundColor: const Color(0xFFBA1A1A)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userName = authState.user?.name ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF6),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(1, -1),
            radius: 1.2,
            colors: [Color(0x26C3ECD7), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x08000000), blurRadius: 40, offset: Offset(0, 16)),
                  ],
                ),
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Step indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StepDot(active: false, done: true, label: '1'),
                          Container(width: 32, height: 2, color: const Color(0xFF003527)),
                          _StepDot(active: true, done: false, label: '2'),
                        ],
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Nana',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF003527),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Lengkapi Profil Kamu',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF191C1B)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Hei $userName, satu langkah lagi!',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF707974)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // Avatar picker
                      GestureDetector(
                        onTap: _pickAvatar,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF003527), width: 2.5),
                                color: const Color(0xFFE8F4EF),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _avatarBytes != null
                                  ? Image.memory(_avatarBytes!, fit: BoxFit.cover)
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF003527),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFF003527),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ketuk untuk pilih foto (opsional)',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF9BA89F)),
                      ),
                      const SizedBox(height: 24),

                      // Username field
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'USERNAME',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF404944),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _usernameController,
                        onChanged: _onUsernameChanged,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Color(0xFF191C1B)),
                        decoration: InputDecoration(
                          hintText: 'contoh: budibudiman',
                          hintStyle: const TextStyle(color: Color(0xFFBFC9C3)),
                          prefixIcon: const Icon(Icons.alternate_email, color: Color(0xFF707974), size: 20),
                          prefixText: '@',
                          prefixStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            color: Color(0xFF003527),
                            fontWeight: FontWeight.bold,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF2F4F1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: _usernameAvailable == null
                                ? BorderSide.none
                                : _usernameAvailable == true
                                    ? const BorderSide(color: Color(0xFF003527), width: 1.5)
                                    : const BorderSide(color: Color(0xFFBA1A1A), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF003527), width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          suffixIcon: _isCheckingUsername
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF003527))),
                                )
                              : _usernameAvailable == true
                                  ? const Icon(Icons.check_circle, color: Color(0xFF003527), size: 20)
                                  : _usernameAvailable == false
                                      ? const Icon(Icons.cancel, color: Color(0xFFBA1A1A), size: 20)
                                      : null,
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Username wajib diisi';
                          if (val.length < 3) return 'Username minimal 3 karakter';
                          if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(val)) {
                            return 'Hanya huruf kecil, angka, titik, dan underscore';
                          }
                          return null;
                        },
                      ),

                      // Username feedback
                      const SizedBox(height: 6),
                      if (_usernameError != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _usernameError!,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFFBA1A1A)),
                          ),
                        )
                      else if (_usernameAvailable == true)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Username tersedia!',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF003527)),
                          ),
                        )
                      else
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Hanya huruf kecil, angka, titik (.) dan underscore (_)',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF9BA89F)),
                          ),
                        ),

                      const SizedBox(height: 28),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: authState.isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF003527),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 2,
                          ),
                          child: authState.isLoading
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Selesai & Mulai',
                                      style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.check, size: 20, color: Colors.white),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      // Skip option
                      TextButton(
                        onPressed: authState.isLoading
                            ? null
                            : () async {
                                // Use default username derived from name
                                final username = _usernameController.text.trim();
                                if (username.isNotEmpty && _usernameAvailable != false) {
                                  await _handleSubmit();
                                }
                              },
                        child: const Text(
                          'Lewati, gunakan username default',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF707974)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool active;
  final bool done;
  final String label;

  const _StepDot({required this.active, required this.done, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? const Color(0xFF003527)
            : active
                ? const Color(0xFF003527)
                : const Color(0xFFE0E5E2),
        border: Border.all(
          color: active || done ? const Color(0xFF003527) : const Color(0xFFBFC9C3),
          width: 2,
        ),
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: active ? Colors.white : const Color(0xFF9BA89F),
                ),
              ),
      ),
    );
  }
}
