/// Accuracy (0-100) for a practice/DPP history item as correct / attempted.
///
/// Returns null when the server did not send `correctCount`/`attemptedCount`
/// (older backend) so callers keep their previous score-based behaviour.
/// An item with zero attempts is 0, not a divide-by-zero.
double? practiceAccuracy(Map item) {
  final correct = num.tryParse(item['correctCount']?.toString() ?? '');
  final attempted = num.tryParse(item['attemptedCount']?.toString() ?? '');
  if (correct == null || attempted == null) return null;
  if (attempted <= 0) return 0;
  return correct / attempted * 100;
}
