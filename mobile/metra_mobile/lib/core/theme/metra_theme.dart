import 'package:material_ui/material_ui.dart';

/// METRA visual tokens — single source for shell and feature screens.
abstract final class MetraColors {
  static const navy = Color(0xFF061B4A);
  static const blue = Color(0xFF087CF0);
  static const surface = Color(0xFFF3F6FC);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFF64748B);
  static const ink = Color(0xFF0F172A);
  static const warningBg = Color(0xFFFFF7E8);
  static const warning = Color(0xFF9A6700);
  static const danger = Color(0xFFB91C1C);
  static const success = Color(0xFF0F766E);
}

abstract final class MetraTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: MetraColors.blue,
      primary: MetraColors.blue,
      surface: MetraColors.surface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: MetraColors.surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: MetraColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: MetraColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: MetraColors.blue.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE2E8F0)),
    );
  }
}
