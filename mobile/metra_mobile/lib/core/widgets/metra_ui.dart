// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// Shared visual identity and reusable UI building blocks for METRA 2027.
/// All screens must use these components to keep one consistent national design language.
const metraNavy = Color(0xFF061B4A);
const metraBlue = Color(0xFF087CF0);
const metraSurface = Color(0xFFF3F6FC);
const metraMuted = Color(0xFF64748B);
const metraSuccess = Color(0xFF0F766E);
const metraWarning = Color(0xFFB45309);
const metraDanger = Color(0xFFB91C1C);

ThemeData buildMetraTheme() {
  final base = ColorScheme.fromSeed(seedColor: metraBlue, brightness: Brightness.light);
  return ThemeData(
    useMaterial3: true,
    colorScheme: base.copyWith(
      primary: metraBlue,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: metraSurface,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: metraNavy,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: metraNavy,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: metraBlue, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: metraBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

class MetraPageHeader extends StatelessWidget {
  const MetraPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: metraNavy,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: metraMuted, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class MetraStatusBanner extends StatelessWidget {
  const MetraStatusBanner({
    super.key,
    required this.message,
    this.tone = MetraBannerTone.info,
    this.icon,
  });

  final String message;
  final MetraBannerTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      MetraBannerTone.info => (const Color(0xFFEFF6FF), metraBlue, Icons.info_outline),
      MetraBannerTone.warning => (const Color(0xFFFFF7ED), metraWarning, Icons.warning_amber_outlined),
      MetraBannerTone.danger => (const Color(0xFFFEF2F2), metraDanger, Icons.error_outline),
      MetraBannerTone.success => (const Color(0xFFECFDF5), metraSuccess, Icons.check_circle_outline),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.$2.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? colors.$3, color: colors.$2, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.$2, height: 1.45, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

enum MetraBannerTone { info, warning, danger, success }

class MetraSectionCard extends StatelessWidget {
  const MetraSectionCard({
    super.key,
    required this.title,
    this.child,
    this.trailing,
  });

  final String title;
  final Widget? child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: metraNavy,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (child != null) ...[
              const SizedBox(height: 12),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}

class MetraEmptyState extends StatelessWidget {
  const MetraEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: metraBlue),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: metraNavy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: metraMuted, height: 1.55),
              ),
              if (action != null) ...[
                const SizedBox(height: 18),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MetraStatusBadge extends StatelessWidget {
  const MetraStatusBadge({
    super.key,
    required this.label,
    this.tone = MetraBannerTone.info,
  });

  final String label;
  final MetraBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      MetraBannerTone.info => (const Color(0xFFEFF6FF), metraBlue),
      MetraBannerTone.warning => (const Color(0xFFFFF7ED), metraWarning),
      MetraBannerTone.danger => (const Color(0xFFFEF2F2), metraDanger),
      MetraBannerTone.success => (const Color(0xFFECFDF5), metraSuccess),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.$2,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
