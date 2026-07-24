// Capacity gameplay — Phase 4. Follows classic_gameplay_screen.dart's
// structure closely on purpose: same GameplayController (unmodified),
// same LevelGraphView (extended in Phase 4 with an optional
// nodeBuilder override, used here to swap in CapacityNodeGauge), same
// outcome-dialog/hint/retry plumbing. Everything that differs is
// genuinely mode-specific: node/pipe visual-state computation (supply
// thresholds via capacity_supply.dart instead of coverage), the hint
// engine (capacity_hint_engine.dart's two-part hint instead of
// classic_hint_engine.dart's single suggestion), and the gauge
// rendering itself.
//
// Nothing here reimplements win-check, star outcomes, retry, the
// timer, or coin awarding — GameplayController's isFullySatisfied
// already dispatches to CapacitySolver.verify() via the engine's own
// verifyWin(graph, mode, taps), because [Level.mode] is
// [GameMode.capacity] for these levels. That dispatch was built once,
// generically, in Phase 3 — this screen doesn't touch it.
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
import '../../design_system/design_system.dart';
import '../../engine/engine.dart';
import '../shared/coin_economy.dart';
import '../shared/gameplay_controller.dart';
import '../shared/gameplay_notifications.dart';
import '../shared/level_graph_view.dart';
import '../shared/onboarding_overlay.dart';
import '../shared/outcome_dialog.dart';
import 'capacity_hint_engine.dart';
import 'capacity_node_gauge.dart';
import 'capacity_supply.dart';

class CapacityGameplayScreen extends ConsumerStatefulWidget {
  const CapacityGameplayScreen({
    super.key,
    required this.slotId,
    required this.initialLevel,
  });

  /// Stable slot identity for progress tracking — see
  /// GameplayController's doc comment. Always the curated level's own
  /// id (see capacity_level_select_screen.dart).
  final String slotId;
  final Level initialLevel;

  @override
  ConsumerState<CapacityGameplayScreen> createState() =>
      _CapacityGameplayScreenState();
}

class _CapacityGameplayScreenState
    extends ConsumerState<CapacityGameplayScreen> {
  late final GameplayController _controller;
  late final ConfettiController _confettiController;
  GameplayOutcome _lastHandledOutcome = GameplayOutcome.playing;
  bool _handlingOutcome = false;
  String? _mostUnderSuppliedNodeId;
  String? _suggestedTapNodeId;
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
      final show = await shouldShowOnboarding(ref, GameMode.capacity);
      if (show && mounted) setState(() => _showOnboarding = true);
    });
  }

  Future<void> _dismissOnboarding() async {
    setState(() => _showOnboarding = false);
    final progressStore = await ref.read(progressStoreProvider.future);
    await progressStore.markOnboardingSeen(GameMode.capacity);
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

  // ---- outcome handling — same shape as Classic's, same shared
  // controller/state machine driving it ------------------------------

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
        final track = await ref.read(capacityTrackProvider.future);
        if (!mounted) return;
        final masteryUnlock = await checkTrackMastery(
          progressStore,
          track,
          AchievementId.capacityMastery,
        );
        // Efficiency is checked against the EXACT tap set that just
        // won — [_controller.tappedNodeIds] still holds it here,
        // since nothing mutates it between the win firing and this
        // handler running.
        Achievement? efficiencyUnlock;
        if (isCapacityClearEfficient(
          _controller.graph,
          _controller.tappedNodeIds,
        )) {
          efficiencyUnlock = await unlockIfNew(
            progressStore,
            AchievementId.capacityEfficient,
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
              '${achievementSuffix(efficiencyUnlock)}',
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
              : 'NOT ENOUGH COINS ($unlockCost)',
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
              : 'NOT ENOUGH COINS ($replaySameLayoutCost)',
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
              : 'NOT ENOUGH COINS ($replaySameLayoutCost)',
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

  /// The slot immediately after this one in the Capacity track's slot
  /// order, if any — null for the last slot.
  Level? _findNextLevel(List<Level> track) {
    final index = track.indexWhere((level) => level.id == widget.slotId);
    if (index == -1 || index + 1 >= track.length) return null;
    return track[index + 1];
  }

  void _openLevel(Level level) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => CapacityGameplayScreen(
          slotId: level.id,
          initialLevel: level,
        ),
      ),
    );
  }

  /// Same non-popping behavior as Classic's — see that file's doc
  /// comment for why this must not also close this screen.
  void _retryNewLayout() {
    final loader = ref.read(levelLoaderProvider);
    final fresh = loader.generateNewLevelSameDifficulty(
      mode: GameMode.capacity,
      tier: _controller.level.difficultyTier,
    );
    _lastHandledOutcome = GameplayOutcome.playing;
    setState(() {
      _mostUnderSuppliedNodeId = null;
      _suggestedTapNodeId = null;
    });
    _controller.retry(fresh);
  }

  /// Resets taps/timer/outcome but keeps the EXACT same graph the
  /// player just attempted — the paid alternative to
  /// [_retryNewLayout] above.
  void _retrySameLayout() {
    _lastHandledOutcome = GameplayOutcome.playing;
    setState(() {
      _mostUnderSuppliedNodeId = null;
      _suggestedTapNodeId = null;
    });
    _controller.retry(_controller.level);
  }

  // ---- hints — same free-allotment/paid-topup MECHANISM as Classic
  // (GameplayController.useFreeHint / freeHintsRemaining, untouched);
  // only the CONTENT of the hint is Capacity-specific -----------------

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
    final hint = computeCapacityHint(
      graph: _controller.graph,
      exampleSolution: _controller.level.exampleSolution,
      tappedNodeIds: _controller.tappedNodeIds,
    );
    setState(() {
      _mostUnderSuppliedNodeId = hint.mostUnderSuppliedNodeId;
      _suggestedTapNodeId = hint.suggestedTapNodeId;
    });
  }

  // ---- visual state computation (Capacity-specific: supply vs demand,
  // not coverage) --------------------------------------------------------

  Map<String, NodeVisualState> _nodeStates() {
    final tapped = _controller.tappedNodeIds;
    final graph = _controller.graph;
    return {
      for (final node in _controller.level.nodes)
        node.id: tapped.contains(node.id)
            ? NodeVisualState.tapped
            : capacitySupplyOf(graph, tapped, node.id) >= node.demand - 1e-9
                ? NodeVisualState.supplied
                : NodeVisualState.decaying,
    };
  }

  /// Every cross-node contribution in Capacity IS the 0.5x spillover
  /// mechanic by definition (a node's OWN capacity never travels along
  /// a pipe — only the half-strength contribution to neighbors does),
  /// so a pipe touching a tapped node always reads [PipeState.spillover]
  /// here, never [PipeState.active] — that state stays Classic's,
  /// where a pipe really does carry full-strength coverage.
  Map<String, PipeState> _pipeStates(Map<String, NodeVisualState> nodeStates) {
    final states = <String, PipeState>{};
    for (final edge in _controller.level.edges) {
      final fromState = nodeStates[edge.from];
      final toState = nodeStates[edge.to];
      final PipeState state;
      if (fromState == NodeVisualState.tapped ||
          toState == NodeVisualState.tapped) {
        state = PipeState.spillover;
      } else if (fromState == NodeVisualState.decaying ||
          toState == NodeVisualState.decaying) {
        state = PipeState.decaying;
      } else {
        state = PipeState.inactive;
      }
      states[LevelGraphView.edgeKey(edge)] = state;
    }
    return states;
  }

  // ---- build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final nodeStates = _nodeStates();
    final pipeStates = _pipeStates(nodeStates);
    final minutes = _controller.remainingSeconds ~/ 60;
    final seconds = (_controller.remainingSeconds % 60).floor();
    final timeLow = _controller.remainingSeconds <
        _controller.level.timeLimitSeconds * 0.2;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CAPACITY: ${_controller.level.difficultyTier.name.toUpperCase()}',
          style: ConvoyTypography.panelTitle.copyWith(fontSize: 16),
        ),
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
              Expanded(
                child: LevelGraphView(
                  level: _controller.level,
                  // unused when nodeBuilder is supplied — CapacityNodeGauge
                  // hardcodes its own gauge/dial glyph instead.
                  nodeIcon: Icons.speed,
                  nodeStates: nodeStates,
                  pipeStates: pipeStates,
                  onNodeTap: _controller.isPlaying
                      ? (nodeId) {
                          setState(() {
                            _mostUnderSuppliedNodeId = null;
                            _suggestedTapNodeId = null;
                          });
                          _controller.toggleNode(nodeId);
                        }
                      : (_) {},
                  nodeBuilder: (node, displayIndex, state, onTap) {
                    final supply = capacitySupplyOf(
                      _controller.graph,
                      _controller.tappedNodeIds,
                      node.id,
                    );
                    return _CapacityNodeWithHints(
                      supply: supply,
                      demand: node.demand,
                      state: state,
                      onTap: onTap,
                      isMostUnderSupplied: node.id == _mostUnderSuppliedNodeId,
                      isSuggestedTap: node.id == _suggestedTapNodeId,
                    );
                  },
                ),
              ),
            ],
          ),
          if (_showOnboarding)
            OnboardingOverlay(
              content: OnboardingCopy.capacity,
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

/// Wraps [CapacityNodeGauge] with Phase 4 item 4's two-part hint
/// decoration: a pulsing red ring for the most under-supplied node, a
/// pulsing (subtler, thinner) cyan ring for the suggested tap — both
/// can apply to the same node at once (concentric, different
/// diameters) if the fix for the worst node IS itself the suggestion.
///
/// CENTERING: [LevelGraphView] anchors every node at
/// `(graphX - 32, graphY - 32)`, i.e. it assumes a 64x64 box. This
/// widget's actual content (gauge ring + hint rings) is wider than
/// that, so it reports a plain 64x64 [SizedBox] to the layout system
/// (matching what LevelGraphView expects) and positions every visual
/// element with NEGATIVE offsets relative to that nominal box's
/// center, via [Clip.none]. Get this arithmetic wrong and the gauge
/// visibly drifts from where the pipes actually connect — worth
/// spelling out explicitly rather than trusting Stack's `alignment`
/// to happen to do the right thing, since the gauge's own label text
/// breaks that assumption (see the diameter constants below).
class _CapacityNodeWithHints extends StatelessWidget {
  const _CapacityNodeWithHints({
    required this.supply,
    required this.demand,
    required this.state,
    required this.onTap,
    required this.isMostUnderSupplied,
    required this.isSuggestedTap,
  });

  final double supply;
  final double demand;
  final NodeVisualState state;
  final VoidCallback onTap;
  final bool isMostUnderSupplied;
  final bool isSuggestedTap;

  /// Matches LevelGraphView's own node-anchor box exactly — do not
  /// change this without also updating LevelGraphView's assumption.
  static const double _anchorBox = 64;

  static const double _baseDiameter = 64;
  // Must match CapacityNodeGauge's own _ringExtra constant.
  static const double _ringDiameter = _baseDiameter + 14;

  /// Top-left offset (from the anchor box's center) to center an
  /// element of the given diameter on that same center point.
  static double _centeringOffset(double diameter) =>
      (_anchorBox / 2) - (diameter / 2);

  @override
  Widget build(BuildContext context) {
    final underSuppliedRingDiameter = _ringDiameter + 16;
    final suggestedRingDiameter = _ringDiameter + 4;

    return SizedBox(
      width: _anchorBox,
      height: _anchorBox,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isMostUnderSupplied)
            Positioned(
              left: _centeringOffset(underSuppliedRingDiameter),
              top: _centeringOffset(underSuppliedRingDiameter),
              child: _PulsingRing(
                diameter: underSuppliedRingDiameter,
                color: ConvoyColors.redDecay,
              ),
            ),
          if (isSuggestedTap)
            Positioned(
              left: _centeringOffset(suggestedRingDiameter),
              top: _centeringOffset(suggestedRingDiameter),
              child: _PulsingRing(
                diameter: suggestedRingDiameter,
                color: ConvoyColors.cyan,
                strokeWidth: 2,
              ),
            ),
          Positioned(
            // CapacityNodeGauge's own top-left IS its ring's top-left
            // (the ring is the first element in its internal Column),
            // so centering it the same way as the pulsing rings above
            // correctly centers the RING specifically — the label
            // text below it just hangs into the overflow space
            // beneath, same as ConvoyNode's label always has.
            left: _centeringOffset(_ringDiameter),
            top: _centeringOffset(_ringDiameter),
            child: CapacityNodeGauge(
              supply: supply,
              demand: demand,
              state: state,
              diameter: _baseDiameter,
              onTap: onTap,
            ),
          ),
        ],
      ),
    );
  }
}

/// A repeating opacity pulse on a plain ring — Phase 4's "subtler"
/// treatment for hint indicators, distinct from the static glow
/// Classic's single hint uses (classic_gameplay_screen.dart /
/// level_graph_view.dart's `highlightedNodeId`).
class _PulsingRing extends StatefulWidget {
  const _PulsingRing({
    required this.diameter,
    required this.color,
    this.strokeWidth = 3,
  });

  final double diameter;
  final Color color;
  final double strokeWidth;

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = 0.3 + 0.5 * _controller.value;
        return Container(
          width: widget.diameter,
          height: widget.diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color.withValues(alpha: opacity),
              width: widget.strokeWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: opacity * 0.6),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}
