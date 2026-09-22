import 'package:meta/meta.dart';

/// Holds listeners that receive values of type [T].
abstract class Subscribable<T> {
  final Set<void Function(T value)> _listeners = <void Function(T value)>{};

  /// A copy of the current listeners, so they can unsubscribe while being
  /// notified.
  @protected
  List<void Function(T value)> get listeners => _listeners.toList();

  /// Adds [listener] and returns a function that removes it.
  void Function() subscribe(void Function(T value) listener) {
    _listeners.add(listener);
    onSubscribe();

    return () {
      if (_listeners.remove(listener)) onUnsubscribe();
    };
  }

  /// Whether anything is subscribed.
  bool get hasListeners => _listeners.isNotEmpty;

  /// Removes every listener without calling [onUnsubscribe].
  @protected
  void clearListeners() => _listeners.clear();

  @protected
  void onSubscribe();

  @protected
  void onUnsubscribe();
}
