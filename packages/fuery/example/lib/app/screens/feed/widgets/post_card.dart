import 'package:example/app/data/models.dart';
import 'package:flutter/material.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onOpen,
    this.onHover,
  });

  final Post post;
  final VoidCallback onLike;
  final VoidCallback onOpen;
  final VoidCallback? onHover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => onHover?.call(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.author, style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(post.body),
                const SizedBox(height: 4),
                Row(
                  children: [
                    IconButton(
                      tooltip: post.liked ? 'Unlike' : 'Like',
                      onPressed: onLike,
                      icon: Icon(
                        post.liked ? Icons.favorite : Icons.favorite_border,
                        color: post.liked ? theme.colorScheme.error : null,
                      ),
                    ),
                    Text('${post.likes}'),
                    const SizedBox(width: 16),
                    const Icon(Icons.mode_comment_outlined, size: 20),
                    const SizedBox(width: 6),
                    Text('${post.commentCount}'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
