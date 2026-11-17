import 'dart:async';

/// Waits about 150 ms after the last keystroke before searching (spec A.6),
/// and drops the answers of searches a newer one has replaced. For the
/// editors' search boxes (D13, D14) and AD19.
///
/// ```dart
/// final hits = await debouncer.run(() => search.drugs(text));
/// if (hits != null) setState(() => _hits = hits); // null: replaced
/// ```
class SearchDebouncer {
  SearchDebouncer({this.delay = const Duration(milliseconds: 150)});

  final Duration delay;
  Timer? _timer;
  Completer<Object?>? _waiting;
  int _generation = 0;

  /// Runs [search] once typing has paused. Completes with null when a later
  /// call replaced this one (before or after it ran).
  Future<T?> run<T>(Future<T> Function() search) {
    _timer?.cancel();
    _waiting?.complete(null);
    final generation = ++_generation;
    final completer = Completer<Object?>();
    _waiting = completer;
    _timer = Timer(delay, () async {
      if (identical(_waiting, completer)) _waiting = null;
      try {
        final result = await search();
        if (!completer.isCompleted) completer.complete(generation == _generation ? result : null);
      } on Object catch (error, stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
      }
    });
    return completer.future.then((value) => value as T?);
  }

  /// Drops a pending search.
  void cancel() {
    _timer?.cancel();
    _waiting?.complete(null);
    _waiting = null;
    _generation++;
  }

  void dispose() => cancel();
}
