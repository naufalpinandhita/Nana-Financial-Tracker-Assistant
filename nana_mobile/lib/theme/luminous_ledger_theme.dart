import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LuminousLedgerColors {
  static const Color primary = Color(0xFF003527); // Deep Emerald Green
  static const Color primaryContainer = Color(0xFF064E3B);
  static const Color surfaceTint = Color(0xFF2B6954);
  static const Color background = Color(0xFFF8FAF6); // Soft Mint / White Smoke
  static const Color onSurface = Color(0xFF191C1B); // Dark Slate
  static const Color onSurfaceVariant = Color(0xFF404944);
  static const Color outlineVariant = Color(0xFFBFC9C3);
  static const Color surfaceContainerLow = Color(0xFFF2F4F1);
  static const Color surfaceContainer = Color(0xFFECEEEB);
  static const Color surfaceContainerHigh = Color(0xFFE7E9E5);

  static const Color secondaryFixed = Color(0xFFC3ECD7);
  static const Color onSecondaryFixedVariant = Color(0xFF294E3F);
  static const Color incomeMint = Color(0xFFC3ECD7);
  static const Color incomeText = Color(0xFF047857);
  static const Color alertRed = Color(0xFFBA1A1A);
  static const Color expenseText = Color(0xFFB91C1C);

  static const Color tertiaryContainer = Color(0xFF6B342D);
  static const Color secondaryContainer = Color(0xFFC3ECD7);

  static const Color onSecondaryContainer = Color(0xFF476C5B);
  static const Color outline = Color(0xFF707974);
  static const Color aiGlowIndigo = Color(0x666366F1); // Indigo pendar AI
  static const Color cardGlassBorder = Color(0x80FFFFFF); // 50% Opacity White
  static const Color cardGlassFill = Color(0xCCFFFFFF); // 80% Opacity White
}

class LuminousLedgerTheme {
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: LuminousLedgerColors.background,
      colorScheme: const ColorScheme.light(
        primary: LuminousLedgerColors.primary,
        primaryContainer: LuminousLedgerColors.primaryContainer,
        surface: LuminousLedgerColors.background,
        onSurface: LuminousLedgerColors.onSurface,
        error: LuminousLedgerColors.alertRed,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.bold, color: LuminousLedgerColors.primary, letterSpacing: -0.8),
        headlineMedium: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600, color: LuminousLedgerColors.primary),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.normal, color: LuminousLedgerColors.onSurface),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.normal, color: LuminousLedgerColors.onSurface),
      ),
    );
  }

  // Financial Number Styling with JetBrains Mono
  static TextStyle financialStyle({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w600,
    Color color = LuminousLedgerColors.primary,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: 0.2,
    );
  }
}
