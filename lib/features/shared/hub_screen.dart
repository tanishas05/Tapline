import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/level_providers.dart';
import '../../data/level_schema.dart';
import '../../data/progress_providers.dart';
import '../../data/progress_store.dart';
import '../../data/slot_progress.dart';
import '../../data/theme_mode_controller.dart';
import '../../design_system/design_system.dart';
import '../../engine/engine.dart';
import '../capacity/capacity_level_select_screen.dart';
import '../classic/classic_level_select_screen.dart';
import '../signal/signal_level_select_screen.dart';
import 'achievements_screen.dart';
import 'demo_screen.dart';
import 'settings_screen.dart';
import 'style_guide_screen.dart';

/// Mode-select hub — the app's start screen. Three parallel tracks
/// (Classic / Capacity / Signal), all unlocked from the start, per
/// the shared progression model. All three have real destinations as
/// of Phase 5.
///
/// Phase 2 adds the small "N LEVELS LOADED" caption under each track
/// — verification checklist: "The app can load and list levels per
/// track on the hub screen from Phase 0, even with no interactive
/// gameplay yet." Counts come from [levelCountsProvider], the same
/// [LevelLoader] Phase 3+ gameplay screens will use — nothing here is
/// hub-screen-specific about how they're fetched.
///
/// Phase 6 adds a star total per track. IMPORTANT — this is display
/// only. Master Context item 1: per-slot unlocking (3-star auto-
/// unlocks the next slot, handled entirely inside
/// level_select_screen.dart) and cumulative star totals (shown here)
/// are two SEPARATE systems. This screen never reads a track's star
/// total to decide whether to let the player tap into it — all three
/// [ModePanel]s below are always tappable, unconditionally, exactly
/// as they were before this phase. The star total is a track-wide
/// meta-progression signal for future bonus/cosmetic content (not yet
/// built — no cosmetic assets exist in this codebase to unlock), not
/// a gate.
class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  static const routeName = '/';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelCounts = ref.watch(levelCountsProvider).value;
    final progressAsync = ref.watch(progressStoreProvider);
    final classicTrack = ref.watch(classicTrackProvider).value;
    final capacityTrack = ref.watch(capacityTrackProvider).value;
    final signalTrack = ref.watch(signalTrackProvider).value;
    final store = progressAsync.value;
    // Watched here, at the top of build — NOT inside the nested Builder
    // below. ref.watch only reliably registers a rebuild dependency
    // while HubScreen's own build(context, ref) is on the stack; a
    // plain Flutter Builder's callback runs later, outside that
    // window, so calling ref.watch in there can silently fail to
    // trigger rebuilds on theme change.
    final themeModeController = ref.watch(themeModeControllerProvider);

    // Wrapped in ListenableBuilder rather than relying solely on the
    // ref.watch above. HubScreen is the initial route, mounted once
    // into the Navigator's Overlay — in practice ref.watch on a
    // ChangeNotifierProvider wasn't reliably forcing this
    // already-mounted route's Element to rebuild on toggle (it only
    // caught up whenever something else happened to rebuild it).
    // ListenableBuilder sidesteps that entirely: it adds its own
    // listener straight to the ChangeNotifier and calls setState
    // itself the instant notifyListeners() fires, the same reliable
    // mechanism app.dart already uses for the rest of the app, just
    // scoped to this screen instead of the whole tree.
    return ListenableBuilder(
      listenable: themeModeController,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'TAPLINE',
              style: ConvoyTypography.wordmark.copyWith(fontSize: 22),
            ),
            actions: [
              if (store != null) _CoinBadge(balance: store.coinBalance),
              Builder(
                builder: (context) {
                  final platformBrightness =
                  MediaQuery.platformBrightnessOf(context);
                  final isDark = themeModeController.isDark(platformBrightness);
                  return IconButton(
                    tooltip: isDark ? 'Light mode' : 'Dark mode',
                    icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                    onPressed: () => themeModeController.toggle(platformBrightness),
                  );
                },
              ),
              IconButton(
                tooltip: 'How to play',
                icon: const Icon(Icons.school),
                onPressed: () {
                  Navigator.of(context).pushNamed(DemoScreen.routeName);
                },
              ),
              IconButton(
                tooltip: 'Achievements',
                icon: const Icon(Icons.emoji_events),
                onPressed: () {
                  Navigator.of(context).pushNamed(AchievementsScreen.routeName);
                },
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.of(context).pushNamed(SettingsScreen.routeName);
                },
              ),
              IconButton(
                tooltip: 'Style guide (dev)',
                icon: const Icon(Icons.palette),
                onPressed: () {
                  Navigator.of(context).pushNamed(StyleGuideScreen.routeName);
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              const BlueprintGrid(),
              SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(ConvoySpacing.lg),
                  children: [
                    // Signature flourish: the same Pipe component that
                    // will carry supply between gameplay nodes, threaded
                    // through the very first screen the player sees.
                    SizedBox(
                      height: 40,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return ConvoyPipe(
                            start: const Offset(0, 18),
                            end: Offset(constraints.maxWidth, 24),
                            state: PipeState.active,
                            curvature: 0.12,
                            baseStrokeWidth: 3,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: ConvoySpacing.sm),
                    Text('MODE SELECT', style: ConvoyTypography.sectionLabel),
                    const SizedBox(height: ConvoySpacing.md),
                    ModePanel(
                      title: 'CLASSIC',
                      description:
                      'Tap the fewest tanks needed to keep every node supplied.',
                      icon: Icons.storage,
                      accentColor: ConvoyColors.amber,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ClassicLevelSelectScreen(),
                          ),
                        );
                      },
                    ),
                    _TrackProgressCaption(
                      count: levelCounts?[GameMode.classic],
                      starTotal: _starTotal(classicTrack, store),
                      maxStars: classicTrack == null ? null : classicTrack.length * 3,
                    ),
                    const SizedBox(height: ConvoySpacing.md),
                    ModePanel(
                      title: 'CAPACITY',
                      description:
                      'Balance weighted supply and demand across the network.',
                      icon: Icons.speed,
                      accentColor: ConvoyColors.amber,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                            const CapacityLevelSelectScreen(),
                          ),
                        );
                      },
                    ),
                    _TrackProgressCaption(
                      count: levelCounts?[GameMode.capacity],
                      starTotal: _starTotal(capacityTrack, store),
                      maxStars:
                      capacityTrack == null ? null : capacityTrack.length * 3,
                    ),
                    const SizedBox(height: ConvoySpacing.md),
                    ModePanel(
                      title: 'SIGNAL',
                      description:
                      'Find the minimum driver nodes to control the whole grid.',
                      icon: Icons.settings_input_antenna,
                      accentColor: ConvoyColors.cyan,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SignalLevelSelectScreen(),
                          ),
                        );
                      },
                    ),
                    _TrackProgressCaption(
                      count: levelCounts?[GameMode.signal],
                      starTotal: _starTotal(signalTrack, store),
                      maxStars: signalTrack == null ? null : signalTrack.length * 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Sums each slot's best-outcome star value (3/2/0) across a track.
  /// Null if either the track or the progress store hasn't loaded
  /// yet — [_TrackProgressCaption] treats that the same as the level
  /// count being null, blank rather than a spinner.
  int? _starTotal(List<Level>? levels, ProgressStore? store) {
    if (levels == null || store == null) return null;
    var total = 0;
    for (final level in levels) {
      total += switch (store.slotProgress(level.id).bestOutcome) {
        SlotOutcome.threeStar => 3,
        SlotOutcome.twoStar => 2,
        SlotOutcome.none => 0,
      };
    }
    return total;
  }
}

/// Small HUD-style caption under a [ModePanel] showing curated level
/// count and cumulative star total for that track — informational
/// only, see [HubScreen]'s doc comment on why this never gates
/// anything. Blank while loading rather than a spinner, same
/// reasoning as the Phase 2 level-count-only version this replaces.
class _TrackProgressCaption extends StatelessWidget {
  const _TrackProgressCaption({
    required this.count,
    required this.starTotal,
    required this.maxStars,
  });

  final int? count;
  final int? starTotal;
  final int? maxStars;

  @override
  Widget build(BuildContext context) {
    if (count == null) return const SizedBox(height: ConvoySpacing.xs);
    final starsText =
    (starTotal != null && maxStars != null) ? ' \u00b7 $starTotal/$maxStars \u2605' : '';
    return Padding(
      padding: const EdgeInsets.only(
        top: ConvoySpacing.xs,
        left: ConvoySpacing.xs,
      ),
      child: Text(
        '$count LEVEL${count == 1 ? '' : 'S'} LOADED$starsText',
        style: ConvoyTypography.monoLabel,
      ),
    );
  }
}

/// Coin balance badge in the app bar — the same [ProgressStore.coinBalance]
/// every gameplay screen already reads/writes, just made visible
/// somewhere a player sees it outside of an active attempt. Purely a
/// display; nothing here spends or earns coins.
class _CoinBadge extends StatelessWidget {
  const _CoinBadge({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ConvoySpacing.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ConvoyColors.surfaceElevated,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: ConvoyColors.amber),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                size: 10,
                color: ConvoyColors.amber,
              ),
              const SizedBox(width: 6),
              Text('$balance', style: ConvoyTypography.hudMedium),
            ],
          ),
        ),
      ),
    );
  }
}