import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:sincerelysea/services/local_notification_service.dart';
import 'package:sincerelysea/widgets/customer_state_view.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _loading = true;
  bool _loadFailed = false;
  bool? _notificationEnabled;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
          ? CustomerStateView(
              icon: Icons.notifications_off_outlined,
              title: 'Notification settings unavailable',
              message: 'Please try again.',
              actionLabel: 'Retry',
              onAction: _load,
            )
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
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Community and store updates appear in the in-app notification center. Use your device settings to allow or mute system notifications.',
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final bool? enabled = await LocalNotificationService.instance
          .areNotificationsEnabled();
      if (!mounted) {
        return;
      }
      setState(() {
        _notificationEnabled = enabled;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
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
