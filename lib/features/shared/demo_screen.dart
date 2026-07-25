// "How to play" / demo screen, reachable from a dedicated hub icon.
//
// Three tabs, one per mode. Each tab is now a page-by-page wizard
// rather than one scrolling paragraph-plus-cramped-graph screen:
// a few short concept steps (one idea per page, each illustrated by
// a small live example graph — not a static image, the real
// LevelGraphView with a hand-picked tapped set, so the illustration
// uses the exact same rendering and colors as real gameplay), then a
// final page that's nothing but the practice graph, full-height, in
// guided-walkthrough mode from the moment it opens.
//
// Nothing on this whole screen ever touches ProgressStore: no coins
// spent or earned, no slot/progress writes, on the concept-step
// illustrations (which are entirely static, not even tappable) or on
// the practice page (whose own untimed, unpersisted GameplayController
// is exactly the one from the previous version of this screen).
//
// The guided walkthrough itself — highlighting one node from the
// level's curated optimal solution at a time, explaining why each one
// matters, computed live rather than hand-written per level — is
// unchanged from before. The only difference is it now starts
// automatically the moment the practice page opens, instead of
// waiting for a "WALK ME THROUGH IT" tap; that button is still there
// (now doubling as "restart the walkthrough"), alongside RESET for
// dropping into free play on the same graph.
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
    optimum: 1,
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
      body: 'Every mode uses a network like this one — tanks connected by '
          'pipes. Right now nothing is supplied.',
      illustration: _illustration,
      tappedIds: const {},
    ),
    _ConceptStep(
      title: 'Tap to supply',
      body: 'Tap a tank to supply it. Supply spreads to every tank it\'s '
          'directly connected to — but no further than that.',
      illustration: _illustration,
      tappedIds: const {'n1'},
    ),
    _ConceptStep(
      title: 'Fewest taps wins',
      body: 'A tank two pipes away from a tap — or not connected at all — '
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
              'needs a supply — so it has to be tapped directly.';
        }
        final labels = _displayIndices(level, newlySatisfied);
        final plural = labels.length == 1 ? '' : 's';
        return 'Tap node $here. It supplies itself and reaches '
            '${labels.length} more node$plural through its pipes — '
            'node$plural ${labels.join(', ')}.';
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
          'demand — just existing on the network isn\'t enough.',
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
      body: 'If spillover isn\'t enough — or a tank isn\'t connected to '
          'anything tapped — it needs a tap of its own. Goal: meet every '
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
      body: 'Signal pipes only run one direction — the arrow matters. '
          'Nothing is under control yet.',
      illustration: _illustration,
      tappedIds: const {},
    ),
    _ConceptStep(
      title: 'Control spreads forward',
      body: 'Tap a tank to broadcast control forward along the arrows — '
          'through as many hops as the pipes allow, not just one.',
      illustration: _illustration,
      tappedIds: const {'n1'},
    ),
    _ConceptStep(
      title: 'Driver nodes',
      body: 'A tank nothing else points to can never be reached — it '
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
              'driver nodes — required for full control even though its '
              'reach overlaps with an earlier tap.';
        }
        final labels = _displayIndices(level, newlySatisfied);
        final plural = labels.length == 1 ? '' : 's';
        return 'Tap node $here. Signal now reaches node$plural '
            '${labels.join(', ')} — no other driver node in this '
            'solution can reach ${labels.length == 1 ? 'it' : 'them'}.';
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
/// hand-picked illustration of it. Never interactive — onNodeTap is a
/// no-op — this is purely "look at this," the practice page at the
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
  });

  final List<_ConceptStep> steps;
  final IconData nodeIcon;
  final _NodeStatesBuilder nodeStatesOf;
  final _PipeStatesBuilder pipeStatesOf;
  final AsyncValue<List<Level>> track;
  final OnboardingContent content;
  final _ExplainStepBuilder explainStep;

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
  });

  final _ConceptStep step;
  final IconData nodeIcon;
  final _NodeStatesBuilder nodeStatesOf;
  final _PipeStatesBuilder pipeStatesOf;

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
            height: 240,
            child: LevelGraphView(
              level: step.illustration,
              nodeIcon: nodeIcon,
              nodeStates: nodeStates,
              pipeStates: pipeStates,
              onNodeTap: (_) {},
            ),
          ),
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
    this.autoStartGuided = false,
  });

  final OnboardingContent content;
  final Level demoLevel;
  final IconData nodeIcon;
  final _NodeStatesBuilder nodeStatesOf;
  final _PipeStatesBuilder pipeStatesOf;
  final _ExplainStepBuilder explainStep;
  final bool autoStartGuided;

  @override
  State<_PlayAlongCard> createState() => _PlayAlongCardState();
}

class _PlayAlongCardState extends State<_PlayAlongCard> {
  late GameplayController _controller;

  bool _guided = false;
  List<String> _guidedOrder = const [];
  int _guidedStep = 0;

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
    _controller.retry(_practiceLevel(widget.demoLevel));
    setState(() {
      _guided = false;
      _guidedOrder = const [];
      _guidedStep = 0;
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
    _controller.retry(_practiceLevel(widget.demoLevel));
    final order = _computeGuidedOrder();
    setState(() {
      _guided = true;
      _guidedOrder = order;
      _guidedStep = 0;
    });
  }

  void _handleNodeTap(String nodeId) {
    if (!_controller.isPlaying) return;
    if (_guided) {
      if (_guidedStep >= _guidedOrder.length) return;
      final expected = _guidedOrder[_guidedStep];
      if (nodeId != expected) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Try the highlighted node first.'),
              duration: Duration(seconds: 1),
            ),
          );
        return;
      }
      _controller.toggleNode(nodeId);
      setState(() {
        _guidedStep++;
        if (_guidedStep >= _guidedOrder.length) {
          // Walkthrough finished — fall back to the normal pass
          // banner below instead of staying in "guided" framing.
          _guided = false;
        }
      });
      return;
    }
    _controller.toggleNode(nodeId);
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
    String? highlightId;
    String? guidedExplanation;
    if (guidedActive) {
      final nodeId = _guidedOrder[_guidedStep];
      highlightId = nodeId;
      final newlySatisfied = _newlySatisfied(tapped, {...tapped, nodeId});
      guidedExplanation =
          widget.explainStep(graph, level, tapped, nodeId, newlySatisfied);
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
          child: Row(
            children: [
              Text(
                'TAPS ${_controller.tapsUsed} / ${_controller.maxTaps} '
                    '(OPTIMAL ${_controller.level.optimum})',
                style: ConvoyTypography.hudMedium,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _guided ? _reset : _startGuided,
                icon: Icon(
                  _guided ? Icons.stop_circle_outlined : Icons.auto_awesome,
                  size: 18,
                ),
                label: Text(_guided ? 'STOP' : 'WALK ME THROUGH IT'),
              ),
              TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('RESET'),
              ),
            ],
          ),
        ),
        if (guidedExplanation != null)
          Container(
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
              border: Border.all(color: widget.content.accentColor, width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.touch_app, size: 18, color: widget.content.accentColor),
                const SizedBox(width: ConvoySpacing.sm),
                Expanded(
                  child: Text(
                    guidedExplanation,
                    style: ConvoyTypography.body
                        .copyWith(color: widget.content.accentColor),
                  ),
                ),
              ],
            ),
          )
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
                  ? 'Optimal! That\'s a 3-star clear.'
                  : outcome == GameplayOutcome.twoStar
                  ? 'Solved, one tap over optimal — a 2-star clear.'
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