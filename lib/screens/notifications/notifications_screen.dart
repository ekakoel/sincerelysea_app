import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sincerelysea/theme/app_semantic_colors.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/screens/post/shared_post_detail_screen.dart';
import 'package:sincerelysea/screens/profile/user_profile_preview_screen.dart';
import 'package:sincerelysea/services/notification_center_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final NotificationCenterService service = context
        .read<NotificationCenterService>();
    final AppSemanticColors semantic = context.semanticColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          TextButton(
            onPressed: () => service.markAllAsRead(),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.notificationsStream(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Failed to load notifications: ${snapshot.error}',
                  ),
                );
              }

              final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                  snapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              if (docs.isEmpty) {
                return const Center(child: Text('No notifications yet.'));
              }

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (BuildContext context, int index) =>
                    Divider(height: 1, color: semantic.divider),
                itemBuilder: (BuildContext context, int index) {
                  final Map<String, dynamic> data = docs[index].data();
                  final String actorUsername =
                      data['actorUsername']?.toString() ?? 'user';
                  final String type = data['type']?.toString() ?? 'activity';
                  final String message =
                      data['message']?.toString().trim().isNotEmpty == true
                      ? data['message'].toString()
                      : _defaultMessage(type, actorUsername);
                  final bool isRead = data['read'] == true;
                  final String? actorUid = data['actorUid']?.toString();
                  final String? postId = data['postId']?.toString();
                  final Color iconColor = isRead
                      ? semantic.notificationIconMuted
                      : semantic.notificationIcon;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isRead
                          ? semantic.badgeMuted
                          : semantic.badge,
                      child: Icon(_iconForType(type), size: 18, color: iconColor),
                    ),
                    title: Text(
                      message,
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(_timeLabel(data['createdAt'])),
                    onTap: () async {
                      await service.markAsRead(docs[index].id);
                      if (!context.mounted) {
                        return;
                      }
                      if (postId != null && postId.isNotEmpty) {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                SharedPostDetailScreen(postId: postId),
                          ),
                        );
                        return;
                      }
                      if (actorUid != null && actorUid.isNotEmpty) {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => UserProfilePreviewScreen(
                              userId: actorUid,
                              initialUsername: actorUsername,
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
      ),
    );
  }

  String _defaultMessage(String type, String actor) {
    switch (type) {
      case 'like':
        return '@$actor liked your post';
      case 'comment':
        return '@$actor commented on your post';
      case 'follow':
        return '@$actor started following you';
      case 'follow_request':
        return '@$actor requested to follow you';
      case 'share':
        return '@$actor shared your post';
      default:
        return '@$actor has new activity';
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite_outline;
      case 'comment':
        return Icons.chat_bubble_outline;
      case 'follow':
      case 'follow_request':
        return Icons.person_add_alt_1;
      case 'share':
        return Icons.ios_share;
      default:
        return Icons.notifications_none;
    }
  }

  String _timeLabel(dynamic timestamp) {
    if (timestamp is! Timestamp) {
      return 'Just now';
    }
    final Duration diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
