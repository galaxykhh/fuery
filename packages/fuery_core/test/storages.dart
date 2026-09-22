import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:fuery_core/fuery_core.dart';

import 'helpers.dart';

/// A storage that reads and writes synchronously.
class MemoryStorage implements QueryStorage {
  MemoryStorage([Map<String, String>? entries]) : entries = entries ?? {};

  final Map<String, String> entries;
  int reads = 0;
  int writes = 0;

  @override
  String? read(String key) {
    reads++;
    return entries[key];
  }

  @override
  void write(String key, String value) {
    writes++;
    entries[key] = value;
  }

  @override
  void delete(String key) => entries.remove(key);

  @override
  Map<String, String> readAll() => Map.of(entries);
}

/// Wraps a [MemoryStorage] and answers after a delay.
class AsyncStorage implements QueryStorage {
  AsyncStorage(
    this.inner, {
    this.readDelay = ms10,
    this.readAllDelay = ms10,
  });

  final MemoryStorage inner;
  final Duration readDelay;
  final Duration readAllDelay;

  @override
  Future<String?> read(String key) =>
      Future.delayed(readDelay, () => inner.read(key));

  @override
  Future<void> write(String key, String value) =>
      Future.delayed(ms10, () => inner.write(key, value));

  @override
  Future<void> delete(String key) =>
      Future.delayed(ms10, () => inner.delete(key));

  @override
  Future<Map<String, String>> readAll() =>
      Future.delayed(readAllDelay, inner.readAll);
}

/// A storage where every call fails, synchronously or asynchronously.
class FailingStorage implements QueryStorage {
  FailingStorage({this.async = false});

  final bool async;

  T _fail<T>() => throw StateError('storage is broken');

  FutureOr<T> _call<T>() => async ? Future<T>(_fail) : _fail();

  @override
  FutureOr<String?> read(String key) => _call();

  @override
  FutureOr<void> write(String key, String value) => _call();

  @override
  FutureOr<void> delete(String key) => _call();

  @override
  FutureOr<Map<String, String>> readAll() => _call();
}

String storageKey(QueryKey queryKey) => '$persistKeyPrefix${hashKey(queryKey)}';

/// A stored entry as Fuery writes it.
String entry(Object? data, {int version = 1, Duration age = Duration.zero}) {
  return jsonEncode({
    'v': version,
    't': clock.now().subtract(age).millisecondsSinceEpoch,
    'd': data,
  });
}

Object? stored(MemoryStorage storage, QueryKey queryKey) {
  final raw = storage.entries[storageKey(queryKey)];
  return raw == null ? null : (jsonDecode(raw) as Map)['d'];
}

final todosPersist = QueryPersist<List<String>>(
  toJson: (todos) => todos,
  fromJson: (json) => List<String>.from(json! as List),
);
