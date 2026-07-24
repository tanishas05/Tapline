// Shared, mode-agnostic attempt/outcome controller — Phase 3 item 3:
// built generically here even though Classic is the only mode using
// it yet, so Capacity (Phase 4) and Signal (Phase 5) reuse it
// directly instead of reimplementing tap/timer/outcome bookkeeping.
//
// Genuinely mode-agnostic in the sense that matters: it never
// hardcodes Classic's verify() — [isFullySatisfied] calls the
// engine's own [verifyWin] dispatcher with [Level.mode], which
// already handles all three modes uniformly (see solvability.dart).
// That IS "taking the mode's own isFullySatisfied() ... as an input"
// per the brief — just via the existing generic dispatch point rather
// than a second, redundant injected-callback layer on top of it.
//
// Deliberately a plain [ChangeNotifier], not a Riverpod
// Notifier/StateNotifier: this needs a live [Timer] and per-screen
// disposal, which a vanilla ChangeNotifier + ConsumerStatefulWidget
// handles with zero framework-version risk (Riverpod's Notifier API
// has changed shape across versions; ChangeNotifierProvider hasn't).
// Riverpod is still used everywhere it already was in this codebase
// (level loading, DI) — this is additive, not a change of approach.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/level_schema.dart';
import '../../engine/engine.dart';
import 'coin_economy.dart';
import 'outcome_logic.dart';

export 'outcome_logic.dart' show GameplayOutcome;

class GameplayController extends ChangeNotifier {
  GameplayController({
    required Level initialLevel,
    required String slotId,
  })  : _level = initialLevel,
        _slotId = slotId,
        _graph = initialLevel.toGraph() {
    _startTimer();
  }

  /// Stable identity for progress tracking — the curated level's own
  /// id, fixed for as long as the player is attempting this slot,
  /// even across retries that swap in a freshly-generated [level].
  String get slotId => _slotId;
  final String _slotId;

  Level _level;
  Level get level => _level;

  Graph _graph;
  Graph get graph => _graph;

  final Set<String> _tappedNodeIds = <String>{};
  Set<String> get tappedNodeIds => Set.unmodifiable(_tappedNodeIds);
  int get tapsUsed => _tappedNodeIds.length;
  int get maxTaps => maxTapsFor(_level.optimum);

  double _elapsedSeconds = 0;
  double get elapsedSeconds => _elapsedSeconds;

  double get remainingSeconds {
    final remaining = _level.timeLimitSeconds - _elapsedSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  GameplayOutcome _outcome = GameplayOutcome.playing;
  GameplayOutcome get outcome => _outcome;
  bool get isPlaying => _outcome == GameplayOutcome.playing;

  /// The cheap per-attempt check (Phase 3 item 2: "not a full
  /// re-solve") — [level.optimum] is what's compared against for
  /// scoring; this only ever answers "does the CURRENT tapped set
  /// win," never recomputes a new optimum.
  bool get isFullySatisfied => verifyWin(_graph, _level.mode, _tappedNodeIds);

  /// Free hints remaining for the CURRENT layout — resets on [retry]
  /// along with everything else, since a fresh layout is a fresh
  /// attempt with its own fresh allotment.
  int _hintsUsedThisAttempt = 0;
  int get freeHintsRemaining {
    final remaining = freeHintsPerAttempt - _hintsUsedThisAttempt;
    return remaining < 0 ? 0 : remaining;
  }

  Timer? _timer;

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!isPlaying) return;
      _elapsedSeconds += 0.1;
      _evaluateOutcome();
      notifyListeners();
    });
  }

  /// Toggles a node tapped/untapped (Phase 3 item 2) and re-runs the
  /// win check. No-ops once [isPlaying] is false — Master Context:
  /// "Once time expires, tap count no longer matters at all," and the
  /// same applies once ANY terminal outcome is reached.
  void toggleNode(String nodeId) {
    if (!isPlaying) return;
    if (_tappedNodeIds.contains(nodeId)) {
      _tappedNodeIds.remove(nodeId);
    } else {
      _tappedNodeIds.add(nodeId);
    }
    _evaluateOutcome();
    notifyListeners();
  }

  void _evaluateOutcome() {
    if (!isPlaying) return;
    _outcome = evaluateOutcome(
      isFullySatisfied: isFullySatisfied,
      tapsUsed: tapsUsed,
      optimum: _level.optimum,
      elapsedSeconds: _elapsedSeconds,
      timeLimitSeconds: _level.timeLimitSeconds,
    );
    if (_outcome != GameplayOutcome.playing) {
      _timer?.cancel();
    }
  }

  /// Records a FREE hint use. The gameplay screen is responsible for
  /// charging a PAID hint through [ProgressStore] once
  /// [freeHintsRemaining] is 0 — this controller has no coin balance
  /// of its own to spend from; its state isn't persisted at all.
  void useFreeHint() {
    if (_hintsUsedThisAttempt < freeHintsPerAttempt) {
      _hintsUsedThisAttempt++;
      notifyListeners();
    }
  }

  /// Swaps in a freshly-generated layout at the same [slotId] and
  /// tier — Master Context's retry rule: "always call
  /// generateNewLevelSameDifficulty() for a brand-new layout at the
  /// same difficulty tier. NEVER reuse the exact layout just
  /// attempted." [slotId] does not change: progress is still recorded
  /// against the original curated slot, not this fresh layout's own
  /// (ephemeral, timestamp-based) id.
  void retry(Level newLevel) {
    assert(newLevel.mode == _level.mode, 'retry must stay in the same mode');
    assert(
      newLevel.difficultyTier == _level.difficultyTier,
      'retry must stay at the same difficultyTier',
    );
    _level = newLevel;
    _graph = newLevel.toGraph();
    _tappedNodeIds.clear();
    _elapsedSeconds = 0;
    _outcome = GameplayOutcome.playing;
    _hintsUsedThisAttempt = 0;
    _timer?.cancel();
    _startTimer();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
