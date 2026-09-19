import 'package:example/app/screens/todo_list/todo_list.dart';
import 'package:flutter/material.dart';

class AppRouter {
  Route? generateRoute(RouteSettings settings) {
    return TodoListScreen.route();
  }
}
