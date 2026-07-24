# generation

Pure Dart level generation — Phase 2. Zero Flutter imports anywhere in
this folder, same discipline as `lib/engine/`; test it with `dart test
test/generation`, no widget harness, no emulator.

```
level_generation_exception.dart   thrown when construct-then-verify can't land within budget
difficulty_tiers.dart             single source of truth for every tunable (node counts, time limits, ...)
classic_capacity_generator.dart   shared star-cluster generator for Classic + Capacity
signal_generator.dart             chain generator for Signal, incl. the teaching-pair construction
generation.dart                   barrel export
```

## The core idea: construct-then-verify, not generate-then-discover

Every level here is built so its optimum is known *by construction*,
then handed to the real Phase 1 solver as a verification pass — never
the other way around (generate a random graph, discover its optimum by
solving it). If verification doesn't match, the candidate is thrown
away and rebuilt, not shipped with a guessed number.

**Classic/Capacity — star clusters.** `k` disjoint clusters (1 hub +
`>=1` leaves each), `k` = the intended optimum. A leaf only ever
touches its own hub, so the cheapest way to dominate one cluster is
always tapping the hub. Decoration edges added afterward are
leaf<->leaf only, across different clusters, and never touch a hub —
which means every cluster's hub can *only* ever be dominated by itself
or one of its own leaves, so the dominating set needs `>=1` node from
each cluster's disjoint `{hub}+leaves` set no matter what decoration
exists. For Classic that's a proof, not a hope — worth stating
precisely because Capacity's numeric spillover threshold doesn't
inherit it for free (a threshold problem, not a pure coverage one),
which is exactly why the solver verification pass still does real work
for Capacity and isn't just a formality there.

**Signal — disjoint chains.** `k` disjoint directed chains, `k` = the
intended driver count. An isolated chain's head has no incoming edge,
so Kuhn's algorithm has nothing to match it to — always a driver — and
the rest of the chain is reachable by following it forward. Regular
decoration never targets a chain head, so it provably can't change the
driver count either. The one place this *is* deliberately violated is
`SignalGenerator.generateTeachingPair`: it splices chains tail-to-head
on purpose, which is precisely Phase 2's "denser graphs can need fewer
driver nodes" moment made concrete and verified, not just asserted in
a design doc.

## Verification methodology

No Dart SDK in the sandbox this was written in (same situation
`lib/engine/README.md` describes) — so both generators were prototyped
and swept in Python first, using ports of the three Phase 1 solvers,
before hand-translation to Dart:

- 360 trials across all three tiers, both Classic and Capacity — every
  one matched its intended optimum on the first construct-then-verify
  attempt.
- A deliberately-broken capacity margin (`0.5`, well under the `1.0`
  theoretical minimum) reliably exhausted every attempt and raised
  rather than silently returning something wrong — confirms the
  reject-and-retry path is load-bearing, not dead code.
- 180 baseline Signal trials, all first-attempt; 30 chain-merge trials
  for the teaching-pair construction, every one landing on the exact
  predicted reduced driver count (`sparseDrivers - (mergedChains - 1)`).

None of that carries any wall-clock performance claim — same caveat as
the engine README — only that the construction strategy itself is
sound. `test/generation/` re-runs a smaller version of the same checks
directly in Dart (independent re-solve via `checkSolvability`, not
just trusting what the generator claims), to catch anything the
hand-translation itself might have gotten wrong.

## Tunables

Every generator-facing number lives in `difficulty_tiers.dart` — node
count ranges, cluster/chain count ranges, decoration density,
Capacity's demand/capacity distribution knobs, and time limits.
**Time limits are explicitly placeholders**, flagged as such in that
file — they need real playtesting once Phase 3+ gameplay exists to
play against, not a guess made here.
