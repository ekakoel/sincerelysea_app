import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:sincerelysea/services/local_notification_service.dart';

class AppPermissionsScreen extends StatefulWidget {
  const AppPermissionsScreen({super.key});

  @override
  State<AppPermissionsScreen> createState() => _AppPermissionsScreenState();
}

class _AppPermissionsScreenState extends State<AppPermissionsScreen> {
  bool _loadingPermissions = false;
  LocationPermission _locationPermission = LocationPermission.unableToDetermine;
  bool _locationServiceEnabled = false;
  bool? _notificationEnabled;
  ph.PermissionStatus _cameraPermission = ph.PermissionStatus.denied;
  ph.PermissionStatus _galleryPermission = ph.PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshPermissionStatus());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Permissions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Permission Status',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_loadingPermissions) ...<Widget>[
                const SizedBox(width: 10),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  subtitle: Text(_notificationPermissionLabel()),
                  trailing: _PermissionTileActions(
                    showRequest: !(_notificationEnabled == true),
                    onRequest: _requestNotificationPermission,
                    onOpenSettings: _openAppSettings,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Location'),
                  subtitle: Text(_locationPermissionLabel()),
                  trailing: _PermissionTileActions(
                    showRequest: !_isLocationGranted(),
                    onRequest: _requestLocationPermission,
                    onOpenSettings: _openAppSettings,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Camera'),
                  subtitle: Text(_permissionStatusLabel(_cameraPermission)),
                  trailing: _PermissionTileActions(
                    showRequest:
                        !(_cameraPermission.isGranted ||
                            _cameraPermission.isLimited),
                    onRequest: _requestCameraPermission,
                    onOpenSettings: _openAppSettings,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Gallery'),
                  subtitle: Text(_permissionStatusLabel(_galleryPermission)),
                  trailing: _PermissionTileActions(
                    showRequest:
                        !(_galleryPermission.isGranted ||
                            _galleryPermission.isLimited),
                    onRequest: _requestGalleryPermission,
                    onOpenSettings: _openAppSettings,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshPermissionStatus() async {
    if (!mounted) {
      return;
    }
    setState(() => _loadingPermissions = true);
    try {
      final bool locationServiceEnabled =
          await Geolocator.isLocationServiceEnabled();
      final LocationPermission locationPermission =
          await Geolocator.checkPermission();
      final bool? notificationEnabled = await LocalNotificationService.instance
          .areNotificationsEnabled();
      final ph.PermissionStatus cameraPermission =
          await ph.Permission.camera.status;
      final ph.PermissionStatus galleryPermission =
          await ph.Permission.photos.status;
      if (!mounted) {
        return;
      }
      setState(() {
        _locationServiceEnabled = locationServiceEnabled;
        _locationPermission = locationPermission;
        _notificationEnabled = notificationEnabled;
        _cameraPermission = cameraPermission;
        _galleryPermission = galleryPermission;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingPermissions = false);
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    final bool granted = await LocalNotificationService.instance
        .requestNotificationPermission();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Notification permission granted'
              : 'Notification permission denied',
        ),
      ),
    );
    await _refreshPermissionStatus();
  }

  Future<void> _requestLocationPermission() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable location service first.'),
          ),
        );
      }
      await Geolocator.openLocationSettings();
      await _refreshPermissionStatus();
      return;
    }

    final LocationPermission permission = await Geolocator.requestPermission();
    if (!mounted) {
      return;
    }
    final bool granted =
        permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Location permission granted'
              : 'Location permission denied',
        ),
      ),
    );
    await _refreshPermissionStatus();
  }

  Future<void> _requestCameraPermission() async {
    final ph.PermissionStatus status = await ph.Permission.camera.request();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Camera permission: ${_permissionStatusLabel(status)}'),
      ),
    );
    await _refreshPermissionStatus();
  }

  Future<void> _requestGalleryPermission() async {
    final ph.PermissionStatus status = await ph.Permission.photos.request();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gallery permission: ${_permissionStatusLabel(status)}'),
      ),
    );
    await _refreshPermissionStatus();
  }

  Future<void> _openAppSettings() async {
    await ph.openAppSettings();
  }

  String _locationPermissionLabel() {
    if (!_locationServiceEnabled) {
      return 'Service Off';
    }
    switch (_locationPermission) {
      case LocationPermission.always:
        return 'Allowed Always';
      case LocationPermission.whileInUse:
        return 'Allowed While Using';
      case LocationPermission.denied:
        return 'Denied';
      case LocationPermission.deniedForever:
        return 'Denied Permanently';
      case LocationPermission.unableToDetermine:
        return 'Not Determined';
    }
  }

  String _notificationPermissionLabel() {
    if (_notificationEnabled == null) {
      return 'Status Unavailable';
    }
    return _notificationEnabled! ? 'Allowed' : 'Denied';
  }

  bool _isLocationGranted() {
    if (!_locationServiceEnabled) {
      return false;
    }
    return _locationPermission == LocationPermission.always ||
        _locationPermission == LocationPermission.whileInUse;
  }

  String _permissionStatusLabel(ph.PermissionStatus status) {
    if (status.isGranted) {
      return 'Allowed';
    }
    if (status.isLimited) {
      return 'Limited';
    }
    if (status.isPermanentlyDenied) {
      return 'Denied Permanently';
    }
    if (status.isRestricted) {
      return 'Restricted';
    }
    if (status.isProvisional) {
      return 'Provisional';
    }
    return 'Denied';
  }
}

class _PermissionTileActions extends StatelessWidget {
  const _PermissionTileActions({
    required this.showRequest,
    required this.onRequest,
    required this.onOpenSettings,
  });

  final bool showRequest;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showRequest)
            TextButton(
              onPressed: onRequest,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Request'),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Allowed',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          IconButton(
            tooltip: 'Open app settings',
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}
