// "How to play" / demo screen, reachable from a dedicated hub icon.
//
// Three tabs, one per mode. Each tab is a page-by-page wizard: a few
// short concept steps (one idea per page, each illustrated by a small
// live example graph — not a static image, the real LevelGraphView
// with a hand-picked tapped set, so the illustration uses the exact
// same rendering and colors as real gameplay), then a final page
// that's nothing but the practice graph, full-height, in guided-
// walkthrough mode from the moment it opens. A "TRY DEMO" button on
// every concept step (not just the last one) jumps straight there —
// a first-time player who'd rather learn by doing than read three
// steps of text never has to swipe through all of them first.
//
// Nothing on this whole screen ever touches ProgressStore: no coins
// spent or earned, no slot/progress writes, on the concept-step
// illustrations (which are entirely static, not even tappable) or on
// the practice page (whose own untimed, unpersisted GameplayController
// is exactly the one from the previous version of this screen).
//
// THE GUIDED WALKTHROUGH is a locked, one-node-at-a-time tutorial, not
// free play with hints: at every step exactly one node (from the
// level's curated optimal solution, computed live rather than
// hand-written per level) is highlighted and tappable-as-intended.
// - Before the tap: an assistant-style bubble names the node and
//   explains why it's the right move.
// - Tapping any OTHER node is rejected — it has no effect on the
//   board — and is met with a mode-specific "common mistake" bubble
//   explaining specifically why that node isn't it (already covered
//   by spillover/reachability? not part of the minimum solution?),
//   not a generic "try again."
// - Tapping the right node is accepted immediately, and a brief
//   "CORRECT" confirmation bubble explains what just happened (which
//   nodes got newly covered and why) before the highlight moves to
//   the next node in the solution.
// - This repeats until the example puzzle is solved, at which point
//   the normal outcome banner (3-star / 2-star) takes over as the
//   "this is what success looks like" payoff.
// It starts automatically the moment the practice page opens, instead
// of waiting for a "WALK ME THROUGH IT" tap; that button is still
// there (now doubling as "restart the walkthrough"), alongside RESET
// for dropping into free play on the same graph.
//
// Node/pipe visual-state mapping per mode is reimplemented here
// rather than imported, deliberately: those are private State methods
// on each real gameplay screen, and each of those screens already
// brings its own copy of this logic rather than sharing it (see
// classic_gameplay_screen.dart's own header comment: "Capacity/Signal
// reuse the first two pieces directly and bring their own... node-
// state computation"). This follows that established pattern rather
// than inventing a new shared abstraction just for this screen. They
// are written as pure functions of (graph, level, tapped set) rather
// than taking a GameplayController, which is also what lets the same
// functions render both the static concept-step illustrations (no
// controller at all, just a hand-picked tapped set) and the greedy
// walkthrough ordering (which simulates hypothetical tapped sets).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/level_providers.dart';
import '../../data/level_schema.dart';
import '../../design_system/design_system.dart';
import '../../engine/engine.dart';
import '../capacity/capacity_supply.dart';
import '../signal/signal_reachability.dart';
import 'gameplay_controller.dart';
import 'level_graph_view.dart';
import 'onboarding_overlay.dart';

typedef _NodeStatesBuilder = Map<String, NodeVisualState> Function(
    Graph graph,
    Level level,
    Set<String> tapped,
    );
typedef _PipeStatesBuilder = Map<String, PipeState> Function(
    Graph graph,
    Level level,
    Set<String> tapped,
    Map<String, NodeVisualState> nodeStates,
    );
typedef _ExplainStepBuilder = String Function(
    Graph graph,
    Level level,
    Set<String> tappedBefore,
    String nodeId,
    Set<String> newlySatisfiedIds,
    );

/// Explains why a WRONG node tap wasn't the right move — mode-specific,
/// so it can name the actual mode-specific reason ("already covered by
/// spillover", "nothing points to it", etc.) rather than a generic
/// "try again." [wrongNodeId] is the node the player tapped that the
/// guided walkthrough rejected; the currently-expected node stays
/// highlighted on screen, this text just explains the miss.
typedef _ExplainMistakeBuilder = String Function(
    Graph graph,
    Level level,
    Set<String> tapped,
    String wrongNodeId,
    );

/// The 1-based number LevelGraphView actually prints on a node, so
/// explanation text can say "tap node 3" and match what's on screen —
/// raw ids like "classic_small_014_n7" mean nothing to the player.
int _displayIndexOf(Level level, String nodeId) =>
    level.nodes.indexWhere((n) => n.id == nodeId) + 1;

List<int> _displayIndices(Level level, Iterable<String> ids) {
  final result = ids.map((id) => _displayIndexOf(level, id)).toList();
  result.sort();
  return result;
}

/// A throwaway [Level] used only to render a static illustration —
/// never solved, never scored, never fed to GameplayController.
/// optimum/exampleSolution/timeLimitSeconds are irrelevant here and
/// filled with placeholders; only nodes/edges/mode matter.
Level _illustrationLevel({
  required String id,
  required GameMode mode,
  required List<GraphNode> nodes,
  required List<GraphEdge> edges,
}) {
  return Level(
    id: id,
    mode: mode,
    difficultyTier: DifficultyTier.small,
    nodes: nodes,
    edges: edges,
    // Matches the empty exampleSolution below — Level's constructor
    // asserts exampleSolution.length == optimum, so these two can't
    // disagree even on a throwaway illustration level.
    optimum: 0,
    exampleSolution: const {},
    timeLimitSeconds: 1 << 20,
  );
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  static const routeName = '/demo';

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'HOW TO PLAY',
          style: ConvoyTypography.panelTitle.copyWith(fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: ConvoyColors.amber,
          unselectedLabelColor: ConvoyColors.textSecondary,
          indicatorColor: ConvoyColors.amber,
          tabs: const [
            Tab(text: 'CLASSIC'),
            Tab(text: 'CAPACITY'),
            Tab(text: 'SIGNAL'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ClassicDemoTab(),
          _CapacityDemoTab(),
          _SignalDemoTab(),
        ],
      ),
    );
  }
}

// ---- per-mode tabs: concept-step content, mode-specific node/pipe
// state + explanation logic, and the real curated track to practice
// on, all handed to the shared wizard shell below. ---------------------

class _ClassicDemoTab extends ConsumerWidget {
  const _ClassicDemoTab();

  static final _illustration = _illustrationLevel(
    id: 'demo_classic_illustration',
    mode: GameMode.classic,
    nodes: const [
      GraphNode(id: 'n1', position: GraphPoint(0, 120)),
      GraphNode(id: 'n2', position: GraphPoint(160, 120)),
      GraphNode(id: 'n3', position: GraphPoint(320, 120)),
      GraphNode(id: 'n4', position: GraphPoint(320, 280)),
    ],
    edges: const [
      GraphEdge('n1', 'n2'),
      GraphEdge('n2', 'n3'),
    ],
  );

  static final _nodeStatesOf = _classicNodeStates;
  static final _pipeStatesOf = _classicPipeStates;

  static final _steps = [
    _ConceptStep(
      title: 'Tanks & pipes',
      body: 'Every mode uses a network like this one, tanks connected by '
          'pipes. Right now nothing is supplied.',
      illustration: _illustration,
      tappedIds: const {},
    ),
    _ConceptStep(
      title: 'Tap to supply',
      body: 'Tap a tank to supply it. Supply spreads to every tank it\'s '
          'directly connected to, but no further than that.',
      illustration: _illustration,
      tappedIds: const {'n1'},
    ),
    _ConceptStep(
      title: 'Fewest taps wins',
      body: 'A tank two pipes away from a tap or not connected at all,'
          'stays unsupplied unless it gets a tap of its own. Goal: supply '
          'every tank using the fewest taps possible. Here, two taps cover '
          'all four.',
      illustration: _illustration,
      tappedIds: const {'n2', 'n4'},
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ModeWizard(
      steps: _steps,
      nodeIcon: Icons.storage,
      nodeStatesOf: _nodeStatesOf,
      pipeStatesOf: _pipeStatesOf,
      track: ref.watch(classicTrackProvider),
      content: OnboardingCopy.classic,
      explainStep: (graph, level, tappedBefore, nodeId, newlySatisfied) {
        final here = _displayIndexOf(level, nodeId);
        if (newlySatisfied.isEmpty) {
          return 'Tap node $here. Its neighbors are already covered by '
              'another tap in this solution, but node $here itself still '
              'needs a supply, so it has to be tapped directly.';
        }
        final labels = _displayIndices(level, newlySatisfied);
        final plural = labels.length == 1 ? '' : 's';
        return 'Tap node $here. It supplies itself and reaches '
            '${labels.length} more node$plural through its pipes,'
            'node$plural ${labels.join(', ')}.';
      },
      explainMistake: (graph, level, tapped, wrongNodeId) {
        final here = _displayIndexOf(level, wrongNodeId);
        final alreadySupplied =
            _classicNodeStates(graph, level, tapped)[wrongNodeId] ==
                NodeVisualState.supplied;
        if (alreadySupplied) {
          return 'Node $here is already supplied by an earlier tap,'
              'tapping it again would waste a tap. A common Classic '
              'mistake: retapping tanks that are already covered instead '
              'of the ones still empty.';
        }
        return 'Node $here isn\'t part of the fewest-taps solution here. '
            'A common Classic mistake is tapping a tank because it '
            'LOOKS central, instead of checking which still-empty tank '
            'the highlighted node actually covers.';
      },
    );
  }
}

class _CapacityDemoTab extends ConsumerWidget {
  const _CapacityDemoTab();

  static final _illustration = _illustrationLevel(
    id: 'demo_capacity_illustration',
    mode: GameMode.capacity,
    nodes: const [
      GraphNode(
        id: 'n1',
        position: GraphPoint(0, 120),
        capacity: 4,
        demand: 3,
      ),
      GraphNode(
        id: 'n2',
        position: GraphPoint(180, 120),
        capacity: 1,
        demand: 2,
      ),
      GraphNode(
        id: 'n3',
        position: GraphPoint(320, 260),
        capacity: 2,
        demand: 2,
      ),
    ],
    edges: const [
      GraphEdge('n1', 'n2'),
    ],
  );

  static final _nodeStatesOf = _capacityNodeStates;
  static final _pipeStatesOf = _capacityPipeStates;

  static final _steps = [
    _ConceptStep(
      title: 'Capacity & demand',
      body: 'Tanks here have a capacity and a demand. Supply must meet '
          'demand, just existing on the network isn\'t enough.',
      illustration: _illustration,
      tappedIds: const {},
    ),
    _ConceptStep(
      title: 'Spillover',
      body: 'Tap a tank: it gets its full capacity, and sends half of '
          'that to every tank it\'s directly connected to. That spillover '
          'alone can be enough to cover a neighbor\'s demand.',
      illustration: _illustration,
      tappedIds: const {'n1'},
    ),
    _ConceptStep(
      title: 'Fewest taps wins',
      body: 'If spillover isn\'t enough, or a tank isn\'t connected to '
          'anything tapped, it needs a tap of its own. Goal: meet every '
          'tank\'s demand with the fewest taps possible.',
      illustration: _illustration,
      tappedIds: const {'n1', 'n3'},
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ModeWizard(
      steps: _steps,
      nodeIcon: Icons.speed,
      nodeStatesOf: _nodeStatesOf,
      pipeStatesOf: _pipeStatesOf,
      track: ref.watch(capacityTrackProvider),
      content: OnboardingCopy.capacity,
      explainStep: (graph, level, tappedBefore, nodeId, newlySatisfied) {
        final here = _displayIndexOf(level, nodeId);
        if (newlySatisfied.isEmpty) {
          return 'Tap node $here. No other tapped node\'s spillover '
              'covers its demand, so it needs a direct tap of its own.';
        }
        final labels = _displayIndices(level, newlySatisfied);
        final plural = labels.length == 1 ? '' : 's';
        return 'Tap node $here. Its capacity, plus the 50% spillover it '
            'sends each neighbor, closes the demand gap on '
            'node$plural ${labels.join(', ')}.';
      },
      explainMistake: (graph, level, tapped, wrongNodeId) {
        final here = _displayIndexOf(level, wrongNodeId);
        final alreadyMet =
            _capacityNodeStates(graph, level, tapped)[wrongNodeId] ==
                NodeVisualState.supplied;
        if (alreadyMet) {
          return 'Node $here already has its demand met from spillover, '
              'tapping it directly would waste a tap. A common Capacity '
              'mistake: tapping tanks that don\'t need it instead of '
              'ones still short.';
        }
        return 'Node $here isn\'t the most efficient tap here. A common '
            'Capacity mistake is forgetting spillover is only HALF a '
            'tapped tank\'s capacity, distant tanks usually still need '
            'their own tap.';
      },
    );
  }
}

class _SignalDemoTab extends ConsumerWidget {
  const _SignalDemoTab();

  static final _illustration = _illustrationLevel(
    id: 'demo_signal_illustration',
    mode: GameMode.signal,
    nodes: const [
      GraphNode(id: 'n1', position: GraphPoint(0, 120)),
      GraphNode(id: 'n2', position: GraphPoint(160, 120)),
      GraphNode(id: 'n3', position: GraphPoint(320, 120)),
      GraphNode(id: 'n4', position: GraphPoint(320, 280)),
    ],
    edges: const [
      GraphEdge('n1', 'n2'),
      GraphEdge('n2', 'n3'),
    ],
  );

  static final _nodeStatesOf = _signalNodeStates;
  static final _pipeStatesOf = _signalPipeStates;

  static final _steps = [
    _ConceptStep(
      title: 'One-way pipes',
      body: 'Signal pipes only run one direction, the arrow matters. '
          'Nothing is under control yet.',
      illustration: _illustration,
      tappedIds: const {},
    ),
    _ConceptStep(
      title: 'Control spreads forward',
      body: 'Tap a tank to broadcast control forward along the arrows, '
          'through as many hops as the pipes allow, not just one.',
      illustration: _illustration,
      tappedIds: const {'n1'},
    ),
    _ConceptStep(
      title: 'Driver nodes',
      body: 'A tank nothing else points to can never be reached, it '
          'must be tapped directly. These are called driver nodes. Goal: '
          'control the whole grid with the fewest driver taps possible.',
      illustration: _illustration,
      tappedIds: const {'n1', 'n4'},
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ModeWizard(
      steps: _steps,
      nodeIcon: Icons.settings_input_antenna,
      nodeStatesOf: _nodeStatesOf,
      pipeStatesOf: _pipeStatesOf,
      track: ref.watch(signalTrackProvider),
      content: OnboardingCopy.signal,
      explainStep: (graph, level, tappedBefore, nodeId, newlySatisfied) {
        final here = _displayIndexOf(level, nodeId);
        if (newlySatisfied.isEmpty) {
          return 'Tap node $here. It\'s one of this level\'s minimum '
              'driver nodes, required for full control even though its '
              'reach overlaps with an earlier tap.';
        }
        final labels = _displayIndices(level, newlySatisfied);
        final plural = labels.length == 1 ? '' : 's';
        return 'Tap node $here. Signal now reaches node$plural '
            '${labels.join(', ')}, no other driver node in this '
            'solution can reach ${labels.length == 1 ? 'it' : 'them'}.';
      },
      explainMistake: (graph, level, tapped, wrongNodeId) {
        final here = _displayIndexOf(level, wrongNodeId);
        final alreadyReached =
            _signalNodeStates(graph, level, tapped)[wrongNodeId] ==
                NodeVisualState.supplied;
        if (alreadyReached) {
          return 'Node $here is already under control from an earlier '
              'tap, a common Signal mistake is re-tapping a reached '
              'tank instead of finding the next driver node.';
        }
        return 'Node $here isn\'t one of this level\'s minimum driver '
            'nodes. A common Signal mistake is tapping whatever LOOKS '
            'busiest, what actually matters is whether anything points '
            'TO it. Nodes nothing points to must be driven directly.';
      },
    );
  }
}

// ---- shared per-mode state-computation functions, factored out so
// both the static illustrations above and the live practice page use
// exactly the same rendering logic. -----------------------------------

Map<String, NodeVisualState> _classicNodeStates(
    Graph graph,
    Level level,
    Set<String> tapped,
    ) {
  final covered = <int>{};
  for (final id in tapped) {
    covered.addAll(graph.closedNeighborhood(graph.indexOf(id)));
  }
  return {
    for (final node in level.nodes)
      node.id: tapped.contains(node.id)
          ? NodeVisualState.tapped
          : covered.contains(graph.indexOf(node.id))
          ? NodeVisualState.supplied
          : NodeVisualState.decaying,
  };
}

Map<String, PipeState> _classicPipeStates(
    Graph graph,
    Level level,
    Set<String> tapped,
    Map<String, NodeVisualState> nodeStates,
    ) {
  final states = <String, PipeState>{};
  for (final edge in level.edges) {
    final fromState = nodeStates[edge.from];
    final toState = nodeStates[edge.to];
    final PipeState state;
    if (fromState == NodeVisualState.tapped ||
        toState == NodeVisualState.tapped) {
      state = PipeState.active;
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

Map<String, NodeVisualState> _capacityNodeStates(
    Graph graph,
    Level level,
    Set<String> tapped,
    ) {
  return {
    for (final node in level.nodes)
      node.id: tapped.contains(node.id)
          ? NodeVisualState.tapped
          : capacitySupplyOf(graph, tapped, node.id) >= node.demand - 1e-9
          ? NodeVisualState.supplied
          : NodeVisualState.decaying,
  };
}

Map<String, PipeState> _capacityPipeStates(
    Graph graph,
    Level level,
    Set<String> tapped,
    Map<String, NodeVisualState> nodeStates,
    ) {
  final states = <String, PipeState>{};
  for (final edge in level.edges) {
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

Map<String, NodeVisualState> _signalNodeStates(
    Graph graph,
    Level level,
    Set<String> tapped,
    ) {
  final reached = signalReachableFrom(graph, tapped);
  return {
    for (final node in level.nodes)
      node.id: tapped.contains(node.id)
          ? NodeVisualState.tapped
          : reached.contains(node.id)
          ? NodeVisualState.supplied
          : NodeVisualState.decaying,
  };
}

Map<String, PipeState> _signalPipeStates(
    Graph graph,
    Level level,
    Set<String> tapped,
    Map<String, NodeVisualState> nodeStates,
    ) {
  final reached = signalReachableFrom(graph, tapped);
  final states = <String, PipeState>{};
  for (final edge in level.edges) {
    states[LevelGraphView.edgeKey(edge)] =
    reached.contains(edge.from) ? PipeState.active : PipeState.inactive;
  }
  return states;
}

/// One page of the instructional wizard: a short idea plus a static,
/// hand-picked illustration of it. Never interactive, onNodeTap is a
/// no-op, this is purely "look at this," the practice page at the
/// end of the wizard is where the player actually taps anything.
class _ConceptStep {
  const _ConceptStep({
    required this.title,
    required this.body,
    required this.illustration,
    required this.tappedIds,
  });

  final String title;
  final String body;
  final Level illustration;
  final Set<String> tappedIds;
}

/// The page-by-page shell: [steps] first, then a final practice page
/// built from [track]'s easiest curated level. Back/Next arrows plus a
/// "STEP X OF Y" counter drive a [PageView]; the practice page starts
/// its own guided walkthrough automatically the moment it's reached.
class _ModeWizard extends StatefulWidget {
  const _ModeWizard({
    required this.steps,
    required this.nodeIcon,
    required this.nodeStatesOf,
    required this.pipeStatesOf,
    required this.track,
    required this.content,
    required this.explainStep,
    required this.explainMistake,
  });

  final List<_ConceptStep> steps;
  final IconData nodeIcon;
  final _NodeStatesBuilder nodeStatesOf;
  final _PipeStatesBuilder pipeStatesOf;
  final AsyncValue<List<Level>> track;
  final OnboardingContent content;
  final _ExplainStepBuilder explainStep;
  final _ExplainMistakeBuilder explainMistake;

  @override
  State<_ModeWizard> createState() => _ModeWizardState();
}

class _ModeWizardState extends State<_ModeWizard> {
  late final PageController _pageController;
  int _pageIndex = 0;

  bool get _onPracticePage => _pageIndex == widget.steps.length;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goNext() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _goBack() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  /// Jumps straight to the interactive practice page from ANY concept
  /// step — the "TRY DEMO" button on every step. A first-time player
  /// who already gets the idea shouldn't have to click NEXT through
  /// the remaining steps just to reach the part where they actually
  /// play; reading all the steps stays available via BACK/NEXT for
  /// anyone who wants it, but it's opt-in, not mandatory.
  void _startDemo() {
    _pageController.animateToPage(
      widget.steps.length,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _pageIndex = index),
            children: [
              for (final step in widget.steps)
                _ConceptStepView(
                  step: step,
                  nodeIcon: widget.nodeIcon,
                  nodeStatesOf: widget.nodeStatesOf,
                  pipeStatesOf: widget.pipeStatesOf,
                  accentColor: widget.content.accentColor,
                  onTryDemo: _startDemo,
                ),
              _TrackLoader(
                track: widget.track,
                builder: (demoLevel) => _PlayAlongCard(
                  content: widget.content,
                  demoLevel: demoLevel,
                  nodeIcon: widget.nodeIcon,
                  nodeStatesOf: widget.nodeStatesOf,
                  pipeStatesOf: widget.pipeStatesOf,
                  explainStep: widget.explainStep,
                  explainMistake: widget.explainMistake,
                  autoStartGuided: true,
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ConvoySpacing.md,
              vertical: ConvoySpacing.sm,
            ),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _pageIndex > 0 ? _goBack : null,
                  icon: const Icon(Icons.arrow_back_ios, size: 14),
                  label: const Text('BACK'),
                ),
                const Spacer(),
                Text(
                  _onPracticePage
                      ? 'PRACTICE'
                      : 'STEP ${_pageIndex + 1} OF ${widget.steps.length}',
                  style: ConvoyTypography.caption
                      .copyWith(color: ConvoyColors.textSecondary),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _onPracticePage ? null : _goNext,
                  icon: const Icon(Icons.arrow_forward_ios, size: 14),
                  label: const Text('NEXT'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A single instructional page: title, one short paragraph, and a
/// small static illustration below — the real LevelGraphView, sized
/// down, with a hand-picked tapped set and onNodeTap doing nothing.
class _ConceptStepView extends StatelessWidget {
  const _ConceptStepView({
    required this.step,
    required this.nodeIcon,
    required this.nodeStatesOf,
    required this.pipeStatesOf,
    required this.accentColor,
    required this.onTryDemo,
  });

  final _ConceptStep step;
  final IconData nodeIcon;
  final _NodeStatesBuilder nodeStatesOf;
  final _PipeStatesBuilder pipeStatesOf;
  final Color accentColor;

  /// Jumps straight to the interactive practice page — available from
  /// every step, not just the last one, so reading the concept steps
  /// is never a precondition for actually playing.
  final VoidCallback onTryDemo;

  @override
  Widget build(BuildContext context) {
    final graph = step.illustration.toGraph();
    final nodeStates = nodeStatesOf(graph, step.illustration, step.tappedIds);
    final pipeStates =
    pipeStatesOf(graph, step.illustration, step.tappedIds, nodeStates);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        ConvoySpacing.lg,
        ConvoySpacing.lg,
        ConvoySpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step.title, style: ConvoyTypography.panelTitle),
          const SizedBox(height: ConvoySpacing.sm),
          Text(step.body, style: ConvoyTypography.body),
          const SizedBox(height: ConvoySpacing.lg),
          SizedBox(
            height: 220,
            child: LevelGraphView(
              level: step.illustration,
              nodeIcon: nodeIcon,
              nodeStates: nodeStates,
              pipeStates: pipeStates,
              onNodeTap: (_) {},
            ),
          ),
          const SizedBox(height: ConvoySpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTryDemo,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: ConvoyColors.background,
                padding:
                const EdgeInsets.symmetric(vertical: ConvoySpacing.sm),
              ),
              icon: const Icon(Icons.play_circle_fill, size: 20),
              label: const Text('TRY DEMO'),
            ),
          ),
          const SizedBox(height: ConvoySpacing.md),
        ],
      ),
    );
  }
}

/// Common loading/empty/error handling for a track's [AsyncValue], so
/// the wizard only has to supply what's actually mode-specific.
class _TrackLoader extends StatelessWidget {
  const _TrackLoader({required this.track, required this.builder});

  final AsyncValue<List<Level>> track;
  final Widget Function(Level demoLevel) builder;

  @override
  Widget build(BuildContext context) {
    return track.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(
          'Could not load a demo level right now.',
          style: ConvoyTypography.body,
        ),
      ),
      data: (levels) {
        if (levels.isEmpty) {
          return Center(
            child:
            Text('No levels available yet.', style: ConvoyTypography.body),
          );
        }
        // Easiest curated level in the track — a demo should never
        // hand a first-time player the hardest thing in the mode.
        return builder(levels.first);
      },
    );
  }
}

/// The final wizard page: a live, tappable [LevelGraphView] wired to
/// its own untimed, unpersisted [GameplayController], in either
/// free-play or guided-walkthrough mode. Trimmed down from the
/// previous version of this screen — no repeated mode description or
/// full scoring card here, since the concept steps already covered
/// that; this page exists to let the graph actually be big.
class _PlayAlongCard extends StatefulWidget {
  const _PlayAlongCard({
    required this.content,
    required this.demoLevel,
    required this.nodeIcon,
    required this.nodeStatesOf,
    required this.pipeStatesOf,
    required this.explainStep,
    required this.explainMistake,
    this.autoStartGuided = false,
  });

  final OnboardingContent content;
  final Level demoLevel;
  final IconData nodeIcon;
  final _NodeStatesBuilder nodeStatesOf;
  final _PipeStatesBuilder pipeStatesOf;
  final _ExplainStepBuilder explainStep;
  final _ExplainMistakeBuilder explainMistake;
  final bool autoStartGuided;

  @override
  State<_PlayAlongCard> createState() => _PlayAlongCardState();
}

class _PlayAlongCardState extends State<_PlayAlongCard> {
  late GameplayController _controller;

  bool _guided = false;
  List<String> _guidedOrder = const [];
  int _guidedStep = 0;

  /// Non-null while a transient "CORRECT" or "NOT QUITE" bubble is
  /// showing in place of the normal instruction bubble — interaction
  /// stays locked (see [_handleNodeTap]) for its whole duration, same
  /// as the instruction bubble it temporarily replaces. Cleared by
  /// [_feedbackTimer] once its short display window elapses.
  String? _feedbackMessage;
  bool _feedbackIsMistake = false;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _controller = GameplayController(
      initialLevel: _practiceLevel(widget.demoLevel),
      slotId: 'demo_${widget.demoLevel.mode.name}',
    )..addListener(_onChanged);
    if (widget.autoStartGuided) {
      // Safe to set these directly (no setState) — this runs before
      // the first build, same as any other initState field setup.
      _guided = true;
      _guidedOrder = _computeGuidedOrder();
      _guidedStep = 0;
    }
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  /// Same graph, same optimum — just an effectively-unlimited time
  /// limit (~12 days) so a practice attempt can only end by running
  /// out of taps, never by the clock.
  Level _practiceLevel(Level source) {
    return Level(
      id: '${source.id}_demo',
      mode: source.mode,
      difficultyTier: source.difficultyTier,
      nodes: source.nodes,
      edges: source.edges,
      optimum: source.optimum,
      exampleSolution: source.exampleSolution,
      timeLimitSeconds: 1 << 20,
    );
  }

  void _reset() {
    _feedbackTimer?.cancel();
    _controller.retry(_practiceLevel(widget.demoLevel));
    setState(() {
      _guided = false;
      _guidedOrder = const [];
      _guidedStep = 0;
      _feedbackMessage = null;
    });
  }

  /// Greedy set-cover-style ordering over the level's curated
  /// [Level.exampleSolution]: at each step, whichever remaining
  /// solution node would newly satisfy the most still-unsatisfied
  /// nodes goes next. Ties break on node id for a deterministic,
  /// repeatable walkthrough. Pure simulation via widget.nodeStatesOf —
  /// no second live controller needed.
  List<String> _computeGuidedOrder() {
    final graph = _controller.graph;
    final level = _controller.level;
    final remaining = Set<String>.from(level.exampleSolution);
    var tapped = <String>{};
    final order = <String>[];
    while (remaining.isNotEmpty) {
      final beforeStates = widget.nodeStatesOf(graph, level, tapped);
      String? best;
      var bestGain = -1;
      for (final candidate in remaining) {
        final trialStates =
        widget.nodeStatesOf(graph, level, {...tapped, candidate});
        final gain = trialStates.entries
            .where((entry) =>
        entry.value == NodeVisualState.supplied &&
            beforeStates[entry.key] != NodeVisualState.supplied)
            .length;
        final better = best == null ||
            gain > bestGain ||
            (gain == bestGain && candidate.compareTo(best) < 0);
        if (better) {
          bestGain = gain;
          best = candidate;
        }
      }
      order.add(best!);
      tapped = {...tapped, best};
      remaining.remove(best);
    }
    return order;
  }

  Set<String> _newlySatisfied(Set<String> before, Set<String> after) {
    final graph = _controller.graph;
    final level = _controller.level;
    final beforeStates = widget.nodeStatesOf(graph, level, before);
    final afterStates = widget.nodeStatesOf(graph, level, after);
    return {
      for (final entry in afterStates.entries)
        if (entry.value == NodeVisualState.supplied &&
            beforeStates[entry.key] != NodeVisualState.supplied)
          entry.key,
    };
  }

  void _startGuided() {
    _feedbackTimer?.cancel();
    _controller.retry(_practiceLevel(widget.demoLevel));
    final order = _computeGuidedOrder();
    setState(() {
      _guided = true;
      _guidedOrder = order;
      _guidedStep = 0;
      _feedbackMessage = null;
    });
  }

  /// Locked, one-node-at-a-time tap handling for the guided
  /// walkthrough: only the currently-highlighted node has any effect.
  /// A wrong tap is rejected outright (the board doesn't change) and
  /// gets a mode-specific "why not" bubble; a right tap is applied
  /// immediately and gets a brief "correct" confirmation before the
  /// highlight advances. While either bubble is showing, taps are
  /// ignored entirely so the explanation has a moment to land instead
  /// of being interrupted by a fast double-tap.
  void _handleNodeTap(String nodeId) {
    if (!_controller.isPlaying) return;
    if (_guided) {
      if (_feedbackMessage != null) return;
      if (_guidedStep >= _guidedOrder.length) return;
      final expected = _guidedOrder[_guidedStep];
      if (nodeId != expected) {
        _showMistakeFeedback(nodeId);
        return;
      }
      final before = _controller.tappedNodeIds;
      final newlySatisfied = _newlySatisfied(before, {...before, nodeId});
      _controller.toggleNode(nodeId);
      _showCorrectFeedback(nodeId, newlySatisfied);
      return;
    }
    _controller.toggleNode(nodeId);
  }

  /// Applies immediately (the node IS tapped by the time this shows),
  /// then holds a "CORRECT" bubble explaining what just happened
  /// before moving the highlight to the next step — or, on the last
  /// step, dropping out of guided mode so the normal outcome banner
  /// takes over as the "here's what success looks like" payoff.
  void _showCorrectFeedback(String nodeId, Set<String> newlySatisfied) {
    final here = _displayIndexOf(_controller.level, nodeId);
    final message = newlySatisfied.isEmpty
        ? 'Correct! node $here tapped.'
        : 'Correct! Node $here is now supplied, and its reach covers '
        'node${newlySatisfied.length == 1 ? '' : 's'} '
        '${_displayIndices(_controller.level, newlySatisfied).join(', ')} '
        'too.';
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackMessage = message;
      _feedbackIsMistake = false;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        _feedbackMessage = null;
        _guidedStep++;
        if (_guidedStep >= _guidedOrder.length) {
          _guided = false;
        }
      });
    });
  }

  /// Rejects the tap outright (no toggle happens — the board is
  /// unchanged) and holds a mode-specific "why that's not it" bubble
  /// for a beat before returning control to the still-current step.
  void _showMistakeFeedback(String wrongNodeId) {
    final message = widget.explainMistake(
      _controller.graph,
      _controller.level,
      _controller.tappedNodeIds,
      wrongNodeId,
    );
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackMessage = message;
      _feedbackIsMistake = true;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _feedbackMessage = null);
    });
  }

  /// One shared assistant-style bubble shape for all three states
  /// (instruction / correct / mistake) — only the icon, accent color,
  /// short label, and message text differ, so it reads as the same
  /// "assistant talking to you" voice throughout the walkthrough
  /// rather than three visually different UI elements.
  Widget _buildFeedbackBubble({
    required IconData icon,
    required Color color,
    required String label,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        ConvoySpacing.lg,
        0,
        ConvoySpacing.lg,
        ConvoySpacing.xs,
      ),
      padding: const EdgeInsets.all(ConvoySpacing.md),
      decoration: BoxDecoration(
        color: ConvoyColors.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: ConvoySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: ConvoyTypography.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: ConvoyTypography.body.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final graph = _controller.graph;
    final level = _controller.level;
    final tapped = _controller.tappedNodeIds;
    final nodeStates = widget.nodeStatesOf(graph, level, tapped);
    final pipeStates = widget.pipeStatesOf(graph, level, tapped, nodeStates);
    final outcome = _controller.outcome;
    final isFail = outcome == GameplayOutcome.failTaps ||
        outcome == GameplayOutcome.failTime;
    final isPass = outcome == GameplayOutcome.threeStar ||
        outcome == GameplayOutcome.twoStar;

    final guidedActive = _guided && _guidedStep < _guidedOrder.length;
    final expectedNodeId = guidedActive ? _guidedOrder[_guidedStep] : null;

    // Bubble priority: a transient CORRECT/NOT QUITE feedback bubble
    // (from the tap that just happened) always wins over the forward-
    // looking instruction bubble, which in turn wins over the final
    // outcome banner — only one of the three shows at a time.
    String? highlightId;
    Widget? bubble;
    if (_feedbackMessage != null) {
      // Mid-mistake, the expected node stays highlighted so the
      // player still knows where to go once the bubble clears; mid-
      // confirmation the just-tapped node already reads as "tapped"
      // on the board, so no glow is needed.
      highlightId = _feedbackIsMistake ? expectedNodeId : null;
      bubble = _buildFeedbackBubble(
        icon: _feedbackIsMistake ? Icons.error_outline : Icons.check_circle,
        color: _feedbackIsMistake ? ConvoyColors.redDecay : widget.content.accentColor,
        label: _feedbackIsMistake ? 'NOT QUITE' : 'CORRECT',
        message: _feedbackMessage!,
      );
    } else if (guidedActive) {
      final nodeId = expectedNodeId!;
      highlightId = nodeId;
      final newlySatisfied = _newlySatisfied(tapped, {...tapped, nodeId});
      final explanation =
      widget.explainStep(graph, level, tapped, nodeId, newlySatisfied);
      bubble = _buildFeedbackBubble(
        icon: Icons.touch_app,
        color: widget.content.accentColor,
        label: 'TAP NODE ${_displayIndexOf(level, nodeId)}',
        message: explanation,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ConvoySpacing.lg,
            ConvoySpacing.md,
            ConvoySpacing.lg,
            ConvoySpacing.xs,
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            spacing: 8,
            children: [
              Text(
                'TAPS ${_controller.tapsUsed}/${_controller.maxTaps} '
                    '(OPT ${_controller.level.optimum})',
                style: ConvoyTypography.hudMedium,
              ),

              TextButton.icon(
                onPressed: _guided ? _reset : _startGuided,
                icon: Icon(
                  _guided
                      ? Icons.stop_circle_outlined
                      : Icons.auto_awesome,
                  size: 18,
                ),
                label: Text(
                  _guided ? 'STOP' : 'WALKTHROUGH',
                ),
              ),

              TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('RESET'),
              ),
            ],
          ),
        ),
        if (bubble != null)
          bubble
        else if (outcome != GameplayOutcome.playing)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ConvoySpacing.lg,
              0,
              ConvoySpacing.lg,
              ConvoySpacing.xs,
            ),
            child: Text(
              outcome == GameplayOutcome.threeStar
                  ? 'Solved with the fewest possible taps that\'s '
                  'exactly what success looks like here. 3-star clear!'
                  : outcome == GameplayOutcome.twoStar
                  ? 'Solved, one tap over optimal, a 2-star clear.'
                  : 'Out of taps. Hit RESET and try a different set of nodes.',
              style: ConvoyTypography.caption.copyWith(
                color: isFail
                    ? ConvoyColors.redDecay
                    : isPass
                    ? widget.content.accentColor
                    : ConvoyColors.textSecondary,
              ),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(ConvoySpacing.sm),
            child: LevelGraphView(
              level: _controller.level,
              nodeIcon: widget.nodeIcon,
              nodeStates: nodeStates,
              pipeStates: pipeStates,
              highlightedNodeId: highlightId,
              onNodeTap: _handleNodeTap,
            ),
          ),
        ),
      ],
    );
  }
}