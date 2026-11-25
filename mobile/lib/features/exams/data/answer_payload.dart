/// Pure helpers for the exam/practice answer wire format.
///
/// Kept free of Flutter/network imports so the mapping can be unit-tested.
/// Backend contract (exam.controller.js saveAnswer / practice.controller.js
/// saveProgress): `selectedOptionId`, `selectedOptionIds`, `numericAnswer`,
/// `subjectiveAnswerText`. Any other key (e.g. the old `answerText`) is ignored
/// by the server and the answer is graded as unattempted.
library;

import 'dart:async';

/// Separator used to keep a multi-select answer inside the player's
/// `Map<int, String>` answer store.
const String kMultiAnswerSeparator = ',';

/// True for option ids the client invents (`opt_A_0`, `opt_2`) when it splits options
/// out of the question text. The server has never heard of them, so they must
/// never be sent.
bool isSyntheticOptionId(String id) =>
    RegExp(r'^opt_(?:[A-Za-z0-9]_)?\d+$').hasMatch(id);

/// True for question types answered by typing a number.
bool isNumericQuestionType(String type) {
  final t = type.toUpperCase();
  return t == 'INTEGER' || t == 'NUMERICAL';
}

/// Splits a stored multi-select answer back into option ids.
List<String> splitMultiAnswer(String? answer) => (answer ?? '')
    .split(kMultiAnswerSeparator)
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

/// Maps one answer to the answer-bearing keys of a save request.
///
/// [answer] is the player's stored string: an option id, comma-joined option
/// ids (MULTIPLE_CORRECT) or typed text. `null`/empty means "cleared" and
/// resets the matching key so the server forgets the old value.
///
/// Multi-select assumption: ids are Mongo ObjectIds (24 hex chars), which never
/// contain a comma, so comma-joining is lossless.
///
/// An empty result means "nothing sendable" (synthetic id, half-typed or
/// non-finite number); callers must not mark such a save as ANSWERED.
Map<String, dynamic> buildAnswerFields({
  required String type,
  required bool hasOptions,
  required String? answer,
}) {
  final t = type.toUpperCase();
  final text = (answer ?? '').trim();

  if (hasOptions) {
    // Synthetic ids can't be graded; drop them rather than send garbage.
    if (t == 'MULTIPLE_CORRECT') {
      final ids = splitMultiAnswer(text);
      if (text.isEmpty) return {'selectedOptionIds': <String>[]};
      final real = ids.where((e) => !isSyntheticOptionId(e)).toList();
      return real.isEmpty ? {} : {'selectedOptionIds': real};
    }
    if (text.isEmpty) return {'selectedOptionId': null};
    return isSyntheticOptionId(text) ? {} : {'selectedOptionId': text};
  }

  if (isNumericQuestionType(t)) {
    if (text.isEmpty) return {'numericAnswer': null};
    final n = num.tryParse(text);
    // "-", "." or "Infinity" are not usable numbers (JSON can't carry
    // Infinity/NaN either): send nothing.
    return (n == null || !n.isFinite) ? {} : {'numericAnswer': n};
  }
  return {'subjectiveAnswerText': text};
}

/// True when [fields] (from [buildAnswerFields]) carries a real answer.
bool hasAnswerValue(Map<String, dynamic> fields) =>
    fields.values.any((v) => v != null && !(v is List && v.isEmpty));

/// Status to send: if the student has an answer that produced no sendable key,
/// ANSWERED would be a lie (the server would count it attempted but empty), so
/// downgrade it.
String resolveAnswerStatus({
  required String status,
  required String? answer,
  required Map<String, dynamic> fields,
}) {
  final hasLocal = (answer ?? '').trim().isNotEmpty;
  if (!hasLocal || hasAnswerValue(fields)) return status;
  return status.contains('MARKED') ? 'MARKED_FOR_REVIEW' : 'NOT_ANSWERED';
}

/// One pending debounced save per question, so typing in question 3 never
/// cancels the pending save of question 2, and nothing is lost on dispose.
/// Each save is a self-contained closure (no BuildContext needed when it
/// fires, e.g. from dispose).
class PendingAnswerSaves {
  final Map<int, Timer> _timers = {};
  final Map<int, Future<void> Function()> _runs = {};

  /// Schedules [run] for [index], replacing any earlier pending save for it.
  void schedule(
    int index,
    Future<void> Function() run, {
    Duration delay = const Duration(milliseconds: 800),
  }) {
    _timers[index]?.cancel();
    _runs[index] = run;
    _timers[index] = Timer(delay, () => flush(index));
  }

  /// Runs the pending save for [index] now, if any.
  void flush(int index) {
    _timers.remove(index)?.cancel();
    final run = _runs.remove(index);
    if (run != null) {
      run().catchError((_) {}); // Silent: the local answer is resent later.
    }
  }

  /// Runs every pending save now (screen leaving).
  void flushAll() {
    for (final i in _runs.keys.toList()) {
      flush(i);
    }
  }

  /// Drops the pending save for [index] (a newer explicit save supersedes it).
  void cancel(int index) {
    _timers.remove(index)?.cancel();
    _runs.remove(index);
  }
}

/// Rebuilds the player's stored answer string from a saved server answer, so
/// every answer type survives leaving and resuming an exam.
String? restoreAnswerString(Map<dynamic, dynamic> saved) {
  final ids = saved['selectedOptionIds'];
  if (ids is List && ids.isNotEmpty) {
    return ids.map((e) => e.toString()).join(kMultiAnswerSeparator);
  }
  final single = saved['selectedOptionId'];
  if (single != null && single.toString().isNotEmpty) return single.toString();
  final numeric = saved['numericAnswer'];
  if (numeric is num) {
    return numeric == numeric.truncate()
        ? numeric.truncate().toString()
        : numeric.toString();
  }
  if (numeric != null && numeric.toString().isNotEmpty) {
    return numeric.toString();
  }
  final subjective = saved['subjectiveAnswerText'] ?? saved['answerText'];
  if (subjective != null && subjective.toString().isNotEmpty) {
    return subjective.toString();
  }
  return null;
}

/// Decides DPP vs PRACTICE from the session document the server returned.
/// The server stores `sessionType` as 'DPP' | 'PRACTICE'; the title is only a
/// last-resort hint for old payloads without the field.
String practiceSessionType(Map<dynamic, dynamic>? session, {String? title}) {
  final raw = session?['sessionType']?.toString().toUpperCase();
  if (raw == 'DPP' || raw == 'PRACTICE') return raw!;
  return (title ?? '').trimLeft().toUpperCase().startsWith('PRACTICE')
      ? 'PRACTICE'
      : 'DPP';
}
