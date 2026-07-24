// Pure win-check decision logic — Master Context's WIN CHECK table,
// plus a resolution for a genuine gap in that table (see below).
// Deliberately factored out of GameplayController as a standalone
// pure function: this is the one piece of Phase 3 correctness-
// critical enough to want a `dart test`-verifiable unit, the same way
// Phase 1/2's algorithmic pieces got that treatment. Everything else
// this phase touches — widgets, Timer, SharedPreferences — needs a
// running app to verify either way; there's no equivalent shortcut
// for those, but there IS one for this.

enum GameplayOutcome { playing, threeStar, twoStar, failTaps, failTime }

/// Implements the Master Context's WIN CHECK table:
/// ```
/// isFullySatisfied AND tapsUsed == optimum          -> 3 STARS
/// isFullySatisfied AND tapsUsed == optimum + 1       -> 2 STARS
/// NOT isFullySatisfied AND tapsUsed > maxTaps         -> FAIL (taps)
/// NOT isFullySatisfied AND timeElapsed >= timeLimit   -> FAIL (time)
/// ```
/// plus a resolution for one case that table leaves undefined: it has
/// no row for `isFullySatisfied == true AND tapsUsed > maxTaps`. E.g.
/// a player who overshoots to 5 taps when maxTaps is 4, and that
/// specific 5-node set happens to satisfy the win condition anyway.
/// This is a genuinely reachable state, not a hypothetical —
/// over-tapping can only ever ADD coverage, never remove it, for all
/// three modes (Classic/Capacity supply is monotonic in the tapped
/// set; Signal's forward-reachability from more driver nodes can only
/// stay the same or grow), so a player can absolutely stumble into
/// "satisfied, but only because I tapped way more than I needed to."
///
/// The Master Context is explicit that "every attempt has exactly
/// THREE possible outcomes" and that completing the puzzle "always
/// yields 2 or 3 stars, never fewer" — read together, that means
/// there's no fourth "completed but unscored" outcome for this
/// resolution to land on. This function resolves it as FAIL: tap
/// count is checked against [maxTapsFor] FIRST and unconditionally,
/// before [isFullySatisfied] is even consulted. A player who has
/// already used more taps than the game will reward under ANY star
/// rating has exceeded what "still playing" means, independent of
/// what their specific tapped set happens to satisfy.
GameplayOutcome evaluateOutcome({
  required bool isFullySatisfied,
  required int tapsUsed,
  required int optimum,
  required double elapsedSeconds,
  required int timeLimitSeconds,
}) {
  final maxTaps = maxTapsFor(optimum);

  if (tapsUsed > maxTaps) {
    return GameplayOutcome.failTaps;
  }
  if (isFullySatisfied && tapsUsed == optimum) {
    return GameplayOutcome.threeStar;
  }
  if (isFullySatisfied && tapsUsed == maxTaps) {
    return GameplayOutcome.twoStar;
  }
  if (!isFullySatisfied && elapsedSeconds >= timeLimitSeconds) {
    return GameplayOutcome.failTime;
  }
  return GameplayOutcome.playing;
}

/// Master Context: "Not stored separately; always derived from
/// optimum so it can't drift" — the single place that arithmetic
/// happens, so nothing else in Phase 3 re-derives it independently.
int maxTapsFor(int optimum) => optimum + 1;
