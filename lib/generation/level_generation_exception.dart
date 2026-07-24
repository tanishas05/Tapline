/// Thrown when a generator can't produce a valid, verified level
/// within its attempt budget. Shared by [ClassicCapacityGenerator]
/// and `SignalGenerator` — the on-device path (Master Context's retry
/// rule) must never silently hand back a level that doesn't actually
/// verify, so both fail loudly instead of guessing.
class LevelGenerationException implements Exception {
  LevelGenerationException(this.message);

  final String message;

  @override
  String toString() => 'LevelGenerationException: $message';
}
