import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:sincerelysea/theme/app_semantic_colors.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sincerelysea/config/share_config.dart';
import 'package:sincerelysea/l10n/app_localizations.dart';
import 'package:sincerelysea/screens/map/map_picker_screen.dart';
import 'package:sincerelysea/screens/notifications/notifications_screen.dart';
import 'package:sincerelysea/screens/profile/user_profile_preview_screen.dart';
import 'package:sincerelysea/services/follow_service.dart';
import 'package:sincerelysea/services/local_notification_service.dart';
import 'package:sincerelysea/services/moderation_service.dart';
import 'package:sincerelysea/services/notification_center_service.dart';
import 'package:sincerelysea/services/post_service.dart';

Future<Position> _getCurrentPosition() async {
  final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Location services are disabled.');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw Exception('Location permission denied.');
  }

  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 10),
    ),
  );
}

class CreatePostRequest {
  const CreatePostRequest({
    required this.caption,
    required this.imageFile,
    required this.location,
    required this.geoPoint,
    required this.hashtags,
  });

  final String caption;
  final File imageFile;
  final String location;
  final GeoPoint? geoPoint;
  final List<String> hashtags;
}

Future<void> showCreatePostDialog(
  BuildContext rootContext, {
  required Future<void> Function(CreatePostRequest request) onSubmit,
}) async {
  const int maxCaptionLength = 220;

  await showGeneralDialog<void>(
    context: rootContext,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(
      rootContext,
    ).modalBarrierDismissLabel,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          final TextEditingController contentController =
              TextEditingController();
          final TextEditingController locationController =
              TextEditingController();
          final TextEditingController hashtagController =
              TextEditingController();
          File? selectedImage;
          GeoPoint? selectedGeoPoint;
          bool isUploading = false;
          bool isFetchingLocation = false;

          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AlertDialog(
                title: const Text('New Post'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      GestureDetector(
                        onTap: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? pickedFile = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (pickedFile != null) {
                            setState(
                              () => selectedImage = File(pickedFile.path),
                            );
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 220,
                          decoration: BoxDecoration(
                            color: AppColors.gray100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.gray400),
                          ),
                          child: selectedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: <Widget>[
                                      Image.file(
                                        selectedImage!,
                                        fit: BoxFit.cover,
                                      ),
                                      Align(
                                        alignment: Alignment.topRight,
                                        child: Container(
                                          margin: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppColors.black54,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: const Padding(
                                            padding: EdgeInsets.all(6.0),
                                            child: Icon(
                                              Icons.edit,
                                              color: AppColors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const <Widget>[
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 40,
                                      color: AppColors.gray500,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Select image to post',
                                      style: TextStyle(
                                        color: AppColors.gray500,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: contentController,
                        decoration: const InputDecoration(
                          hintText: 'Add caption',
                        ),
                        maxLength: maxCaptionLength,
                        inputFormatters: <TextInputFormatter>[
                          LengthLimitingTextInputFormatter(maxCaptionLength),
                        ],
                        maxLines: 3,
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            TextButton.icon(
                              onPressed: isFetchingLocation
                                  ? null
                                  : () async {
                                      setState(() => isFetchingLocation = true);
                                      try {
                                        final Position position =
                                            await _getCurrentPosition();
                                        if (!context.mounted) {
                                          return;
                                        }

                                        setState(() {
                                          selectedGeoPoint = GeoPoint(
                                            position.latitude,
                                            position.longitude,
                                          );
                                          locationController.text =
                                              '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
                                        });
                                      } catch (e) {
                                        if (rootContext.mounted) {
                                          ScaffoldMessenger.of(
                                            rootContext,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Failed to get location: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (context.mounted) {
                                          setState(
                                            () => isFetchingLocation = false,
                                          );
                                        }
                                      }
                                    },
                              icon: isFetchingLocation
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.my_location, size: 18),
                              label: Text(
                                isFetchingLocation
                                    ? 'Getting location...'
                                    : 'Use current location',
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final MapPickerResult? picked =
                                    await Navigator.of(
                                      rootContext,
                                    ).push<MapPickerResult>(
                                      MaterialPageRoute<MapPickerResult>(
                                        builder: (_) => const MapPickerScreen(),
                                      ),
                                    );
                                if (picked == null || !context.mounted) {
                                  return;
                                }

                                setState(() {
                                  selectedGeoPoint = GeoPoint(
                                    picked.point.latitude,
                                    picked.point.longitude,
                                  );
                                  locationController.text = picked.label;
                                });
                              },
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: const Text('Pick on map'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gray100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.gray300),
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.location_on_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                locationController.text.isEmpty
                                    ? 'No location selected'
                                    : locationController.text,
                                style: TextStyle(
                                  color: locationController.text.isEmpty
                                      ? AppColors.gray600
                                      : AppColors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: hashtagController,
                        decoration: const InputDecoration(
                          hintText: 'Hashtags (e.g. #sea #sun)',
                          prefixIcon: Icon(Icons.tag),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: isUploading
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isUploading
                        ? null
                        : () async {
                            final String trimmedContent = contentController.text
                                .trim();
                            if (trimmedContent.length > maxCaptionLength) {
                              final AppLocalizations l10n = AppLocalizations.of(
                                rootContext,
                              );
                              ScaffoldMessenger.of(rootContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.captionMaxLength(maxCaptionLength),
                                  ),
                                ),
                              );
                              return;
                            }
                            if (selectedImage == null) {
                              ScaffoldMessenger.of(rootContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Please add an image first'),
                                ),
                              );
                              return;
                            }
                            setState(() => isUploading = true);

                            final List<String> hashtags = hashtagController.text
                                .trim()
                                .split(' ')
                                .where((String tag) => tag.isNotEmpty)
                                .map(
                                  (String tag) =>
                                      tag.startsWith('#') ? tag : '#$tag',
                                )
                                .toList();

                            final CreatePostRequest request = CreatePostRequest(
                              caption: trimmedContent,
                              imageFile: selectedImage!,
                              location: locationController.text.trim(),
                              geoPoint: selectedGeoPoint,
                              hashtags: hashtags,
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                            unawaited(onSubmit(request));
                          },
                    child: isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Post'),
                  ),
                ],
              );
            },
          );
        },
    transitionBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          return ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _posts =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  final Set<String> _prefetchedImageUrls = <String>{};
  Timer? _paginationDebounceTimer;

  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _isPublishingPost = false;
  bool _hasMore = true;
  bool _isGridView = false;
  double _uploadProgress = 0;
  int _lastNotifiedUploadPercent = -1;
  int _lastDebugLoggedPercent = -1;
  DocumentSnapshot<Object?>? _lastDocument;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _fetchInitialPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageController.dispose();
    _paginationDebounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        !_isFetchingMore &&
        _hasMore) {
      _paginationDebounceTimer?.cancel();
      _paginationDebounceTimer = Timer(const Duration(milliseconds: 280), () {
        if (!_isFetchingMore && _hasMore && mounted) {
          _fetchMorePosts();
        }
      });
    }
  }

  void _onSnapPageChanged(int index) {
    if (index >= _posts.length) {
      return;
    }
    _prefetchUpcomingImages(index);
    if (index >= _posts.length - 2 && !_isFetchingMore && _hasMore) {
      _fetchMorePosts();
    }
  }

  Future<void> _fetchInitialPosts() async {
    setState(() {
      _isLoading = true;
      _posts.clear();
      _lastDocument = null;
      _hasMore = true;
    });

    try {
      await _fetchPosts();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load posts. Pull to retry.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchMorePosts() async {
    if (mounted) {
      setState(() => _isFetchingMore = true);
    }

    try {
      await _fetchPosts();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load more posts.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingMore = false);
      }
    }
  }

  Future<void> _fetchPosts() async {
    final PostService postService = context.read<PostService>();
    final ModerationService moderationService = context
        .read<ModerationService>();
    final User? currentUser = context.read<User?>();
    final QuerySnapshot<Map<String, dynamic>> snapshot = await postService
        .getPostsPaginated(limit: _pageSize, startAfter: _lastDocument);

    if (snapshot.docs.length < _pageSize) {
      _hasMore = false;
    }
    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
    }

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> visibleDocs =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String postOwnerUid = data['uid']?.toString() ?? '';
      if (postOwnerUid.isEmpty) {
        continue;
      }
      final bool isHidden = await moderationService.isPostHidden(doc.id);
      final bool isBlocked = await moderationService.isUserBlocked(
        postOwnerUid,
      );
      if (isHidden || isBlocked) {
        continue;
      }
      final String visibility = data['visibility']?.toString() ?? 'public';
      if (visibility == 'private' &&
          currentUser != null &&
          currentUser.uid != postOwnerUid) {
        continue;
      }
      visibleDocs.add(doc);
    }

    if (mounted) {
      setState(() => _posts.addAll(visibleDocs));
    }
  }

  Future<void> _onRefresh() async {
    await _fetchInitialPosts();
  }

  Future<void> _submitPostInBackground(CreatePostRequest request) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isPublishingPost = true;
      _uploadProgress = 0;
    });
    _lastNotifiedUploadPercent = -1;

    final PostService postService = context.read<PostService>();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Uploading your post in background...'),
        duration: Duration(seconds: 2),
      ),
    );
    unawaited(
      LocalNotificationService.instance.showUploadProgressNotification(
        progress: 0,
      ),
    );

    unawaited(_publishPost(request, postService));
  }

  Future<void> _publishPost(
    CreatePostRequest request,
    PostService postService,
  ) async {
    bool isSuccess = false;
    final Stopwatch debugWatch = Stopwatch()..start();
    String currentStage = 'start';
    _lastDebugLoggedPercent = -1;

    void logStage(String message) {
      if (!kDebugMode) {
        return;
      }
      final int ms = debugWatch.elapsedMilliseconds;
      debugPrint('[POST_DEBUG +${ms}ms][$currentStage] $message');
    }

    logStage('Create post flow started');
    try {
      currentStage = 'upload:start';
      logStage('Uploading image to Storage...');
      final String? imageUrl = await postService.uploadImage(
        request.imageFile,
        onProgress: (double progress) {
          final int percent = (progress * 100).round().clamp(0, 100).toInt();
          if (mounted) {
            setState(() => _uploadProgress = progress);
          }
          if (kDebugMode &&
              (_lastDebugLoggedPercent < 0 ||
                  percent >= _lastDebugLoggedPercent + 25 ||
                  percent == 100)) {
            _lastDebugLoggedPercent = percent;
            logStage('Upload progress: $percent%');
          }
          final bool shouldNotify =
              _lastNotifiedUploadPercent < 0 ||
              percent >= _lastNotifiedUploadPercent + 5 ||
              percent == 100;
          if (shouldNotify) {
            _lastNotifiedUploadPercent = percent;
            unawaited(
              LocalNotificationService.instance.showUploadProgressNotification(
                progress: percent,
              ),
            );
          }
        },
      ).timeout(const Duration(seconds: 60));
      currentStage = 'upload:done';
      logStage('Upload finished');
      if (imageUrl == null || imageUrl.trim().isEmpty) {
        throw FirebaseException(
          plugin: 'post_publish',
          code: 'upload-empty-url',
          message: 'Upload completed without download URL.',
        );
      }
      unawaited(
        LocalNotificationService.instance.showUploadProgressNotification(
          progress: 100,
          isPublishing: true,
        ),
      );
      currentStage = 'firestore:write:start';
      logStage('Writing post document to Firestore...');
      await postService.addPost(
        request.caption,
        imageUrl: imageUrl,
        location: request.location,
        geo: request.geoPoint,
        hashtags: request.hashtags,
      ).timeout(const Duration(seconds: 30));
      currentStage = 'firestore:write:done';
      logStage('Firestore write success');
      isSuccess = true;

      if (mounted) {
        await _onRefresh();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your post has been published.')),
        );
      }
      await LocalNotificationService.instance.showPostPublishedNotification();
    } on FirebaseException catch (e) {
      logStage('FirebaseException (${e.code}): ${e.message ?? '-'}');
      if (mounted) {
        final String message = switch (e.code) {
          'permission-denied' =>
            'Permission denied. Please check Firestore/Storage rules.',
          'unauthenticated' => 'Please login again and try posting.',
          'failed-precondition' =>
            'A required Firebase index or config is missing.',
          'upload-empty-url' =>
            'Upload failed: image URL is empty after upload.',
          _ => 'Failed to publish post (${e.code}). Please try again.',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$message [stage: $currentStage]')),
        );
      }
      await LocalNotificationService.instance.showPostFailedNotification();
    } on TimeoutException {
      logStage('TimeoutException on stage $currentStage');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Post publish timed out at stage: $currentStage. Check connection and retry.',
            ),
          ),
        );
      }
      await LocalNotificationService.instance.showPostFailedNotification();
    } catch (_) {
      logStage('Unknown exception');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to publish post. Please try again. [stage: $currentStage]',
            ),
          ),
        );
      }
      await LocalNotificationService.instance.showPostFailedNotification();
    } finally {
      logStage(
        isSuccess
            ? 'Flow completed successfully in ${debugWatch.elapsedMilliseconds}ms'
            : 'Flow ended with failure in ${debugWatch.elapsedMilliseconds}ms',
      );
      debugWatch.stop();
      await LocalNotificationService.instance
          .cancelUploadProgressNotification();
      _lastNotifiedUploadPercent = -1;
      if (mounted) {
        if (isSuccess) {
          setState(() => _uploadProgress = 1);
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        if (mounted) {
          setState(() {
            _isPublishingPost = false;
            _uploadProgress = 0;
          });
        }
      }
    }
  }

  Widget _buildFeedContent(User? user) {
    if (_isLoading) {
      return ListView.builder(
        key: const ValueKey<String>('loading'),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (BuildContext context, int index) =>
            const SkeletonPostCard(),
      );
    }

    if (_posts.isEmpty) {
      return LayoutBuilder(
        key: const ValueKey<String>('empty'),
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: const Center(child: Text('No posts yet. Be the first!')),
            ),
          );
        },
      );
    }

    if (_isGridView) {
      return GridView.builder(
        key: const ValueKey<String>('grid'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        cacheExtent: 1200,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        itemCount: _posts.length + (_isFetchingMore ? 1 : 0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (BuildContext context, int index) {
          if (index == _posts.length) {
            return const Center(child: CircularProgressIndicator());
          }
          _prefetchUpcomingImages(index);
          final Map<String, dynamic> data = _posts[index].data();
          return _HomeGridPostTile(post: data);
        },
      );
    }

    return PageView.builder(
      key: const ValueKey<String>('list_snap'),
      controller: _pageController,
      scrollDirection: Axis.vertical,
      pageSnapping: true,
      physics: const AlwaysScrollableScrollPhysics(
        parent: PageScrollPhysics(),
      ),
      itemCount: _posts.length + (_isFetchingMore ? 1 : 0),
      onPageChanged: _onSnapPageChanged,
      itemBuilder: (BuildContext context, int index) {
        if (index == _posts.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final QueryDocumentSnapshot<Map<String, dynamic>> doc = _posts[index];
        return PostCard(post: doc.data(), postId: doc.id, currentUser: user);
      },
    );
  }

  Widget _buildUploadProgressBanner() {
    final int percent = (_uploadProgress * 100).round().clamp(0, 100).toInt();
    return Material(
      color: AppColors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              percent >= 100 ? 'Publishing post...' : 'Uploading media...',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: _uploadProgress),
            const SizedBox(height: 6),
            Text('$percent%'),
          ],
        ),
      ),
    );
  }

  void _prefetchUpcomingImages(int currentIndex) {
    if (!mounted || _posts.isEmpty) {
      return;
    }

    final int start = currentIndex + 1;
    final int end = math.min(_posts.length - 1, currentIndex + 3);
    for (int i = start; i <= end; i++) {
      final Map<String, dynamic> data = _posts[i].data();
      final String? imageUrl = data['imageUrl']?.toString();
      if (imageUrl == null || imageUrl.isEmpty) {
        continue;
      }
      if (_prefetchedImageUrls.add(imageUrl)) {
        precacheImage(CachedNetworkImageProvider(imageUrl), context).catchError(
          (Object _) {
            _prefetchedImageUrls.remove(imageUrl);
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = context.watch<User?>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            showCreatePostDialog(context, onSubmit: _submitPostInBackground);
          },
        ),
        title: const Text('Sincerelysea'),
        actions: <Widget>[
          StreamBuilder<int>(
            stream: context
                .read<NotificationCenterService>()
                .unreadCountStream(),
            builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
              final int unread = snapshot.data ?? 0;
              return IconButton(
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(unread > 99 ? '99+' : unread.toString()),
                  child: const Icon(Icons.notifications_none),
                ),
              );
            },
          ),
          IconButton(
            tooltip: _isGridView ? 'View as list' : 'View as grid',
            icon: Icon(_isGridView ? Icons.view_agenda : Icons.grid_view),
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_isPublishingPost) _buildUploadProgressBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _buildFeedContent(user),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.postId,
    required this.currentUser,
  });

  final Map<String, dynamic> post;
  final String postId;
  final User? currentUser;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _showHeart = false;
  bool _isSharing = false;

  Future<void> _sharePost({
    required String username,
    required String caption,
    required String postId,
    String? imageUrl,
    String? postOwnerUid,
  }) async {
    if (_isSharing) {
      return;
    }
    setState(() => _isSharing = true);
    final PostService postService = context.read<PostService>();
    final NotificationCenterService notificationService = context
        .read<NotificationCenterService>();
    final User? currentUser = widget.currentUser;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String trimmedCaption = caption.trim();
    final String preview = trimmedCaption.isEmpty
        ? ''
        : (trimmedCaption.length > 100
              ? '${trimmedCaption.substring(0, 100)}...'
              : trimmedCaption);
    final String postLink = ShareConfig.buildTrackablePostLink(postId);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String previewSection = preview.isEmpty ? '' : ':\n"$preview"';
    final String message = l10n.sharePreview(
      username,
      previewSection,
      postLink,
      ShareConfig.playStoreUrl,
      ShareConfig.appStoreUrl,
    );

    XFile? shareImageFile;
    try {
      shareImageFile = await _prepareShareImageFile(imageUrl);
      final ShareResult result = await _shareToSystemApps(
        message: message,
        subject: l10n.shareSubject,
        imageFile: shareImageFile,
      );
      if (result.status == ShareResultStatus.success) {
        await _handleShareSuccess(
          postId: postId,
          shareMethod: 'system_share',
          postOwnerUid: postOwnerUid,
          currentUser: currentUser,
          postService: postService,
          notificationService: notificationService,
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) {
        return;
      }
      final String code = e.code.toLowerCase();
      final String message =
          code == 'share failed' ||
              code == 'unavailable' ||
              code == 'unavailable_error'
          ? 'Share is unavailable on this device right now. Please try Copy link.'
          : 'Failed to share post. Please try Copy link.';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to share post: $e')),
      );
    } finally {
      if (shareImageFile != null) {
        try {
          await File(shareImageFile.path).delete();
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<ShareResult> _shareToSystemApps({
    required String message,
    required String subject,
    XFile? imageFile,
  }) async {
    Rect? origin;
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      origin = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    }

    try {
      return await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: subject,
          files: imageFile == null ? null : <XFile>[imageFile],
          sharePositionOrigin: origin,
        ),
      );
    } on PlatformException {
      // Fallback for platform implementations that fail with origin/subject.
      try {
        return await SharePlus.instance.share(
          ShareParams(
            text: message,
            files: imageFile == null ? null : <XFile>[imageFile],
          ),
        );
      } on PlatformException {
        return SharePlus.instance.share(
          ShareParams(text: message),
        );
      }
    }
  }

  Future<XFile?> _prepareShareImageFile(String? imageUrl) async {
    final String raw = imageUrl?.trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    final Uri? uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    try {
      final http.Response response = await http
          .get(uri)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }

      final String contentType = response.headers['content-type'] ?? '';
      final String ext = _imageExtensionFromContentType(contentType);
      final String path =
          '${Directory.systemTemp.path}/share_${widget.postId}_${DateTime.now().microsecondsSinceEpoch}.$ext';
      final File file = File(path);
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return XFile(file.path, mimeType: contentType.isEmpty ? null : contentType);
    } catch (_) {
      return null;
    }
  }

  String _imageExtensionFromContentType(String contentType) {
    final String type = contentType.toLowerCase();
    if (type.contains('png')) {
      return 'png';
    }
    if (type.contains('webp')) {
      return 'webp';
    }
    if (type.contains('gif')) {
      return 'gif';
    }
    return 'jpg';
  }

  Future<void> _copyPostLink({
    required String postId,
    String? postOwnerUid,
  }) async {
    if (_isSharing) {
      return;
    }
    setState(() => _isSharing = true);
    final PostService postService = context.read<PostService>();
    final NotificationCenterService notificationService = context
        .read<NotificationCenterService>();
    final User? currentUser = widget.currentUser;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String postLink = ShareConfig.buildTrackablePostLink(
      postId,
      medium: 'copy_link',
      campaign: 'post_copy_link',
    );
    try {
      await Clipboard.setData(ClipboardData(text: postLink));
      await _handleShareSuccess(
        postId: postId,
        shareMethod: 'copy_link',
        postOwnerUid: postOwnerUid,
        currentUser: currentUser,
        postService: postService,
        notificationService: notificationService,
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Post link copied to clipboard')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to copy link: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _handleShareSuccess({
    required String postId,
    required String shareMethod,
    required String? postOwnerUid,
    required User? currentUser,
    required PostService postService,
    required NotificationCenterService notificationService,
  }) async {
    try {
      await postService.incrementShareCount(postId, method: shareMethod);
    } catch (_) {
      // Do not block share/copy UX if analytics write is rejected by rules.
    }

    if (currentUser != null &&
        postOwnerUid != null &&
        postOwnerUid.isNotEmpty &&
        postOwnerUid != currentUser.uid) {
      try {
        await notificationService.createNotification(
          targetUid: postOwnerUid,
          type: 'share',
          actorUid: currentUser.uid,
          actorUsername:
              currentUser.displayName ??
              currentUser.email?.split('@').first ??
              'user',
          postId: postId,
        );
      } catch (_) {
        // Keep the share flow successful even when notification write fails.
      }
    }
  }

  Future<void> _showShareActionsSheet({
    required String username,
    required String caption,
    required String postId,
    String? imageUrl,
    String? postOwnerUid,
  }) async {
    if (_isSharing) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share to apps'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _sharePost(
                    username: username,
                    caption: caption,
                    postId: postId,
                    imageUrl: imageUrl,
                    postOwnerUid: postOwnerUid,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_outlined),
                title: const Text('Copy link'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _copyPostLink(
                    postId: postId,
                    postOwnerUid: postOwnerUid,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditPostDialog(Map<String, dynamic> postData) async {
    final TextEditingController captionController = TextEditingController(
      text: postData['content']?.toString() ?? '',
    );
    final TextEditingController locationController = TextEditingController(
      text: postData['location']?.toString() ?? '',
    );
    final List<dynamic> currentHashtags =
        postData['hashtags'] as List<dynamic>? ?? <dynamic>[];
    final TextEditingController hashtagController = TextEditingController(
      text: currentHashtags.map((dynamic tag) => tag.toString()).join(' '),
    );
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: const Text('Edit Post'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: captionController,
                    decoration: const InputDecoration(hintText: 'Edit caption'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      hintText: 'Edit location',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: hashtagController,
                    decoration: const InputDecoration(
                      hintText: 'Edit hashtags (e.g. #sea #sun)',
                      prefixIcon: Icon(Icons.tag),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setState(() => isSaving = true);
                        try {
                          final List<String> hashtags = hashtagController.text
                              .trim()
                              .split(' ')
                              .where((String tag) => tag.isNotEmpty)
                              .map(
                                (String tag) =>
                                    tag.startsWith('#') ? tag : '#$tag',
                              )
                              .toList();

                          await context.read<PostService>().updatePost(
                            widget.postId,
                            content: captionController.text.trim(),
                            location: locationController.text.trim(),
                            hashtags: hashtags,
                          );

                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to edit post: $e'),
                              ),
                            );
                          }
                        } finally {
                          if (context.mounted) {
                            setState(() => isSaving = false);
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String?> _showReasonDialog({
    required String title,
    required String hint,
  }) async {
    final TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLength: 120,
            decoration: InputDecoration(hintText: hint),
            minLines: 2,
            maxLines: 3,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.addStatusListener((AnimationStatus status) async {
      if (status == AnimationStatus.completed) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          await _controller.reverse();
        }
      }
      if (status == AnimationStatus.dismissed && mounted) {
        setState(() => _showHeart = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: context.read<PostService>().getPost(widget.postId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> postData =
                snapshot.data?.data() ?? widget.post;

            final String username =
                postData['username']?.toString() ?? 'Anonymous';
            final String content = postData['content']?.toString() ?? '';
            final String? imageUrl = postData['imageUrl'] as String?;
            final String? location = postData['location'] as String?;
            final List<dynamic> hashtags =
                postData['hashtags'] as List<dynamic>? ?? <dynamic>[];
            final List<dynamic> likes =
                postData['likes'] as List<dynamic>? ?? <dynamic>[];
            final int commentCount = postData['commentCount'] as int? ?? 0;
            final int shareCount = postData['shareCount'] as int? ?? 0;

            final Timestamp? timestamp = postData['timestamp'] is Timestamp
                ? postData['timestamp'] as Timestamp
                : null;
            final String timeString = timestamp != null
                ? timeAgo(timestamp.toDate())
                : 'Just now';

            final bool isLiked =
                widget.currentUser != null &&
                likes.contains(widget.currentUser!.uid);
            final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;
            final bool hasLocation = location != null && location.isNotEmpty;
            final String? postOwnerUid = postData['uid']?.toString();
            final bool isPostOwner =
                widget.currentUser != null &&
                postOwnerUid != null &&
                widget.currentUser!.uid == postOwnerUid;
            final Timestamp? postTimestamp = postData['timestamp'] is Timestamp
                ? postData['timestamp'] as Timestamp
                : null;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.gray300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: postOwnerUid == null
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            UserProfilePreviewScreen(
                                              userId: postOwnerUid,
                                              initialUsername: username,
                                            ),
                                      ),
                                    );
                                  },
                            child: Row(
                              children: <Widget>[
                                CircleAvatar(
                                  backgroundColor: AppColors.gray300,
                                  child: Text(
                                    username.isNotEmpty
                                        ? username[0].toUpperCase()
                                        : '?',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        username,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Row(
                                        children: <Widget>[
                                          Text(
                                            timeString,
                                            style: TextStyle(
                                              color: AppColors.gray600,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (postOwnerUid != null) ...<Widget>[
                                            const SizedBox(width: 8),
                                            StreamBuilder<
                                              QuerySnapshot<
                                                Map<String, dynamic>
                                              >
                                            >(
                                              stream: context
                                                  .read<FollowService>()
                                                  .followersStream(
                                                    postOwnerUid,
                                                  ),
                                              builder:
                                                  (
                                                    BuildContext context,
                                                    AsyncSnapshot<
                                                      QuerySnapshot<
                                                        Map<String, dynamic>
                                                      >
                                                    >
                                                    followerSnapshot,
                                                  ) {
                                                    final int followerCount =
                                                        followerSnapshot
                                                            .data
                                                            ?.docs
                                                            .length ??
                                                        0;
                                                    return Text(
                                                      '$followerCount followers',
                                                      style: TextStyle(
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                        fontSize: 12,
                                                      ),
                                                    );
                                                  },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!isPostOwner && postOwnerUid != null)
                          StreamBuilder<bool>(
                            stream: context
                                .read<FollowService>()
                                .isFollowingStream(postOwnerUid),
                            builder:
                                (
                                  BuildContext context,
                                  AsyncSnapshot<bool> followSnapshot,
                                ) {
                                  final bool isFollowing =
                                      followSnapshot.data ?? false;
                                  return StreamBuilder<bool>(
                                    stream: context
                                        .read<FollowService>()
                                        .isFollowRequestedStream(postOwnerUid),
                                    builder:
                                        (
                                          BuildContext context,
                                          AsyncSnapshot<bool> requestSnapshot,
                                        ) {
                                          final bool isRequested =
                                              requestSnapshot.data ?? false;
                                          return TextButton(
                                            onPressed:
                                                widget.currentUser == null
                                                ? null
                                                : () async {
                                                    try {
                                                      if (isFollowing) {
                                                        await context
                                                            .read<
                                                              FollowService
                                                            >()
                                                            .unfollowUser(
                                                              postOwnerUid,
                                                            );
                                                      } else if (!isRequested) {
                                                        await context
                                                            .read<
                                                              FollowService
                                                            >()
                                                            .followUser(
                                                              targetUid:
                                                                  postOwnerUid,
                                                              targetUsername:
                                                                  username,
                                                            );
                                                      }
                                                    } catch (e) {
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Failed to update follow: $e',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                            style: TextButton.styleFrom(
                                              minimumSize: const Size(0, 32),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: Text(
                                              isFollowing
                                                  ? 'Following'
                                                  : (isRequested
                                                        ? 'Requested'
                                                        : 'Follow'),
                                            ),
                                          );
                                        },
                                  );
                                },
                          ),
                        if (isPostOwner)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_horiz),
                            onSelected: (String value) {
                              if (value == 'edit') {
                                _showEditPostDialog(postData);
                              }
                            },
                            itemBuilder: (BuildContext context) =>
                                const <PopupMenuEntry<String>>[
                                  PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Text('Edit Post'),
                                  ),
                                ],
                          )
                        else if (postOwnerUid != null)
                          StreamBuilder<bool>(
                            stream: context
                                .read<ModerationService>()
                                .isUserBlockedStream(postOwnerUid),
                            builder:
                                (
                                  BuildContext context,
                                  AsyncSnapshot<bool> blockSnapshot,
                                ) {
                                  final bool isBlocked =
                                      blockSnapshot.data ?? false;
                                  return PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_horiz),
                                    onSelected: (String value) async {
                                      final ModerationService
                                      moderationService = context
                                          .read<ModerationService>();
                                      if (value == 'hide') {
                                        await moderationService.hidePost(
                                          postId: widget.postId,
                                          postOwnerUid: postOwnerUid,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Post hidden from feed',
                                              ),
                                            ),
                                          );
                                        }
                                      } else if (value == 'report_post') {
                                        final String? reason =
                                            await _showReasonDialog(
                                              title: 'Report post',
                                              hint: 'Tell us what happened',
                                            );
                                        if (reason != null &&
                                            reason.isNotEmpty) {
                                          await moderationService.reportPost(
                                            postId: widget.postId,
                                            postOwnerUid: postOwnerUid,
                                            reason: reason,
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text('Post reported'),
                                              ),
                                            );
                                          }
                                        }
                                      } else if (value == 'report_user') {
                                        final String? reason =
                                            await _showReasonDialog(
                                              title: 'Report user',
                                              hint: 'Tell us what happened',
                                            );
                                        if (reason != null &&
                                            reason.isNotEmpty) {
                                          await moderationService.reportUser(
                                            targetUid: postOwnerUid,
                                            reason: reason,
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text('User reported'),
                                              ),
                                            );
                                          }
                                        }
                                      } else if (value == 'block') {
                                        await moderationService.blockUser(
                                          targetUid: postOwnerUid,
                                          targetUsername: username,
                                        );
                                      } else if (value == 'unblock') {
                                        await moderationService.unblockUser(
                                          postOwnerUid,
                                        );
                                      }
                                    },
                                    itemBuilder: (BuildContext context) =>
                                        <PopupMenuEntry<String>>[
                                          const PopupMenuItem<String>(
                                            value: 'hide',
                                            child: Text('Hide post'),
                                          ),
                                          const PopupMenuItem<String>(
                                            value: 'report_post',
                                            child: Text('Report post'),
                                          ),
                                          const PopupMenuItem<String>(
                                            value: 'report_user',
                                            child: Text('Report user'),
                                          ),
                                          PopupMenuItem<String>(
                                            value: isBlocked
                                                ? 'unblock'
                                                : 'block',
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
                  ),
                  if (hasImage)
                    GestureDetector(
                      onDoubleTap: () {
                        context.read<PostService>().toggleLike(
                          widget.postId,
                          false,
                        );
                        setState(() => _showHeart = true);
                        _controller.forward(from: 0.0);
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 8.0),
                            child: _SmoothPostImage(imageUrl: imageUrl),
                          ),
                          if (_showHeart)
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: const Icon(
                                Icons.favorite,
                                color: AppColors.white,
                                size: 100,
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (hasImage && content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0),
                      child: Text(
                        content,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  if (hasImage && hashtags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 0),
                      child: Wrap(
                        spacing: 4,
                        children: hashtags
                            .map(
                              (dynamic tag) => Text(
                                tag.toString(),
                                style: const TextStyle(color: AppColors.black),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  if (hasImage && hasLocation)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 0),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: AppColors.gray600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            location,
                            style: TextStyle(
                              color: AppColors.gray600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!hasImage && content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        content,
                        style: TextStyle(color: AppColors.gray700),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4.0,
                      vertical: 4.0,
                    ),
                    child: Row(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            IconButton(
                              icon: Icon(
                                isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isLiked ? AppColors.black : null,
                              ),
                              onPressed: () {
                                context.read<PostService>().toggleLike(
                                  widget.postId,
                                  isLiked,
                                );
                              },
                            ),
                            if (likes.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text('${likes.length}'),
                              ),
                          ],
                        ),
                        Row(
                          children: <Widget>[
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline),
                              onPressed: () {
                                showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (BuildContext context) => SizedBox(
                                    height:
                                        MediaQuery.of(context).size.height *
                                        0.75,
                                    child: CommentsSheet(postId: widget.postId),
                                  ),
                                );
                              },
                            ),
                            if (commentCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text('$commentCount'),
                              ),
                          ],
                        ),
                        IconButton(
                          icon: _isSharing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_outlined),
                          onPressed: _isSharing
                              ? null
                              : () {
                            _showShareActionsSheet(
                              username: username,
                              caption: content,
                              postId: widget.postId,
                              imageUrl: imageUrl,
                              postOwnerUid: postOwnerUid,
                            );
                          },
                        ),
                        if (shareCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text('$shareCount'),
                          ),
                        StreamBuilder<bool>(
                          stream: context
                              .read<FollowService>()
                              .isPostSavedStream(widget.postId),
                          builder:
                              (
                                BuildContext context,
                                AsyncSnapshot<bool> saveSnapshot,
                              ) {
                                final bool isSaved = saveSnapshot.data ?? false;
                                return IconButton(
                                  icon: Icon(
                                    isSaved
                                        ? Icons.bookmark
                                        : Icons.bookmark_border_outlined,
                                  ),
                                  onPressed: widget.currentUser == null
                                      ? null
                                      : () async {
                                          try {
                                            await context
                                                .read<FollowService>()
                                                .toggleSavePost(
                                                  postId: widget.postId,
                                                  postOwnerUid:
                                                      postOwnerUid ?? '',
                                                  caption: content,
                                                  imageUrl: imageUrl,
                                                  timestamp: postTimestamp,
                                                );
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Failed to save post: $e',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                );
                              },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
    );
  }
}

class CommentsSheet extends StatefulWidget {
  const CommentsSheet({super.key, required this.postId});

  final String postId;

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _isPosting = false;
  String? _replyingToCommentId;
  String? _replyingToUsername;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _startReply(String commentId, String username) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUsername = username;
    });
  }

  void _clearReplyTarget() {
    if (!mounted) {
      return;
    }
    setState(() {
      _replyingToCommentId = null;
      _replyingToUsername = null;
    });
  }

  Future<void> _submitCommentOrReply() async {
    if (_commentController.text.trim().isEmpty) {
      return;
    }

    setState(() => _isPosting = true);
    try {
      if (_replyingToCommentId != null) {
        await context.read<PostService>().addReply(
          widget.postId,
          _replyingToCommentId!,
          _commentController.text.trim(),
        );
      } else {
        await context.read<PostService>().addComment(
          widget.postId,
          _commentController.text.trim(),
        );
      }
      _commentController.clear();
      _clearReplyTarget();
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }
      final String message = switch (e.code) {
        'permission-denied' =>
          'You do not have permission to comment on this post.',
        'failed-precondition' =>
          'Comment failed due to server precondition. Please refresh and try again.',
        _ => e.message ?? 'Failed to send comment.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  Future<void> _showEditCommentDialog(
    String commentId,
    String currentContent,
  ) async {
    final TextEditingController editController = TextEditingController(
      text: currentContent,
    );

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Edit Komentar'),
        content: TextField(
          controller: editController,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).writeCommentHint,
          ),
          maxLines: 3,
          minLines: 1,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancelLabel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (editController.text.trim().isNotEmpty) {
                await context.read<PostService>().updateComment(
                  widget.postId,
                  commentId,
                  editController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = context.watch<User?>();
    final AppSemanticColors semantic = context.semanticColors;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Comments',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Divider(height: 1, color: semantic.divider),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: context.read<PostService>().getComments(widget.postId),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                  ) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    docs =
                        snapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                    if (docs.isEmpty) {
                      return const Center(child: Text('No comments yet.'));
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (BuildContext context, int index) {
                        final QueryDocumentSnapshot<Map<String, dynamic>> doc =
                            docs[index];
                        final Map<String, dynamic> data = doc.data();
                        final String commentId = doc.id;
                        final String? commentUid = data['uid']?.toString();
                        final List<dynamic> likes =
                            data['likes'] as List<dynamic>? ?? <dynamic>[];

                        final String username =
                            data['username']?.toString() ?? 'Anonymous';
                        final String content =
                            data['content']?.toString() ?? '';
                        final Timestamp? timestamp =
                            data['timestamp'] as Timestamp?;
                        final String timeString = timestamp != null
                            ? timeAgo(timestamp.toDate())
                            : 'Just now';

                        final bool isCommentLiked =
                            currentUser != null &&
                            likes.contains(currentUser.uid);

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Column(
                            children: <Widget>[
                              ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                    username.isNotEmpty
                                        ? username[0].toUpperCase()
                                        : '?',
                                  ),
                                ),
                                title: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        username,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        timeString,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          color: AppColors.gray500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(content),
                                    const SizedBox(height: 4),
                                    TextButton(
                                      onPressed: () =>
                                          _startReply(commentId, username),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 0),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('Reply'),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    if (likes.isNotEmpty)
                                      Text(
                                        '${likes.length}',
                                        style: TextStyle(
                                          color: AppColors.gray600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    IconButton(
                                      icon: Icon(
                                        isCommentLiked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: isCommentLiked
                                            ? AppColors.black
                                            : AppColors.gray500,
                                        size: 20,
                                      ),
                                      onPressed: () => context
                                          .read<PostService>()
                                          .toggleCommentLike(
                                            widget.postId,
                                            commentId,
                                            isCommentLiked,
                                          ),
                                    ),
                                    if (currentUser != null &&
                                        commentUid != null &&
                                        currentUser.uid ==
                                            commentUid) ...<Widget>[
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          color: AppColors.black,
                                          size: 20,
                                        ),
                                        onPressed: () => _showEditCommentDialog(
                                          commentId,
                                          content,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: AppColors.gray700,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          showDialog<void>(
                                            context: context,
                                            builder:
                                                (
                                                  BuildContext dialogContext,
                                                ) => AlertDialog(
                                                  title: Text(
                                                    AppLocalizations.of(
                                                      context,
                                                    ).deleteCommentTitle,
                                                  ),
                                                  content: Text(
                                                    AppLocalizations.of(
                                                      context,
                                                    ).confirmDeleteComment,
                                                  ),
                                                  actions: <Widget>[
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            dialogContext,
                                                          ),
                                                      child: Text(
                                                        AppLocalizations.of(
                                                          context,
                                                        ).cancelLabel,
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () async {
                                                        Navigator.pop(
                                                          dialogContext,
                                                        );
                                                        try {
                                                          await context
                                                              .read<
                                                                PostService
                                                              >()
                                                              .deleteComment(
                                                                widget.postId,
                                                                commentId,
                                                              );
                                                        } catch (e) {
                                                          if (context.mounted) {
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  AppLocalizations.of(
                                                                    context,
                                                                  ).failedToDelete(
                                                                    '$e',
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                        }
                                                      },
                                                      child: Text(
                                                        AppLocalizations.of(
                                                          context,
                                                        ).deleteLabel,
                                                        style: const TextStyle(
                                                          color:
                                                              AppColors.black,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 56,
                                  right: 8,
                                  bottom: 4,
                                ),
                                child:
                                    StreamBuilder<
                                      QuerySnapshot<Map<String, dynamic>>
                                    >(
                                      stream: context
                                          .read<PostService>()
                                          .getReplies(widget.postId, commentId),
                                      builder:
                                          (
                                            BuildContext context,
                                            AsyncSnapshot<
                                              QuerySnapshot<
                                                Map<String, dynamic>
                                              >
                                            >
                                            replySnapshot,
                                          ) {
                                            if (!replySnapshot.hasData ||
                                                replySnapshot
                                                    .data!
                                                    .docs
                                                    .isEmpty) {
                                              return const SizedBox.shrink();
                                            }
                                            final List<
                                              QueryDocumentSnapshot<
                                                Map<String, dynamic>
                                              >
                                            >
                                            replies = replySnapshot.data!.docs;
                                            return Column(
                                              children: replies.map((
                                                QueryDocumentSnapshot<
                                                  Map<String, dynamic>
                                                >
                                                replyDoc,
                                              ) {
                                                final Map<String, dynamic>
                                                replyData = replyDoc.data();
                                                final String replyUsername =
                                                    replyData['username']
                                                        ?.toString() ??
                                                    'Anonymous';
                                                final String replyContent =
                                                    replyData['content']
                                                        ?.toString() ??
                                                    '';
                                                final Timestamp? replyTs =
                                                    replyData['timestamp']
                                                        as Timestamp?;
                                                final String replyTime =
                                                    replyTs != null
                                                    ? timeAgo(replyTs.toDate())
                                                    : 'now';

                                                return Container(
                                                  width: double.infinity,
                                                  margin: const EdgeInsets.only(
                                                    bottom: 6,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.gray100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: RichText(
                                                    text: TextSpan(
                                                      style: const TextStyle(
                                                        color: AppColors.black,
                                                        fontSize: 13,
                                                      ),
                                                      children: <InlineSpan>[
                                                        TextSpan(
                                                          text:
                                                              '$replyUsername ',
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                        TextSpan(
                                                          text: replyContent,
                                                        ),
                                                        TextSpan(
                                                          text:
                                                              '  •  $replyTime',
                                                          style:
                                                              const TextStyle(
                                                                color: AppColors
                                                                    .gray600,
                                                                fontSize: 12,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            );
                                          },
                                    ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
            ),
          ),
          Divider(height: 1, color: semantic.divider),
          if (_replyingToCommentId != null && _replyingToUsername != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
              color: AppColors.gray100,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Replying to @$_replyingToUsername',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.gray700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _clearReplyTarget,
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: _replyingToCommentId == null
                          ? 'Add a comment...'
                          : 'Write a reply...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ),
                IconButton(
                  icon: _isPosting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: _isPosting ? null : _submitCommentOrReply,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeGridPostTile extends StatelessWidget {
  const _HomeGridPostTile({required this.post});

  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) {
    final String username = post['username']?.toString() ?? 'Anonymous';
    final String caption = post['content']?.toString() ?? '';
    final String imageUrl = post['imageUrl']?.toString() ?? '';
    final bool hasImage = imageUrl.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: AppColors.white,
        child: InkWell(
          onTap: () {
            final int likeCount =
                (post['likes'] as List<dynamic>? ?? <dynamic>[]).length;
            final int commentCount = post['commentCount'] as int? ?? 0;
            final int shareCount = post['shareCount'] as int? ?? 0;
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (BuildContext context) => _HomeGridPostDetailSheet(
                post: post,
                likeCount: likeCount,
                commentCount: commentCount,
                shareCount: shareCount,
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: hasImage
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        memCacheWidth: 720,
                        placeholder: (BuildContext context, String _) =>
                            Container(
                              color: AppColors.gray200,
                              child: const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                        errorWidget:
                            (BuildContext context, String _, Object error) =>
                                Container(
                                  color: AppColors.gray200,
                                  child: const Center(
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                      )
                    : Container(
                        color: AppColors.gray200,
                        child: const Center(
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caption.isEmpty ? '-' : caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.gray700, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeGridPostDetailSheet extends StatelessWidget {
  const _HomeGridPostDetailSheet({
    required this.post,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
  });

  final Map<String, dynamic> post;
  final int likeCount;
  final int commentCount;
  final int shareCount;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = post['imageUrl']?.toString() ?? '';
    final String caption = post['content']?.toString() ?? '';
    final String location = post['location']?.toString() ?? '-';
    final List<dynamic> hashtags =
        post['hashtags'] as List<dynamic>? ?? <dynamic>[];
    final int totalEngagement = likeCount + commentCount + shareCount;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: <Widget>[
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 240,
                    fit: BoxFit.cover,
                    placeholder: (BuildContext context, String _) => Container(
                      height: 240,
                      color: AppColors.gray200,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget:
                        (BuildContext context, String _, Object error) =>
                            Container(
                              height: 240,
                              color: AppColors.gray200,
                              child: const Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                caption.isEmpty ? 'No caption' : caption,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
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
              const Text(
                'Insights',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _InsightTile(
                      label: 'Likes',
                      value: likeCount.toString(),
                      icon: Icons.favorite_border,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InsightTile(
                      label: 'Comments',
                      value: commentCount.toString(),
                      icon: Icons.chat_bubble_outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InsightTile(
                      label: 'Shares',
                      value: shareCount.toString(),
                      icon: Icons.send_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _InsightTile(
                label: 'Total Engagement',
                value: totalEngagement.toString(),
                icon: Icons.insights_outlined,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
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

String timeAgo(DateTime date) {
  final DateTime now = DateTime.now();
  final Duration difference = now.difference(date);

  if (difference.inDays > 7) {
    return '${date.day}/${date.month}/${date.year}';
  }
  if (difference.inDays > 0) {
    return '${difference.inDays}d ago';
  }
  if (difference.inHours > 0) {
    return '${difference.inHours}h ago';
  }
  if (difference.inMinutes > 0) {
    return '${difference.inMinutes}m ago';
  }
  return 'Just now';
}

class SkeletonPostCard extends StatefulWidget {
  const SkeletonPostCard({super.key});

  @override
  State<SkeletonPostCard> createState() => _SkeletonPostCardState();
}

class _SkeletonPostCardState extends State<SkeletonPostCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: AppColors.gray300,
      end: AppColors.gray100,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final Color? color = _colorAnimation.value;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.gray300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(backgroundColor: color),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(width: 120, height: 14, color: color),
                        const SizedBox(height: 6),
                        Container(width: 80, height: 12, color: color),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(width: double.infinity, height: 14, color: color),
                    const SizedBox(height: 6),
                    Container(width: 200, height: 14, color: color),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 4 / 5,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SmoothPostImage extends StatefulWidget {
  const _SmoothPostImage({required this.imageUrl});

  final String imageUrl;

  @override
  State<_SmoothPostImage> createState() => _SmoothPostImageState();
}

class _SmoothPostImageState extends State<_SmoothPostImage> {
  Timer? _timeoutTimer;
  bool _useFallbackNetwork = false;

  @override
  void initState() {
    super.initState();
    _startTimeout();
  }

  @override
  void didUpdateWidget(covariant _SmoothPostImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _useFallbackNetwork = false;
      _timeoutTimer?.cancel();
      _startTimeout();
    }
  }

  void _startTimeout() {
    _timeoutTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) {
        setState(() => _useFallbackNetwork = true);
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String imageUrl = widget.imageUrl;
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: _useFallbackNetwork
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder:
                    (
                      BuildContext context,
                      Widget child,
                      ImageChunkEvent? loadingProgress,
                    ) {
                      if (loadingProgress == null) {
                        return child;
                      }
                      return Container(
                        color: AppColors.gray200,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) => Container(
                      color: AppColors.gray200,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
              )
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 1080,
                fadeInDuration: const Duration(milliseconds: 220),
                placeholder: (BuildContext context, String _) => Container(
                  color: AppColors.gray200,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (BuildContext context, String _, Object error) =>
                    Container(
                      color: AppColors.gray200,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
              ),
      ),
    );
  }
}
