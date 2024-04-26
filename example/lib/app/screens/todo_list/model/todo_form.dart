class TodoForm {
  final String title;
  final String description;

  const TodoForm({
    required this.title,
    required this.description,
  });

  TodoForm copyWith({
    String? title,
    String? description,
  }) {
    return TodoForm(
      title: title ?? this.title,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'title': title,
      'description': description,
    };
  }

  @override
  String toString() => 'TodoForm(title: $title, description: $description)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TodoForm &&
        other.title == title &&
        other.description == description;
  }

  @override
  int get hashCode => title.hashCode ^ description.hashCode;
}
