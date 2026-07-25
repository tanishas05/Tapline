// The first fully playable screen — Phase 3. Wires GameplayController
// (shared, mode-agnostic) + LevelGraphView (shared, presentational) +
// classic_hint_engine.dart (Classic-specific) together for Classic
// specifically. Capacity/Signal (Phase 4/5) reuse the first two
// pieces directly and bring their own hint engine and node-state
// computation, following this file as the template.
//
// Phase 6 outcome-screen pass: real star icons + confetti on a
// 3-star, a direct "NEXT LEVEL" jump instead of only popping back to
// level select, and a free replay-with-a-new-graph option on EVERY
// outcome (3-star, 2-star, and fail alike) — a 2-star is a pass, so
// it must never be more expensive to try again than a fail is. Only
// same-layout replay (a near-guaranteed 3-star "safe bet") stays
// paid, on both the 2-star and fail paths (see coin_economy.dart's
// replaySameLayoutCost).
// NOTE: retrySameLayout below intentionally reuses the exact level
// the player just attempted — this reverses an earlier "NEVER reuse
// the exact layout just attempted" rule that used to apply to every
// retry path uniformly; it's now deliberately offered as a paid
// option instead of forbidden outright.

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
import '../shared/coin_economy.dart';
import '../shared/gameplay_controller.dart';
import '../shared/gameplay_notifications.dart';
import '../shared/level_graph_view.dart';
import '../shared/onboarding_overlay.dart';
import '../shared/outcome_dialog.dart';
import 'classic_hint_engine.dart';

class ClassicGameplayScreen extends ConsumerStatefulWidget {
  const ClassicGameplayScreen({
    super.key,
    required this.slotId,
    required this.initialLevel,
  });

  /// Stable slot identity for progress tracking — see
  /// GameplayController's doc comment. For Phase 3, always the
  /// curated level's own id (see classic_level_select_screen.dart).
  final String slotId;
  final Level initialLevel;

  @override
  ConsumerState<ClassicGameplayScreen> createState() =>
      _ClassicGameplayScreenState();
}

class _ClassicGameplayScreenState extends ConsumerState<ClassicGameplayScreen> {
  late final GameplayController _controller;
  late final ConfettiController _confettiController;
  GameplayOutcome _lastHandledOutcome = GameplayOutcome.playing;
  bool _handlingOutcome = false;
  String? _hintedNodeId;
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
    // Phase 6 item 4: shown once, ever, per track — see
    // gameplay_notifications.dart's doc comment on why this is a
    // post-frame callback rather than an eager check in initState
    // itself (the read is async; nothing should setState before the
    // first frame has actually built).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final show = await shouldShowOnboarding(ref, GameMode.classic);
      if (show && mounted) setState(() => _showOnboarding = true);
    });
  }

  Future<void> _dismissOnboarding() async {
    setState(() => _showOnboarding = false);
    final progressStore = await ref.read(progressStoreProvider.future);
    await progressStore.markOnboardingSeen(GameMode.classic);
  }

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

  // ---- outcome handling -----------------------------------------------

  Future<void> _handleOutcome(GameplayOutcome outcome) async {
    _handlingOutcome = true;
    final progressStore = await ref.read(progressStoreProvider.future);
    if (!mounted) return;

    switch (outcome) {
      case GameplayOutcome.threeStar:
        final payout = coinPayoutByTier[_controller.level.difficultyTier]!;
        await progressStore.recordOutcome(widget.slotId, SlotOutcome.threeStar);
        await progressStore.addCoins(payout);
        if (!mounted) return;
        final track = await ref.read(classicTrackProvider.future);
        if (!mounted) return;
        final unlocked = await checkTrackMastery(
          progressStore,
          track,
          AchievementId.classicMastery,
        );
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
              'The next slot is unlocked.${achievementSuffix(unlocked)}',
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
        await _handleTwoStarOutcome(progressStore);
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

  Future<void> _handleTwoStarOutcome(ProgressStore progressStore) async {
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
      body: 'One tap over optimum, no coins this time.\n\n'
          'Balance: ${progressStore.coinBalance} coins',
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

  /// Spends [cost] then runs [action] — shared by every PAID
  /// replay/retry path above so the "deduct, then hand off to the
  /// same retry logic the free path already uses" sequence isn't
  /// repeated inline at each call site.
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

  /// The slot immediately after this one in the Classic track's slot
  /// order, if any — null for the last slot. Used by both the 3-star
  /// "NEXT LEVEL" jump and the fail path's paid "SKIP TO NEXT LEVEL."
  Level? _findNextLevel(List<Level> track) {
    final index = track.indexWhere((level) => level.id == widget.slotId);
    if (index == -1 || index + 1 >= track.length) return null;
    return track[index + 1];
  }

  /// Swaps this screen for a gameplay screen on [level] — used for
  /// both "NEXT LEVEL" and "SKIP TO NEXT LEVEL." pushReplacement
  /// rather than push: the level just finished shouldn't stay on the
  /// back stack under the new one, so the system back button from the
  /// next level returns to level select, not to the already-cleared
  /// level.
  void _openLevel(Level level) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ClassicGameplayScreen(
          slotId: level.id,
          initialLevel: level,
        ),
      ),
    );
  }

  /// Regenerates a fresh layout at the same slot/tier and keeps
  /// playing right here. Deliberately does NOT pop this screen: the
  /// outcome dialog that triggered this already dismisses itself (see
  /// outcome_dialog.dart), and retrying means staying on THIS screen
  /// with the new layout, not leaving it — unlike the 3-star/pay-
  /// past-2-star/skip paths, which navigate away on purpose.
  void _retryNewLayout() {
    final loader = ref.read(levelLoaderProvider);
    final fresh = loader.generateNewLevelSameDifficulty(
      mode: GameMode.classic,
      tier: _controller.level.difficultyTier,
    );
    _lastHandledOutcome = GameplayOutcome.playing;
    setState(() => _hintedNodeId = null);
    _controller.retry(fresh);
  }

  /// Resets taps/timer/outcome but keeps the EXACT same graph the
  /// player just attempted — the paid alternative to
  /// [_retryNewLayout] above, offered on a 2-star or a fail.
  void _retrySameLayout() {
    _lastHandledOutcome = GameplayOutcome.playing;
    setState(() => _hintedNodeId = null);
    _controller.retry(_controller.level);
  }

  // ---- hints ------------------------------------------------------------

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
    final hint = nextClassicHint(
      graph: _controller.graph,
      exampleSolution: _controller.level.exampleSolution,
      tappedNodeIds: _controller.tappedNodeIds,
    );
    setState(() => _hintedNodeId = hint);
  }

  // ---- visual state computation (Classic-specific coverage) -------------

  Map<String, NodeVisualState> _nodeStates() {
    final tapped = _controller.tappedNodeIds;
    final graph = _controller.graph;
    final covered = <int>{};
    for (final id in tapped) {
      covered.addAll(graph.closedNeighborhood(graph.indexOf(id)));
    }
    return {
      for (final node in _controller.level.nodes)
        node.id: tapped.contains(node.id)
            ? NodeVisualState.tapped
            : covered.contains(graph.indexOf(node.id))
                ? NodeVisualState.supplied
                : NodeVisualState.inactive,
    };
  }

  Map<String, PipeState> _pipeStates(Map<String, NodeVisualState> nodeStates) {
    final states = <String, PipeState>{};
    for (final edge in _controller.level.edges) {
      final fromState = nodeStates[edge.from];
      final toState = nodeStates[edge.to];
      final PipeState state;
      if (fromState == NodeVisualState.tapped ||
          toState == NodeVisualState.tapped) {
        state = PipeState.active;
      } else {
        state = PipeState.inactive;
      }
      states[LevelGraphView.edgeKey(edge)] = state;
    }
    return states;
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final nodeStates = _nodeStates();
    final pipeStates = _pipeStates(nodeStates);
    final minutes = _controller.remainingSeconds ~/ 60;
    final seconds = (_controller.remainingSeconds % 60).floor();
    final timeLow = _controller.remainingSeconds <
        _controller.level.timeLimitSeconds * 0.2;

    final themeModeController = ref.watch(themeModeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CLASSIC: ${_controller.level.difficultyTier.name.toUpperCase()}',
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
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ConvoySpacing.lg,
                  vertical: ConvoySpacing.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TAPS ${_controller.tapsUsed} / ${_controller.maxTaps}',
                          style: ConvoyTypography.hudMedium,
                        ),
                        Text(
                          'OPTIMAL: ${_controller.level.optimum}',
                          style: ConvoyTypography.caption,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '${minutes.toString().padLeft(2, '0')}:'
                      '${seconds.toString().padLeft(2, '0')}',
                      style: ConvoyTypography.hudMedium.copyWith(
                        color: timeLow
                            ? ConvoyColors.redDecay
                            : ConvoyColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Hint '
                          '(${_controller.freeHintsRemaining} free left)',
                      icon: const Icon(Icons.lightbulb_outline),
                      color: ConvoyColors.amber,
                      onPressed: _controller.isPlaying ? _onHintPressed : null,
                    ),
                  ],
                ),
              ),
              // Small bulb-and-wire flourish — same visual language as
              // the hub banner — filling the gap between the header
              // and the graph rather than leaving it bare.
              SizedBox(
                height: 56,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final center = Offset(w / 2, 40);
                    final ends = [
                      Offset(w * 0.15, 12),
                      Offset(w * 0.85, 12),
                    ];
                    return Stack(
                      children: [
                        for (final end in ends)
                          ConvoyPipe(
                            start: center,
                            end: end,
                            state: PipeState.active,
                            curvature: 0.15,
                            baseStrokeWidth: 2,
                          ),
                        Positioned(
                          left: center.dx - 14,
                          top: center.dy - 14,
                          child: Icon(
                            Icons.lightbulb,
                            color: ConvoyColors.amber,
                            size: 28,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Expanded(
                child: LevelGraphView(
                  level: _controller.level,
                  nodeIcon: Icons.propane_tank,
                  nodeStates: nodeStates,
                  pipeStates: pipeStates,
                  highlightedNodeId: _hintedNodeId,
                  onNodeTap: _controller.isPlaying
                      ? (nodeId) {
                          setState(() => _hintedNodeId = null);
                          _controller.toggleNode(nodeId);
                        }
                      : (_) {},
                ),
              ),
            ],
          ),
          if (_showOnboarding)
            OnboardingOverlay(
              content: OnboardingCopy.classic,
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