import 'package:example/app/screens/home/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

class FeedApp extends StatelessWidget {
  const FeedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fuery feed',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF6B4EFF)),
      // Shows the Fuery devtools button in debug and profile builds.
      builder: (context, child) => FueryDevtools(child: child!),
      home: const HomeShell(),
    );
  }
}
