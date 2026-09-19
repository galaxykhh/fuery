import 'package:flutter/widgets.dart';
import 'package:fuery_core/fuery_core.dart';

import 'result_subscriber.dart';

typedef _Observer<TPage, TParam> = InfiniteQueryObserver<TPage, TParam>;
typedef _Result<TPage, TParam> = InfiniteQueryResult<TPage, TParam>;

/// Builds UI from an infinite query, like `BlocBuilder`.
///
/// ```dart
/// InfiniteQueryBuilder(
///   query: posts,
///   builder: (context, state) => ListView(
///     children: [
///       for (final page in state.pages) ...page.items.map(PostTile.new),
///       if (state.hasNextPage)
///         TextButton(
///           onPressed: state.isFetchingNextPage ? null : posts.fetchNextPage,
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
      builder: builder,
      buildWhen: buildWhen,
    );
  }
}

/// Runs side effects when an infinite query changes, like `BlocListener`.
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
      listener: listener,
      listenWhen: listenWhen,
      child: child,
    );
  }
}

/// An [InfiniteQueryBuilder] and [InfiniteQueryListener] in one, like
/// `BlocConsumer`.
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
      builder: builder,
      buildWhen: buildWhen,
      listener: listener,
      listenWhen: listenWhen,
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
