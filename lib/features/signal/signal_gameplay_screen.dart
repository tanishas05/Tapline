// Signal gameplay — Phase 5. Follows classic_gameplay_screen.dart's
// structure closely — Signal's visual needs turned out closer to
// Classic's than Capacity's (a single hint highlight via
// LevelGraphView's existing highlightedNodeId, standard tapped/
// supplied/decaying node mapping) rather than needing a custom
// nodeBuilder the way Capacity's gauge did.
//
// Nothing here reimplements win-check, star outcomes, retry, the
// timer, or coin awarding — GameplayController's isFullySatisfied
// already dispatches to signal_solver.dart's verify() (reachability
// from the selected driver set) via the engine's own
// verifyWin(graph, mode, taps), because a Signal Level's mode is
// GameMode.signal. That generic dispatch was built once in Phase 3;
// this screen doesn't touch it, same as Capacity didn't in Phase 4.
//
// Phase 6 outcome-screen pass: same shape as classic_gameplay_screen.dart's
// (real star icons + confetti, NEXT LEVEL jump, free new-graph replay
// on 3-star, paid same-layout replay on 2-star/fail) — see that
// file's doc comment for the full reasoning; not repeated here.

import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/achievements.dart';
import '../../data/level_providers.dart';
import '../../data/level_schema.dart';
import '../../data/progress_providers.dart';
import '../../data/progress_store.dart';
import '../../data/slot_progress.dart';
import '../../data/theme_mode_controller.dart';
import '../../design_system/design_system.dart';
import '../../engine/engine.dart';
import '../shared/coin_badge.dart';
import '../shared/coin_economy.dart';
import '../shared/gameplay_controller.dart';
import '../shared/gameplay_notifications.dart';
import '../shared/haptics.dart';
import '../shared/sound.dart';
import '../shared/hint_button.dart';
import '../shared/level_graph_view.dart';
import '../shared/onboarding_overlay.dart';
import '../shared/outcome_dialog.dart';
import 'signal_hint_engine.dart';
import 'signal_reachability.dart';

class SignalGameplayScreen extends ConsumerStatefulWidget {
  const SignalGameplayScreen({
    super.key,
    required this.slotId,
    required this.initialLevel,
  });

  /// Stable slot identity for progress tracking — see
  /// GameplayController's doc comment. Always the curated level's own
  /// id (see signal_level_select_screen.dart).
  final String slotId;
  final Level initialLevel;

  @override
  ConsumerState<SignalGameplayScreen> createState() =>
      _SignalGameplayScreenState();
}

class _SignalGameplayScreenState extends ConsumerState<SignalGameplayScreen> {
  late final GameplayController _controller;
  late final ConfettiController _confettiController;
  GameplayOutcome _lastHandledOutcome = GameplayOutcome.playing;
  bool _handlingOutcome = false;
  String? _hintedNodeId;
  bool _densityCalloutDismissed = false;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _controller = GameplayController(
      initialLevel: widget.initialLevel,
      slotId: widget.slotId,
    )..addListener(_onControllerChanged);
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final show = await shouldShowOnboarding(ref, GameMode.signal);
      if (show && mounted) setState(() => _showOnboarding = true);
    });
  }

  Future<void> _dismissOnboarding() async {
    setState(() => _showOnboarding = false);
    final progressStore = await ref.read(progressStoreProvider.future);
    await progressStore.markOnboardingSeen(GameMode.signal);
  }

  /// Phase 6's "MORE PIPES, FEWER DRIVERS" achievement — any winning
  /// outcome (2-star or 3-star both count; the point is experiencing
  /// the mechanic, not perfect play) on one of the curated
  /// `_teach_dense` levels, same id convention [build] already uses
  /// for the inline [_DensityCallout].
  bool get _isDensityTeachingLevel =>
      _controller.level.id.contains('_teach_dense');

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
    final outcome = _controller.outcome;
    if (outcome != GameplayOutcome.playing &&
        outcome != _lastHandledOutcome &&
        !_handlingOutcome) {
      _lastHandledOutcome = outcome;
      _handleOutcome(outcome);
    }
  }

  // ---- outcome handling — same shape as Classic's/Capacity's, same
  // shared controller/state machine driving it -------------------

  Future<void> _handleOutcome(GameplayOutcome outcome) async {
    _handlingOutcome = true;
    final progressStore = await ref.read(progressStoreProvider.future);
    if (!mounted) return;

    if (outcome == GameplayOutcome.threeStar) {
      hapticSuccess(progressStore);
      soundSuccess(progressStore);
    } else if (outcome == GameplayOutcome.twoStar) {
      hapticFailure(progressStore);
      soundFailure(progressStore);
    } else if (outcome == GameplayOutcome.failTaps ||
        outcome == GameplayOutcome.failTime) {
      hapticFailure(progressStore);
      soundFailure(progressStore);
    }

    switch (outcome) {
      case GameplayOutcome.threeStar:
        final payout = coinPayoutByTier[_controller.level.difficultyTier]!;
        await progressStore.recordOutcome(widget.slotId, SlotOutcome.threeStar);
        await progressStore.addCoins(payout);
        if (!mounted) return;
        final track = await ref.read(signalTrackProvider.future);
        if (!mounted) return;
        final masteryUnlock = await checkTrackMastery(
          progressStore,
          track,
          AchievementId.signalMastery,
        );
        Achievement? densityUnlock;
        if (_isDensityTeachingLevel) {
          densityUnlock = await unlockIfNew(
            progressStore,
            AchievementId.signalDensityAha,
          );
        }
        if (!mounted) return;
        ref.invalidate(progressStoreProvider);
        _confettiController.play();
        final nextLevel = _findNextLevel(track);
        await showOutcomeDialog(
          context: context,
          starCount: 3,
          title: '3 STARS',
          accent: ConvoyColors.amber,
          body: 'Exact optimum: $payout coins earned. '
              'The next slot is unlocked.'
              '${achievementSuffix(masteryUnlock)}'
              '${achievementSuffix(densityUnlock)}',
          actions: [
            if (nextLevel != null)
              OutcomeDialogAction(
                'NEXT LEVEL',
                () => _openLevel(nextLevel),
                primary: true,
              ),
            OutcomeDialogAction('REPLAY (NEW GRAPH)', _retryNewLayout),
            OutcomeDialogAction(
              'LEVEL SELECT',
              () => Navigator.of(context).pop(),
            ),
          ],
        );
        break;
      case GameplayOutcome.twoStar:
        await progressStore.recordOutcome(widget.slotId, SlotOutcome.twoStar);
        if (!mounted) return;
        Achievement? twoStarDensityUnlock;
        if (_isDensityTeachingLevel) {
          twoStarDensityUnlock = await unlockIfNew(
            progressStore,
            AchievementId.signalDensityAha,
          );
        }
        if (!mounted) return;
        await _handleTwoStarOutcome(progressStore, twoStarDensityUnlock);
        break;
      case GameplayOutcome.failTaps:
        if (!mounted) return;
        await _handleFailOutcome(progressStore, title: 'OUT OF TAPS');
        break;
      case GameplayOutcome.failTime:
        if (!mounted) return;
        await _handleFailOutcome(progressStore, title: "TIME'S UP");
        break;
      case GameplayOutcome.playing:
        break;
    }
    _handlingOutcome = false;
  }

  Future<void> _handleTwoStarOutcome(
    ProgressStore progressStore,
    Achievement? densityUnlock,
  ) async {
    final unlockCost =
        unlockPastTwoStarCostByTier[_controller.level.difficultyTier]!;
    final canAffordUnlock = progressStore.coinBalance >= unlockCost;
    final canAffordSameLayout =
        progressStore.coinBalance >= replaySameLayoutCost;
    await showOutcomeDialog(
      context: context,
      starCount: 2,
      title: '2 STARS',
      accent: ConvoyColors.textPrimary,
      body: 'One driver over optimum, no coins this time.\n\n'
          'Balance: ${progressStore.coinBalance} coins'
          '${achievementSuffix(densityUnlock)}',
      actions: [
        OutcomeDialogAction(
          canAffordUnlock
              ? 'UNLOCK NEXT LEVEL ($unlockCost coins)'
              : 'UNLOCK NEXT LEVEL — NEED $unlockCost COINS',
          canAffordUnlock
              ? () async {
                  await progressStore.spendCoins(unlockCost);
                  await progressStore.markPaidPast(widget.slotId);
                  ref.invalidate(progressStoreProvider);
                  if (mounted) Navigator.of(context).pop();
                }
              : null,
          primary: true,
        ),
        OutcomeDialogAction(
          'REPLAY (NEW GRAPH)',
          _retryNewLayout,
        ),
        OutcomeDialogAction(
          canAffordSameLayout
              ? 'REPLAY (SAME GRAPH, $replaySameLayoutCost coins)'
              : 'REPLAY (SAME GRAPH) — NEED $replaySameLayoutCost COINS',
          canAffordSameLayout
              ? () =>
                  _spendThen(progressStore, replaySameLayoutCost, _retrySameLayout)
              : null,
        ),
      ],
    );
  }

  Future<void> _handleFailOutcome(
    ProgressStore progressStore, {
    required String title,
  }) async {
    final canAffordSameLayout =
        progressStore.coinBalance >= replaySameLayoutCost;
    await showOutcomeDialog(
      context: context,
      title: title,
      accent: ConvoyColors.redDecay,
      body: 'That attempt is done. Try a fresh layout at the same '
          'difficulty, or pay to try again a different way.\n\n'
          'Balance: ${progressStore.coinBalance} coins',
      actions: [
        OutcomeDialogAction(
          'RETRY (NEW GRAPH)',
          _retryNewLayout,
          primary: true,
        ),
        OutcomeDialogAction(
          canAffordSameLayout
              ? 'RETRY (SAME GRAPH, $replaySameLayoutCost coins)'
              : 'RETRY (SAME GRAPH) — NEED $replaySameLayoutCost COINS',
          canAffordSameLayout
              ? () =>
                  _spendThen(progressStore, replaySameLayoutCost, _retrySameLayout)
              : null,
        ),
      ],
    );
  }

  Future<void> _spendThen(
    ProgressStore progressStore,
    int cost,
    VoidCallback action,
  ) async {
    final spent = await progressStore.spendCoins(cost);
    if (!spent) return;
    ref.invalidate(progressStoreProvider);
    action();
  }

  /// The slot immediately after this one in the Signal track's slot
  /// order, if any — null for the last slot.
  Level? _findNextLevel(List<Level> track) {
    final index = track.indexWhere((level) => level.id == widget.slotId);
    if (index == -1 || index + 1 >= track.length) return null;
    return track[index + 1];
  }

  void _openLevel(Level level) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => SignalGameplayScreen(
          slotId: level.id,
          initialLevel: level,
        ),
      ),
    );
  }

  /// Same non-popping behavior as Classic's/Capacity's — see
  /// classic_gameplay_screen.dart's doc comment for why this must not
  /// also close this screen.
  void _retryNewLayout() {
    final loader = ref.read(levelLoaderProvider);
    final fresh = loader.generateNewLevelSameDifficulty(
      mode: GameMode.signal,
      tier: _controller.level.difficultyTier,
    );
    _lastHandledOutcome = GameplayOutcome.playing;
    setState(() {
      _hintedNodeId = null;
      _densityCalloutDismissed = false;
    });
    _controller.retry(fresh);
  }

  /// Resets taps/timer/outcome but keeps the EXACT same graph the
  /// player just attempted — the paid alternative to
  /// [_retryNewLayout] above.
  void _retrySameLayout() {
    _lastHandledOutcome = GameplayOutcome.playing;
    setState(() => _hintedNodeId = null);
    _controller.retry(_controller.level);
  }

  // ---- hints — same free-allotment/paid-topup mechanism as the other
  // two modes; only the CONTENT is Signal-specific ---------------------

  Future<void> _onHintPressed() async {
    if (_controller.freeHintsRemaining > 0) {
      _controller.useFreeHint();
      _revealHint();
      return;
    }
    final progressStore = await ref.read(progressStoreProvider.future);
    if (!mounted) return;
    final cost = hintCoinCost;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ConvoyColors.surface,
        title: Text('USE A HINT?', style: ConvoyTypography.panelTitle),
        content: Text(
          'Free hints used up for this layout. $cost coins for one '
          'more.\n\nBalance: ${progressStore.coinBalance} coins',
          style: ConvoyTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('CANCEL', style: ConvoyTypography.buttonLabel),
          ),
          TextButton(
            onPressed: progressStore.coinBalance >= cost
                ? () => Navigator.of(context).pop(true)
                : null,
            child: Text(
              progressStore.coinBalance >= cost
                  ? 'PAY $cost'
                  : 'NOT ENOUGH COINS',
              style: ConvoyTypography.buttonLabel,
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await progressStore.spendCoins(cost);
      _revealHint();
    }
  }

  void _revealHint() {
    final hint = nextSignalHint(
      graph: _controller.graph,
      exampleSolution: _controller.level.exampleSolution,
      tappedNodeIds: _controller.tappedNodeIds,
    );
    setState(() => _hintedNodeId = hint);
  }

  // ---- visual state computation (Signal-specific: reachability from
  // drivers, not coverage or supply) --------------------------------

  Map<String, NodeVisualState> _nodeStates(Set<String> reached) {
    final tapped = _controller.tappedNodeIds;
    return {
      for (final node in _controller.level.nodes)
        node.id: tapped.contains(node.id)
            ? NodeVisualState.tapped
            : reached.contains(node.id)
                ? NodeVisualState.supplied
                : NodeVisualState.inactive,
    };
  }

  /// Directed edges only ever have two readings here, not three: an
  /// edge is [PipeState.active] if its SOURCE is under control (it's
  /// actively carrying reachability forward — and by definition of
  /// forward reachability, its destination is then automatically
  /// under control too), or [PipeState.inactive] otherwise. There's
  /// no natural "decaying" case for a directed edge the way an
  /// undirected pipe touching an unsupplied node has one in Classic/
  /// Capacity — a source that isn't reachable simply isn't carrying
  /// anything, regardless of whether the destination happens to be
  /// reachable via some OTHER edge.
  Map<String, PipeState> _pipeStates(Set<String> reached) {
    final states = <String, PipeState>{};
    for (final edge in _controller.level.edges) {
      states[LevelGraphView.edgeKey(edge)] =
          reached.contains(edge.from) ? PipeState.active : PipeState.inactive;
    }
    return states;
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final reached = signalReachableFrom(
      _controller.graph,
      _controller.tappedNodeIds,
    );
    final nodeStates = _nodeStates(reached);
    final pipeStates = _pipeStates(reached);
    final minutes = _controller.remainingSeconds ~/ 60;
    final seconds = (_controller.remainingSeconds % 60).floor();
    final timeLow = _controller.remainingSeconds <
        _controller.level.timeLimitSeconds * 0.2;

    final themeModeController = ref.watch(themeModeControllerProvider);
    final progressStore = ref.watch(progressStoreProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SIGNAL: ${_controller.level.difficultyTier.name.toUpperCase()}',
          style: ConvoyTypography.panelTitle.copyWith(fontSize: 16),
        ),
        actions: [
          Builder(
            builder: (context) {
              final platformBrightness = MediaQuery.platformBrightnessOf(context);
              final isDark = themeModeController.isDark(platformBrightness);
              return IconButton(
                tooltip: isDark ? 'Light mode' : 'Dark mode',
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => themeModeController.toggle(platformBrightness),
              );
            },
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        fit: StackFit.expand,
        children: [
          const BlueprintGrid(),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ConvoySpacing.lg,
                  vertical: ConvoySpacing.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'DRIVERS ${_controller.tapsUsed} / ${_controller.maxTaps}',
                              style: ConvoyTypography.hudMedium,
                            ),
                            Text(
                              'OPTIMAL: ${_controller.level.optimum}',
                              style: ConvoyTypography.caption,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          '${minutes.toString().padLeft(2, '0')}:'
                          '${seconds.toString().padLeft(2, '0')}',
                          style: ConvoyTypography.hudMedium.copyWith(
                            color: timeLow
                                ? ConvoyColors.redDecay
                                : ConvoyColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: progressStore != null
                            ? CoinBadge(balance: progressStore.coinBalance)
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isDensityTeachingLevel && !_densityCalloutDismissed)
                _DensityCallout(
                  onDismiss: () =>
                      setState(() => _densityCalloutDismissed = true),
                ),
              Expanded(
                child: LevelGraphView(
                  level: _controller.level,
                  nodeIcon: Icons.settings_input_antenna,
                  nodeStates: nodeStates,
                  pipeStates: pipeStates,
                  highlightedNodeId: _hintedNodeId,
                  onNodeTap: _controller.isPlaying
                      ? (nodeId) {
                          setState(() => _hintedNodeId = null);
                          hapticNodeTap(ref.read(progressStoreProvider).value);
                          soundNodeTap(ref.read(progressStoreProvider).value);
                          _controller.toggleNode(nodeId);
                        }
                      : (_) {},
                ),
              ),
              // Bottom bar: hint only, centered — timer moved up into
              // the top HUD row (see above) per feedback, so this bar
              // now just anchors the hint action below the graph.
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ConvoySpacing.lg,
                    vertical: ConvoySpacing.sm,
                  ),
                  child: Center(
                    child: HintButton(
                      freeHintsRemaining: _controller.freeHintsRemaining,
                      hintCoinCost: hintCoinCost,
                      enabled: _controller.isPlaying,
                      onPressed: _onHintPressed,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_showOnboarding)
            OnboardingOverlay(
              content: OnboardingCopy.signal,
              onDismiss: _dismissOnboarding,
            ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: math.pi / 2, // downward, "raining" from the top
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 40,
            emissionFrequency: 0.05,
            gravity: 0.3,
            colors: [
              ConvoyColors.amber,
              ConvoyColors.cyan,
              ConvoyColors.redDecay,
              ConvoyColors.textPrimary,
            ],
          ),
        ],
      ),
    );
  }
}

/// Phase 5 item 4's "surface the density aha moment" — deliberately a
/// dismissible inline banner, not a dialog: the brief specifically
/// asks for "a short, non-intrusive callout, not a modal lecture."
class _DensityCallout extends StatelessWidget {
  const _DensityCallout({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        ConvoySpacing.lg,
        0,
        ConvoySpacing.lg,
        ConvoySpacing.sm,
      ),
      padding: const EdgeInsets.all(ConvoySpacing.sm),
      decoration: BoxDecoration(
        color: ConvoyColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ConvoyColors.cyan),
      ),
      child: Row(
        children: [
          Icon(Icons.insights, color: ConvoyColors.cyan, size: 18),
          const SizedBox(width: ConvoySpacing.sm),
          Expanded(
            child: Text(
              'Denser than it looks sparse, but needs FEWER drivers. '
              'More connections can mean fewer taps.',
              style: ConvoyTypography.caption,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            color: ConvoyColors.textSecondary,
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}