/// A 2D point used only for level layout/rendering — no solver ever
/// reads this. Deliberately not Flutter's `Offset`: this package has
/// zero Flutter imports, and `dart:ui` (where `Offset` lives) isn't
/// available outside a Flutter engine context, so plain `dart test`
/// couldn't even resolve the import.
class GraphPoint {
  const GraphPoint(this.x, this.y);

  final double x;
  final double y;

  @override
  String toString() => 'GraphPoint($x, $y)';
}

/// A single node in a level graph.
class GraphNode {
  const GraphNode({
    required this.id,
    this.position,
    this.capacity = 0,
    this.demand = 0,
  });

  /// Stable, level-authored identifier. Solvers map this to a dense
  /// internal index; nothing about solving depends on what these
  /// strings actually are, so level data can use whatever ids make
  /// sense upstream.
  final String id;

  /// Layout position for rendering only — no solver reads this.
  final GraphPoint? position;

  /// Capacity mode only. Ignored by Classic and Signal.
  final double capacity;

  /// Capacity mode only. Ignored by Classic and Signal.
  final double demand;

  @override
  String toString() => 'GraphNode($id)';
}

/// An edge between two nodes, referenced by id. Undirected for
/// Classic/Capacity graphs, directed (from -> to) for Signal graphs —
/// see [Graph.undirected] and [Graph.directed].
class GraphEdge {
  const GraphEdge(this.from, this.to);

  final String from;
  final String to;

  @override
  String toString() => '$from -> $to';
}

/// A graph ready for solving: nodes plus an adjacency structure,
/// packed into dense integer indices (0..nodeCount-1) internally so
/// solvers can use bitmasks and plain array lookups instead of
/// hashing on ids in their hot paths. Build with [Graph.undirected]
/// (Classic, Capacity) or [Graph.directed] (Signal); everything else
/// is indices in, ids out.
class Graph {
  Graph._({
    required this.nodes,
    required this.directed,
    required List<List<int>> adjacency,
    required Map<String, int> idToIndex,
  })  : _adjacency = adjacency,
        _idToIndex = idToIndex;

  /// Builds an undirected graph for Classic/Capacity: each [edges]
  /// entry connects both directions.
  factory Graph.undirected({
    required List<GraphNode> nodes,
    required List<GraphEdge> edges,
  }) {
    final idToIndex = _buildIndex(nodes);
    final adjacency = List.generate(nodes.length, (_) => <int>[]);
    for (final edge in edges) {
      final u = _requireIndex(idToIndex, edge.from);
      final v = _requireIndex(idToIndex, edge.to);
      if (u == v) continue; // self-loops are meaningless for domination
      if (!adjacency[u].contains(v)) {
        adjacency[u].add(v);
        adjacency[v].add(u);
      }
    }
    return Graph._(
      nodes: nodes,
      directed: false,
      adjacency: adjacency,
      idToIndex: idToIndex,
    );
  }

  /// Builds a directed graph for Signal: each [edges] entry is
  /// `from -> to` only.
  factory Graph.directed({
    required List<GraphNode> nodes,
    required List<GraphEdge> edges,
  }) {
    final idToIndex = _buildIndex(nodes);
    final adjacency = List.generate(nodes.length, (_) => <int>[]);
    for (final edge in edges) {
      final u = _requireIndex(idToIndex, edge.from);
      final v = _requireIndex(idToIndex, edge.to);
      if (u == v) continue;
      if (!adjacency[u].contains(v)) {
        adjacency[u].add(v);
      }
    }
    return Graph._(
      nodes: nodes,
      directed: true,
      adjacency: adjacency,
      idToIndex: idToIndex,
    );
  }

  static Map<String, int> _buildIndex(List<GraphNode> nodes) {
    final idToIndex = <String, int>{};
    for (var i = 0; i < nodes.length; i++) {
      final id = nodes[i].id;
      if (idToIndex.containsKey(id)) {
        throw ArgumentError('Duplicate node id "$id"');
      }
      idToIndex[id] = i;
    }
    return idToIndex;
  }

  static int _requireIndex(Map<String, int> idToIndex, String id) {
    final index = idToIndex[id];
    if (index == null) {
      throw ArgumentError('Edge references unknown node id "$id"');
    }
    return index;
  }

  final List<GraphNode> nodes;
  final bool directed;
  final List<List<int>> _adjacency;
  final Map<String, int> _idToIndex;

  int get nodeCount => nodes.length;

  /// The dense internal index for a node id — throws if unknown.
  int indexOf(String id) {
    final index = _idToIndex[id];
    if (index == null) {
      throw ArgumentError('Unknown node id "$id"');
    }
    return index;
  }

  /// The node id at a dense internal index.
  String idAt(int index) => nodes[index].id;

  GraphNode nodeAt(int index) => nodes[index];

  /// Outgoing neighbors of node [index]. For an undirected graph this
  /// is the full neighbor set (edges point both ways by
  /// construction); for a directed graph, only nodes reachable by
  /// following one edge forward from [index].
  List<int> neighbors(int index) => _adjacency[index];

  /// `{v} ∪ neighbors(v)`, as a list of indices. Meaningful for
  /// undirected graphs (Classic/Capacity); Signal doesn't use this.
  List<int> closedNeighborhood(int index) => [index, ..._adjacency[index]];

  /// `{v} ∪ neighbors(v)` packed as a bitmask — bit i set means node
  /// i is a member. Requires [nodeCount] <= 62; see
  /// [assertBitmaskCapacity].
  int closedNeighborhoodMask(int index) {
    var mask = 1 << index;
    for (final u in _adjacency[index]) {
      mask |= 1 << u;
    }
    return mask;
  }

  /// Bitmask-based solvers (Classic, Capacity) pack node membership
  /// into a single native int, one bit per node. To stay unambiguous
  /// across Dart's 64-bit signed VM/AOT ints without touching the
  /// sign bit, that's a hard ceiling of 62 usable bits — comfortably
  /// past the Master Context's 8-40 node range for these modes, so
  /// this should never fire in practice. Solvers call it defensively
  /// rather than silently producing a wrong answer on an oversized
  /// graph.
  void assertBitmaskCapacity() {
    if (nodeCount > 62) {
      throw StateError(
        'Graph has $nodeCount nodes; bitmask-based solving supports at '
        'most 62. Split the level, or extend the solver to use sets or '
        'BigInt, before going higher.',
      );
    }
  }
}
