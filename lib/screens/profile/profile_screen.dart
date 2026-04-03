import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:sincerelysea/theme/app_semantic_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/l10n/app_localizations.dart';
import 'package:sincerelysea/screens/product/product_detail_screen.dart';
import 'package:sincerelysea/screens/profile/profile_settings_menu_screen.dart';
import 'package:sincerelysea/services/auth_service.dart';
import 'package:sincerelysea/services/follow_service.dart';
import 'package:sincerelysea/services/post_service.dart';
import 'package:sincerelysea/services/theme_service.dart';
import 'package:sincerelysea/services/user_profile_service.dart';
import 'package:sincerelysea/services/wishlist_service.dart';
import 'package:sincerelysea/utils/post_location_label.dart';
import 'package:sincerelysea/widgets/app_check_network_image.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingAvatar = false;

  Future<void> _pickAndUploadProfileImage(User user) async {
    final UserProfileService profileService = context
        .read<UserProfileService>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }

    setState(() => _isUploadingAvatar = true);
    try {
      final File imageFile = File(picked.path);
      await profileService.uploadProfilePhoto(imageFile);

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Profile image updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to update profile image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = context.watch<User?>();
    final AuthService authService = context.read<AuthService>();
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to see your profile.')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> profileData =
                snapshot.data?.data() ?? <String, dynamic>{};
            final String username =
                profileData['username']?.toString() ??
                _emailPrefix(currentUser.email).toLowerCase();
            final ColorScheme colorScheme = Theme.of(context).colorScheme;
            final AppSemanticColors semantic = context.semanticColors;

            return DefaultTabController(
              length: 3,
              child: Scaffold(
                backgroundColor: colorScheme.surface,
                body: NestedScrollView(
                  headerSliverBuilder:
                      (BuildContext context, bool innerBoxIsScrolled) {
                        return <Widget>[
                          SliverAppBar(
                            pinned: true,
                            expandedHeight: 440,
                            backgroundColor: colorScheme.surface,
                            surfaceTintColor: AppColors.transparent,
                            title: Text('@$username'),
                            leading: IconButton(
                              icon: Icon(
                                context.watch<ThemeService>().isDarkMode
                                    ? Icons.dark_mode_outlined
                                    : Icons.light_mode_outlined,
                                size: 22,
                              ),
                              tooltip: 'Toggle theme',
                              onPressed: () => context
                                  .read<ThemeService>()
                                  .toggleThemeMode(),
                            ),
                            actions: <Widget>[
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.settings_outlined),
                                onSelected: (String value) =>
                                    _onSettingsSelected(value, authService),
                                itemBuilder: (BuildContext context) =>
                                    const <PopupMenuEntry<String>>[
                                      PopupMenuItem<String>(
                                        value: 'settings',
                                        child: Text('Settings'),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'logout',
                                        child: Text('Log out'),
                                      ),
                                    ],
                              ),
                            ],
                            flexibleSpace: FlexibleSpaceBar(
                              collapseMode: CollapseMode.parallax,
                              background: SafeArea(
                                bottom: false,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    68,
                                    20,
                                    6,
                                  ),
                                  child: _ProfileHeader(
                                    user: currentUser,
                                    userId: currentUser.uid,
                                    profileData: profileData,
                                    isUploadingAvatar: _isUploadingAvatar,
                                    onTapAvatar: () =>
                                        _pickAndUploadProfileImage(currentUser),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _TabBarSliverDelegate(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  border: Border(
                                    top: BorderSide(color: semantic.divider),
                                    bottom: BorderSide(color: semantic.divider),
                                  ),
                                ),
                                child: TabBar(
                                  indicatorColor: colorScheme.primary,
                                  indicatorWeight: 2.4,
                                  labelColor: colorScheme.onSurface,
                                  unselectedLabelColor: colorScheme.onSurface
                                      .withValues(alpha: 0.65),
                                  tabs: const <Tab>[
                                    Tab(
                                      icon: Icon(Icons.shopping_bag_outlined),
                                      text: 'COLLECTIONS',
                                    ),
                                    Tab(
                                      icon: Icon(Icons.camera_alt_outlined),
                                      text: 'POSTS',
                                    ),
                                    Tab(
                                      icon: Icon(Icons.favorite_border),
                                      text: 'WISHLIST',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ];
                      },
                  body: TabBarView(
                    children: <Widget>[
                      _CollectionsTab(userId: currentUser.uid),
                      _UserPostGrid(userId: currentUser.uid),
                      _WishlistManager(userId: currentUser.uid),
                    ],
                  ),
                ),
              ),
            );
          },
    );
  }

  void _onSettingsSelected(String value, AuthService authService) {
    if (value == 'settings') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const ProfileSettingsMenuScreen(),
        ),
      );
      return;
    }
    if (value == 'logout') {
      showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Log out'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                authService.signOut();
              },
              child: const Text('Log out'),
            ),
          ],
        ),
      );
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.userId,
    required this.profileData,
    required this.isUploadingAvatar,
    required this.onTapAvatar,
  });

  final User user;
  final String userId;
  final Map<String, dynamic> profileData;
  final bool isUploadingAvatar;
  final VoidCallback onTapAvatar;

  @override
  Widget build(BuildContext context) {
    final String displayName =
        profileData['displayName']?.toString() ??
        user.displayName ??
        _emailPrefix(user.email);
    final String bio = profileData['bio']?.toString().trim() ?? '';
    final String username =
        profileData['username']?.toString() ??
        _emailPrefix(user.email).toLowerCase();
    final bool isAdmin =
        profileData['role']?.toString().trim().toLowerCase() == 'admin';
    final String? avatarUrl =
        profileData['photoUrl']?.toString().isNotEmpty == true
        ? profileData['photoUrl']?.toString()
        : user.photoURL;

    return Column(
      children: <Widget>[
        GestureDetector(
          onTap: isUploadingAvatar ? null : onTapAvatar,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              AppCheckAvatar(
                radius: 72,
                backgroundColor: AppColors.gray300,
                imageUrl: avatarUrl,
                fallback: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black54,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 4,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.black,
                  child: isUploadingAvatar
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: AppColors.white,
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  fontFamily: 'serif',
                ),
              ),
            ),
            if (isAdmin) ...<Widget>[
              const SizedBox(width: 8),
              const _ProfileRoleBadge(label: 'ADMIN'),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '@$username',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.gray700,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (bio.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            bio,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.35),
          ),
        ],
        const SizedBox(height: 14),
        _ProfileStatsRow(userId: userId),
      ],
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

class _TabBarSliverDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarSliverDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 72;

  @override
  double get maxExtent => 72;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _TabBarSliverDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _ProfileStatsRow extends StatelessWidget {
  const _ProfileStatsRow({required this.userId});

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
                  final int count = snapshot.data?.docs.length ?? 0;
                  return _StatItem(label: 'Posts', value: count);
                },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: followService.followersStream(userId),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                ) {
                  final int count = snapshot.data?.docs.length ?? 0;
                  return _StatItem(label: 'Followers', value: count);
                },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: followService.followingStream(userId),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                ) {
                  final int count = snapshot.data?.docs.length ?? 0;
                  return _StatItem(label: 'Following', value: count);
                },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('collections')
                .snapshots(),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                ) {
                  final int count = snapshot.data?.docs.length ?? 0;
                  return _StatItem(label: 'Collections', value: count);
                },
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.gray700)),
      ],
    );
  }
}

class _CollectionsTab extends StatelessWidget {
  const _CollectionsTab({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('collections')
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Failed to load collections: ${snapshot.error}'),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                  snapshot.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                );

            if (docs.isEmpty) {
              return const Center(
                child: Text('No collections yet. Add products you own first.'),
              );
            }

            docs.sort((a, b) {
              final Timestamp? tsA = a.data()['createdAt'] as Timestamp?;
              final Timestamp? tsB = b.data()['createdAt'] as Timestamp?;
              if (tsA == null && tsB == null) {
                return 0;
              }
              if (tsA == null) {
                return 1;
              }
              if (tsB == null) {
                return -1;
              }
              return tsB.compareTo(tsA);
            });

            final _ThumbnailConfig thumbConfig = _ThumbnailConfig.fromContext(
              context,
            );

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
              cacheExtent: 900,
              itemCount: docs.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.86,
              ),
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> data = docs[index].data();
                final String imageUrl =
                    data['imageUrl']?.toString() ??
                    data['thumbnailUrl']?.toString() ??
                    '';
                final String title =
                    data['title']?.toString() ??
                    data['name']?.toString() ??
                    data['content']?.toString() ??
                    'SincerelySea Product';
                final String? postId = data['postId']?.toString();

                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Material(
                    color: AppColors.transparent,
                    child: InkWell(
                      onTap: () async {
                        if (postId != null && postId.isNotEmpty) {
                          final DocumentSnapshot<Map<String, dynamic>> postDoc =
                              await FirebaseFirestore.instance
                                  .collection('posts')
                                  .doc(postId)
                                  .get();
                          if (context.mounted &&
                              postDoc.exists &&
                              postDoc.data() != null) {
                            final Map<String, dynamic> postData = postDoc
                                .data()!;
                            final int likeCount =
                                (postData['likes'] as List<dynamic>? ??
                                        <dynamic>[])
                                    .length;
                            final int commentCount =
                                postData['commentCount'] as int? ?? 0;
                            final int shareCount =
                                postData['shareCount'] as int? ?? 0;
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              builder: (BuildContext context) =>
                                  _PostDetailSheet(
                                    data: postData,
                                    likeCount: likeCount,
                                    commentCount: commentCount,
                                    shareCount: shareCount,
                                  ),
                            );
                            return;
                          }
                        }

                        if (!context.mounted) {
                          return;
                        }
                        showModalBottomSheet<void>(
                          context: context,
                          builder: (BuildContext context) {
                            final String description =
                                data['description']?.toString() ??
                                data['notes']?.toString() ??
                                '-';
                            final String price =
                                data['price']?.toString() ?? '-';
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                24,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Price: $price'),
                                  const SizedBox(height: 4),
                                  Text('Description: $description'),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      child: Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: _ProfilePostImage(
                              imageUrl: imageUrl,
                              thumbConfig: thumbConfig,
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              color: AppColors.black.withValues(alpha: 0.33),
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
    );
  }
}

class _UserPostGrid extends StatelessWidget {
  const _UserPostGrid({required this.userId});

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
            if (snapshot.hasError) {
              return Center(
                child: Text('Failed to load posts: ${snapshot.error}'),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                  snapshot.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                );
            docs.sort((a, b) {
              final Timestamp? tsA = a.data()['timestamp'] as Timestamp?;
              final Timestamp? tsB = b.data()['timestamp'] as Timestamp?;
              if (tsA == null && tsB == null) {
                return 0;
              }
              if (tsA == null) {
                return 1;
              }
              if (tsB == null) {
                return -1;
              }
              return tsB.compareTo(tsA);
            });
            if (docs.isEmpty) {
              return const Center(child: Text('No posts yet.'));
            }

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
              cacheExtent: 900,
              itemCount: docs.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.86,
              ),
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> data = docs[index].data();
                final String imageUrl = data['imageUrl']?.toString() ?? '';
                final String caption = data['content']?.toString() ?? '';
                final int likeCount =
                    (data['likes'] as List<dynamic>? ?? <dynamic>[]).length;
                final int commentCount = data['commentCount'] as int? ?? 0;
                final int shareCount = data['shareCount'] as int? ?? 0;
                final _ThumbnailConfig thumbConfig =
                    _ThumbnailConfig.fromContext(context);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Material(
                    color: AppColors.transparent,
                    child: InkWell(
                      onTap: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (BuildContext context) => _PostDetailSheet(
                            data: data,
                            likeCount: likeCount,
                            commentCount: commentCount,
                            shareCount: shareCount,
                          ),
                        );
                      },
                      child: Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: _ProfilePostImage(
                              imageUrl: imageUrl,
                              thumbConfig: thumbConfig,
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              color: AppColors.black.withValues(alpha: 0.33),
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                caption.isEmpty ? 'No caption' : caption,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
    );
  }
}

class _ProfilePostImage extends StatefulWidget {
  const _ProfilePostImage({required this.imageUrl, required this.thumbConfig});

  final String imageUrl;
  final _ThumbnailConfig thumbConfig;

  @override
  State<_ProfilePostImage> createState() => _ProfilePostImageState();
}

class _ProfilePostImageState extends State<_ProfilePostImage> {
  Timer? _timeoutTimer;
  bool _timedOut = false;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _startTimeoutWatchdog();
  }

  @override
  void didUpdateWidget(covariant _ProfilePostImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _timedOut = false;
      _retryCount = 0;
      _startTimeoutWatchdog();
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startTimeoutWatchdog() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted) {
        return;
      }
      setState(() => _timedOut = true);
    });
  }

  void _markLoadDone() {
    _timeoutTimer?.cancel();
  }

  void _retry() {
    setState(() {
      _timedOut = false;
      _retryCount += 1;
    });
    _startTimeoutWatchdog();
  }

  bool _isValidImageUrl(String value) {
    final Uri? uri = Uri.tryParse(value.trim());
    if (uri == null) {
      return false;
    }
    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Widget _fallback({
    required IconData icon,
    required String message,
    bool canRetry = false,
  }) {
    return Container(
      color: AppColors.gray200,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: AppColors.gray700),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.gray700),
          ),
          if (canRetry) ...<Widget>[
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _retry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String cleanUrl = widget.imageUrl.trim();
    if (cleanUrl.isEmpty) {
      return _fallback(
        icon: Icons.image_not_supported_outlined,
        message: AppLocalizations.of(context).emptyImageUrl,
      );
    }
    if (!_isValidImageUrl(cleanUrl)) {
      return _fallback(
        icon: Icons.link_off_outlined,
        message: AppLocalizations.of(context).invalidImageUrl,
      );
    }
    if (_timedOut) {
      return _fallback(
        icon: Icons.wifi_tethering_error_rounded,
        message: 'Image timeout',
        canRetry: true,
      );
    }

    return AppCheckCachedNetworkImage(
      imageKey: ValueKey<String>('${cleanUrl}_$_retryCount'),
      imageUrl: cleanUrl,
      fit: BoxFit.cover,
      memCacheWidth: widget.thumbConfig.memWidth,
      memCacheHeight: widget.thumbConfig.memHeight,
      maxWidthDiskCache: widget.thumbConfig.diskWidth,
      maxHeightDiskCache: widget.thumbConfig.diskHeight,
      filterQuality: FilterQuality.low,
      fadeInDuration: const Duration(milliseconds: 180),
      imageBuilder: (BuildContext context, ImageProvider imageProvider) {
        _markLoadDone();
        return Image(image: imageProvider, fit: BoxFit.cover);
      },
      placeholder: Container(
        color: AppColors.gray200,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      onError: _markLoadDone,
      error: _fallback(
        icon: Icons.broken_image_outlined,
        message: AppLocalizations.of(context).failedToLoadImage,
        canRetry: true,
      ),
    );
  }
}

class _ThumbnailConfig {
  const _ThumbnailConfig({
    required this.memWidth,
    required this.memHeight,
    required this.diskWidth,
    required this.diskHeight,
  });

  final int memWidth;
  final int memHeight;
  final int diskWidth;
  final int diskHeight;

  static _ThumbnailConfig fromContext(BuildContext context) {
    const int crossAxisCount = 2;
    const double horizontalPadding = 24;
    const double spacing = 12;
    const double aspectRatio = 0.86;
    final double logicalWidth =
        (MediaQuery.of(context).size.width -
            horizontalPadding -
            (spacing * (crossAxisCount - 1))) /
        crossAxisCount;
    final double logicalHeight = logicalWidth / aspectRatio;
    final double dpr = MediaQuery.of(context).devicePixelRatio;
    final int targetW = (logicalWidth * dpr).round().clamp(200, 1200);
    final int targetH = (logicalHeight * dpr).round().clamp(220, 1400);

    return _ThumbnailConfig(
      memWidth: targetW,
      memHeight: targetH,
      diskWidth: targetW,
      diskHeight: targetH,
    );
  }
}

class _PostDetailSheet extends StatelessWidget {
  const _PostDetailSheet({
    required this.data,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
  });

  final Map<String, dynamic> data;
  final int likeCount;
  final int commentCount;
  final int shareCount;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = data['imageUrl']?.toString() ?? '';
    final String caption = data['content']?.toString() ?? '';
    final String location = data['location']?.toString() ?? '-';
    final List<dynamic> hashtags =
        data['hashtags'] as List<dynamic>? ?? <dynamic>[];
    final int totalEngagement = likeCount + commentCount + shareCount;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) =>
          Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              controller: scrollController,
              children: <Widget>[
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AppCheckCachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 250,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        height: 250,
                        color: AppColors.gray200,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: Container(
                        height: 250,
                        color: AppColors.gray200,
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Text(
                  caption.isEmpty ? 'No caption' : caption,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<String>(
                  future: resolvePostLocationLabel(data),
                  builder:
                      (BuildContext context, AsyncSnapshot<String> snapshot) {
                        final String resolved =
                            snapshot.data?.trim().isNotEmpty == true
                            ? snapshot.data!.trim()
                            : location;
                        return Text(
                          'Location: $resolved',
                          style: TextStyle(color: AppColors.gray700),
                        );
                      },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: hashtags
                      .map(
                        (dynamic tag) => Chip(
                          label: Text(tag.toString()),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Insights',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _InsightBox(
                        label: 'Likes',
                        value: likeCount.toString(),
                        icon: Icons.favorite_border,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InsightBox(
                        label: 'Comments',
                        value: commentCount.toString(),
                        icon: Icons.chat_bubble_outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InsightBox(
                        label: 'Shares',
                        value: shareCount.toString(),
                        icon: Icons.send_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _InsightBox(
                  label: 'Total Engagement',
                  value: totalEngagement.toString(),
                  icon: Icons.insights_outlined,
                ),
              ],
            ),
          ),
    );
  }
}

class _InsightBox extends StatelessWidget {
  const _InsightBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: AppColors.gray700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _WishlistManager extends StatefulWidget {
  const _WishlistManager({required this.userId});

  final String userId;

  @override
  State<_WishlistManager> createState() => _WishlistManagerState();
}

class _WishlistManagerState extends State<_WishlistManager> {
  final Set<String> _processingIds = <String>{};

  Future<void> _showWishlistForm({
    QueryDocumentSnapshot<Map<String, dynamic>>? existingDoc,
  }) async {
    final Map<String, dynamic> existingData =
        existingDoc?.data() ?? <String, dynamic>{};
    final TextEditingController titleController = TextEditingController(
      text: existingData['title']?.toString() ?? '',
    );
    final TextEditingController notesController = TextEditingController(
      text: existingData['notes']?.toString() ?? '',
    );
    final TextEditingController categoryController = TextEditingController(
      text: existingData['category']?.toString() ?? '',
    );
    DateTime? targetDate = (existingData['targetDate'] as Timestamp?)?.toDate();
    int priority = (existingData['priority'] as int?)?.clamp(1, 3) ?? 2;
    bool isSaving = false;
    final WishlistService wishlistService = context.read<WishlistService>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Future<void> submit() async {
              final String title = titleController.text.trim();
              if (title.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Title cannot be empty')),
                );
                return;
              }
              setModalState(() => isSaving = true);
              try {
                if (existingDoc == null) {
                  await wishlistService.addWishlist(
                    title: title,
                    notes: notesController.text,
                    category: categoryController.text,
                    priority: priority,
                    targetDate: targetDate,
                  );
                } else {
                  await wishlistService.updateWishlist(
                    wishlistId: existingDoc.id,
                    title: title,
                    notes: notesController.text,
                    category: categoryController.text,
                    priority: priority,
                    targetDate: targetDate,
                  );
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        existingDoc == null
                            ? 'Wishlist item added'
                            : 'Wishlist item updated',
                      ),
                    ),
                  );
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to save wishlist: $e')),
                );
              } finally {
                if (context.mounted) {
                  setModalState(() => isSaving = false);
                }
              }
            }

            return AlertDialog(
              title: Text(
                existingDoc == null ? 'Add Wishlist' : 'Edit Wishlist',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: titleController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'Ex: Leather bag classic',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 220,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Extra details, budget, links, etc.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: categoryController,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 40,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        hintText: 'Ex: Fashion',
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<int>(
                      initialValue: priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: const <DropdownMenuItem<int>>[
                        DropdownMenuItem<int>(value: 1, child: Text('Low')),
                        DropdownMenuItem<int>(value: 2, child: Text('Medium')),
                        DropdownMenuItem<int>(value: 3, child: Text('High')),
                      ],
                      onChanged: (int? value) {
                        if (value == null) {
                          return;
                        }
                        setModalState(() => priority = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            targetDate == null
                                ? 'Target Date: Not set'
                                : 'Target Date: ${_formatDate(targetDate!)}',
                            style: TextStyle(color: AppColors.gray700),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final DateTime now = DateTime.now();
                            final DateTime initialDate = targetDate ?? now;
                            final DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: initialDate,
                              firstDate: DateTime(now.year - 1),
                              lastDate: DateTime(now.year + 10),
                            );
                            if (pickedDate != null) {
                              setModalState(() => targetDate = pickedDate);
                            }
                          },
                          child: const Text('Pick Date'),
                        ),
                        if (targetDate != null)
                          IconButton(
                            onPressed: () {
                              setModalState(() => targetDate = null);
                            },
                            icon: const Icon(Icons.close),
                            tooltip: 'Clear date',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving ? null : submit,
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleStatus({
    required String wishlistId,
    required bool currentlyFulfilled,
  }) async {
    setState(() => _processingIds.add(wishlistId));
    try {
      await context.read<WishlistService>().toggleWishlistStatus(
        wishlistId: wishlistId,
        fulfilled: !currentlyFulfilled,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyFulfilled
                  ? 'Wishlist moved to active'
                  : 'Wishlist marked as fulfilled',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(wishlistId));
      }
    }
  }

  Future<void> _deleteItem(String wishlistId) async {
    final WishlistService wishlistService = context.read<WishlistService>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Wishlist'),
        content: const Text('This item will be removed permanently.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _processingIds.add(wishlistId));
    try {
      await wishlistService.deleteWishlist(wishlistId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Wishlist item deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete wishlist: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(wishlistId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: context.read<WishlistService>().getWishlistStream(widget.userId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Failed to load wishlist: ${snapshot.error}'),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                snapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final List<QueryDocumentSnapshot<Map<String, dynamic>>>
            activeItems = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final List<QueryDocumentSnapshot<Map<String, dynamic>>>
            fulfilledItems = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                in docs) {
              final String status =
                  doc.data()['status']?.toString() ?? 'active';
              if (status == 'fulfilled') {
                fulfilledItems.add(doc);
              } else {
                activeItems.add(doc);
              }
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () => _showWishlistForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Wishlist'),
                ),
                const SizedBox(height: 14),
                _WishlistSection(
                  title: 'Active Wishlist',
                  emptyText: 'No active wishlist yet.',
                  items: activeItems,
                  processingIds: _processingIds,
                  onEdit: (QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                    _showWishlistForm(existingDoc: doc);
                  },
                  onToggleStatus: (String id, bool currentlyFulfilled) =>
                      _toggleStatus(
                        wishlistId: id,
                        currentlyFulfilled: currentlyFulfilled,
                      ),
                  onDelete: _deleteItem,
                ),
                const SizedBox(height: 14),
                _WishlistSection(
                  title: 'Fulfilled',
                  emptyText: 'No fulfilled wishlist yet.',
                  items: fulfilledItems,
                  processingIds: _processingIds,
                  onEdit: (QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                    _showWishlistForm(existingDoc: doc);
                  },
                  onToggleStatus: (String id, bool currentlyFulfilled) =>
                      _toggleStatus(
                        wishlistId: id,
                        currentlyFulfilled: currentlyFulfilled,
                      ),
                  onDelete: _deleteItem,
                ),
              ],
            );
          },
    );
  }
}

class _WishlistSection extends StatelessWidget {
  const _WishlistSection({
    required this.title,
    required this.emptyText,
    required this.items,
    required this.processingIds,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final String title;
  final String emptyText;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> items;
  final Set<String> processingIds;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onEdit;
  final void Function(String id, bool currentlyFulfilled) onToggleStatus;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color sectionBackground = isDark
        ? AppColors.gray100
        : AppColors.white;
    final Color sectionTitleColor = isDark
        ? AppColors.black87
        : Theme.of(context).colorScheme.onSurface;
    final Color emptyTextColor = isDark ? AppColors.gray700 : AppColors.gray600;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.gray200),
        borderRadius: BorderRadius.circular(14),
        color: sectionBackground,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: sectionTitleColor,
              ),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(emptyText, style: TextStyle(color: emptyTextColor)),
              ),
            ...items.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
              final Map<String, dynamic> data = doc.data();
              final bool isFulfilled =
                  data['status']?.toString() == 'fulfilled';
              final bool isProcessing = processingIds.contains(doc.id);
              return _WishlistCard(
                doc: doc,
                data: data,
                isFulfilled: isFulfilled,
                isProcessing: isProcessing,
                onEdit: () => onEdit(doc),
                onToggleStatus: () => onToggleStatus(doc.id, isFulfilled),
                onDelete: () => onDelete(doc.id),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _WishlistCard extends StatelessWidget {
  const _WishlistCard({
    required this.doc,
    required this.data,
    required this.isFulfilled,
    required this.isProcessing,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Map<String, dynamic> data;
  final bool isFulfilled;
  final bool isProcessing;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors semantic = context.semanticColors;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isProductWishlist = data['type']?.toString() == 'product';
    final String productId = data['productId']?.toString() ?? '';
    final String productImageUrl = data['productImageUrl']?.toString() ?? '';
    final double productPrice = data['productPrice'] is num
        ? (data['productPrice'] as num).toDouble()
        : 0;
    final String title = data['title']?.toString() ?? '-';
    final String notes = data['notes']?.toString() ?? '';
    final String category = data['category']?.toString() ?? '';
    final int priority = (data['priority'] as int?)?.clamp(1, 3) ?? 2;
    final Timestamp? targetTs = data['targetDate'] as Timestamp?;
    final DateTime? targetDate = targetTs?.toDate();
    final Color priorityColor = switch (priority) {
      3 => semantic.warning,
      2 => AppColors.gray600,
      _ => semantic.success,
    };
    final String priorityText = switch (priority) {
      3 => 'High',
      2 => 'Medium',
      _ => 'Low',
    };
    final Color cardBackground = isDark ? AppColors.gray100 : AppColors.surface;
    final Color primaryTextColor = isDark
        ? AppColors.black87
        : Theme.of(context).colorScheme.onSurface;
    final Color secondaryTextColor = isDark
        ? AppColors.gray700
        : AppColors.gray700;

    return Card(
      margin: const EdgeInsets.only(top: 10),
      elevation: 0,
      color: cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isProductWishlist && productId.trim().isNotEmpty
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProductDetailScreen(productId: productId),
                  ),
                );
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (isProductWishlist) ...<Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: productImageUrl.isEmpty
                            ? Container(
                                color: AppColors.gray200,
                                child: const Icon(Icons.inventory_2_outlined),
                              )
                            : AppCheckCachedNetworkImage(
                                imageUrl: productImageUrl,
                                fit: BoxFit.cover,
                                placeholder: Container(color: AppColors.gray200),
                                error: Container(
                                  color: AppColors.gray200,
                                  child: const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '\$${productPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap to view product',
                            style: TextStyle(color: secondaryTextColor),
                          ),
                        ],
                      ),
                    ),
                    _buildMenu(isProductWishlist, isFulfilled, context),
                  ],
                ),
              ] else
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                    _buildMenu(isProductWishlist, isFulfilled, context),
                  ],
                ),
              if (isProcessing)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  _WishlistTag(
                    icon: isFulfilled ? Icons.task_alt : Icons.schedule,
                    label: isFulfilled ? 'Fulfilled' : 'Active',
                    color: isFulfilled ? semantic.success : semantic.warning,
                  ),
                  if (!isProductWishlist)
                    _WishlistTag(
                      icon: Icons.flag_outlined,
                      label: 'Priority: $priorityText',
                      color: priorityColor,
                    ),
                  if (category.isNotEmpty)
                    _WishlistTag(
                      icon: Icons.sell_outlined,
                      label: category,
                      color: AppColors.gray700,
                    ),
                  if (isProductWishlist)
                    _WishlistTag(
                      icon: Icons.favorite_border,
                      label: 'Product Wishlist',
                      color: Colors.red,
                    ),
                ],
              ),
              if (notes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(notes, style: TextStyle(color: secondaryTextColor)),
              ],
              if (!isProductWishlist && targetDate != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'Target: ${_formatDate(targetDate)}',
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(
    bool isProductWishlist,
    bool isFulfilled,
    BuildContext context,
  ) {
    return PopupMenuButton<String>(
      onSelected: (String value) {
        if (value == 'edit') {
          onEdit();
        } else if (value == 'toggle') {
          onToggleStatus();
        } else if (value == 'delete') {
          onDelete();
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        if (!isProductWishlist)
          const PopupMenuItem<String>(
            value: 'edit',
            child: Text('Edit'),
          ),
        PopupMenuItem<String>(
          value: 'toggle',
          child: Text(
            isFulfilled ? 'Move to active' : 'Mark as fulfilled',
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('Delete'),
        ),
      ],
    );
  }
}

class _WishlistTag extends StatelessWidget {
  const _WishlistTag({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final String day = date.day.toString().padLeft(2, '0');
  final String month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _emailPrefix(String? email) {
  if (email == null || email.isEmpty) {
    return 'User';
  }
  return email.split('@').first;
}
