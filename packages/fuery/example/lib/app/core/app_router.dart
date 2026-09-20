import 'package:example/app/screens/cases/cases_screen.dart';
import 'package:example/app/screens/todo_list/todo_list.dart';
import 'package:example/app/screens/todo_stats/todo_stats.dart';
import 'package:flutter/material.dart';

class AppRouter {
  Route? generateRoute(RouteSettings settings) {
    return switch (settings.name) {
      TodoListScreen.routeName => TodoListScreen.route(),
      TodoStatsScreen.routeName => TodoStatsScreen.route(),
      _ => CasesScreen.route(),
    };
  }
}
