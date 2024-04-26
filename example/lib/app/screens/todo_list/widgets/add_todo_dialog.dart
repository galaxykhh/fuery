import 'package:example/app/data/payloads/add_todo_payload.dart';
import 'package:flutter/material.dart';

class AddTodoDialog extends StatefulWidget {
  const AddTodoDialog._({required this.onSubmit});

  final void Function(AddTodoPayload payload) onSubmit;

  static show(
    BuildContext context, {
    required void Function(AddTodoPayload payload) onSubmit,
  }) {
    return showDialog(
      context: context,
      builder: (context) {
        return AddTodoDialog._(onSubmit: onSubmit);
      },
    );
  }

  @override
  State<AddTodoDialog> createState() => _AddTodoDialogState();
}

class _AddTodoDialogState extends State<AddTodoDialog> {
  AddTodoPayload payload = const AddTodoPayload(
    title: '',
    description: '',
  );

  void setPayload(AddTodoPayload payload) {
    setState(() => this.payload = payload);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add your task',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextField(
              style: Theme.of(context).textTheme.bodyMedium,
              onChanged: (value) => setPayload(payload.copyWith(title: value)),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.zero,
                hintText: 'Title',
              ),
            ),
            TextField(
              style: Theme.of(context).textTheme.bodyMedium,
              onChanged: (value) => setPayload(
                payload.copyWith(description: value),
              ),
              keyboardType: TextInputType.multiline,
              minLines: 1,
              maxLines: 2,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.zero,
                hintText: 'Description',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onSubmit(payload);
                  },
                  child: const Text('ADD'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
