import 'package:flutter/material.dart';

/// Named color tokens for Convoy's "Industrial Cartography" identity.
///
/// Every color used anywhere in the app should come from this file —
/// no raw hex values scattered through widgets. Grouped as:
///
///   - Base: the graphite/navy (dark) or warm-paper (light) surfaces
///     everything sits on, plus text.
///   - Accents: exactly two functional accent hues (amber, cyan) and
///     one danger hue (red), used with restraint by design. Do not
///     introduce a third "decorative" accent — if something needs to
///     stand out, it should be doing so *because* it's active,
///     signal-related, or decaying, not for variety's sake.
///
/// LIGHT/DARK: originally dark-only. Every token below is now a
/// brightness-aware getter instead of a `static const` — but every
/// existing call site in the app (~150 of them, `ConvoyColors.amber`,
/// `ConvoyColors.surface`, etc.) is UNCHANGED and keeps working
/// exactly as written, because [brightness] is a single mutable
/// static field every getter reads, rather than a parameter every
/// call site would otherwise need to start passing. app.dart sets
/// [brightness] once per frame (via MaterialApp's `builder`, reading
/// the already-resolved `Theme.of(context).brightness` — which
/// itself already correctly accounts for ThemeMode.system) before any
/// of this frame's widgets are actually built, so every getter read
/// during that build sees the right palette. This is a pragmatic
/// choice given the size of the existing call-site surface, not the
/// most "pure" Flutter pattern (an InheritedWidget/Theme extension
/// lookup per call site would be) — documented here so it doesn't
/// read as an oversight later.
///
/// The dark palette's values are UNCHANGED from the original
/// dark-only build — dark mode looks pixel-identical to before this
/// was added. The light palette is a cool neutral gray-white — not
/// the warm cream/beige this originally shipped with, swapped out per
/// request for something cleaner and less "off."
class ConvoyColors {
  ConvoyColors._();

  /// Which palette every getter below currently resolves to. See this
  /// class's own doc comment for who sets this and when.
  static Brightness brightness = Brightness.dark;

  static bool get _isDark => brightness == Brightness.dark;

  // ---- Dark palette (graphite/navy — never pure black; unchanged) ------
  static const Color _backgroundDark = Color(0xFF10141A);
  static const Color _surfaceDark = Color(0xFF1A212B);
  static const Color _surfaceElevatedDark = Color(0xFF212A36);
  static const Color _outlineDark = Color(0xFF2E3947);
  static const Color _gridLineDark = Color(0xFF1B232D);
  static const Color _textPrimaryDark = Color(0xFFE7ECF2);
  static const Color _textSecondaryDark = Color(0xFF8B96A3);
  static const Color _textDisabledDark = Color(0xFF4B5561);
  static const Color _amberDark = Color(0xFFE8A33D);
  static const Color _amberDimDark = Color(0xFF5A4526);
  static const Color _cyanDark = Color(0xFF49C6D6);
  static const Color _cyanDimDark = Color(0xFF204750);
  static const Color _redDecayDark = Color(0xFFC1554A);
  static const Color _redDecayDimDark = Color(0xFF4A2B27);

  // ---- Light palette (cool neutral gray-white, not warm beige) ----------
  static const Color _backgroundLight = Color(0xFFF5F6F8);
  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static const Color _surfaceElevatedLight = Color(0xFFFAFBFC);
  static const Color _outlineLight = Color(0xFFE1E4E8);
  static const Color _gridLineLight = Color(0xFFEDEEF1);
  static const Color _textPrimaryLight = Color(0xFF000000);
  static const Color _textSecondaryLight = Color(0xFF2B2B2B);
  static const Color _textDisabledLight = Color(0xFFAEB4BB);
  static const Color _amberLight = Color(0xFFB4720C);
  static const Color _amberDimLight = Color(0xFFF2E7D3);
  static const Color _cyanLight = Color(0xFF0F7C8C);
  static const Color _cyanDimLight = Color(0xFFD3EEF2);
  static const Color _redDecayLight = Color(0xFFAF3B30);
  static const Color _redDecayDimLight = Color(0xFFF3D9D6);

  // ---- Base --------------------------------------------------------------
  static Color get background => _isDark ? _backgroundDark : _backgroundLight;
  static Color get surface => _isDark ? _surfaceDark : _surfaceLight;
  static Color get surfaceElevated =>
      _isDark ? _surfaceElevatedDark : _surfaceElevatedLight;
  static Color get outline => _isDark ? _outlineDark : _outlineLight;

  /// Barely-there grid lines for the blueprint backdrop — sits just
  /// above [background], never competes with foreground content.
  static Color get gridLine => _isDark ? _gridLineDark : _gridLineLight;

  // ---- Text --------------------------------------------------------------
  static Color get textPrimary =>
      _isDark ? _textPrimaryDark : _textPrimaryLight;
  static Color get textSecondary =>
      _isDark ? _textSecondaryDark : _textSecondaryLight;
  static Color get textDisabled =>
      _isDark ? _textDisabledDark : _textDisabledLight;

  // ---- Accents (restraint: amber + cyan only; red is danger-only) -------

  /// Active / supplied. Used by Classic & Capacity.
  static Color get amber => _isDark ? _amberDark : _amberLight;
  static Color get amberDim => _isDark ? _amberDimDark : _amberDimLight;

  /// Signal mode's directed edges and driver nodes — nowhere else.
  static Color get cyan => _isDark ? _cyanDark : _cyanLight;
  static Color get cyanDim => _isDark ? _cyanDimDark : _cyanDimLight;

  /// Decay / danger only. Never used decoratively.
  static Color get redDecay => _isDark ? _redDecayDark : _redDecayLight;
  static Color get redDecayDim =>
      _isDark ? _redDecayDimDark : _redDecayDimLight;

  // ---- Explicit-brightness resolvers -------------------------------------
  // Used by ConvoyTheme.light()/.dark(), which each need a SPECIFIC
  // palette's values regardless of whatever [brightness] currently is
  // (both ThemeData objects are built once, up front, for
  // MaterialApp's `theme:`/`darkTheme:` — not re-resolved per frame
  // the way the getters above are).
  static Color backgroundFor(Brightness b) =>
      b == Brightness.dark ? _backgroundDark : _backgroundLight;
  static Color surfaceFor(Brightness b) =>
      b == Brightness.dark ? _surfaceDark : _surfaceLight;
  static Color surfaceElevatedFor(Brightness b) =>
      b == Brightness.dark ? _surfaceElevatedDark : _surfaceElevatedLight;
  static Color outlineFor(Brightness b) =>
      b == Brightness.dark ? _outlineDark : _outlineLight;
  static Color textPrimaryFor(Brightness b) =>
      b == Brightness.dark ? _textPrimaryDark : _textPrimaryLight;
  static Color textSecondaryFor(Brightness b) =>
      b == Brightness.dark ? _textSecondaryDark : _textSecondaryLight;
  static Color amberFor(Brightness b) =>
      b == Brightness.dark ? _amberDark : _amberLight;
  static Color amberDimFor(Brightness b) =>
      b == Brightness.dark ? _amberDimDark : _amberDimLight;
  static Color cyanFor(Brightness b) =>
      b == Brightness.dark ? _cyanDark : _cyanLight;
  static Color redDecayFor(Brightness b) =>
      b == Brightness.dark ? _redDecayDark : _redDecayLight;
}