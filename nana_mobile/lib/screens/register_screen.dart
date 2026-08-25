import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToLogin;

  const RegisterScreen({super.key, required this.onNavigateToLogin});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda harus menyetujui Syarat & Ketentuan'),
          backgroundColor: Color(0xFFBA1A1A),
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final authNotifier = ref.read(authProvider.notifier);
      final success = await authNotifier.register(
        name: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!success && mounted) {
        final authState = ref.read(authProvider);
        if (authState.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authState.errorMessage!),
              backgroundColor: const Color(0xFFBA1A1A),
            ),
          );
        }
      }
    }
  }

  void _handleGoogleSignIn() async {
    final authNotifier = ref.read(authProvider.notifier);
    final success = await authNotifier.loginWithGoogle();
    if (!success && mounted) {
      final authState = ref.read(authProvider);
      if (authState.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authState.errorMessage!),
            backgroundColor: const Color(0xFFBA1A1A),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 40,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Nana',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003527),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Buat Akun Baru',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF191C1B),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Full Name
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'NAMA LENGKAP',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF404944),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _fullNameController,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Color(0xFF191C1B)),
                      decoration: InputDecoration(
                        hintText: 'Masukkan nama sesuai identitas',
                        hintStyle: const TextStyle(color: Color(0xFFBFC9C3)),
                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF707974), size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF2F4F1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Nama lengkap wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    // Email
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'EMAIL',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF404944),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Color(0xFF191C1B)),
                      decoration: InputDecoration(
                        hintText: 'nama@email.com',
                        hintStyle: const TextStyle(color: Color(0xFFBFC9C3)),
                        prefixIcon: const Icon(Icons.mail_outline, color: Color(0xFF707974), size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF2F4F1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Email wajib diisi';
                        if (!val.contains('@')) return 'Format email tidak valid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'KATA SANDI',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF404944),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Color(0xFF191C1B)),
                      decoration: InputDecoration(
                        hintText: 'Minimal 8 karakter',
                        hintStyle: const TextStyle(color: Color(0xFFBFC9C3)),
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF707974), size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: const Color(0xFF707974),
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF2F4F1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Kata sandi wajib diisi';
                        if (val.length < 6) return 'Kata sandi minimal 6 karakter';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Terms Checkbox
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _acceptedTerms,
                            activeColor: const Color(0xFF003527),
                            onChanged: (val) => setState(() => _acceptedTerms = val ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                            child: const Text.rich(
                              TextSpan(
                                text: 'Saya menyetujui ',
                                style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF404944)),
                                children: [
                                  TextSpan(
                                    text: 'Syarat & Ketentuan',
                                    style: TextStyle(color: Color(0xFF003527), fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text: ' serta kebijakan privasi data Nana yang melindungi informasi pribadi saya.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003527),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Daftar Sekarang',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 20, color: Colors.white),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        Expanded(child: Divider(color: Color(0xFFBFC9C3))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'atau',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF707974),
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Color(0xFFBFC9C3))),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Google Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: authState.isLoading ? null : _handleGoogleSignIn,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFBFC9C3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuCxVHLWwh9tygW-IhEJTPDsOyGM5ES5K5-AZ-70oyLg5vg6jV-2Zm_y6xIXKKY5iCs1NNT9gzT25mRPDa5r1pyyY6oEYsMpgrOdWidztwLlEvlCaFR980yvyOlSw5NqGvdLP2c6he79Kk_3evmvuDz9AqXpqP5ZdNrNSpnqgaL4kT82PiyI4VcqqDpxeyST0_KvSoUmxcfdSkkcmkpsDnaX_W7kARMCWCxl_SVnkb1MC-oHK-Adev4t',
                              width: 20,
                              height: 20,
                              errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24, color: Colors.blue),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Daftar dengan Google',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF191C1B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Sudah punya akun? ',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF404944)),
                        ),
                        GestureDetector(
                          onTap: widget.onNavigateToLogin,
                          child: const Text(
                            'Masuk di sini',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF003527),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
