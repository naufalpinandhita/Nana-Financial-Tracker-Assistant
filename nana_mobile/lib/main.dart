import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/luminous_ledger_theme.dart';
import 'screens/dashboard_screen.dart';

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
      home: const DashboardScreen(),
    );
  }
}
