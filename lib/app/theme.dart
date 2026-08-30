import 'package:flutter/material.dart';

// CUSTOM THEME EXTENSION
class TvThemeExtension extends ThemeExtension<TvThemeExtension> {
  final Color accentFocus;
  final Color activeSelected;
  final Color surfaceCard;
  final Color deepBackground;

  const TvThemeExtension({
    required this.accentFocus,
    required this.activeSelected,
    required this.surfaceCard,
    required this.deepBackground,
  });

  @override
  TvThemeExtension copyWith({
    Color? accentFocus,
    Color? activeSelected,
    Color? surfaceCard,
    Color? deepBackground,
  }) {
    return TvThemeExtension(
      accentFocus: accentFocus ?? this.accentFocus,
      activeSelected: activeSelected ?? this.activeSelected,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      deepBackground: deepBackground ?? this.deepBackground,
    );
  }

  @override
  TvThemeExtension lerp(
    covariant ThemeExtension<TvThemeExtension>? other,
    double t,
  ) {
    if (other is! TvThemeExtension) return this;
    return TvThemeExtension(
      accentFocus: Color.lerp(accentFocus, other.accentFocus, t)!,
      activeSelected: Color.lerp(activeSelected, other.activeSelected, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      deepBackground: Color.lerp(deepBackground, other.deepBackground, t)!,
    );
  }
}

const Color kDeepBackground = Color(0xFF090514);

const Color kSurfaceCard = Color(0xFF160D27);
const Color kAccentPurple = Color(0xFFB388FF);
const Color kSemanticRed = Color(0xFFFF3B3B);
const Color kPrimaryButtonColor = Color(0xFF9370DB);
const Color kSecondaryButtonColor = Color(0xFF321A4A);
const Color kFocusedButtonColor = Color(0xFFB08CFC);
const Color kTextPrimary = Color(0xDEFFFFFF);
const Color kTextSecondary = Color(0x99FFFFFF);
const Color kTextDisabled = Color(0x61FFFFFF);
final Color kOverlayDimBackground = Colors.black.withValues(alpha: 0.8);

const double kSmallRadius = 8.0;
const double kStandardRadius = 10.0;
const double kLargeRadius = 16.0;

const TextStyle kTextStyleHeader = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: kTextPrimary,
);

const TextStyle kTextStyleTitle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: kTextPrimary,
);

const TextStyle kTextStyleBody = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.normal,
  color: kTextPrimary,
);

const TextStyle kTextStyleCaption = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.normal,
  color: kTextSecondary,
);

const EdgeInsets kPickerPadding = EdgeInsets.symmetric(
  horizontal: 14,
  vertical: 8,
);

BoxDecoration focusDecoration({
  bool focused = false,
  double radius = kStandardRadius,
}) {
  return BoxDecoration(
    color: focused ? kAccentPurple.withValues(alpha: 0.15) : Colors.transparent,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: focused ? kAccentPurple : Colors.transparent,
      width: 2,
    ),
  );
}

BoxDecoration get kAppBackgroundDecoration => const BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A1A4A), Color(0xFF120826), Color(0xFF090514)],
  ),
);

BoxDecoration buildDialogDecoration({
  double radius = kLargeRadius,
  double blurRadius = 30,
}) {
  return kAppBackgroundDecoration.copyWith(
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: kAccentPurple.withValues(alpha: 0.3)),
    boxShadow: [
      BoxShadow(color: kOverlayDimBackground, blurRadius: blurRadius),
    ],
  );
}

BoxDecoration buildListItemDecoration({
  required bool isFocused,
  required bool isSelected,
  bool isHovered = false,
  double radius = 10,
}) {
  return BoxDecoration(
    color: isSelected
        ? kAccentPurple.withValues(alpha: 0.15)
        : (isHovered || isFocused)
        ? kAccentPurple.withValues(alpha: 0.30)
        : Colors.transparent,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: isSelected || isFocused || isHovered
          ? kAccentPurple
          : Colors.transparent,
      width: isSelected || isFocused || isHovered ? 1.5 : 1,
    ),
  );
}

BoxDecoration buildSeasonButtonDecoration({
  required bool isFocused,
  required bool isSelected,
  bool isHovered = false,
  double radius = 8,
}) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isSelected
          ? [
              kAccentPurple.withValues(alpha: 0.25),
              kAccentPurple.withValues(alpha: 0.10),
            ]
          : (isFocused || isHovered)
          ? [
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.04),
            ]
          : [
              Colors.white.withValues(alpha: 0.05),
              Colors.white.withValues(alpha: 0.01),
            ],
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: isSelected
          ? kAccentPurple
          : (isFocused || isHovered)
          ? kAccentPurple.withValues(alpha: 0.5)
          : Colors.white.withValues(alpha: 0.08),
      width: isSelected || isFocused || isHovered ? 1.5 : 1.0,
    ),
    boxShadow: (isSelected || isFocused)
        ? [
            BoxShadow(
              color: kAccentPurple.withValues(alpha: 0.15),
              blurRadius: 8,
            ),
          ]
        : null,
  );
}

BoxDecoration buildCategoryPickerDecoration({
  required bool isFocused,
  double radius = 10,
}) {
  return kAppBackgroundDecoration.copyWith(
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: isFocused ? kAccentPurple : Colors.white.withValues(alpha: 0.08),
      width: isFocused ? 2 : 1.5,
    ),
    boxShadow: isFocused
        ? [
            BoxShadow(
              color: kAccentPurple.withValues(alpha: 0.2),
              blurRadius: 16,
            ),
          ]
        : [],
  );
}

List<BoxShadow> buildGlowShadow({
  Color color = kAccentPurple,
  double alpha = 0.25,
  double blurRadius = 24,
  Offset offset = const Offset(0, 4),
}) {
  return [
    BoxShadow(
      color: color.withValues(alpha: alpha),
      blurRadius: blurRadius,
      spreadRadius: 0,
      offset: offset,
    ),
  ];
}

BoxDecoration buildGlassyPillDecoration({
  double radius = 16,
  double glowAlpha = 0.1,
  double blurRadius = 20,
  double spreadRadius = 1,
  List<Color>? gradientColors,
  Color glowColor = kAccentPurple,
}) {
  return BoxDecoration(
    gradient: LinearGradient(
      colors:
          gradientColors ??
          [
            const Color(0xFF2A1A4A).withValues(alpha: 0.7),
            const Color(0xFF120826).withValues(alpha: 0.4),
          ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: glowAlpha > 0
          ? glowColor.withValues(alpha: glowAlpha * 0.8)
          : Colors.white.withValues(alpha: 0.08),
      width: 1.5,
    ),
    boxShadow: [
      if (glowAlpha > 0)
        BoxShadow(
          color: glowColor.withValues(alpha: glowAlpha),
          blurRadius: blurRadius,
          spreadRadius: spreadRadius,
          offset: const Offset(0, 0),
        )
      else
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 16,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
    ],
  );
}

ThemeData buildTvTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kDeepBackground,
    canvasColor: kDeepBackground,
    cardColor: kSurfaceCard,

    colorScheme: const ColorScheme.dark(
      primary: kAccentPurple,
      secondary: kAccentPurple,
      surface: kSurfaceCard,
      error: kSemanticRed,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: kTextPrimary,
      onError: Colors.white,
    ),

    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: kTextPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: kTextPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: kTextPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: kTextPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: kTextPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: kTextSecondary,
      ),
      bodyLarge: TextStyle(fontSize: 18, color: kTextPrimary),
      bodyMedium: TextStyle(fontSize: 16, color: kTextSecondary),
      bodySmall: TextStyle(fontSize: 14, color: kTextDisabled),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: kTextPrimary,
      ),
    ),

    cardTheme: CardThemeData(
      color: kSurfaceCard,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(4),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurfaceCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kAccentPurple, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kSemanticRed, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kSemanticRed, width: 2),
      ),
      errorStyle: const TextStyle(
        color: kSemanticRed,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      labelStyle: const TextStyle(color: kTextSecondary, fontSize: 16),
      hintStyle: const TextStyle(color: kTextDisabled, fontSize: 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccentPurple,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: kSurfaceCard,
      selectedColor: kAccentPurple.withValues(alpha: 0.25),
      labelStyle: const TextStyle(fontSize: 14, color: kTextPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: kAccentPurple,
    ),

    extensions: const <ThemeExtension>[
      TvThemeExtension(
        accentFocus: kAccentPurple,
        activeSelected: kAccentPurple,
        surfaceCard: kSurfaceCard,
        deepBackground: kDeepBackground,
      ),
    ],
  );
}
