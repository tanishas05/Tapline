import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/theme_mode_controller.dart';
import 'design_system/convoy_colors.dart';
import 'design_system/convoy_theme.dart';
import 'features/shared/achievements_screen.dart';
import 'features/shared/demo_screen.dart';
import 'features/shared/hub_screen.dart';
import 'features/shared/settings_screen.dart';
import 'features/shared/style_guide_screen.dart';

/// Root widget for Convoy.
///
/// Phase 0 wired up navigation between the mode-select hub and the
/// dev-only style guide with plain named routes — that's all that
/// phase needed. A more capable router can replace this later if
/// gameplay routes end up needing arguments/deep links beyond what
/// [HubScreen]'s `Navigator.push` already handles for the "coming
/// soon" destinations.
///
/// Phase 6 addition: light/dark mode. This is now a
/// ConsumerStatefulWidget (previously stateless) so it can
/// addListener on [ThemeModeController] and rebuild itself when the
/// player toggles theme — the same listen-and-rebuild pattern every
/// gameplay screen already uses for its own GameplayController, just
/// at the app root instead of a single screen.
class ConvoyApp extends ConsumerStatefulWidget {
  const ConvoyApp({super.key});

  @override
  ConsumerState<ConvoyApp> createState() => _ConvoyAppState();
}

class _ConvoyAppState extends ConsumerState<ConvoyApp> {
  late final ThemeModeController _themeModeController;

  @override
  void initState() {
    super.initState();
    _themeModeController = ref.read(themeModeControllerProvider)
      ..addListener(_onThemeModeChanged);
  }

  void _onThemeModeChanged() => setState(() {});

  @override
  void dispose() {
    _themeModeController.removeListener(_onThemeModeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tapline',
      debugShowCheckedModeBanner: false,
      theme: ConvoyTheme.light(),
      darkTheme: ConvoyTheme.dark(),
      themeMode: _themeModeController.mode,
      // Runs once per frame, before any of the app's actual screen
      // content builds — this is what keeps ConvoyColors.brightness
      // (and therefore every one of the ~150 direct
      // `ConvoyColors.xxx` references throughout the app) in sync
      // with whichever theme MaterialApp just resolved, INCLUDING
      // ThemeMode.system (Theme.of(context).brightness here already
      // reflects Flutter's own correct system-brightness resolution,
      // so this doesn't need to re-derive that itself). See
      // convoy_colors.dart's class doc comment for the full
      // reasoning behind this bridge.
      builder: (context, child) {
        ConvoyColors.brightness = Theme.of(context).brightness;
        return child!;
      },
      initialRoute: HubScreen.routeName,
      routes: {
        HubScreen.routeName: (context) => const HubScreen(),
        DemoScreen.routeName: (context) => const DemoScreen(),
        StyleGuideScreen.routeName: (context) => const StyleGuideScreen(),
        SettingsScreen.routeName: (context) => const SettingsScreen(),
        AchievementsScreen.routeName: (context) => const AchievementsScreen(),
      },
    );
  }
}