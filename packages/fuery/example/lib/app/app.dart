import 'package:example/app/core/app_router.dart';
import 'package:example/app/screens/cases/cases_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

class TodoApp extends StatefulWidget {
  const TodoApp({super.key});

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  final AppRouter router = AppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Shows the Fuery devtools button in debug and profile builds. The web
      // demo is a release build, so it turns them on with a define.
      builder: (context, child) => FueryDevtools(
        enabled: !kReleaseMode || const bool.fromEnvironment('fuery.demo'),
        child: child!,
      ),
      onGenerateRoute: router.generateRoute,
      initialRoute: CasesScreen.routeName,
    );
  }
}
