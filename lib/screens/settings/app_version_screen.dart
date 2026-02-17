import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppVersionScreen extends StatefulWidget {
  const AppVersionScreen({super.key});

  @override
  State<AppVersionScreen> createState() => _AppVersionScreenState();
}

class _AppVersionScreenState extends State<AppVersionScreen> {
  static const String _iosAppStoreId = '';
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  @override
  Widget build(BuildContext context) {
    final PackageInfo? info = _info;
    final String appName = info?.appName ?? 'SincerelySea';
    final String packageName = info?.packageName ?? '-';
    final String version = info?.version ?? '-';
    final String build = info?.buildNumber ?? '-';
    final String platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    final List<String> releaseNotes = _releaseNotesForVersion(version);

    return Scaffold(
      appBar: AppBar(title: const Text('App Version')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    appName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Version $version ($build)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(title: const Text('Version'), trailing: Text(version)),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Build Number'),
                  trailing: Text(build),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Platform'),
                  trailing: Text(platform),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () => _checkForUpdates(packageName: packageName),
            icon: const Icon(Icons.system_update_alt_outlined),
            label: const Text('Check for Updates'),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Release Notes',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...releaseNotes.map(
                    (String note) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $note'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => _copyAppInfo(
              appName: appName,
              version: version,
              build: build,
              platform: platform,
            ),
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy App Info'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () {
              showLicensePage(
                context: context,
                applicationName: appName,
                applicationVersion: '$version ($build)',
              );
            },
            icon: const Icon(Icons.description_outlined),
            label: const Text('Open Source Licenses'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadInfo() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() => _info = info);
  }

  Future<void> _copyAppInfo({
    required String appName,
    required String version,
    required String build,
    required String platform,
  }) async {
    final String text =
        'App: $appName\n'
        'Version: $version ($build)\n'
        'Platform: $platform';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('App info copied')));
  }

  Future<void> _checkForUpdates({required String packageName}) async {
    if (kIsWeb) {
      _showInfo('Check updates is available on mobile app stores.');
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final Uri marketUri = Uri.parse('market://details?id=$packageName');
      final Uri webUri = Uri.parse(
        'https://play.google.com/store/apps/details?id=$packageName',
      );
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        return;
      }
      final bool launched = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showInfo('Failed to open Play Store.');
      }
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (_iosAppStoreId.isEmpty) {
        _showInfo('Set iOS App Store ID in app_version_screen.dart first.');
        return;
      }
      final Uri uri = Uri.parse('https://apps.apple.com/app/id$_iosAppStoreId');
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showInfo('Failed to open App Store.');
      }
      return;
    }
    _showInfo('Store updates are not supported on this platform.');
  }

  List<String> _releaseNotesForVersion(String version) {
    const Map<String, List<String>> notes = <String, List<String>>{
      '1.0.0': <String>[
        'Introduced full Settings hub with centralized controls.',
        'Added Notification Preferences with per-event toggles.',
        'Improved App Permissions flow with clear allowed/denied states.',
        'Expanded legal/support pages and account management tools.',
      ],
    };
    return notes[version] ??
        <String>[
          'Stability improvements and bug fixes.',
          'UI/UX refinements for performance and consistency.',
        ];
  }

  void _showInfo(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
