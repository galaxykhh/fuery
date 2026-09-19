import 'package:example/app/data/todo.dart';
import 'package:flutter/material.dart';

class TodoListItem extends StatelessWidget {
  const TodoListItem({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onDelete,
  });

  final Todo todo;
  final void Function(Todo todo) onToggle;
  final void Function(Todo todo) onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const ColorScheme.light().background,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  todo.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Column(
            children: [
              GestureDetector(
                onTap: () => onToggle(todo),
                child: Text(
                  todo.isCompleted ? 'Done' : 'In Progress',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: todo.isCompleted
                            ? const ColorScheme.light().onBackground
                            : const ColorScheme.light().primary,
                      ),
                ),
              ),
              GestureDetector(
                child: IconButton(
                  onPressed: () => onDelete(todo),
                  icon: const Icon(
                    Icons.remove_circle,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
