import 'dart:async';

import 'package:example/app/data/feed_queries.dart';
import 'package:example/app/data/models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuery/fuery.dart';

/// The unread count for the navigation bar badge, from the same query the
/// notifications screen shows. Listening to the stream is what starts the
/// polling, and the cubit sees every change the screen makes.
class NotificationsCubit extends Cubit<int> {
  NotificationsCubit({QueryObserver<List<FeedNotification>>? notifications})
      : _notifications = notifications ?? notificationsOptions().observe(),
        super(0) {
    _subscription = _notifications.stream.listen(_onResult);
  }

  final QueryObserver<List<FeedNotification>> _notifications;
  late final StreamSubscription<QueryResult<List<FeedNotification>>>
      _subscription;

  void _onResult(QueryResult<List<FeedNotification>> result) {
    final notifications = result.data ?? const <FeedNotification>[];
    emit(notifications.where((notification) => !notification.read).length);
  }

  @override
  Future<void> close() {
    // Not awaited: the future never completes under `testWidgets`.
    _subscription.cancel();
    return super.close();
  }
}
