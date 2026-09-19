class AddTodoPayload {
  final String title;
  final String description;

  const AddTodoPayload({
    required this.title,
    required this.description,
  });

  AddTodoPayload copyWith({
    String? title,
    String? description,
  }) {
    return AddTodoPayload(
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
  String toString() =>
      'AddTodoPayload(title: $title, description: $description)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AddTodoPayload &&
        other.title == title &&
        other.description == description;
  }

  @override
  int get hashCode => title.hashCode ^ description.hashCode;
}
