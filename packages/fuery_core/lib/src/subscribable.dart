import 'package:meta/meta.dart';

/// Holds listeners that receive values of type [T].
abstract class Subscribable<T> {
  @protected
  Set<void Function(T value)> listeners = <void Function(T value)>{};

  /// Adds [listener] and returns a function that removes it.
  void Function() subscribe(void Function(T value) listener) {
    listeners.add(listener);
    onSubscribe();

    return () {
      if (listeners.remove(listener)) onUnsubscribe();
    };
  }

  bool hasListeners() => listeners.isNotEmpty;

  @protected
  void onSubscribe() {}

  @protected
  void onUnsubscribe() {}
}
