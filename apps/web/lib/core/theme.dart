import 'package:flutter/material.dart';

/// Semantic colour tokens. The only colour source in the app: screens read
/// them with `SathiColors.of(context)` and never use raw colour values.
@immutable
class SathiColors extends ThemeExtension<SathiColors> {
  const SathiColors({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.flag,
    required this.flagTint,
    required this.error,
    required this.errorTint,
    required this.success,
    required this.successTint,
    required this.info,
    required this.infoTint,
    required this.focusRing,
    required this.mapScale,
    required this.onMapScale,
  });

  final Brightness brightness;
  final Color primary, onPrimary, primaryContainer, accent;
  final Color background, surface, surfaceAlt, border, borderStrong;
  final Color textPrimary, textSecondary;

  /// Unreviewed audit flags and "watch". Never red.
  final Color flag, flagTint;

  /// Confirmed problems and overspend only.
  final Color error, errorTint;
  final Color success, successTint, info, infoTint, focusRing;

  /// Ward shading by spend against budget, five steps, with the text colour for each.
  final List<Color> mapScale, onMapScale;

  static const light = SathiColors(
    brightness: Brightness.light,
    primary: Color(0xFF123A6B),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDCE8F7),
    accent: Color(0xFF0E7C86),
    background: Color(0xFFF4F6F9),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEAEEF3),
    border: Color(0xFFD9DFE7),
    borderStrong: Color(0xFF6F7C8C),
    textPrimary: Color(0xFF14202E),
    textSecondary: Color(0xFF4A5868),
    flag: Color(0xFF8A5100),
    flagTint: Color(0xFFFFF4E0),
    error: Color(0xFFB3261E),
    errorTint: Color(0xFFFCEBEA),
    success: Color(0xFF1A7340),
    successTint: Color(0xFFE6F4EC),
    info: Color(0xFF1F5FAE),
    infoTint: Color(0xFFE5EEFA),
    focusRing: Color(0xFFB36B00),
    mapScale: [Color(0xFFD6E6F5), Color(0xFFA9CBEA), Color(0xFF6FA5DA), Color(0xFFF0B45A), Color(0xFFC2410C)],
    onMapScale: [Color(0xFF14202E), Color(0xFF14202E), Color(0xFF14202E), Color(0xFF14202E), Color(0xFFFFFFFF)],
  );

  static const dark = SathiColors(
    brightness: Brightness.dark,
    primary: Color(0xFF8DB4F0),
    onPrimary: Color(0xFF0B1F3A),
    primaryContainer: Color(0xFF1B3558),
    accent: Color(0xFF5CC6CF),
    background: Color(0xFF0E1520),
    surface: Color(0xFF172131),
    surfaceAlt: Color(0xFF1D293B),
    border: Color(0xFF2A3648),
    borderStrong: Color(0xFF7D8CA3),
    textPrimary: Color(0xFFE6ECF4),
    textSecondary: Color(0xFFA3B1C2),
    flag: Color(0xFFF2B84B),
    flagTint: Color(0xFF3A2C0E),
    error: Color(0xFFFF8A80),
    errorTint: Color(0xFF3B1512),
    success: Color(0xFF6FCF97),
    successTint: Color(0xFF12301F),
    info: Color(0xFF8DB4F0),
    infoTint: Color(0xFF142A47),
    focusRing: Color(0xFFF2B84B),
    mapScale: [Color(0xFF1F3A5C), Color(0xFF2B5688), Color(0xFF3F78BA), Color(0xFFB57A22), Color(0xFFE0683A)],
    onMapScale: [Color(0xFFE6ECF4), Color(0xFFE6ECF4), Color(0xFFFFFFFF), Color(0xFF0E1520), Color(0xFF0E1520)],
  );

  static SathiColors of(BuildContext context) => Theme.of(context).extension<SathiColors>()!;

  @override
  SathiColors copyWith() => this;

  @override
  SathiColors lerp(ThemeExtension<SathiColors>? other, double t) =>
      other is SathiColors && t >= 0.5 ? other : this;
}

/// Spacing on a 4 px grid.
class Gap {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, xxl = 32.0;
}

const kRadius = 8.0;

ThemeData buildTheme(SathiColors c) {
  final scheme = ColorScheme(
    brightness: c.brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    secondary: c.accent,
    onSecondary: c.onPrimary,
    error: c.error,
    onError: c.onPrimary,
    surface: c.surface,
    onSurface: c.textPrimary,
    outline: c.borderStrong,
    outlineVariant: c.border,
    primaryContainer: c.primaryContainer,
    onPrimaryContainer: c.textPrimary,
    surfaceContainerHighest: c.surfaceAlt,
    onSurfaceVariant: c.textSecondary,
  );
  // Tabular numerals keep money columns aligned.
  const tab = [FontFeature.tabularFigures()];
  TextStyle s(double size, FontWeight w, Color color, [double h = 1.35]) =>
      TextStyle(fontFamily: 'Mukta', fontSize: size, fontWeight: w, color: color, height: h, fontFeatures: tab);
  final border = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(kRadius),
    side: BorderSide(color: c.border),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Mukta',
    scaffoldBackgroundColor: c.background,
    extensions: [c],
    splashFactory: NoSplash.splashFactory,
    textTheme: TextTheme(
      headlineMedium: s(28, FontWeight.w600, c.textPrimary, 1.2),
      titleLarge: s(20, FontWeight.w600, c.textPrimary, 1.25),
      titleMedium: s(16, FontWeight.w600, c.textPrimary),
      bodyLarge: s(16, FontWeight.w400, c.textPrimary),
      bodyMedium: s(14, FontWeight.w400, c.textPrimary),
      bodySmall: s(12, FontWeight.w400, c.textSecondary),
      labelLarge: s(14, FontWeight.w500, c.textPrimary),
      labelMedium: s(12, FontWeight.w500, c.textSecondary),
      labelSmall: s(12, FontWeight.w500, c.textSecondary),
    ),
    // Borders instead of elevation: they hold up better on a projector.
    cardTheme: CardThemeData(elevation: 0, color: c.surface, margin: EdgeInsets.zero, shape: border),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: s(20, FontWeight.w600, c.textPrimary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        textStyle: s(14, FontWeight.w600, c.onPrimary),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        side: BorderSide(color: c.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadius), borderSide: BorderSide(color: c.borderStrong)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadius), borderSide: BorderSide(color: c.borderStrong)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadius), borderSide: BorderSide(color: c.primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.md),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.primaryContainer,
      selectedIconTheme: IconThemeData(color: c.primary),
      unselectedIconTheme: IconThemeData(color: c.textSecondary),
      selectedLabelTextStyle: s(14, FontWeight.w600, c.primary),
      unselectedLabelTextStyle: s(14, FontWeight.w500, c.textSecondary),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.primaryContainer,
      elevation: 0,
      labelTextStyle: WidgetStatePropertyAll(s(12, FontWeight.w500, c.textPrimary)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: c.primary,
      unselectedLabelColor: c.textSecondary,
      indicatorColor: c.primary,
      dividerColor: c.border,
      labelStyle: s(14, FontWeight.w600, c.primary),
      unselectedLabelStyle: s(14, FontWeight.w500, c.textSecondary),
    ),
    focusColor: c.focusRing.withValues(alpha: 0.2),
  );
}
