import 'package:flutter/material.dart';

/// "Works" design tokens, 1:1 with design/tokens.css plus the few extra greys the screens use.
/// Light theme only; dark mode still runs on [SathiColors.dark].
abstract final class Tok {
  // neutrals
  static const ground = Color(0xFFE6E7EA); // page behind the app shell
  static const shell = Color(0xFFF6F6F7); // app frame, sidebar, content column
  static const panel = Color(0xFFFFFFFF); // section panels, sub-cards
  static const inset = Color(0xFFF3F4F5); // grey cards, list rows, table header
  static const line = Color(0xFFE4E6E9); // borders, dividers
  static const ink = Color(0xFF15181B); // titles, figures
  static const text2 = Color(0xFF565C65); // body secondary
  static const text3 = Color(0xFF676D75); // labels, icons
  // extra greys taken from the screen HTML
  static const lineSoft = Color(0xFFEEF0F2); // inner dividers, table row rules, selected segment
  static const lineInset = Color(0xFFECEDEF); // border of grey cards and the table header
  static const treeLine = Color(0xFFD9DCE0); // sidebar ward tree line
  static const dash = Color(0xFFB9BEC4); // dashed borders (synthetic tag, empty state, dashed rules)
  static const neutralLine = Color(0xFFD5D8DC); // neutral chip border, switch track
  static const strongLine = Color(0xFF8A9097); // "below" band chip border, compare hatch
  static const dot = Color(0xFF9AA0A7); // neutral status dot
  static const sep = Color(0xFFA3A8AE); // the "·" separator in titles and lines
  static const hatchRest1 = Color(0xFFE3E5E8), hatchRest2 = Color(0xFFF4F5F6); // progress remainder
  // teal: selection, primary actions, neutral data bars
  static const teal = Color(0xFF0E6F66);
  static const tealDark = Color(0xFF0A5750);
  static const tealTint = Color(0xFFE2F1EE);
  static const tealLine = Color(0xFFB9DDD7); // border of teal-tint chips
  static const tealRail = Color(0xFF8CC3BB); // stepper connector between recorded stages
  static const tealZone = Color(0xFFBFE0DA); // range strip "normal" zone
  // amber: unreviewed flag or watch ONLY
  static const amberText = Color(0xFF92400E);
  static const amberIcon = Color(0xFFB45309);
  static const amberFill = Color(0xFFFEF3C7);
  static const amberLine = Color(0xFFF1D58A);
  static const amberNode = Color(0xFFD9A53A); // stepper amber node border
  // red: overspend or confirmed problem ONLY
  static const red = Color(0xFFB42318);
  static const redHatch = Color(0xFFFBD5D0);
  static const redTint = Color(0xFFFDECEA);
  static const redLine = Color(0xFFF1B5AD); // border of red-tint chips and the error box
  // map scale: spend as share of budget
  static const map1 = Color(0xFFCFE6E1); // under 80%
  static const map2 = Color(0xFF6DB0A7); // 80-89%
  static const map3 = Color(0xFF0E6F66); // 90-99%
  static const map4 = Color(0xFFFBD5D0); // 100-110%, + diagonal hatch
  static const map5 = Color(0xFFF7BDB6); // over 110%, + cross hatch
  // shape
  static const rShell = 22.0, rPanel = 16.0, rCard = 12.0, rControl = 10.0, rPill = 999.0;
  static const shadowPanel = [BoxShadow(color: Color(0x0814181C), offset: Offset(0, 1), blurRadius: 2)];
  static const shadowControl = [BoxShadow(color: Color(0x0A14181C), offset: Offset(0, 1), blurRadius: 2)];
  static const shadowShell = [
    BoxShadow(color: Color(0x0D14181C), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x1F14181C), offset: Offset(0, 12), blurRadius: 32, spreadRadius: -12),
  ];
  // spacing steps
  static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s5 = 24.0, s6 = 32.0;
  static const gapPanels = 10.0, gapCards = 12.0;
  // layout
  static const sidebarW = 232.0, detailW = 440.0, controlH = 34.0, inputH = 44.0;

  // type (Geist, Devanagari falls back to Noto Sans Devanagari, tabular figures everywhere)
  static const font = 'Geist';
  static const fontFallback = ['NotoSansDevanagari'];
  static const tabular = [FontFeature.tabularFigures()];
  static const _b = TextStyle(fontFamily: font, fontFamilyFallback: fontFallback, fontFeatures: tabular, color: ink);

  /// 11/16 w500 +0.06em, grey. Uppercase the text yourself (or use the `Caps` widget).
  static final caps = _b.copyWith(fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w500, letterSpacing: 0.66, color: text3);
  static final sub = _b.copyWith(fontSize: 12, height: 17 / 12, color: text2); // sub-lines, pills, chips
  static final body = _b.copyWith(fontSize: 13, height: 19 / 13); // body, buttons, table cells
  static final nav = _b.copyWith(fontSize: 13.5, height: 20 / 13.5); // sidebar items, tabs
  static final emph = _b.copyWith(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500);
  static final cardTitle = _b.copyWith(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w600);
  static final pageTitle = _b.copyWith(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600, letterSpacing: -0.16);
  static final section = _b.copyWith(fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600, letterSpacing: -0.18);
  static final figure = _b.copyWith(fontSize: 28, height: 32 / 28, fontWeight: FontWeight.w600, letterSpacing: -0.56);
}

/// Semantic colour tokens kept for older screens (`SathiColors.of(context)`). The light set now maps
/// onto [Tok]; new code reads [Tok] directly.
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
    primary: Tok.teal,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Tok.tealTint,
    accent: Tok.teal,
    background: Tok.shell,
    surface: Tok.panel,
    surfaceAlt: Tok.inset,
    border: Tok.line,
    borderStrong: Tok.text3,
    textPrimary: Tok.ink,
    textSecondary: Tok.text2,
    flag: Tok.amberText,
    flagTint: Tok.amberFill,
    error: Tok.red,
    errorTint: Tok.redTint,
    success: Tok.tealDark,
    successTint: Tok.tealTint,
    info: Tok.text2,
    infoTint: Tok.inset,
    focusRing: Tok.teal,
    mapScale: [Tok.map1, Tok.map2, Tok.map3, Tok.map4, Tok.map5],
    onMapScale: [Tok.ink, Tok.ink, Color(0xFFFFFFFF), Tok.ink, Tok.ink],
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
  SathiColors lerp(ThemeExtension<SathiColors>? other, double t) => other is SathiColors && t >= 0.5 ? other : this;
}

/// Spacing on a 4 px grid (kept for older screens; same steps as Tok.s1..s6).
class Gap {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, xxl = 32.0;
}

/// Control radius.
const kRadius = Tok.rControl;

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
  TextStyle s(double size, FontWeight w, Color color, [double h = 1.4, double ls = 0]) => TextStyle(
    fontFamily: Tok.font,
    fontFamilyFallback: Tok.fontFallback,
    fontSize: size,
    fontWeight: w,
    color: color,
    height: h,
    letterSpacing: ls,
    fontFeatures: Tok.tabular,
  );
  final r = BorderRadius.circular(Tok.rControl);
  // Keyboard focus only: a 2 px teal ring.
  WidgetStateProperty<BorderSide?> side(BorderSide normal) =>
      WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.focused) ? BorderSide(color: c.focusRing, width: 2) : normal);
  const btnSize = Size(34, Tok.controlH);
  const btnPad = EdgeInsets.symmetric(horizontal: 12);
  OutlineInputBorder ib(Color col, [double w = 1]) => OutlineInputBorder(
    borderRadius: r,
    borderSide: BorderSide(color: col, width: w),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: Tok.font,
    fontFamilyFallback: Tok.fontFallback,
    scaffoldBackgroundColor: c.background,
    extensions: [c],
    splashFactory: NoSplash.splashFactory,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textTheme: TextTheme(
      headlineMedium: s(28, FontWeight.w600, c.textPrimary, 32 / 28, -0.56),
      titleLarge: s(18, FontWeight.w600, c.textPrimary, 24 / 18, -0.18),
      titleMedium: s(15, FontWeight.w600, c.textPrimary, 20 / 15),
      titleSmall: s(14, FontWeight.w600, c.textPrimary, 20 / 14),
      bodyLarge: s(14, FontWeight.w400, c.textPrimary, 20 / 14),
      bodyMedium: s(13, FontWeight.w400, c.textPrimary, 19 / 13),
      bodySmall: s(12, FontWeight.w400, c.textSecondary, 17 / 12),
      labelLarge: s(13, FontWeight.w500, c.textPrimary, 19 / 13),
      labelMedium: s(12, FontWeight.w500, c.textSecondary, 17 / 12),
      labelSmall: s(11, FontWeight.w500, c.borderStrong, 16 / 11, 0.66),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: c.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tok.rPanel),
        side: BorderSide(color: c.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: s(16, FontWeight.w600, c.textPrimary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(btnSize),
        padding: const WidgetStatePropertyAll(btnPad),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: r)),
        textStyle: WidgetStatePropertyAll(s(13, FontWeight.w600, c.onPrimary)),
        iconSize: const WidgetStatePropertyAll(14),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.disabled)
              ? c.surfaceAlt
              : st.contains(WidgetState.hovered)
              ? (c.brightness == Brightness.light ? Tok.tealDark : c.primary)
              : c.primary,
        ),
        foregroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.disabled) ? c.borderStrong : c.onPrimary),
        side: side(BorderSide(color: c.brightness == Brightness.light ? Tok.tealDark : c.primary)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(btnSize),
        padding: const WidgetStatePropertyAll(btnPad),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: r)),
        textStyle: WidgetStatePropertyAll(s(13, FontWeight.w500, c.textPrimary)),
        iconSize: const WidgetStatePropertyAll(14),
        backgroundColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.disabled)
              ? c.surfaceAlt
              : st.contains(WidgetState.hovered)
              ? c.surfaceAlt
              : c.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.disabled) ? c.borderStrong : c.textPrimary),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        side: side(BorderSide(color: c.border)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(btnSize),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: r)),
        textStyle: WidgetStatePropertyAll(s(13, FontWeight.w500, c.primary)),
        iconSize: const WidgetStatePropertyAll(13),
        foregroundColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.disabled) ? c.borderStrong : (c.brightness == Brightness.light ? Tok.tealDark : c.primary),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.hovered) ? c.primaryContainer : Colors.transparent,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        side: side(const BorderSide(color: Colors.transparent)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(Tok.controlH, Tok.controlH)),
        fixedSize: const WidgetStatePropertyAll(Size(Tok.controlH, Tok.controlH)),
        iconSize: const WidgetStatePropertyAll(16),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: r)),
        foregroundColor: WidgetStatePropertyAll(c.textPrimary),
        side: side(BorderSide.none),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      isDense: true,
      constraints: const BoxConstraints(minHeight: Tok.inputH),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12.5),
      hintStyle: s(13, FontWeight.w400, c.borderStrong),
      labelStyle: s(12.5, FontWeight.w500, c.textPrimary),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      helperStyle: s(12, FontWeight.w400, c.textSecondary, 16 / 12),
      errorStyle: s(12, FontWeight.w500, c.error, 16 / 12),
      prefixIconColor: c.borderStrong,
      suffixIconColor: c.borderStrong,
      border: ib(c.border),
      enabledBorder: ib(c.border),
      disabledBorder: ib(c.border),
      focusedBorder: ib(c.focusRing, 2),
      errorBorder: ib(c.error),
      focusedErrorBorder: ib(c.error, 2),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowHeight: 36,
      dataRowMinHeight: 46,
      dataRowMaxHeight: double.infinity,
      horizontalMargin: 12,
      columnSpacing: 24,
      dividerThickness: 1,
      headingRowColor: WidgetStatePropertyAll(c.surfaceAlt),
      headingTextStyle: s(11, FontWeight.w500, c.borderStrong, 16 / 11, 0.66),
      dataTextStyle: s(13, FontWeight.w400, c.textPrimary, 19 / 13),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface,
      side: BorderSide(color: c.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tok.rPill)),
      labelStyle: s(12, FontWeight.w500, c.textPrimary, 17 / 12),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      iconTheme: IconThemeData(size: 13, color: c.borderStrong),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(34, Tok.controlH)),
        textStyle: WidgetStatePropertyAll(s(13, FontWeight.w500, c.textPrimary)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: r)),
        side: WidgetStatePropertyAll(BorderSide(color: c.border)),
        backgroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? c.surfaceAlt : c.surface),
        foregroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? c.textPrimary : c.textSecondary),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: c.brightness == Brightness.light ? Tok.tealDark : c.primary,
      unselectedLabelColor: c.textSecondary,
      indicatorColor: c.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: c.border,
      labelStyle: s(13.5, FontWeight.w600, c.primary),
      unselectedLabelStyle: s(13.5, FontWeight.w400, c.textSecondary),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? c.primary : Tok.neutralLine),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? c.primary : c.borderStrong),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? c.primary : Colors.transparent),
      side: BorderSide(color: c.borderStrong, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tok.rCard),
        side: BorderSide(color: c.border),
      ),
      textStyle: s(13, FontWeight.w400, c.textPrimary),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: Tok.ink, borderRadius: BorderRadius.circular(6)),
      textStyle: s(12, FontWeight.w500, Colors.white),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Tok.ink,
      contentTextStyle: s(13, FontWeight.w500, Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tok.rControl)),
      width: 420,
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
    focusColor: c.focusRing.withValues(alpha: 0.12),
    hoverColor: c.surfaceAlt,
  );
}
