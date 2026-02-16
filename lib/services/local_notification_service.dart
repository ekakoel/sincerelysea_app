import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationTapPayload {
  const NotificationTapPayload({
    required this.type,
    this.postId,
    this.actorUid,
    this.rawPayload,
  });

  final String type;
  final String? postId;
  final String? actorUid;
  final String? rawPayload;
}

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  static const String postUploadChannelId = 'post_upload_progress';
  static const String postUploadChannelName = 'Post upload progress';
  static const String postUploadChannelDesc =
      'Ongoing progress for post upload';
  static const String postUpdatesChannelId = 'post_updates';
  static const String postUpdatesChannelName = 'Post updates';
  static const String postUpdatesChannelDesc =
      'Notifications for post upload status';
  static const String activityChannelId = 'social_activity';
  static const String activityChannelName = 'Social activity';
  static const String activityChannelDesc =
      'Notifications for like, comment, follow, and share';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<NotificationTapPayload> _tapController =
      StreamController<NotificationTapPayload>.broadcast();
  bool _initialized = false;
  static const int _uploadProgressNotificationId = 1000;
  Stream<NotificationTapPayload> get tapStream => _tapController.stream;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwinInit =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    await _createAndroidChannels();
    _initialized = true;
  }

  Future<void> _createAndroidChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) {
      return;
    }

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        postUploadChannelId,
        postUploadChannelName,
        description: postUploadChannelDesc,
        importance: Importance.low,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        postUpdatesChannelId,
        postUpdatesChannelName,
        description: postUpdatesChannelDesc,
        importance: Importance.high,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        activityChannelId,
        activityChannelName,
        description: activityChannelDesc,
        importance: Importance.defaultImportance,
      ),
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    final NotificationTapPayload payload = _parsePayload(response.payload);
    _tapController.add(payload);
  }

  NotificationTapPayload _parsePayload(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const NotificationTapPayload(type: 'unknown');
    }
    final Uri? uri = Uri.tryParse(raw);
    if (uri == null) {
      return NotificationTapPayload(type: 'unknown', rawPayload: raw);
    }
    return NotificationTapPayload(
      type: uri.queryParameters['type'] ?? 'unknown',
      postId: uri.queryParameters['postId'],
      actorUid: uri.queryParameters['actorUid'],
      rawPayload: raw,
    );
  }

  Future<bool> requestNotificationPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final bool? androidGranted = await androidPlugin
        ?.requestNotificationsPermission();
    if (androidGranted != null) {
      return androidGranted;
    }

    final IOSFlutterLocalNotificationsPlugin? iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final bool? iosGranted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (iosGranted != null) {
      return iosGranted;
    }

    final MacOSFlutterLocalNotificationsPlugin? macPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    final bool? macGranted = await macPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return macGranted ?? false;
  }

  Future<bool?> areNotificationsEnabled() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return androidPlugin?.areNotificationsEnabled();
  }

  Future<void> showPostPublishedNotification() async {
    await cancelUploadProgressNotification();
    await _plugin.show(
      1001,
      'Post published',
      'Your post has been published.',
      _notificationDetails(channelId: postUpdatesChannelId),
    );
  }

  Future<void> showPostFailedNotification() async {
    await cancelUploadProgressNotification();
    await _plugin.show(
      1002,
      'Post failed',
      'We could not publish your post. Please try again.',
      _notificationDetails(channelId: postUpdatesChannelId),
    );
  }

  Future<void> showUploadProgressNotification({
    required int progress,
    bool isPublishing = false,
  }) async {
    final int safeProgress = progress.clamp(0, 100);
    await _plugin.show(
      _uploadProgressNotificationId,
      isPublishing ? 'Publishing post' : 'Uploading post',
      isPublishing
          ? 'Finalizing your post...'
          : 'Upload progress: $safeProgress%',
      NotificationDetails(
        android: AndroidNotificationDetails(
          postUploadChannelId,
          postUploadChannelName,
          channelDescription: postUploadChannelDesc,
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          ongoing: true,
          showProgress: true,
          maxProgress: 100,
          progress: safeProgress,
          indeterminate: isPublishing,
        ),
      ),
    );
  }

  Future<void> showActivityNotification({
    required int id,
    required String title,
    required String body,
    String type = 'activity',
    String? postId,
    String? actorUid,
  }) async {
    final Map<String, String> query = <String, String>{
      'type': type,
      if (postId != null && postId.isNotEmpty) 'postId': postId,
      if (actorUid != null && actorUid.isNotEmpty) 'actorUid': actorUid,
    };
    final String payload = Uri(
      scheme: 'sincerelysea',
      host: 'notification',
      queryParameters: query,
    ).toString();
    await _plugin.show(
      id,
      title,
      body,
      _notificationDetails(channelId: activityChannelId),
      payload: payload,
    );
  }

  Future<void> cancelUploadProgressNotification() async {
    await _plugin.cancel(_uploadProgressNotificationId);
  }

  NotificationDetails _notificationDetails({required String channelId}) {
    final String channelName = switch (channelId) {
      postUpdatesChannelId => postUpdatesChannelName,
      activityChannelId => activityChannelName,
      _ => postUpdatesChannelName,
    };
    final String channelDesc = switch (channelId) {
      postUpdatesChannelId => postUpdatesChannelDesc,
      activityChannelId => activityChannelDesc,
      _ => postUpdatesChannelDesc,
    };
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
    );
  }
}
