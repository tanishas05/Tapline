// Shared level select screen — factored out during Phase 4 rather
// than hand-copying classic_level_select_screen.dart's structure a
// second time for Capacity: the two were identical except for which
// track provider to watch, what title to show, and which gameplay
// screen a tap should open. Parameterizing those three things means a
// future fix here (lock-state logic, layout, whatever) only has to
// happen once — Signal (Phase 5) should be able to use this directly
// too, unchanged.
//
// SCOPING NOTE (carried over from Phase 3's classic_level_select_screen.dart):
// "the track" is exactly a mode's curated levels, in curated order —
// not an open-ended/infinite sequence. A slot's underlying GRAPH can
// still change across attempts (a retry after a 2-star decline or a
// fail swaps in a freshly-generated layout at the same tier), but the
// SLOT POSITIONS themselves are fixed at the curated count. Extending
// any track past its curated set with more on-device-generated slots
// is a natural later extension, not decided here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/level_schema.dart';
import '../../data/progress_providers.dart';
import '../../data/progress_store.dart';
import '../../data/slot_progress.dart';
import '../../design_system/design_system.dart';
import '../../engine/engine.dart';
import '../../generation/difficulty_tiers.dart';

class LevelSelectScreen extends ConsumerWidget {
  const LevelSelectScreen({
    super.key,
    required this.title,
    required this.trackProvider,
    required this.openGameplayScreen,
  });

  final String title;
  final FutureProvider<List<Level>> trackProvider;

  /// Pushes whatever gameplay screen this mode uses, given the slot's
  /// stable id and the level to start with.
  final void Function(BuildContext context, String slotId, Level initialLevel)
      openGameplayScreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackAsync = ref.watch(trackProvider);
    final progressAsync = ref.watch(progressStoreProvider);

    return Scaffold(
      appBar: AppBar(title: Text(title, style: ConvoyTypography.panelTitle)),
      body: Stack(
        children: [
          const BlueprintGrid(),
          SafeArea(
            child: trackAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'Could not load the $title track.\n$error',
                  style: ConvoyTypography.body,
                  textAlign: TextAlign.center,
                ),
              ),
              data: (levels) {
                return progressAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Text(
                      'Could not load saved progress.\n$error',
                      style: ConvoyTypography.body,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  data: (progressStore) => _SlotList(
                    levels: levels,
                    progressStore: progressStore,
                    openGameplayScreen: openGameplayScreen,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotList extends StatelessWidget {
  const _SlotList({
    required this.levels,
    required this.progressStore,
    required this.openGameplayScreen,
  });

  final List<Level> levels;
  final ProgressStore progressStore;
  final void Function(BuildContext context, String slotId, Level initialLevel)
      openGameplayScreen;

  @override
  Widget build(BuildContext context) {
    if (levels.isEmpty) {
      return Center(
        child: Text('No levels in this track.', style: ConvoyTypography.body),
      );
    }

    // Unlocking is one continuous chain across the WHOLE track — Master
    // Context's per-slot rule doesn't reset or otherwise care about tier
    // boundaries, so this computation stays over the full linear `levels`
    // order exactly as before. Tier grouping below is purely a display
    // concern layered on top: it never reorders `levels`/`progress`/
    // `unlocked`, it just inserts a header where the tier changes.
    final progress = [
      for (final level in levels) progressStore.slotProgress(level.id),
    ];
    final unlocked = computeUnlockedSlots(progress);

    // Every level in a track shares one GameMode (Signal is its own
    // track, never mixed with Classic/Capacity) — Signal's node-count
    // range lives in its own table (Phase 2: "polynomial solve time
    // means it can scale node count more aggressively"); Classic and
    // Capacity share `classicCapacityNodeCount` (Phase 2 item 3:
    // Capacity's difficulty lever is its demand/capacity distribution,
    // not node count, so it reuses Classic's table rather than getting
    // its own). Single source of truth either way — nothing here
    // invents its own numbers.
    final nodeCountByTier = levels.first.mode == GameMode.signal
        ? signalNodeCount
        : classicCapacityNodeCount;

    final items = <Widget>[];
    DifficultyTier? lastTier;
    for (var i = 0; i < levels.length; i++) {
      final level = levels[i];
      if (level.difficultyTier != lastTier) {
        lastTier = level.difficultyTier;
        items.add(_TierHeader(
          tier: lastTier,
          nodeRange: nodeCountByTier[lastTier]!,
          timeLimitSeconds: timeLimitSecondsByTier[lastTier]!,
        ));
      }
      items.add(_SlotTile(
        level: level,
        slotNumber: i + 1,
        progress: progress[i],
        isUnlocked: unlocked[i],
        openGameplayScreen: openGameplayScreen,
      ));
    }

    return ListView(
      padding: const EdgeInsets.all(ConvoySpacing.lg),
      children: items,
    );
  }
}

/// Section header marking where a track's slots move into the next
/// [DifficultyTier] — reads its node-count range and time limit
/// straight from `generation/difficulty_tiers.dart` rather than
/// hardcoding a copy of those numbers here, so this can never drift
/// out of sync with what the generator actually builds levels to.
class _TierHeader extends StatelessWidget {
  const _TierHeader({
    required this.tier,
    required this.nodeRange,
    required this.timeLimitSeconds,
  });

  final DifficultyTier tier;
  final IntRange nodeRange;
  final int timeLimitSeconds;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: ConvoySpacing.md,
        bottom: ConvoySpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            tier.name.toUpperCase(),
            style: ConvoyTypography.sectionLabel,
          ),
          const SizedBox(width: ConvoySpacing.sm),
          Expanded(
            child: Container(height: 1, color: ConvoyColors.outline),
          ),
          const SizedBox(width: ConvoySpacing.sm),
          Text(
            '${nodeRange.min}\u2013${nodeRange.max} NODES \u00b7 '
            '${timeLimitSeconds}s',
            style: ConvoyTypography.monoLabel,
          ),
        ],
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.level,
    required this.slotNumber,
    required this.progress,
    required this.isUnlocked,
    required this.openGameplayScreen,
  });

  final Level level;
  final int slotNumber;
  final SlotProgress progress;
  final bool isUnlocked;
  final void Function(BuildContext context, String slotId, Level initialLevel)
      openGameplayScreen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ConvoySpacing.sm),
      child: Material(
        color: ConvoyColors.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isUnlocked
              ? () => openGameplayScreen(context, level.id, level)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(ConvoySpacing.md),
            child: Row(
              children: [
                Icon(
                  isUnlocked ? Icons.lock_open : Icons.lock,
                  color: isUnlocked
                      ? ConvoyColors.amber
                      : ConvoyColors.textSecondary,
                ),
                const SizedBox(width: ConvoySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SLOT $slotNumber',
                        style: ConvoyTypography.panelTitle
                            .copyWith(fontSize: 16),
                      ),
                      Text(
                        level.difficultyTier.name.toUpperCase(),
                        style: ConvoyTypography.monoLabel,
                      ),
                    ],
                  ),
                ),
                _StarBadge(outcome: progress.bestOutcome),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StarBadge extends StatelessWidget {
  const _StarBadge({required this.outcome});

  final SlotOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final starCount = switch (outcome) {
      SlotOutcome.none => 0,
      SlotOutcome.twoStar => 2,
      SlotOutcome.threeStar => 3,
    };
    if (starCount == 0) {
      return Text('-', style: ConvoyTypography.monoLabel);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < starCount; i++)
          Icon(Icons.star, color: ConvoyColors.amber, size: 16),
      ],
    );
  }
}
