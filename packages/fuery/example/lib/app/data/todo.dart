class Todo {
  final int id;
  final String title;
  final String description;
  final bool isCompleted;

  const Todo({
    required this.id,
    required this.title,
    required this.description,
    required this.isCompleted,
  });

  Todo copyWith({
    int? id,
    String? title,
    String? description,
    bool? isCompleted,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
    };
  }

  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'] ?? 0,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  /// Takes the value `jsonDecode` produced, so callers don't cast.
  factory Todo.fromJson(Object? json) =>
      Todo.fromMap(json! as Map<String, dynamic>);

  @override
  String toString() {
    return 'Todo(id: $id, title: $title, description: $description, isCompleted: $isCompleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Todo &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.isCompleted == isCompleted;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        description.hashCode ^
        isCompleted.hashCode;
  }
}
