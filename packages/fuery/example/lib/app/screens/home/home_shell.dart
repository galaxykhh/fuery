import 'package:example/app/screens/compose/compose_screen.dart';
import 'package:example/app/screens/feed/feed_screen.dart';
import 'package:example/app/screens/notifications/notifications_cubit.dart';
import 'package:example/app/screens/notifications/notifications_screen.dart';
import 'package:example/app/screens/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuery/fuery.dart';

/// The three tabs, with an unread badge on the notifications tab and an
/// airplane-mode switch in the app bar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static const String routeName = 'home';

  static Route route() {
    return MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => const HomeShell(),
    );
  }

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _titles = ['Feed', 'Search', 'Notifications'];

  int _tab = 0;
  bool _offline = false;

  // Any value computed from the client can be watched as a stream, without
  // fetching anything. This one drives the activity indicator.
  late final Stream<bool> _busy = Fuery.client.watch(
    (client) => client.isFetching() + client.isMutating() > 0,
  );

  // Reports connectivity to Fuery. A real app connects a connectivity plugin
  // in `main` instead; this switch stands in for airplane mode.
  void _toggleOffline() {
    setState(() => _offline = !_offline);
    onlineManager.setOnline(!_offline);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NotificationsCubit(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titles[_tab]),
          actions: [
            StreamBuilder(
              stream: _busy,
              builder: (context, snapshot) => SizedBox.square(
                dimension: 16,
                child: snapshot.data ?? false
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              tooltip: _offline ? 'Go online' : 'Go offline',
              onPressed: _toggleOffline,
              icon: Icon(_offline ? Icons.wifi_off : Icons.wifi),
            ),
          ],
        ),
        body: IndexedStack(
          index: _tab,
          children: const [
            FeedScreen(),
            SearchScreen(),
            NotificationsScreen(),
          ],
        ),
        floatingActionButton: _tab == 0
            ? FloatingActionButton(
                tooltip: 'Write a post',
                onPressed: () => Navigator.push(context, ComposeScreen.route()),
                child: const Icon(Icons.edit),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() => _tab = index),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Feed',
            ),
            const NavigationDestination(
              icon: Icon(Icons.search),
              label: 'Search',
            ),
            NavigationDestination(
              // The badge comes from a cubit over the notifications query, so
              // it and the notifications screen share one request.
              icon: BlocBuilder<NotificationsCubit, int>(
                builder: (context, unread) => Badge.count(
                  count: unread,
                  isLabelVisible: unread > 0,
                  child: const Icon(Icons.notifications_outlined),
                ),
              ),
              selectedIcon: const Icon(Icons.notifications),
              label: 'Notifications',
            ),
          ],
        ),
      ),
    );
  }
}
