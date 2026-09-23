import 'package:flutter/foundation.dart';

/// The ids of the posts the user opened, newest first. The search screen
/// shows them when nothing is typed, with one query per post.
final recentPosts = ValueNotifier<List<int>>(const []);

/// Moves [id] to the front of [recentPosts], keeping the last five.
void rememberPost(int id) {
  recentPosts.value = [
    id,
    ...recentPosts.value.where((recent) => recent != id),
  ].take(5).toList();
}
