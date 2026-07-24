import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'convoy_colors.dart';

/// Convoy's two-typeface system.
///
/// - [_technicalBase] (JetBrains Mono) reads like an instrument
///   readout: HUD numbers, stats, star counts, node/level codes. Used
///   with restraint — numbers and short labels, never paragraphs.
/// - [_chromeBase] (Overpass) is the humanist sans for everything
///   else. Overpass was originally drawn from U.S. highway signage,
///   so it carries some "infrastructure" character even in ordinary
///   body copy — a deliberate pick for this brief, not a default UI
///   font reached for out of habit.
///
/// NOTE: google_fonts fetches + caches these at runtime by default,
/// which is the simplest path and fine for day-to-day development.
/// If a fully offline build is ever needed (e.g. no wifi at a demo),
/// download the .ttf files from fonts.google.com, add them under
/// assets/fonts/, declare them in pubspec.yaml, and swap the
/// GoogleFonts.* calls below for TextStyle(fontFamily: '...'). Every
/// text style in the app is defined in this one file, so that swap
/// stays contained here.
class ConvoyTypography {
  ConvoyTypography._();

  static TextStyle get _technicalBase => GoogleFonts.jetBrainsMono();
  static TextStyle get _chromeBase => GoogleFonts.overpass();

  // ---- Display / wordmark ------------------------------------------------
  static TextStyle get wordmark => _chromeBase.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: 6,
        color: ConvoyColors.textPrimary,
      );

  // ---- Section labels — uppercase eyebrow text used the way a
  // control-room panel actually labels its sections ("MODE SELECT",
  // "DESIGN SYSTEM"), not decorative numbering. ----------------------------
  static TextStyle get sectionLabel => _chromeBase.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 3,
        color: ConvoyColors.textSecondary,
      );

  // ---- Panel / mode titles ------------------------------------------------
  static TextStyle get panelTitle => _chromeBase.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: ConvoyColors.textPrimary,
      );

  static TextStyle get panelSubtitle => _chromeBase.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: ConvoyColors.textSecondary,
        height: 1.4,
      );

  // ---- Body / UI chrome ----------------------------------------------------
  static TextStyle get body => _chromeBase.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: ConvoyColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get caption => _chromeBase.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: ConvoyColors.textSecondary,
      );

  static TextStyle get buttonLabel => _chromeBase.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: ConvoyColors.textPrimary,
      );

  // ---- Technical / HUD (numbers, stats, node labels) -----------------------
  static TextStyle get hudLarge => _technicalBase.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: ConvoyColors.amber,
      );

  static TextStyle get hudMedium => _technicalBase.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: ConvoyColors.textPrimary,
      );

  /// `height: 1.0` is deliberate, not a stray default. Left unset, a
  /// [Text] using this style renders at JetBrains Mono's own natural
  /// line-box metrics — which run visibly taller than the nominal 11px
  /// fontSize (ascent+descent padding baked into the font itself), not
  /// a fixed, predictable number you can budget layout space against.
  /// convoy_node.dart's node Column found this out the hard way: a
  /// height budget sized for "an 11px label" overflowed by 2px on
  /// every single node on a real device, because the actual rendered
  /// label was taller than 11px. Pinning `height` here makes this
  /// style's vertical footprint something call sites can actually
  /// reason about, instead of an implicit font-metric fact nobody
  /// wrote down anywhere.
  static TextStyle get monoLabel => _technicalBase.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.0,
        color: ConvoyColors.textSecondary,
      );

  /// Builds the full [TextTheme] so standard Material widgets (app
  /// bars, buttons, etc.) that read from `Theme.of(context)` pick up
  /// Convoy's type system automatically, without every widget having
  /// to reference [ConvoyTypography] directly.
  static TextTheme textTheme() {
    return TextTheme(
      displayLarge: wordmark,
      titleLarge: panelTitle,
      titleMedium: panelSubtitle,
      labelLarge: buttonLabel,
      bodyLarge: body,
      bodyMedium: body,
      bodySmall: caption,
      labelSmall: sectionLabel,
    );
  }
}
