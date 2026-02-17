import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sincerelysea/screens/legal/privacy_policy_screen.dart';
import 'package:sincerelysea/screens/legal/terms_of_service_screen.dart';
import 'package:sincerelysea/screens/profile/change_password_screen.dart';
import 'package:sincerelysea/screens/profile/profile_settings_screen.dart';
import 'package:sincerelysea/screens/settings/app_permissions_screen.dart';
import 'package:sincerelysea/screens/settings/app_version_screen.dart';
import 'package:sincerelysea/screens/settings/notification_preferences_screen.dart';
import 'package:sincerelysea/screens/settings/privacy_controls_screen.dart';
import 'package:sincerelysea/screens/settings/session_management_screen.dart';
import 'package:sincerelysea/screens/support/contact_support_screen.dart';
import 'package:sincerelysea/services/auth_service.dart';
import 'package:sincerelysea/services/local_notification_service.dart';
import 'package:sincerelysea/theme/app_semantic_colors.dart';

class ProfileSettingsMenuScreen extends StatefulWidget {
  const ProfileSettingsMenuScreen({super.key});

  @override
  State<ProfileSettingsMenuScreen> createState() =>
      _ProfileSettingsMenuScreenState();
}

class _ProfileSettingsMenuScreenState extends State<ProfileSettingsMenuScreen> {
  bool _clearingCache = false;
  bool _loadingCacheEstimate = true;
  int _estimatedCacheBytes = 0;
  String _privacyBadge = 'Checking...';
  String _permissionsBadge = 'Checking...';
  String _notificationsBadge = 'Checking...';

  @override
  void initState() {
    super.initState();
    _loadCacheEstimate();
    _refreshBadges();
  }

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors semantic = context.semanticColors;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          _SectionCard(
            title: 'Account',
            items: <Widget>[
              _SettingsItem(
                icon: Icons.person_outline,
                title: 'Edit Profile',
                subtitle: 'Name, bio, username, profile photo',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfileSettingsScreen(),
                  ),
                ),
              ),
              Divider(height: 1, color: semantic.divider),
              _SettingsItem(
                icon: Icons.lock_outline,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                ),
              ),
              Divider(height: 1, color: semantic.divider),
              _SettingsItem(
                icon: Icons.devices_outlined,
                title: 'Session Management',
                subtitle: 'Review active sessions and device access',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SessionManagementScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Privacy',
            items: <Widget>[
              _SettingsItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Controls',
                subtitle:
                    'Private account, comments, blocked users • $_privacyBadge',
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyControlsScreen(),
                    ),
                  );
                  if (mounted) {
                    await _refreshBadges();
                  }
                },
              ),
              Divider(height: 1, color: semantic.divider),
              _SettingsItem(
                icon: Icons.app_settings_alt_outlined,
                title: 'App Permissions',
                subtitle:
                    'Manage notification, location, camera and gallery • $_permissionsBadge',
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AppPermissionsScreen(),
                    ),
                  );
                  if (mounted) {
                    await _refreshBadges();
                  }
                },
              ),
              Divider(height: 1, color: semantic.divider),
              _SettingsItem(
                icon: Icons.visibility_off_outlined,
                title: 'Hidden Content',
                subtitle: 'Manage hidden posts and muted content',
                onTap: () => _openStub(
                  context,
                  title: 'Hidden Content',
                  description:
                      'This section is ready. Hidden posts and content preferences can be managed here.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Notifications',
            items: <Widget>[
              _SettingsItem(
                icon: Icons.notifications_outlined,
                title: 'Notification Preferences',
                subtitle:
                    'Likes, comments, follows, shares • $_notificationsBadge',
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationPreferencesScreen(),
                    ),
                  );
                  if (mounted) {
                    await _refreshBadges();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Data & Storage',
            items: <Widget>[
              _SettingsItem(
                icon: Icons.download_outlined,
                title: 'Export Data',
                subtitle: 'Download your account data',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfileSettingsScreen(),
                  ),
                ),
              ),
              Divider(height: 1, color: semantic.divider),
              _SettingsItem(
                icon: Icons.cleaning_services_outlined,
                title: 'Clear Media Cache',
                subtitle: _clearingCache
                    ? 'Clearing media cache...'
                    : _loadingCacheEstimate
                    ? 'Calculating cache usage...'
                    : 'Cached media: ${_formatMegabytes(_estimatedCacheBytes)}',
                onTap: _clearingCache ? null : _confirmAndClearMediaCache,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Support & Legal',
            items: <Widget>[
              _SettingsItem(
                icon: Icons.policy_outlined,
                title: 'Privacy Policy',
                subtitle: 'Read how your data is handled',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
              ),
              Divider(height: 1, color: semantic.divider),
              _SettingsItem(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                subtitle: 'Understand rules and terms of use',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TermsOfServiceScreen(),
                  ),
                ),
              ),
              Divider(height: 1, color: semantic.divider),
              _SettingsItem(
                icon: Icons.support_agent_outlined,
                title: 'Contact Support',
                subtitle: 'Report issues or request help',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ContactSupportScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'About',
            items: <Widget>[
              _SettingsItem(
                icon: Icons.info_outline,
                title: 'App Version',
                subtitle: 'Version, build, and diagnostics',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AppVersionScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.tonalIcon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  void _openStub(
    BuildContext context, {
    required String title,
    required String description,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _SettingsStubScreen(title: title, description: description),
      ),
    );
  }

  Future<void> _loadCacheEstimate() async {
    try {
      final int diskBytes = await DefaultCacheManager().store.getCacheSize();
      if (!mounted) {
        return;
      }
      setState(() {
        _estimatedCacheBytes = diskBytes;
        _loadingCacheEstimate = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingCacheEstimate = false);
    }
  }

  Future<void> _refreshBadges() async {
    await Future.wait(<Future<void>>[
      _loadPrivacyBadge(),
      _loadPermissionBadge(),
      _loadNotificationBadge(),
    ]);
  }

  Future<void> _loadPrivacyBadge() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _privacyBadge = 'Unknown');
      }
      return;
    }
    final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection('users')
        .doc(user.uid)
        .get();
    final bool privateOn = doc.data()?['isPrivate'] == true;
    if (!mounted) {
      return;
    }
    setState(() => _privacyBadge = privateOn ? 'Private ON' : 'Public');
  }

  Future<void> _loadPermissionBadge() async {
    final bool? notification = await LocalNotificationService.instance
        .areNotificationsEnabled();
    final bool locationServiceEnabled =
        await Geolocator.isLocationServiceEnabled();
    final LocationPermission locationPermission =
        await Geolocator.checkPermission();
    final ph.PermissionStatus camera = await ph.Permission.camera.status;
    final ph.PermissionStatus gallery = await ph.Permission.photos.status;

    int granted = 0;
    if (notification == true) {
      granted++;
    }
    if (locationServiceEnabled &&
        (locationPermission == LocationPermission.always ||
            locationPermission == LocationPermission.whileInUse)) {
      granted++;
    }
    if (camera.isGranted || camera.isLimited) {
      granted++;
    }
    if (gallery.isGranted || gallery.isLimited) {
      granted++;
    }
    final String label = granted == 4
        ? 'All allowed'
        : granted == 0
        ? 'Denied'
        : 'Partially allowed';
    if (!mounted) {
      return;
    }
    setState(() => _permissionsBadge = label);
  }

  Future<void> _loadNotificationBadge() async {
    const String kLikes = 'notif_pref_likes';
    const String kComments = 'notif_pref_comments';
    const String kFollows = 'notif_pref_follows';
    const String kShares = 'notif_pref_shares';
    const String kInApp = 'notif_pref_in_app';

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<bool> values = <bool>[
      prefs.getBool(kLikes) ?? true,
      prefs.getBool(kComments) ?? true,
      prefs.getBool(kFollows) ?? true,
      prefs.getBool(kShares) ?? true,
      prefs.getBool(kInApp) ?? true,
    ];
    final int enabledCount = values.where((bool v) => v).length;
    final String label = enabledCount == values.length
        ? 'All on'
        : enabledCount == 0
        ? 'Muted'
        : 'Custom';
    if (!mounted) {
      return;
    }
    setState(() => _notificationsBadge = label);
  }

  String _formatMegabytes(int bytes) {
    final double mb = bytes / (1024 * 1024);
    if (mb < 0.1) {
      return '< 0.1 MB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  String _recommendedAction(int bytes) {
    final double mb = bytes / (1024 * 1024);
    if (mb >= 200) {
      return 'Recommended: Clear now to free storage and keep scrolling smooth.';
    }
    if (mb >= 50) {
      return 'Recommended: Clear if your device storage is limited.';
    }
    return 'Recommendation: You can keep this cache for faster image loading.';
  }

  Future<void> _confirmAndClearMediaCache() async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Clear Media Cache'),
            content: Text(
              'Current cache: ${_formatMegabytes(_estimatedCacheBytes)}\n\n'
              '${_recommendedAction(_estimatedCacheBytes)}\n\n'
              'Do you want to continue?',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Clear'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    await _clearMediaCache();
  }

  Future<void> _clearMediaCache() async {
    setState(() => _clearingCache = true);
    try {
      await DefaultCacheManager().emptyCache();
      imageCache.clear();
      imageCache.clearLiveImages();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Media cache cleared successfully.')),
      );
      await _loadCacheEstimate();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to clear media cache.')),
      );
    } finally {
      if (mounted) {
        setState(() => _clearingCache = false);
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final bool shouldLogout =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Log out'),
            content: const Text('Are you sure you want to log out?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Log out'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldLogout || !context.mounted) {
      return;
    }
    await context.read<AuthService>().signOut();
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.items});

  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: items),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _SettingsStubScreen extends StatelessWidget {
  const _SettingsStubScreen({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(description, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
