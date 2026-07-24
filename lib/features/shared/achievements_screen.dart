// Achievements screen — Phase 6 item 3's UI half. The catalog itself
// and the cross-track "is this track mastered" logic live in
// achievements.dart (pure, testable); this file is just rendering
// [ProgressStore.unlockedAchievementIds] against
// [achievementCatalog] — no evaluation logic belongs here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/achievements.dart';
import '../../data/progress_providers.dart';
import '../../design_system/design_system.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  static const routeName = '/achievements';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(progressStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ACHIEVEMENTS')),
      body: Stack(
        children: [
          const BlueprintGrid(),
          SafeArea(
            child: progressAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'Could not load achievements.\n$error',
                  style: ConvoyTypography.body,
                  textAlign: TextAlign.center,
                ),
              ),
              data: (store) {
                final unlockedIds = store.unlockedAchievementIds;
                final achievements = achievementCatalog.values.toList();
                return ListView.builder(
                  padding: const EdgeInsets.all(ConvoySpacing.lg),
                  itemCount: achievements.length,
                  itemBuilder: (context, index) {
                    final achievement = achievements[index];
                    final unlocked =
                        unlockedIds.contains(achievement.id.name);
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: ConvoySpacing.sm),
                      child: _AchievementTile(
                        achievement: achievement,
                        unlocked: unlocked,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.unlocked});

  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final accent = unlocked ? ConvoyColors.amber : ConvoyColors.textDisabled;
    return Container(
      padding: const EdgeInsets.all(ConvoySpacing.md),
      decoration: BoxDecoration(
        color: ConvoyColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: unlocked ? ConvoyColors.amber : ConvoyColors.outline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ConvoyColors.surfaceElevated,
              border: Border.all(color: accent, width: 2),
            ),
            child: Icon(
              unlocked ? Icons.emoji_events : Icons.lock,
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(width: ConvoySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: ConvoyTypography.panelTitle.copyWith(
                    fontSize: 15,
                    color: unlocked
                        ? ConvoyColors.textPrimary
                        : ConvoyColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(achievement.description, style: ConvoyTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
