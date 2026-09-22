import 'package:example/app/data/feed_mutations.dart';
import 'package:example/app/data/feed_queries.dart';
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

/// Notifications, refreshed every five seconds while the app is open. The
/// badge in the navigation bar reads the same query through a cubit.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final notifications = notificationsQuery();
  final markAllRead = markAllReadMutation();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return QueryBuilder(
      query: notifications,
      builder: (context, state) => switch (state) {
        QueryResult(:final data?) => Column(
            children: [
              ListTile(
                title: Text(
                  'Checks for new ones every 5 seconds while the app is open',
                  style: theme.textTheme.bodySmall,
                ),
                trailing: TextButton(
                  onPressed: data.any((notification) => !notification.read)
                      ? markAllRead.mutate
                      : null,
                  child: const Text('Mark all read'),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final notification in data)
                      ListTile(
                        leading: Icon(
                          notification.read
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                          color: notification.read
                              ? null
                              : theme.colorScheme.primary,
                        ),
                        title: Text(
                          notification.text,
                          style: notification.read
                              ? null
                              : const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        QueryResult(:final error?) => Center(child: Text('Error: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
