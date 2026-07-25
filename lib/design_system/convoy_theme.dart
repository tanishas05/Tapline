import 'package:flutter/material.dart';

import 'convoy_colors.dart';
import 'convoy_typography.dart';

/// Builds Convoy's [ThemeData] — one for each brightness now that the
/// app supports a light/dark toggle (previously dark-only; see
/// convoy_colors.dart's doc comment for how the rest of the app's
/// ~150 direct `ConvoyColors.xxx` references stay in sync with
/// whichever of these two is actually active).
///
/// Both builders take an explicit [Brightness] and read colors via
/// ConvoyColors's `xxxFor(brightness)` resolvers rather than its
/// plain getters — these are built once, up front, for MaterialApp's
/// `theme:`/`darkTheme:` properties, so each needs its OWN palette's
/// values regardless of whatever the ambient `ConvoyColors.brightness`
/// happens to be at the moment this runs.
class ConvoyTheme {
  ConvoyTheme._();

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      surface: ConvoyColors.surfaceFor(brightness),
      onSurface: ConvoyColors.textPrimaryFor(brightness),
      primary: ConvoyColors.amberFor(brightness),
      onPrimary: ConvoyColors.backgroundFor(brightness),
      secondary: ConvoyColors.cyanFor(brightness),
      onSecondary: ConvoyColors.backgroundFor(brightness),
      error: ConvoyColors.redDecayFor(brightness),
      onError: ConvoyColors.backgroundFor(brightness),
      outline: ConvoyColors.outlineFor(brightness),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: ConvoyColors.backgroundFor(brightness),
      colorScheme: colorScheme,
      textTheme: ConvoyTypography.textTheme(brightness),

      // Restrained, amber-tinted tap feedback instead of Material's
      // default grey/white ripple — small detail, but it's the kind
      // of thing that keeps every screen reading as one identity.
      splashColor: ConvoyColors.amberFor(brightness).withValues(alpha: 0.12),
      highlightColor:
          ConvoyColors.amberFor(brightness).withValues(alpha: 0.05),

      appBarTheme: AppBarTheme(
        backgroundColor: ConvoyColors.backgroundFor(brightness),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // Force-overridden to THIS brightness's color, same reasoning
        // as textTheme()'s doc comment above: ConvoyTypography.panelTitle
        // on its own reads the live/ambient ConvoyColors.textPrimary,
        // which is whatever brightness happened to be active at the
        // moment this ThemeData was built — not necessarily this
        // brightness. Left unguarded, this is exactly what made AppBar
        // titles ("SETTINGS", "ACHIEVEMENTS", etc.) render in the wrong
        // mode's text color after a toggle — right color scheme
        // everywhere else on the screen, unreadable title.
        titleTextStyle: ConvoyTypography.panelTitle.copyWith(
          color: ConvoyColors.textPrimaryFor(brightness),
        ),
        iconTheme:
            IconThemeData(color: ConvoyColors.textPrimaryFor(brightness)),
      ),
      iconTheme: IconThemeData(color: ConvoyColors.textPrimaryFor(brightness)),
      dividerTheme: DividerThemeData(
        color: ConvoyColors.outlineFor(brightness),
        thickness: 1,
        space: 1,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ConvoyColors.amberFor(brightness),
          textStyle: ConvoyTypography.buttonLabel,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ConvoyColors.amberFor(brightness),
          foregroundColor: ConvoyColors.backgroundFor(brightness),
          textStyle: ConvoyTypography.buttonLabel,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }

  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);
}