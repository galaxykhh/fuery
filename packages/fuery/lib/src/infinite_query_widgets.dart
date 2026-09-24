import 'package:flutter/widgets.dart';
import 'package:fuery_core/fuery_core.dart';

import 'result_subscriber.dart';

typedef _Source<TPage, TParam> = InfiniteQuerySource<TPage, TParam>;
typedef _Result<TPage, TParam> = InfiniteQueryResult<TPage, TParam>;

/// Builds UI from an infinite query.
///
/// [query] is an [InfiniteQuery] definition, or an observer that is already
/// shared. A definition can be built in `build`: the widget keeps one
/// observer for it.
///
/// ```dart
/// InfiniteQueryBuilder(
///   query: posts,
///   builder: (context, state) => ListView(
///     children: [
///       for (final page in state.pages) ...page.items.map(PostTile.new),
///       if (state.hasNextPage)
///         TextButton(
///           onPressed: state.isFetching ? null : state.fetchNextPage,
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

  final InfiniteQuerySource<TPage, TParam> query;
  final ResultWidgetBuilder<InfiniteQueryResult<TPage, TParam>> builder;
  final ResultCondition<InfiniteQueryResult<TPage, TParam>>? buildWhen;

  @override
  Widget build(BuildContext context) {
    return ResultSubscriber<_Source<TPage, TParam>, _Result<TPage, TParam>>(
      source: query,
      createSlot: InfiniteQuerySlot<TPage, TParam>.new,
      debugName: 'InfiniteQueryBuilder',
      debugKey: debugSameKey(_observerKey),
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

  final InfiniteQuerySource<TPage, TParam> query;
  final ResultWidgetListener<InfiniteQueryResult<TPage, TParam>> listener;
  final ResultCondition<InfiniteQueryResult<TPage, TParam>>? listenWhen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ResultSubscriber<_Source<TPage, TParam>, _Result<TPage, TParam>>(
      source: query,
      createSlot: InfiniteQuerySlot<TPage, TParam>.new,
      debugName: 'InfiniteQueryListener',
      debugKey: debugSameKey(_observerKey),
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

  final InfiniteQuerySource<TPage, TParam> query;
  final ResultWidgetBuilder<InfiniteQueryResult<TPage, TParam>> builder;
  final ResultWidgetListener<InfiniteQueryResult<TPage, TParam>> listener;
  final ResultCondition<InfiniteQueryResult<TPage, TParam>>? buildWhen;
  final ResultCondition<InfiniteQueryResult<TPage, TParam>>? listenWhen;

  @override
  Widget build(BuildContext context) {
    return ResultSubscriber<_Source<TPage, TParam>, _Result<TPage, TParam>>(
      source: query,
      createSlot: InfiniteQuerySlot<TPage, TParam>.new,
      debugName: 'InfiniteQueryConsumer',
      debugKey: debugSameKey(_observerKey),
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

  final InfiniteQuerySource<TPage, TParam> query;
  final T Function(InfiniteQueryResult<TPage, TParam> state) selector;
  final ResultWidgetBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    return ResultSelector<_Source<TPage, TParam>, _Result<TPage, TParam>, T>(
      source: query,
      createSlot: InfiniteQuerySlot<TPage, TParam>.new,
      debugName: 'InfiniteQuerySelector',
      debugKey: debugSameKey(_observerKey),
      selector: selector,
      builder: builder,
    );
  }
}

String? _observerKey<TPage, TParam>(InfiniteQuerySource<TPage, TParam> query) {
  return query is InfiniteQueryObserver<TPage, TParam>
      ? hashKey(query.options.queryKey)
      : null;
}
