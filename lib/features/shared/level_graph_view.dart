// Renders a level's graph using the Phase 0 Node/Pipe design system
// components, positioned per the level's own stored layout — Phase 3
// item 1. Deliberately dumb/presentational: it takes pre-computed
// visual states as input rather than deciding "what does supplied
// mean" itself, since that's mode-specific (Classic's coverage,
// Capacity's threshold, Signal's reachability) and this widget is
// meant to be reused across all three, the same way the attempt
// controller is.
//
// Phase 5 (Signal) needed [directed] pipe rendering (arrowheads —
// wired straight from [Level.directed], no new parameter needed
// since that's already data the level carries).
//
// FIT-TO-SCREEN: earlier versions of this widget tried to guarantee
// the whole graph is visible by computing a zoom-out scale by hand
// and applying it to an InteractiveViewer's TransformationController
// (to also get pinch-to-zoom/pan for free). That went through
// several revisions and never reliably worked — the computed scale
// depended on getting real layout constraints AND a deferred
// application (a postFrameCallback, later a same-frame mutation)
// landing correctly before the player saw the screen, and evidently
// something in that chain kept silently not sticking, in ways that
// were never fully diagnosable from code alone. Rather than keep
// patching that, this now uses [FittedBox] with [BoxFit.contain]:
// a core Flutter primitive whose only job is "scale this child to
// fit the space you're given," resolved synchronously during layout
// by the framework itself. There's no custom math, no controller, no
// deferred step — so there's nothing left in this widget that can
// independently fail to apply. The trade-off: no pinch-to-zoom for
// now. Full, guaranteed visibility of every node is worth more than
// zoom, and zoom can come back later as a wrapper around the fitted
// content once the core "can the player see the graph" problem is
// solid.

import 'package:flutter/material.dart';

import '../../data/level_schema.dart';
import '../../design_system/design_system.dart';
import '../../engine/engine.dart';

class LevelGraphView extends StatelessWidget {
  const LevelGraphView({
    super.key,
    required this.level,
    required this.nodeIcon,
    required this.nodeStates,
    required this.pipeStates,
    required this.onNodeTap,
    this.highlightedNodeId,
    this.nodeBuilder,
  });

  final Level level;
  final IconData nodeIcon;

  /// Visual state per node id. A node missing from this map renders
  /// [NodeVisualState.inactive].
  final Map<String, NodeVisualState> nodeStates;

  /// Visual state per edge, keyed by [edgeKey]. An edge missing from
  /// this map renders [PipeState.inactive].
  final Map<String, PipeState> pipeStates;

  final void Function(String nodeId) onNodeTap;

  /// The current hint target, if any — drawn as a glow ring behind
  /// the node rather than a new [NodeVisualState], since "hinted" is
  /// orthogonal to supply state (a hinted node can be tapped or not,
  /// supplied or not) rather than another value on the same axis.
  /// Ignored when [nodeBuilder] is provided — Capacity mode (Phase 4)
  /// has its own two-part hint visualization and builds it itself.
  final String? highlightedNodeId;

  /// Overrides how each node renders — Capacity mode (Phase 4)
  /// substitutes [CapacityNodeGauge] for the default [ConvoyNode] this
  /// way, without this widget needing to know Capacity exists. Gets
  /// the node, its 1-based display position, its resolved
  /// [NodeVisualState], and the tap callback already wired up. When
  /// null (Classic, Signal), falls back to this widget's own default
  /// ConvoyNode + hint-glow rendering.
  final Widget Function(
    GraphNode node,
    int displayIndex,
    NodeVisualState state,
    VoidCallback onTap,
  )? nodeBuilder;

  static String edgeKey(GraphEdge edge) => '${edge.from}|${edge.to}';

  static const double _nodeDiameter = 64;
  static const double _padding = 70;

  @override
  Widget build(BuildContext context) {
    final positions = <String, GraphPoint>{
      for (final node in level.nodes)
        if (node.position != null) node.id: node.position!,
    };
    if (positions.isEmpty) {
      // Every Phase 2 generator always sets a position, so this
      // should be unreachable for real level data — guarded rather
      // than assumed, since this widget doesn't control what data it
      // gets handed.
      return const Center(child: Text('This level has no layout data.'));
    }

    final xs = positions.values.map((p) => p.x);
    final ys = positions.values.map((p) => p.y);
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);

    final canvasWidth = (maxX - minX) + _padding * 2;
    final canvasHeight = (maxY - minY) + _padding * 2;

    Offset localOffset(GraphPoint p) {
      return Offset(p.x - minX + _padding, p.y - minY + _padding);
    }

    // FittedBox needs bounded incoming constraints to know what box
    // to fit into — Center provides that from whatever the parent
    // (an Expanded, in every current caller) hands down, same as
    // before.
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: canvasWidth,
          height: canvasHeight,
          child: Stack(
            children: [
              for (final edge in level.edges)
                if (positions[edge.from] != null &&
                    positions[edge.to] != null)
                  Positioned.fill(
                    child: ConvoyPipe(
                      start: localOffset(positions[edge.from]!),
                      end: localOffset(positions[edge.to]!),
                      state: pipeStates[LevelGraphView.edgeKey(edge)] ??
                          PipeState.inactive,
                      directed: level.directed,
                    ),
                  ),
              for (var i = 0; i < level.nodes.length; i++)
                if (positions[level.nodes[i].id] != null)
                  _positionedNode(level.nodes[i], i, localOffset, positions),
            ],
          ),
        ),
      ),
    );
  }

  Widget _positionedNode(
    GraphNode node,
    int displayIndex,
    Offset Function(GraphPoint) localOffset,
    Map<String, GraphPoint> positions,
  ) {
    final offset = localOffset(positions[node.id]!);
    final state = nodeStates[node.id] ?? NodeVisualState.inactive;
    final onTap = () => onNodeTap(node.id);
    const nodeDiameter = _nodeDiameter;

    final builder = nodeBuilder;
    if (builder != null) {
      return Positioned(
        left: offset.dx - nodeDiameter / 2,
        top: offset.dy - nodeDiameter / 2,
        child: builder(node, displayIndex, state, onTap),
      );
    }

    final isHighlighted = node.id == highlightedNodeId;
    return Positioned(
      left: offset.dx - nodeDiameter / 2,
      top: offset.dy - nodeDiameter / 2,
      child: SizedBox(
        width: nodeDiameter,
        // Room for the label below. This used to be a bare +20, sized
        // assuming the label's rendered height matched its nominal
        // 11px font size — it didn't (see monoLabel's doc comment),
        // and every node on a real device overflowed by 2px as a
        // result. +28 is deliberately more than the fixed strictly
        // needs today: real headroom against label content changing
        // (convoy_node.dart's own doc comment already flags the
        // current "1", "2", "3"... position numbers as a placeholder
        // for real level ids later, e.g. "c0_hub" — a longer string,
        // in the same font), not just a patched magic number.
        height: nodeDiameter + 28,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            if (isHighlighted)
              Positioned(
                top: -8,
                child: Container(
                  width: nodeDiameter + 16,
                  height: nodeDiameter + 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ConvoyColors.cyan, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: ConvoyColors.cyan.withValues(alpha: 0.5),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ConvoyNode(
              icon: nodeIcon,
              // Raw ids (e.g. "c0_hub") are the stable data-layer key
              // but read as internal/engineer-facing — showing a
              // plain 1-based position instead is a placeholder in
              // the same spirit as Phase 0/2's other placeholders
              // (icons, time limits): a one-line change to swap for
              // something nicer later, not a structural decision.
              label: '${displayIndex + 1}',
              state: state,
              diameter: nodeDiameter,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}
