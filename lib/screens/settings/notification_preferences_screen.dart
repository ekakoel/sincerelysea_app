import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sincerelysea/services/local_notification_service.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _loading = true;
  bool? _notificationEnabled;

  bool _likes = true;
  bool _comments = true;
  bool _follows = true;
  bool _shares = true;
  bool _inApp = true;

  static const String _kLikes = 'notif_pref_likes';
  static const String _kComments = 'notif_pref_comments';
  static const String _kFollows = 'notif_pref_follows';
  static const String _kShares = 'notif_pref_shares';
  static const String _kInApp = 'notif_pref_in_app';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: <Widget>[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('System notification permission'),
                    subtitle: Text(
                      _notificationEnabled == true ? 'Allowed' : 'Denied',
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: <Widget>[
                        TextButton(
                          onPressed: _requestPermission,
                          child: const Text('Request'),
                        ),
                        IconButton(
                          tooltip: 'Open app settings',
                          onPressed: _openAppSettings,
                          icon: const Icon(Icons.settings_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Activity notifications',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: <Widget>[
                      SwitchListTile(
                        title: const Text('Likes'),
                        subtitle: const Text(
                          'Notify when someone likes your post',
                        ),
                        value: _likes,
                        onChanged: (bool value) => _updatePref(_kLikes, value),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Comments'),
                        subtitle: const Text(
                          'Notify when someone comments on your post',
                        ),
                        value: _comments,
                        onChanged: (bool value) =>
                            _updatePref(_kComments, value),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Follows'),
                        subtitle: const Text(
                          'Notify when someone follows your account',
                        ),
                        value: _follows,
                        onChanged: (bool value) =>
                            _updatePref(_kFollows, value),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Shares'),
                        subtitle: const Text(
                          'Notify when your post is shared by others',
                        ),
                        value: _shares,
                        onChanged: (bool value) => _updatePref(_kShares, value),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('In-app inbox'),
                        subtitle: const Text(
                          'Show activity updates in notification center',
                        ),
                        value: _inApp,
                        onChanged: (bool value) => _updatePref(_kInApp, value),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool? enabled = await LocalNotificationService.instance
        .areNotificationsEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _notificationEnabled = enabled;
      _likes = prefs.getBool(_kLikes) ?? true;
      _comments = prefs.getBool(_kComments) ?? true;
      _follows = prefs.getBool(_kFollows) ?? true;
      _shares = prefs.getBool(_kShares) ?? true;
      _inApp = prefs.getBool(_kInApp) ?? true;
      _loading = false;
    });
  }

  Future<void> _updatePref(String key, bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (!mounted) {
      return;
    }
    setState(() {
      switch (key) {
        case _kLikes:
          _likes = value;
          break;
        case _kComments:
          _comments = value;
          break;
        case _kFollows:
          _follows = value;
          break;
        case _kShares:
          _shares = value;
          break;
        case _kInApp:
          _inApp = value;
          break;
      }
    });
  }

  Future<void> _requestPermission() async {
    final bool granted = await LocalNotificationService.instance
        .requestNotificationPermission();
    if (!mounted) {
      return;
    }
    setState(() => _notificationEnabled = granted);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Notification permission granted'
              : 'Notification permission denied',
        ),
      ),
    );
  }

  Future<void> _openAppSettings() async {
    await ph.openAppSettings();
  }
}
