import 'package:flutter/widgets.dart';
import 'package:fuery_core/fuery_core.dart';

import 'result_subscriber.dart';

typedef _Observer<TPage, TParam> = InfiniteQueryObserver<TPage, TParam>;
typedef _Result<TPage, TParam> = InfiniteQueryResult<TPage, TParam>;

/// Builds UI from an infinite query.
///
/// ```dart
/// InfiniteQueryBuilder(
///   query: posts,
///   builder: (context, state) => ListView(
///     children: [
///       for (final page in state.pages) ...page.items.map(PostTile.new),
///       if (state.hasNextPage)
///         TextButton(
///           onPressed: state.isFetching ? null : posts.fetchNextPage,
///           child: const Text('Load more'),
///         ),
///     ],
///   ),
/// )
/// ```
class InfiniteQueryBuilder<TPage, TParam> extends StatelessWidget {
  const InfiniteQueryBuilder({
    super.key,
    required this.query,
    required this.builder,
    this.buildWhen,
  });

  final InfiniteQueryObserver<TPage, TParam> query;
  final ResultWidgetBuilder<InfiniteQueryResult<TPage, TParam>> builder;
  final ResultCondition<InfiniteQueryResult<TPage, TParam>>? buildWhen;

  @override
  Widget build(BuildContext context) {
    return ResultSubscriber<_Observer<TPage, TParam>, _Result<TPage, TParam>>(
      source: query,
      initialResult: _initialResult,
      subscribe: _subscribe,
      debugKey: _debugKey,
      builder: builder,
      buildWhen: buildWhen,
    );
  }
}

/// Runs side effects when an infinite query changes. Not called for the
/// result the query already had when the listener mounted.
class InfiniteQueryListener<TPage, TParam> extends StatelessWidget {
  const InfiniteQueryListener({
    super.key,
    required this.query,
    required this.listener,
    this.listenWhen,
    required this.child,
  });

  final InfiniteQueryObserver<TPage, TParam> query;
  final ResultWidgetListener<InfiniteQueryResult<TPage, TParam>> listener;
  final ResultCondition<InfiniteQueryResult<TPage, TParam>>? listenWhen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ResultSubscriber<_Observer<TPage, TParam>, _Result<TPage, TParam>>(
      source: query,
      initialResult: _initialResult,
      subscribe: _subscribe,
      debugKey: _debugKey,
      listener: listener,
      listenWhen: listenWhen,
      child: child,
    );
  }
}

/// An [InfiniteQueryBuilder] and [InfiniteQueryListener] in one.
class InfiniteQueryConsumer<TPage, TParam> extends StatelessWidget {
  const InfiniteQueryConsumer({
    super.key,
    required this.query,
    required this.builder,
    required this.listener,
    this.buildWhen,
    this.listenWhen,
  });

  final InfiniteQueryObserver<TPage, TParam> query;
  final ResultWidgetBuilder<InfiniteQueryResult<TPage, TParam>> builder;
  final ResultWidgetListener<InfiniteQueryResult<TPage, TParam>> listener;
  final ResultCondition<InfiniteQueryResult<TPage, TParam>>? buildWhen;
  final ResultCondition<InfiniteQueryResult<TPage, TParam>>? listenWhen;

  @override
  Widget build(BuildContext context) {
    return ResultSubscriber<_Observer<TPage, TParam>, _Result<TPage, TParam>>(
      source: query,
      initialResult: _initialResult,
      subscribe: _subscribe,
      debugKey: _debugKey,
      builder: builder,
      buildWhen: buildWhen,
      listener: listener,
      listenWhen: listenWhen,
    );
  }
}

/// Builds UI from a value selected from an infinite query's results, and
/// rebuilds only when that value changes.
///
/// ```dart
/// InfiniteQuerySelector(
///   query: posts,
///   selector: (state) => state.pages.fold(0, (n, page) => n + page.items.length),
///   builder: (context, count) => Text('$count posts'),
/// )
/// ```
class InfiniteQuerySelector<TPage, TParam, T> extends StatelessWidget {
  const InfiniteQuerySelector({
    super.key,
    required this.query,
    required this.selector,
    required this.builder,
  });

  final InfiniteQueryObserver<TPage, TParam> query;
  final T Function(InfiniteQueryResult<TPage, TParam> state) selector;
  final ResultWidgetBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    return ResultSelector<_Observer<TPage, TParam>, _Result<TPage, TParam>, T>(
      source: query,
      initialResult: _initialResult,
      subscribe: _subscribe,
      debugKey: _debugKey,
      selector: selector,
      builder: builder,
    );
  }
}

_Result<TPage, TParam> _initialResult<TPage, TParam>(
  _Observer<TPage, TParam> query,
) {
  return query.getOptimisticResult();
}

void Function() _subscribe<TPage, TParam>(
  _Observer<TPage, TParam> query,
  void Function(_Result<TPage, TParam>) listener,
) {
  return query.subscribe(
    (result) => listener(result as _Result<TPage, TParam>),
  );
}

String _debugKey<TPage, TParam>(InfiniteQueryObserver<TPage, TParam> query) =>
    hashKey(query.options.queryKey);
