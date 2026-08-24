import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/luminous_ledger_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? customFillColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 24.0,
    this.customFillColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          // Soft shadow matching Tailwind .soft-shadow
          BoxShadow(
            color: const Color(0xFF2B6954).withValues(alpha: 0.1),
            offset: const Offset(4, 4),
            blurRadius: 12,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.8),
            offset: const Offset(-4, -4),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: customFillColor ?? LuminousLedgerColors.cardGlassFill,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: LuminousLedgerColors.cardGlassBorder,
                width: 1.0,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
