// Settings screen — Phase 6 item 5. Sound, haptics, reset progress.
//
// Reads/writes directly through [ProgressStore] (see progress_store.dart's
// new "settings" and "reset" sections) rather than introducing a
// separate settings provider/controller — there's exactly one
// read-then-write action per row here, no local draft state that
// needs to diverge from persisted state before a "save" button, so a
// thin ConsumerWidget calling straight through to the store is the
// right amount of machinery, not a shortcut.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/progress_providers.dart';
import '../../data/progress_store.dart';
import '../../design_system/design_system.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const routeName = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(progressStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: Stack(
        children: [
          const BlueprintGrid(),
          SafeArea(
            child: progressAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'Could not load settings.\n$error',
                  style: ConvoyTypography.body,
                  textAlign: TextAlign.center,
                ),
              ),
              data: (store) => _SettingsBody(store: store),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.store});

  final ProgressStore store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(ConvoySpacing.lg),
      children: [
        Text('AUDIO & FEEDBACK', style: ConvoyTypography.sectionLabel),
        const SizedBox(height: ConvoySpacing.md),
        _SettingsToggleTile(
          title: 'SOUND',
          subtitle: 'Tap and win/fail sound effects.',
          icon: Icons.volume_up,
          value: store.soundEnabled,
          onChanged: (value) async {
            await store.setSoundEnabled(value);
            ref.invalidate(progressStoreProvider);
          },
        ),
        const SizedBox(height: ConvoySpacing.sm),
        _SettingsToggleTile(
          title: 'HAPTICS',
          subtitle: 'Vibration feedback on tap and on level-complete.',
          icon: Icons.vibration,
          value: store.hapticsEnabled,
          onChanged: (value) async {
            await store.setHapticsEnabled(value);
            ref.invalidate(progressStoreProvider);
          },
        ),
        const SizedBox(height: ConvoySpacing.xl),
        Text('PROGRESS', style: ConvoyTypography.sectionLabel),
        const SizedBox(height: ConvoySpacing.md),
        _ResetProgressTile(store: store, ref: ref),
      ],
    );
  }
}

class _SettingsToggleTile extends StatelessWidget {
  const _SettingsToggleTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ConvoySpacing.md),
      decoration: BoxDecoration(
        color: ConvoyColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ConvoyColors.outline),
      ),
      child: Row(
        children: [
          Icon(icon, color: ConvoyColors.amber),
          const SizedBox(width: ConvoySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ConvoyTypography.panelTitle.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: ConvoyTypography.caption),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: ConvoyColors.amber,
          ),
        ],
      ),
    );
  }
}

class _ResetProgressTile extends StatelessWidget {
  const _ResetProgressTile({required this.store, required this.ref});

  final ProgressStore store;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ConvoySpacing.md),
      decoration: BoxDecoration(
        color: ConvoyColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ConvoyColors.redDecay),
      ),
      child: Row(
        children: [
          Icon(Icons.restart_alt, color: ConvoyColors.redDecay),
          const SizedBox(width: ConvoySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RESET PROGRESS',
                  style: ConvoyTypography.panelTitle.copyWith(
                    fontSize: 15,
                    color: ConvoyColors.redDecay,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Clears every track\'s stars, unlocks, coins, and '
                  'achievements. Cannot be undone.',
                  style: ConvoyTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: ConvoySpacing.sm),
          TextButton(
            onPressed: () => _confirmReset(context),
            style: TextButton.styleFrom(foregroundColor: ConvoyColors.redDecay),
            child: const Text('RESET'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ConvoyColors.surface,
        title: const Text('RESET ALL PROGRESS?'),
        content: Text(
          'This clears stars, unlocks, coins, and achievements across '
          'all three tracks. This cannot be undone.',
          style: ConvoyTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: ConvoyColors.redDecay),
            child: const Text('RESET'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await store.resetAllProgress();
      ref.invalidate(progressStoreProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress reset.')),
        );
      }
    }
  }
}
