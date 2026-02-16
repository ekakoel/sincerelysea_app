import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/services/post_service.dart';

class SharedPostDetailScreen extends StatelessWidget {
  const SharedPostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context) {
    final PostService postService = context.read<PostService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Shared Post')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: postService.getPost(postId),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Failed to load post: ${snapshot.error}'),
                );
              }
              final Map<String, dynamic>? data = snapshot.data?.data();
              if (data == null) {
                return const Center(child: Text('Post not found.'));
              }

              final String username =
                  data['username']?.toString() ?? 'Anonymous';
              final String content = data['content']?.toString() ?? '';
              final String imageUrl = data['imageUrl']?.toString() ?? '';
              final String location = data['location']?.toString() ?? '-';
              final List<dynamic> hashtags =
                  data['hashtags'] as List<dynamic>? ?? <dynamic>[];
              final int likeCount =
                  (data['likes'] as List<dynamic>? ?? <dynamic>[]).length;
              final int commentCount = data['commentCount'] as int? ?? 0;
              final int shareCount = data['shareCount'] as int? ?? 0;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Text(
                    '@$username',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (BuildContext context, String _) =>
                            Container(
                              color: AppColors.gray200,
                              height: 260,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        errorWidget:
                            (BuildContext context, String _, Object error) =>
                                Container(
                                  color: AppColors.gray200,
                                  height: 260,
                                  child: const Center(
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    content.isEmpty ? 'No caption' : content,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Location: $location',
                    style: TextStyle(color: AppColors.gray700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: hashtags
                        .map(
                          (dynamic tag) => Chip(
                            label: Text(tag.toString()),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      _MetricChip(label: 'Likes', value: likeCount),
                      const SizedBox(width: 8),
                      _MetricChip(label: 'Comments', value: commentCount),
                      const SizedBox(width: 8),
                      _MetricChip(label: 'Shares', value: shareCount),
                    ],
                  ),
                ],
              );
            },
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gray200),
        ),
        child: Column(
          children: <Widget>[
            Text(
              value.toString(),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.gray700),
            ),
          ],
        ),
      ),
    );
  }
}
