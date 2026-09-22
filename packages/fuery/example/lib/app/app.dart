import 'package:example/app/screens/home/home_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

class FeedApp extends StatelessWidget {
  const FeedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fuery feed',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF6B4EFF)),
      // Shows the Fuery devtools button in debug and profile builds. The web
      // demo is a release build, so it turns them on with a define.
      builder: (context, child) => FueryDevtools(
        enabled: !kReleaseMode || const bool.fromEnvironment('fuery.demo'),
        // Out of the way of the navigation bar and the compose button.
        buttonAlignment: Alignment.centerRight,
        child: child!,
      ),
      home: const HomeShell(),
    );
  }
}
