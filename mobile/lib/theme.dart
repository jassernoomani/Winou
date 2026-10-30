import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Winou's colours, from the Figma design guide ("Winou · Android design guide").
/// Blue is the brand; the others carry meaning everywhere, map included and in both themes:
/// coral = lost, blue = sighting, amber = street animal, green = found or confirmed, red = injured.
abstract final class Brand {
  static const blue = Color(0xFF3884FF);
  static const blueLight = Color(0xFF3884FF);
  static const indigo = Color(0xFF4338CA);
  static const sky = Color(0xFF38BDF8);
  static const coral = Color(0xFFF43F5E);
  static const coralDeep = Color(0xFFE11D48);
  static const amber = Color(0xFFF59E0B);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);

  /// Text on brand blue, green and coral fills ("ink on brand blue, not white", for contrast).
  static const ink = Color(0xFF111D36);

  /// 135°, as in the guide: headers, splash, the floating buttons' shell, my chat bubbles.
  static const gradient = LinearGradient(colors: [blue, indigo], begin: Alignment.topLeft, end: Alignment.bottomRight);

  /// The "report a lost pet" button: deeper coral, so its white label stays readable.
  static const lostGradient = LinearGradient(
    colors: [coralDeep, Color(0xFFBE123C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// The "I saw an animal" button: deeper blue to indigo, for the same reason.
  static const sightingGradient = LinearGradient(
    colors: [Color(0xFF2563EB), indigo],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// What a status pill or note means; each has a tonal background and a readable foreground per theme.
enum Tone { lost, found, info, stray, injured, neutral }

/// The guide's surface and text colours for one theme. Read with `context.tokens` (widgets/common.dart).
@immutable
class WinouTokens extends ThemeExtension<WinouTokens> {
  const WinouTokens({
    required this.ink,
    required this.muted,
    required this.accent,
    required this.tonal,
    required this.card,
    required this.border,
    required this.errorText,
    required this.tones,
  });

  final Color ink; // titles and body text
  final Color muted; // secondary text, icons
  final Color accent; // accessible blue: outlined buttons, links, selected chips
  final Color tonal; // soft blue fills
  final Color card;
  final Color border;
  final Color errorText;
  final Map<Tone, (Color background, Color foreground)> tones;

  static const light = WinouTokens(
    ink: Color(0xFF111D36),
    muted: Color(0xFF526079),
    accent: Color(0xFF294AB8),
    tonal: Color(0xFFEAF0FF),
    card: Colors.white,
    border: Color(0xFFD8DFEA),
    errorText: Color(0xFFB4232B),
    tones: {
      Tone.lost: (Color(0xFFFFE7ED), Color(0xFFA41F42)),
      Tone.found: (Color(0xFFDDF8E8), Color(0xFF146237)),
      Tone.info: (Color(0xFFEAF0FF), Color(0xFF294AB8)),
      Tone.stray: (Color(0xFFFFF1D6), Color(0xFF8A5300)),
      Tone.injured: (Color(0xFFFFE4E4), Color(0xFFB4232B)),
      Tone.neutral: (Color(0xFFEEF1F6), Color(0xFF526079)),
    },
  );

  static const dark = WinouTokens(
    ink: Colors.white,
    muted: Color(0xFFB6C2D6),
    accent: Color(0xFFA9C8FF),
    tonal: Color(0xFF253755),
    card: Color(0xFF1C283C),
    border: Color(0xFF43516A),
    errorText: Color(0xFFFFB3B3),
    tones: {
      Tone.lost: (Color(0xFF432738), Color(0xFFFFADBF)),
      Tone.found: (Color(0xFF173D32), Color(0xFF8DE8AF)),
      Tone.info: (Color(0xFF253755), Color(0xFFA9C8FF)),
      Tone.stray: (Color(0xFF3F3220), Color(0xFFFFD089)),
      Tone.injured: (Color(0xFF46262B), Color(0xFFFFB3B3)),
      Tone.neutral: (Color(0xFF263247), Color(0xFFB6C2D6)),
    },
  );

  (Color, Color) tone(Tone tone) => tones[tone]!;

  @override
  WinouTokens copyWith() => this;

  @override
  WinouTokens lerp(WinouTokens? other, double t) => t < 0.5 || other == null ? this : other;
}

const _font = 'Nunito';

/// Nunito has no Arabic letters: Tajawal draws them, in the same weights.
const _fallback = ['Tajawal'];

/// Card shadow from the guide: 0 6 20, ink at 6%.
const cardShadow = [BoxShadow(color: Color(0x0F101D36), blurRadius: 20, offset: Offset(0, 6))];

ThemeData winouTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final t = dark ? WinouTokens.dark : WinouTokens.light;
  final background = dark ? const Color(0xFF101827) : const Color(0xFFF8F9FD);
  final scheme = ColorScheme.fromSeed(seedColor: Brand.blue, brightness: brightness).copyWith(
    primary: t.accent,
    onPrimary: dark ? Brand.ink : Colors.white,
    primaryContainer: t.tonal,
    onPrimaryContainer: t.accent,
    secondary: Brand.coral,
    tertiary: Brand.green,
    surface: background,
    onSurface: t.ink,
    onSurfaceVariant: t.muted,
    surfaceContainerLowest: t.card,
    surfaceContainerLow: t.card,
    surfaceContainer: t.card,
    surfaceContainerHigh: dark ? const Color(0xFF243149) : const Color(0xFFF0F3FA),
    surfaceContainerHighest: dark ? const Color(0xFF2A3852) : const Color(0xFFE8EDF7),
    outline: t.muted,
    outlineVariant: t.border,
    error: Brand.red,
    onError: Colors.white,
  );

  // The guide's type scale: Display 32/900/38, Title 26/900/32, Heading 20/800/26,
  // Body 16/400/24, Label 14/800/20, Caption 12/400/18.
  TextStyle style(double size, FontWeight weight, double height) => TextStyle(
    fontFamily: _font,
    fontFamilyFallback: _fallback,
    fontSize: size,
    fontWeight: weight,
    height: height / size,
    color: t.ink,
  );
  final text = TextTheme(
    displaySmall: style(32, FontWeight.w900, 38),
    headlineMedium: style(32, FontWeight.w900, 38),
    headlineSmall: style(26, FontWeight.w900, 32),
    titleLarge: style(20, FontWeight.w800, 26),
    titleMedium: style(16, FontWeight.w800, 22),
    titleSmall: style(14, FontWeight.w800, 20),
    bodyLarge: style(16, FontWeight.w400, 24),
    bodyMedium: style(14, FontWeight.w400, 20),
    bodySmall: style(12, FontWeight.w400, 18).copyWith(color: t.muted),
    labelLarge: style(14, FontWeight.w800, 20),
    labelMedium: style(12, FontWeight.w800, 16),
    labelSmall: style(11, FontWeight.w700, 14).copyWith(color: t.muted),
  );

  const pill = StadiumBorder();
  const buttonText = TextStyle(
    fontFamily: _font,
    fontFamilyFallback: _fallback,
    fontSize: 15,
    fontWeight: FontWeight.w800,
  );
  OutlineInputBorder field(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color, width: width),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: _font,
    fontFamilyFallback: _fallback,
    textTheme: text,
    extensions: [t],
    scaffoldBackgroundColor: background,
    actionIconTheme: ActionIconThemeData(
      // Mirrored in right-to-left, like Material's own back arrow
      backButtonIconBuilder: (context) => Transform.flip(
        flipX: Directionality.of(context) == TextDirection.rtl,
        child: const Icon(LucideIcons.arrowLeft),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: t.ink,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: t.card,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: t.border),
      ),
    ),
    // Chips: 48 high; selected = soft blue with an accessible-blue outline and label
    chipTheme: ChipThemeData(
      shape: pill,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      backgroundColor: t.card,
      selectedColor: t.tonal,
      checkmarkColor: t.accent,
      iconTheme: IconThemeData(color: t.accent, size: 18),
      side: WidgetStateBorderSide.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? BorderSide(color: t.accent, width: 1.5)
            : BorderSide(color: t.border),
      ),
      labelStyle: TextStyle(
        fontFamily: _font,
        fontFamilyFallback: _fallback,
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: WidgetStateColor.resolveWith((states) => states.contains(WidgetState.selected) ? t.accent : t.ink),
      ),
    ),
    // Buttons: 52 high pills, label 15/800. Filled = brand blue with ink text.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.blue,
        foregroundColor: Brand.ink,
        disabledBackgroundColor: t.border,
        minimumSize: const Size(64, 52),
        shape: pill,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.accent,
        backgroundColor: t.card,
        side: BorderSide(color: t.accent, width: 1.5),
        minimumSize: const Size(64, 52),
        shape: pill,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: t.accent, minimumSize: const Size(48, 48), textStyle: buttonText),
    ),
    // Fields: 56 high, radius 16; focused = 2px brand blue, error = 2px red
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.card,
      hintStyle: TextStyle(fontFamily: _font, fontFamilyFallback: _fallback, fontSize: 16, color: t.muted),
      prefixIconColor: t.muted,
      suffixIconColor: t.muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: field(t.border, 1),
      enabledBorder: field(t.border, 1),
      focusedBorder: field(Brand.blue, 2),
      errorBorder: field(Brand.red, 2),
      focusedErrorBorder: field(Brand.red, 2),
      errorStyle: TextStyle(fontFamily: _font, fontFamilyFallback: _fallback, fontSize: 12, color: t.errorText),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: t.card,
      foregroundColor: t.accent,
      shape: const CircleBorder(),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFFE8EDF7) : Brand.ink,
      contentTextStyle: TextStyle(
        fontFamily: _font,
        fontFamilyFallback: _fallback,
        fontSize: 14,
        color: dark ? Brand.ink : Colors.white,
      ),
      actionTextColor: dark ? const Color(0xFF294AB8) : const Color(0xFFA9C8FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: t.accent,
      unselectedLabelColor: t.muted,
      labelStyle: text.labelLarge,
      unselectedLabelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: t.accent, width: 3),
        borderRadius: BorderRadius.circular(3),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: text.titleMedium,
      subtitleTextStyle: text.bodySmall,
      iconColor: t.muted,
    ),
    // Same selected look as the chips
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: _font, fontFamilyFallback: _fallback, fontSize: 14, fontWeight: FontWeight.w800),
        ),
        backgroundColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? t.tonal : t.card,
        ),
        foregroundColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? t.accent : t.ink,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: t.border)),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Brand.blue : t.border,
      ),
      thumbColor: WidgetStateColor.resolveWith((states) => states.contains(WidgetState.selected) ? Brand.ink : t.card),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Brand.blue),
    dividerTheme: DividerThemeData(color: t.border),
    badgeTheme: const BadgeThemeData(backgroundColor: Brand.coral, textColor: Colors.white),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
