import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/services/follow_service.dart';
import 'package:sincerelysea/services/moderation_service.dart';
import 'package:sincerelysea/services/post_service.dart';
import 'package:sincerelysea/widgets/app_check_network_image.dart';

class UserProfilePreviewScreen extends StatelessWidget {
  const UserProfilePreviewScreen({
    super.key,
    required this.userId,
    required this.initialUsername,
  });

  final String userId;
  final String initialUsername;

  @override
  Widget build(BuildContext context) {
    final User? currentUser = context.watch<User?>();
    final bool isSelf = currentUser != null && currentUser.uid == userId;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> data =
                snapshot.data?.data() ?? <String, dynamic>{};
            final String username =
                data['username']?.toString().isNotEmpty == true
                ? data['username']!.toString()
                : initialUsername;
            final String displayName =
                data['displayName']?.toString().isNotEmpty == true
                ? data['displayName']!.toString()
                : username;
            final String bio = data['bio']?.toString() ?? '';
            final String? photoUrl = data['photoUrl']?.toString();
            final bool isPrivate = data['isPrivate'] == true;
            final bool isAdmin =
                <String>{'admin', 'developer'}.contains(
                  data['role']?.toString().trim().toLowerCase(),
                );

            return Scaffold(
              appBar: AppBar(
                title: Text('@$username'),
                actions: <Widget>[
                  if (!isSelf)
                    StreamBuilder<bool>(
                      stream: context
                          .read<ModerationService>()
                          .isUserBlockedStream(userId),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<bool> blockSnapshot,
                          ) {
                            final bool isBlocked = blockSnapshot.data ?? false;
                            return PopupMenuButton<String>(
                              onSelected: (String value) async {
                                if (value == 'report') {
                                  await context
                                      .read<ModerationService>()
                                      .reportUser(
                                        targetUid: userId,
                                        reason: 'Reported from user profile',
                                      );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('User reported'),
                                      ),
                                    );
                                  }
                                } else if (value == 'block') {
                                  await context
                                      .read<ModerationService>()
                                      .blockUser(
                                        targetUid: userId,
                                        targetUsername: username,
                                      );
                                } else if (value == 'unblock') {
                                  await context
                                      .read<ModerationService>()
                                      .unblockUser(userId);
                                }
                              },
                              itemBuilder: (BuildContext context) =>
                                  <PopupMenuEntry<String>>[
                                    const PopupMenuItem<String>(
                                      value: 'report',
                                      child: Text('Report user'),
                                    ),
                                    PopupMenuItem<String>(
                                      value: isBlocked ? 'unblock' : 'block',
                                      child: Text(
                                        isBlocked
                                            ? 'Unblock user'
                                            : 'Block user',
                                      ),
                                    ),
                                  ],
                            );
                          },
                    ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      AppCheckAvatar(
                        radius: 40,
                        backgroundColor: AppColors.gray300,
                        imageUrl: photoUrl,
                        fallback: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (isAdmin) ...<Widget>[
                                  const SizedBox(width: 8),
                                  const _ProfileRoleBadge(label: 'ADMIN'),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@$username',
                              style: TextStyle(color: AppColors.gray700),
                            ),
                            if (bio.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 8),
                              Text(
                                bio,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.gray800),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _StatsRow(userId: userId),
                  const SizedBox(height: 12),
                  if (!isSelf)
                    _FollowButton(targetUid: userId, targetUsername: username),
                  const SizedBox(height: 16),
                  const Text(
                    'Posts',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (isSelf || !isPrivate)
                    _UserPostsGrid(userId: userId)
                  else
                    StreamBuilder<bool>(
                      stream: context.read<FollowService>().isFollowingStream(
                        userId,
                      ),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<bool> followingSnapshot,
                          ) {
                            if (followingSnapshot.data == true) {
                              return _UserPostsGrid(userId: userId);
                            }
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.gray100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.gray300),
                              ),
                              child: const Text(
                                'This account is private. Follow to see posts.',
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                    ),
                ],
              ),
            );
          },
    );
  }
}

class _ProfileRoleBadge extends StatelessWidget {
  const _ProfileRoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _FollowButton extends StatefulWidget {
  const _FollowButton({required this.targetUid, required this.targetUsername});

  final String targetUid;
  final String targetUsername;

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final FollowService followService = context.read<FollowService>();
    return StreamBuilder<bool>(
      stream: followService.isFollowingStream(widget.targetUid),
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        final bool isFollowing = snapshot.data ?? false;
        return StreamBuilder<bool>(
          stream: followService.isFollowRequestedStream(widget.targetUid),
          builder: (BuildContext context, AsyncSnapshot<bool> requestSnapshot) {
            final bool isRequested = requestSnapshot.data ?? false;
            return StreamBuilder<bool>(
              stream: followService.isFollowingYouStream(widget.targetUid),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<bool> followBackSnapshot,
                  ) {
                    final bool isFollowingYou =
                        followBackSnapshot.data ?? false;
                    final String followLabel = isRequested
                        ? 'Requested'
                        : (isFollowingYou ? 'Follow back' : 'Follow');
                    return SizedBox(
                      height: 42,
                      child: isFollowing
                          ? OutlinedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () async {
                                      setState(() => _isSubmitting = true);
                                      try {
                                        await followService.unfollowUser(
                                          widget.targetUid,
                                        );
                                      } catch (e) {
                                        if (!context.mounted) {
                                          return;
                                        }
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Failed: $e')),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isSubmitting = false);
                                        }
                                      }
                                    },
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Unfollow'),
                            )
                          : FilledButton(
                              onPressed: _isSubmitting || isRequested
                                  ? null
                                  : () async {
                                      setState(() => _isSubmitting = true);
                                      try {
                                        await followService.followUser(
                                          targetUid: widget.targetUid,
                                          targetUsername: widget.targetUsername,
                                        );
                                      } catch (e) {
                                        if (!context.mounted) {
                                          return;
                                        }
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Failed: $e')),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isSubmitting = false);
                                        }
                                      }
                                    },
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.white,
                                      ),
                                    )
                                  : Text(followLabel),
                            ),
                    );
                  },
            );
          },
        );
      },
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final PostService postService = context.read<PostService>();
    final FollowService followService = context.read<FollowService>();

    return Row(
      children: <Widget>[
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: postService.getUserPosts(userId),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                ) {
                  return _StatChip(
                    label: 'Posts',
                    value: snapshot.data?.docs.length ?? 0,
                  );
                },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: followService.followersStream(userId),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                ) {
                  return _StatChip(
                    label: 'Followers',
                    value: snapshot.data?.docs.length ?? 0,
                  );
                },
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(label, style: TextStyle(color: AppColors.gray700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _UserPostsGrid extends StatelessWidget {
  const _UserPostsGrid({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final PostService postService = context.read<PostService>();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: postService.getUserPosts(userId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('Failed to load posts: ${snapshot.error}'),
              );
            }
            final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                  snapshot.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                );
            docs.sort((a, b) {
              final Timestamp? aTs = a.data()['timestamp'] as Timestamp?;
              final Timestamp? bTs = b.data()['timestamp'] as Timestamp?;
              if (aTs == null && bTs == null) {
                return 0;
              }
              if (aTs == null) {
                return 1;
              }
              if (bTs == null) {
                return -1;
              }
              return bTs.compareTo(aTs);
            });
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text('No posts yet'),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 1,
              ),
              itemBuilder: (BuildContext context, int index) {
                final String imageUrl =
                    docs[index].data()['imageUrl']?.toString() ?? '';
                if (imageUrl.isEmpty) {
                  return Container(
                    color: AppColors.gray200,
                    child: const Icon(Icons.image_not_supported_outlined),
                  );
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppCheckCachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: AppColors.gray200,
                      child: const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    error: Container(
                      color: AppColors.gray200,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                );
              },
            );
          },
    );
  }
}
