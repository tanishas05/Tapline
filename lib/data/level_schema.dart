// Level JSON schema — Phase 2 item 1. Deliberately reuses the Phase 1
// engine's GraphNode/GraphEdge/GraphPoint directly instead of
// inventing parallel "LevelNodeData"/"LevelEdgeData" types: a [Level]
// IS a graph plus scoring metadata, and [toGraph] should be a
// zero-conversion no-op. Serialization lives here as free functions
// rather than on the engine types themselves, so engine/ stays
// completely unaware that JSON exists — its only job is solving.
//
// This file has zero Flutter imports on purpose (same discipline as
// lib/engine/), so lib/generation/'s pure-Dart generators can depend
// on it without dragging Flutter along. The Flutter-facing half of
// "Level JSON loading" (Phase 2 item 4) — actually reading asset
// bundles — lives in level_loader.dart instead, which is the one file
// in this folder that's allowed to import Flutter.

import '../engine/engine.dart';

/// Which difficulty slot a level belongs to within its track. The
/// node-count/optimum ranges and time limit each tier maps to are
/// tunable data, not part of this enum — see
/// generation/difficulty_tiers.dart for the single source of truth.
enum DifficultyTier { small, medium, large }

/// One playable level: a graph plus everything the Master Context's
/// shared win/score model needs to grade an attempt against it.
///
/// [maxTaps] is deliberately NOT a field here — Master Context: "Not
/// stored separately; always derived from optimum so it can't drift."
/// Compute `optimum + 1` at the call site instead (Phase 3).
class Level {
  const Level({
    required this.id,
    required this.mode,
    required this.difficultyTier,
    required this.nodes,
    required this.edges,
    required this.optimum,
    required this.exampleSolution,
    required this.timeLimitSeconds,
  }) : assert(
          exampleSolution.length == optimum,
          'exampleSolution must contain exactly optimum members',
        );

  /// Stable identifier — e.g. "classic_small_014" for curated content,
  /// or a freshly-minted id for an on-device retry layout. Unique
  /// within a track/tier is enough; nothing treats this as globally
  /// unique across the whole app.
  final String id;

  final GameMode mode;
  final DifficultyTier difficultyTier;

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  /// True for [GameMode.signal], false for Classic/Capacity. A
  /// computed getter, not a stored field, so it can never drift out
  /// of sync with [mode] — still written into [toJson]'s output
  /// explicitly (Phase 2 item 1 calls for a "directed flag" alongside
  /// the edge list), just never trusted back on the way in.
  bool get directed => mode == GameMode.signal;

  /// The exact minimum solution size, from the Phase 1 solver at
  /// generation time. Star thresholds derive from this alone (Master
  /// Context) — never recomputed from [exampleSolution]'s length at
  /// score time, though the two always agree by construction here.
  final int optimum;

  /// One valid optimal tap set, for hint generation. Always has
  /// exactly [optimum] members — enforced by the assertion above.
  final Set<String> exampleSolution;

  /// Per-level countdown, resolved from [difficultyTier] at
  /// generation time (generation/difficulty_tiers.dart) — independent
  /// of [optimum], never derived from it.
  final int timeLimitSeconds;

  /// Builds the solvable/playable [Graph] for this level — directed
  /// for Signal, undirected for Classic/Capacity, per [directed].
  /// Zero-conversion: [nodes]/[edges] are handed straight through.
  Graph toGraph() {
    return directed
        ? Graph.directed(nodes: nodes, edges: edges)
        : Graph.undirected(nodes: nodes, edges: edges);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'mode': mode.name,
      'difficultyTier': difficultyTier.name,
      'directed': directed,
      'nodes': nodes.map(_nodeToJson).toList(),
      'edges': edges.map(_edgeToJson).toList(),
      'optimum': optimum,
      'exampleSolution': exampleSolution.toList(),
      'timeLimitSeconds': timeLimitSeconds,
    };
  }

  factory Level.fromJson(Map<String, dynamic> json) {
    return Level(
      id: json['id'] as String,
      mode: GameMode.values.byName(json['mode'] as String),
      difficultyTier:
          DifficultyTier.values.byName(json['difficultyTier'] as String),
      nodes: (json['nodes'] as List)
          .map((e) => _nodeFromJson(e as Map<String, dynamic>))
          .toList(),
      edges: (json['edges'] as List)
          .map((e) => _edgeFromJson(e as Map<String, dynamic>))
          .toList(),
      optimum: json['optimum'] as int,
      exampleSolution: (json['exampleSolution'] as List)
          .map((e) => e as String)
          .toSet(),
      timeLimitSeconds: json['timeLimitSeconds'] as int,
    );
  }

  @override
  String toString() =>
      'Level($id, $mode, ${difficultyTier.name}, ${nodes.length} nodes, '
      'optimum $optimum, ${timeLimitSeconds}s)';
}

Map<String, dynamic> _nodeToJson(GraphNode node) {
  final position = node.position;
  return <String, dynamic>{
    'id': node.id,
    if (position != null) 'x': position.x,
    if (position != null) 'y': position.y,
    'capacity': node.capacity,
    'demand': node.demand,
  };
}

GraphNode _nodeFromJson(Map<String, dynamic> json) {
  final hasPosition = json.containsKey('x') && json.containsKey('y');
  return GraphNode(
    id: json['id'] as String,
    position: hasPosition
        ? GraphPoint(
            (json['x'] as num).toDouble(),
            (json['y'] as num).toDouble(),
          )
        : null,
    capacity: (json['capacity'] as num?)?.toDouble() ?? 0,
    demand: (json['demand'] as num?)?.toDouble() ?? 0,
  );
}

Map<String, dynamic> _edgeToJson(GraphEdge edge) {
  return <String, dynamic>{'from': edge.from, 'to': edge.to};
}

GraphEdge _edgeFromJson(Map<String, dynamic> json) {
  return GraphEdge(json['from'] as String, json['to'] as String);
}
