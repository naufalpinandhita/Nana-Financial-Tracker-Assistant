import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/luminous_ledger_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'providers/auth_provider.dart';

void main() {
  runApp(
    const ProviderScope(
      child: NanaApp(),
    ),
  );
}

class NanaApp extends StatelessWidget {
  const NanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nana Financial Tracker',
      debugShowCheckedModeBanner: false,
      theme: LuminousLedgerTheme.themeData,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _showRegister = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Loading / checking token
    if (authState.status == AuthStatus.unknown) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAF6),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF003527))),
      );
    }

    // Logged in and profile complete
    if (authState.status == AuthStatus.authenticated) {
      return const DashboardScreen();
    }

    // Logged in but username not set yet → step 2
    if (authState.status == AuthStatus.needsProfileSetup) {
      return const ProfileSetupScreen();
    }

    // Not logged in
    if (_showRegister) {
      return RegisterScreen(
        onNavigateToLogin: () => setState(() => _showRegister = false),
      );
    }

    return LoginScreen(
      onNavigateToRegister: () => setState(() => _showRegister = true),
    );
  }
}
