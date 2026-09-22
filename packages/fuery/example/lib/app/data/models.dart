/// A post is `processing` right after it is created, while the server
/// prepares it, and `published` once it is visible to everyone.
enum PostStatus { processing, published }

class Post {
  const Post({
    required this.id,
    required this.author,
    required this.body,
    required this.likes,
    required this.liked,
    required this.commentCount,
    required this.status,
  });

  final int id;
  final String author;
  final String body;
  final int likes;
  final bool liked;
  final int commentCount;
  final PostStatus status;

  Post copyWith({
    int? likes,
    bool? liked,
    int? commentCount,
    PostStatus? status,
  }) {
    return Post(
      id: id,
      author: author,
      body: body,
      likes: likes ?? this.likes,
      liked: liked ?? this.liked,
      commentCount: commentCount ?? this.commentCount,
      status: status ?? this.status,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'author': author,
        'body': body,
        'likes': likes,
        'liked': liked,
        'commentCount': commentCount,
        'status': status.name,
      };

  /// Takes the value `jsonDecode` produced, so callers don't cast.
  factory Post.fromJson(Object? json) {
    final map = json! as Map<String, Object?>;
    return Post(
      id: map['id']! as int,
      author: map['author']! as String,
      body: map['body']! as String,
      likes: map['likes']! as int,
      liked: map['liked']! as bool,
      commentCount: map['commentCount']! as int,
      status: PostStatus.values.byName(map['status']! as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Post &&
      other.id == id &&
      other.author == author &&
      other.body == body &&
      other.likes == likes &&
      other.liked == liked &&
      other.commentCount == commentCount &&
      other.status == status;

  @override
  int get hashCode =>
      Object.hash(id, author, body, likes, liked, commentCount, status);
}

/// One page of the feed. [nextCursor] is null on the last page.
class PostPage {
  const PostPage({required this.posts, required this.nextCursor});

  final List<Post> posts;
  final int? nextCursor;

  Map<String, Object?> toJson() => {
        'posts': [for (final post in posts) post.toJson()],
        'nextCursor': nextCursor,
      };

  factory PostPage.fromJson(Object? json) {
    final map = json! as Map<String, Object?>;
    return PostPage(
      posts: [for (final post in map['posts']! as List) Post.fromJson(post)],
      nextCursor: map['nextCursor'] as int?,
    );
  }
}

class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.author,
    required this.body,
  });

  final int id;
  final int postId;
  final String author;
  final String body;
}

class FeedNotification {
  const FeedNotification({
    required this.id,
    required this.text,
    required this.read,
  });

  final int id;
  final String text;
  final bool read;

  FeedNotification copyWith({bool? read}) =>
      FeedNotification(id: id, text: text, read: read ?? this.read);
}
