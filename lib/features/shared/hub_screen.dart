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
///
/// The hero used to be a hand-drawn maze-with-a-figure boxed in a
/// bordered "photo" card. [_HeroWheels] replaces it with the same
/// [ConvoyNodeGlyph]/[ConvoyPipe] pieces gameplay actually uses, lit
/// and connected, sitting directly on [BlueprintGrid] with no framing
/// box — it reads as "the game, mid-flow," not decoration bolted on.
///
/// The coin balance and utility icons (theme toggle, achievements,
/// settings, style guide) belong in the AppBar — that's the
/// conventional, always-visible spot for them, not floating loose
/// mid-page — so they're back there, just using [_CompactIconButton]/
/// a trimmed [_CoinBadge] (~40x40 tap targets instead of the default
/// 48x48) so five items plus the wordmark fit without truncating.
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
            titleSpacing: ConvoySpacing.md,
            // FittedBox as a safety net: with the coin badge plus 5
            // icons back in the actions row (How to Play included),
            // this scales the wordmark down instead of silently
            // truncating it on a narrower device, the same failure
            // mode that started this whole thread.
            title: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'TAPLINE',
                style: ConvoyTypography.wordmark.copyWith(
                  fontSize: 20,
                  letterSpacing: 2,
                  color: ConvoyColors.textPrimaryFor(Theme.of(context).brightness),
                ),
              ),
            ),
            actionsIconTheme: const IconThemeData(size: 22),
            actions: [
              if (store != null) _CoinBadge(balance: store.coinBalance),
              Builder(
                builder: (context) {
                  final platformBrightness = MediaQuery.platformBrightnessOf(context);
                  final isDark = themeModeController.isDark(platformBrightness);
                  return _CompactIconButton(
                    tooltip: isDark ? 'Light mode' : 'Dark mode',
                    icon: isDark ? Icons.light_mode : Icons.dark_mode,
                    onPressed: () => themeModeController.toggle(platformBrightness),
                  );
                },
              ),
              _CompactIconButton(
                tooltip: 'How to play',
                icon: Icons.school,
                onPressed: () {
                  Navigator.of(context).pushNamed(DemoScreen.routeName);
                },
              ),
              _CompactIconButton(
                tooltip: 'Achievements',
                icon: Icons.emoji_events,
                onPressed: () {
                  Navigator.of(context).pushNamed(AchievementsScreen.routeName);
                },
              ),
              _CompactIconButton(
                tooltip: 'Settings',
                icon: Icons.settings,
                onPressed: () {
                  Navigator.of(context).pushNamed(SettingsScreen.routeName);
                },
              ),
              _CompactIconButton(
                tooltip: 'Style guide (dev)',
                icon: Icons.palette,
                onPressed: () {
                  Navigator.of(context).pushNamed(StyleGuideScreen.routeName);
                },
              ),
              const SizedBox(width: ConvoySpacing.xs),
            ],
          ),
          body: Stack(
            children: [
              const BlueprintGrid(),
              SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(ConvoySpacing.lg),
                  children: [
                    // Hero — lit valve wheels linked by active pipes,
                    // the same pieces a gameplay board is built from.
                    // No card/border around it: it sits straight on
                    // the blueprint background like the rest of the
                    // chrome does.
                    const _HeroWheels(),
                    const SizedBox(height: ConvoySpacing.lg),
                    Builder(
                      builder: (context) => Text(
                        'MODE SELECT',
                        style: ConvoyTypography.sectionLabel.copyWith(
                          color: ConvoyColors.textSecondaryFor(
                            Theme.of(context).brightness,
                          ),
                        ),
                      ),
                    ),
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

/// The hub's hero: a short run of [ConvoyNodeGlyph] valve wheels,
/// linked by lit [ConvoyPipe] segments — literally the same widgets
/// a gameplay board renders, not a separate illustration. Deliberate:
/// the old hero was a hand-drawn maze-with-a-figure inside a bordered
/// photo-style card, which read as decoration bolted onto the game
/// rather than the game itself. This reads as "the game, mid-flow,"
/// and drawing it with the real gameplay widgets means it can never
/// visually drift out of sync with what a board actually looks like.
/// No card/border/background — it's meant to sit directly on
/// [BlueprintGrid] like every other piece of chrome on this screen.
class _HeroWheels extends StatelessWidget {
  const _HeroWheels();

  static const double _diameter = 52;

  // Extra clearance beyond the wheel's own radius so its glow
  // (boxShadow blurRadius 22 + spreadRadius 4 in ConvoyNodeGlyph)
  // has room to fall off before the Stack's edge — without this the
  // end wheels' halos (and the wheels themselves, at t=0/t=1) get
  // hard-clipped by the container bounds, which is what was cutting
  // the first and last wheels in half.
  static const double _glowClearance = 26;

  // A gentle up/down wave rather than a dead-flat row — reads as a
  // little run of track, closer to the level-path treatment casual
  // games (Candy Crush, Subway Surfer's coin trails) use, instead of
  // four circles glued edge-to-edge in a straight line.
  static const double _waveAmplitude = 16;

  // Alternating tapped/supplied so the strip doesn't read as one
  // flat color — mirrors how a real board mixes "this one's the
  // source" (tapped, solid fill) with "this one's downstream"
  // (supplied, outline) rather than lighting every wheel identically.
  static const List<NodeVisualState> _states = [
    NodeVisualState.tapped,
    NodeVisualState.supplied,
    NodeVisualState.supplied,
    NodeVisualState.tapped,
  ];

  @override
  Widget build(BuildContext context) {
    final inset = _diameter / 2 + _glowClearance;
    return SizedBox(
      height: _diameter + _glowClearance * 2 + _waveAmplitude * 2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = _states.length;
          final centerY = constraints.maxHeight / 2;
          // Usable span is inset from both edges so nothing —
          // wheel or glow — ever touches the container boundary.
          final span = (constraints.maxWidth - inset * 2).clamp(0.0, double.infinity);
          final positions = List.generate(count, (i) {
            final t = count == 1 ? 0.5 : i / (count - 1);
            // Alternate above/below center; the middle wheels sit
            // closest to center, the end ones swing furthest, so
            // the whole strip reads as one continuous gentle curve
            // rather than a hard zigzag.
            final wave = _waveAmplitude * (i.isEven ? -1 : 1);
            return Offset(inset + span * t, centerY + wave);
          });
          return Stack(
            // The glow is allowed to bleed slightly past a wheel's
            // own box (that's the point of a soft shadow) — clipping
            // it at the Stack's own edge is exactly what produced
            // the hard-cut halo look, so let it render past bounds.
            clipBehavior: Clip.none,
            children: [
              // Pipes first, wheels drawn on top so a wheel's glow
              // isn't hidden behind an incoming pipe.
              for (var i = 0; i < count - 1; i++)
                Positioned.fill(
                  child: ConvoyPipe(
                    start: positions[i],
                    end: positions[i + 1],
                    state: PipeState.active,
                    curvature: 0.16,
                    baseStrokeWidth: 3,
                  ),
                ),
              for (var i = 0; i < count; i++)
                Positioned(
                  left: positions[i].dx - _diameter / 2,
                  top: positions[i].dy - _diameter / 2,
                  child: ConvoyNodeGlyph(
                    // Unused for rendering (ConvoyNodeGlyph always
                    // draws the valve-wheel glyph) — kept only
                    // because the constructor still requires one.
                    icon: Icons.circle,
                    state: _states[i],
                    diameter: _diameter,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A plain [IconButton] reserves a 48x48 tap target by default —
/// four of those plus the coin badge next to a title is exactly what
/// forced "TAPLINE" to truncate before. This trims padding/
/// constraints down to a still-comfortable ~40x40 without losing tap-
/// target accessibility sizing by much, which is what makes room for
/// the wordmark and the icons to coexist in the AppBar.
class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: onPressed,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      visualDensity: VisualDensity.compact,
    );
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
        style: ConvoyTypography.monoLabel.copyWith(
          color: ConvoyColors.textSecondaryFor(Theme.of(context).brightness),
        ),
      ),
    );
  }
}

/// Coin balance badge — the same [ProgressStore.coinBalance] every
/// gameplay screen already reads/writes, just made visible somewhere
/// a player sees it outside of an active attempt. Purely a display;
/// nothing here spends or earns coins.
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