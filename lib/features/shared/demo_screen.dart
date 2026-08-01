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

  // The PDF guide's exact worked example: one tank in the middle,
  // connected to four separate outer tanks; the outer tanks are NOT
  // connected to each other, only to the middle one.
  static final _illustration = _illustrationLevel(
    id: 'demo_classic_illustration',
    mode: GameMode.classic,
    nodes: const [
      GraphNode(id: 'nMiddle', position: GraphPoint(160, 180)),
      GraphNode(id: 'nTop', position: GraphPoint(160, 20)),
      GraphNode(id: 'nRight', position: GraphPoint(320, 180)),
      GraphNode(id: 'nBottom', position: GraphPoint(160, 340)),
      GraphNode(id: 'nLeft', position: GraphPoint(0, 180)),
    ],
    edges: const [
      GraphEdge('nMiddle', 'nTop'),
      GraphEdge('nMiddle', 'nRight'),
      GraphEdge('nMiddle', 'nBottom'),
      GraphEdge('nMiddle', 'nLeft'),
    ],
  );

  static final _nodeStatesOf = _classicNodeStates;
  static final _pipeStatesOf = _classicPipeStates;

  static final _steps = [
    _ConceptStep(
      title: 'Taps, stars & fails',
      body: 'Tap a point to activate it; tap the same point again to undo '
          'that tap, as long as you\'re still within the tap limit. Every '
          'level shows an OPTIMAL number of taps at the top: finish using '
          'exactly that many for 3 stars, or one more than that for 2 '
          'stars. An attempt fails if you go more than one tap over '
          'optimal without finishing, or if the countdown timer runs out '
          'first. These rules are the same in every mode; only what '
          'counts as "finished" changes from here.',
      illustration: _illustration,
      tappedIds: const {},
    ),
    _ConceptStep(
      title: 'The idea',
      body: 'Picture every point on the board as a tank, joined to some '
          'other tanks by pipes. Tapping a tank turns its supply ON. The '
          'moment a tank\'s supply is on, that supply automatically flows '
          'out through every pipe connected to it. So a single tap '
          'supplies TWO things: the tank you tapped AND every tank '
          'directly connected to it by one pipe. A level is finished once '
          'every tank on the board has supply, either because you tapped '
          'it or because it sits directly next to one you did tap. Your '
          'goal is to cover the whole board using as few taps as '
          'possible.',
      illustration: _illustration,
      tappedIds: const {},
    ),
    _ConceptStep(
      title: 'Worked example: tap the middle',
      body: 'Imagine five tanks arranged like a plus sign: one tank in the '
          'middle, connected to four separate tanks around it (the four '
          'outer tanks are not connected to each other, only to the '
          'middle one), just like the board below. Tap the MIDDLE tank: '
          'supply reaches the middle tank itself, plus all four outer '
          'tanks (each is directly connected to it). All five tanks are '
          'supplied in just one tap.',
      illustration: _illustration,
      tappedIds: const {'nMiddle'},
    ),
    _ConceptStep(
      title: 'Worked example: tap an outer tank',
      body: 'Tap an OUTER tank instead: supply reaches that outer tank and '
          'the middle tank only (its one connection). The other three '
          'outer tanks are still unsupplied; you would need at least one '
          'more tap to finish, and probably several.',
      illustration: _illustration,
      tappedIds: const {'nTop'},
    ),
    _ConceptStep(
      title: 'The lesson',
      body: 'A well-connected tank (one touching many pipes) almost '
          'always covers more of the board than a tank sitting at a dead '
          'end. Before tapping, look for the most-connected points on the '
          'board; they are usually the strongest first moves.',
      illustration: _illustration,
      tappedIds: const {'nMiddle'},
    ),
    _ConceptStep(
      title: 'Playing a level',
      body: '1. Open Classic from the home screen and choose an unlocked '
          'level.\n'
          '2. Look at the whole board before tapping anything; note which '
          'tanks look well-connected and which sit off on their own.\n'
          '3. Check the OPTIMAL number at the top of the screen. That is '
          'your target tap count for 3 stars.\n'
          '4. Tap a tank. It, and every tank directly next to it, will '
          'visually change to show they now have supply.\n'
          '5. Look for tanks that still show no supply, and tap the '
          'most-connected among THOSE next, not just any remaining tank.\n'
          '6. Keep going until every tank on the board shows supply. The '
          'result (3 star / 2 star / fail) is worked out automatically '
          'the moment you finish.\n'
          '7. If you tap a tank by mistake, tap it again to undo it, as '
          'long as you are still within the tap limit.',
      illustration: _illustration,
      tappedIds: const {'nMiddle'},
    ),
    _ConceptStep(
      title: 'Common mistakes',
      body: '\u2022 Tapping tanks one at a time in the order they catch '
          'your eye, instead of scanning the whole board first for the '
          'best-connected ones.\n'
          '\u2022 Missing a tank tucked in a corner of the board; look at '
          'every part of the network, not just the middle, before '
          'deciding you are done.\n'
          '\u2022 Tapping a tank that\'s already fully covered by a '
          'neighbour\'s supply, instead of hunting for the parts of the '
          'board that are still unsupplied.',
      illustration: _illustration,
      tappedIds: const {'nMiddle'},
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
            '${labels.length} more node$plural through its pipes: '
            'node$plural ${labels.join(', ')}.';
      },
      explainMistake: (graph, level, tapped, wrongNodeId) {
        final here = _displayIndexOf(level, wrongNodeId);
        final alreadySupplied =
            _classicNodeStates(graph, level, tapped)[wrongNodeId] ==
                NodeVisualState.supplied;
        if (alreadySupplied) {
          return 'Node $here is already supplied by an earlier tap, so '
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
        id: 'nA',
        position: GraphPoint(0, 120),
        capacity: 10,
        demand: 5,
      ),
      GraphNode(
        id: 'nB',
        position: GraphPoint(180, 120),
        capacity: 4,
        demand: 8,
      ),
      GraphNode(
        id: 'nC',
        position: GraphPoint(360, 120),
        capacity: 6,
        demand: 3,
      ),
    ],
    edges: const [
      GraphEdge('nA', 'nB'),
      GraphEdge('nB', 'nC'),
    ],
  );

  static final _nodeStatesOf = _capacityNodeStates;
  static final _pipeStatesOf = _capacityPipeStates;

  static final _steps = [
    _ConceptStep(
      title: 'Taps, stars & fails',
      body: 'Tap a point to activate it; tap the same point again to undo '
          'that tap, as long as you\'re still within the tap limit. Every '
          'level shows an OPTIMAL number of taps at the top: finish using '
          'exactly that many for 3 stars, or one more than that for 2 '
          'stars. An attempt fails if you go more than one tap over '
          'optimal without finishing, or if the countdown timer runs out '
          'first. These rules are the same in every mode; only what '
          'counts as "finished" changes from here.',
      illustration: _illustration,
      tappedIds: const {},
    ),
    _ConceptStep(
      title: 'The idea',
      body: 'Capacity mode uses the same tank-and-pipe board as Classic, '
          'but "supplied" is no longer just on or off. Every tank now '
          'carries two numbers of its own: DEMAND, how much supply that '
          'tank needs before it counts as satisfied, and CAP (short for '
          'capacity), how much supply that tank is able to send out if '
          'you tap it. Here is the twist that makes this mode different '
          'from Classic: when you tap a tank, it does NOT send its full '
          'capacity to its neighbours. The tank you tapped keeps its full '
          'CAP for itself. Every tank directly next to it receives only '
          'HALF of that CAP; this halving is called spillover, like water '
          'splashing over the side into the next pipe rather than being '
          'fully delivered. A tank counts as satisfied once its current '
          'supply is at least equal to its demand. Because of spillover, '
          'a tank can become fully satisfied WITHOUT you ever tapping it '
          'directly, if enough of its neighbours are tapped, their '
          'combined half-shares can be enough on their own. A level is '
          'finished once every tank\'s demand is met, by whatever '
          'combination of direct taps and spillover got it there.',
      illustration: _illustration,
      tappedIds: const {},
    ),
    _ConceptStep(
      title: 'Worked example: tap tank A',
      body: 'Picture three tanks in a row: A is connected to B, and B is '
          'connected to C. A and C are NOT directly connected to each '
          'other. Tank A: CAP 10, DEMAND 5. Tank B: CAP 4, DEMAND 8. Tank '
          'C: CAP 6, DEMAND 3. Now tap ONLY tank A. Tank A is tapped '
          'directly, so it gets its own full CAP: current supply = 10. '
          'Its demand was only 5, satisfied, with plenty to spare. Tank B '
          'is A\'s neighbour, so it receives HALF of A\'s capacity: '
          '0.5 \u00d7 10 = 5. Its demand is 8, NOT satisfied yet; it\'s '
          'short by 3. Tank C is not connected to A at all, so it gets '
          'nothing from this tap: current supply = 0. Its demand is 3, '
          'NOT satisfied. One tap clearly isn\'t enough.',
      illustration: _illustration,
      tappedIds: const {'nA'},
    ),
    _ConceptStep(
      title: 'Worked example: tap A and C',
      body: 'Now ALSO tap tank C. Tank A stays at 10 (unchanged, not '
          'connected to C), still meeting its demand of 5. Tank C is '
          'tapped directly, so its supply becomes its own full CAP of 6, '
          'meeting its demand of 3. Tank B\'s supply is now 8: 5 from A\'s '
          'spillover plus 3 from C\'s spillover (half of C\'s 6), exactly '
          'matching its demand of 8. With A and C tapped, all three tanks '
          'are now satisfied, using only 2 taps, and tank B, the one with '
          'the HIGHEST demand on the whole board, was never tapped '
          'directly at all. It reached full supply purely through '
          'spillover from both of its neighbours at once.',
      illustration: _illustration,
      tappedIds: const {'nA', 'nC'},
    ),
    _ConceptStep(
      title: 'The core trick',
      body: 'Sometimes the smartest tap is not on the neediest tank '
          'itself, but on the tanks AROUND it, especially when a needy '
          'tank has two or more neighbours whose combined half-shares can '
          'cover it between them.',
      illustration: _illustration,
      tappedIds: const {'nA', 'nC'},
    ),
    _ConceptStep(
      title: 'Playing a level',
      body: '1. Before tapping anything, look at every tank\'s CAP number '
          'and every tank\'s DEMAND number. This tells you what each tank '
          'could contribute (if tapped or as a neighbour) and what each '
          'tank needs.\n'
          '2. Find the tanks with the highest demand first; work out '
          'whether one direct tap on that tank alone would cover it, or '
          'whether it will need help from its neighbours too.\n'
          '3. When choosing where to tap, prefer a tank that helps itself '
          'AND meaningfully helps its neighbours, over a tank that only '
          'helps itself.\n'
          '4. Watch each tank\'s ring fill live as you tap. A ring that\'s '
          'still short means that tank needs more supply from somewhere: '
          'either a direct tap on it, or a tap on one more of its '
          'neighbours.\n'
          '5. If a number surprises you, press and hold that tank to see '
          'exactly where its current supply is coming from.\n'
          '6. Stop once every tank\'s ring shows full.',
      illustration: _illustration,
      tappedIds: const {'nA', 'nC'},
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
          return 'Node $here already has its demand met from spillover, so '
              'tapping it directly would waste a tap. A common Capacity '
              'mistake: tapping tanks that don\'t need it instead of '
              'ones still short.';
        }
        return 'Node $here isn\'t the most efficient tap here. A common '
            'Capacity mistake is forgetting spillover is only HALF a '
            'tapped tank\'s capacity; distant tanks usually still need '
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
      GraphNode(id: 'nTower1', position: GraphPoint(0, 120)),
      GraphNode(id: 'nTower2', position: GraphPoint(160, 120)),
      GraphNode(id: 'nTower3', position: GraphPoint(320, 120)),
      GraphNode(id: 'nTower4', position: GraphPoint(480, 120)),
    ],
    edges: const [
      GraphEdge('nTower1', 'nTower2'),
      GraphEdge('nTower2', 'nTower3'),
      GraphEdge('nTower3', 'nTower4'),
    ],
  );

  static final _nodeStatesOf = _signalNodeStates;
  static final _pipeStatesOf = _signalPipeStates;

  static final _steps = [
    _ConceptStep(
      title: 'Taps, stars & fails',
      body: 'Tap a point to activate it; tap the same point again to undo '
          'that tap, as long as you\'re still within the tap limit. Every '
          'level shows an OPTIMAL number of taps at the top: finish using '
          'exactly that many for 3 stars, or one more than that for 2 '
          'stars. An attempt fails if you go more than one tap over '
          'optimal without finishing, or if the countdown timer runs out '
          'first. These rules are the same in every mode; only what '
          'counts as "finished" changes from here.',
      illustration: _illustration,
      tappedIds: const {},
    ),
    _ConceptStep(
      title: 'The idea',
      body: 'Signal mode uses the same style of board, but with an '
          'important difference: every pipe between them is ONE-WAY, '
          'shown as an arrow. An arrow only ever carries a signal in the '
          'direction it points, never backwards. Tapping a tower makes it '
          'a DRIVER, a starting broadcast point. Once a tower is a '
          'driver, its signal spreads forward: first to every tower its '
          'own outgoing arrows point to, and then onward from THOSE '
          'towers along THEIR outgoing arrows, and so on, hopping forward '
          'through the whole network however many steps it takes. A '
          'tower counts as controlled the moment a signal from any '
          'driver can reach it by following arrows forward, no matter '
          'how many other towers it has to pass through on the way. A '
          'level is finished once every tower on the board is '
          'controlled. Your goal, as always, is to reach that using as '
          'few driver taps as possible. The one rule to hold onto above '
          'all others: signal only ever travels FORWARD along an arrow. '
          'A tower can never help control a tower that its arrows point '
          'away from.',
      illustration: _illustration,
      tappedIds: const {},
    ),
    _ConceptStep(
      title: 'Worked example: tap Tower 1',
      body: 'Picture four towers in a straight line, with every arrow '
          'pointing the same way: Tower 1 \u2192 Tower 2 \u2192 Tower 3 '
          '\u2192 Tower 4. Tap TOWER 1: its signal follows the arrow to '
          'tower 2. Tower 2\'s own outgoing arrow then carries it on to '
          'tower 3, and tower 3\'s arrow carries it on to tower 4. One '
          'single tap controls all four towers, because the signal can '
          'hop all the way down the chain.',
      illustration: _illustration,
      tappedIds: const {'nTower1'},
    ),
    _ConceptStep(
      title: 'Worked example: tap Tower 3 instead',
      body: 'Tap TOWER 3 instead: the signal can only go forward, so it '
          'reaches tower 4, but towers 1 and 2 sit "upstream" of tower 3, '
          'and there is no arrow leading backward into them. They stay '
          'uncontrolled no matter what happens at tower 3. You would '
          'need a separate tap on tower 1 (or 2) to ever reach them.',
      illustration: _illustration,
      tappedIds: const {'nTower3'},
    ),
    _ConceptStep(
      title: 'The lesson',
      body: 'Always look for the tower at the very START of a chain, the '
          'one with arrows only leading OUT of it, none leading in, '
          'because tapping it is the only way to light up everything '
          'that follows from it.',
      illustration: _illustration,
      tappedIds: const {'nTower1'},
    ),
    _ConceptStep(
      title: 'Playing a level',
      body: '1. Before tapping anything, trace the arrows across the '
          'whole board. Find towers where every arrow touching them '
          'points OUT and none point IN; these chain-starts are usually '
          'your strongest first taps.\n'
          '2. Tap a likely chain-start. Watch which towers light up as '
          'controlled, following the arrows forward from it.\n'
          '3. If some towers are still not lit, check whether they '
          'belong to a separate chain (needs its own driver tap) or sit '
          'inside a closed loop with nothing feeding in from outside '
          '(also needs one driver tap, placed inside the loop).\n'
          '4. Keep tapping chain-starts (or one tower inside each '
          'stubborn loop) until every tower on the board is controlled.\n'
          '5. Check DRIVERS used against the OPTIMAL number at the top '
          'of the screen.',
      illustration: _illustration,
      tappedIds: const {'nTower1'},
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
            '${labels.join(', ')}; no other driver node in this '
            'solution can reach ${labels.length == 1 ? 'it' : 'them'}.';
      },
      explainMistake: (graph, level, tapped, wrongNodeId) {
        final here = _displayIndexOf(level, wrongNodeId);
        final alreadyReached =
            _signalNodeStates(graph, level, tapped)[wrongNodeId] ==
                NodeVisualState.supplied;
        if (alreadyReached) {
          return 'Node $here is already under control from an earlier '
              'tap. A common Signal mistake is re-tapping a reached '
              'tank instead of finding the next driver node.';
        }
        return 'Node $here isn\'t one of this level\'s minimum driver '
            'nodes. A common Signal mistake is tapping whatever LOOKS '
            'busiest: what actually matters is whether anything points '
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
        ? 'Correct. Node $here tapped.'
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
                  ? 'Solved with the fewest possible taps, exactly '
                  'what success looks like here. 3-star clear!'
                  : outcome == GameplayOutcome.twoStar
                  ? 'Solved, one tap over optimal: a 2-star clear.'
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