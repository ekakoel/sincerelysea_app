import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:sincerelysea/services/post_service.dart';

class MapPostsScreen extends StatefulWidget {
  const MapPostsScreen({super.key});

  @override
  State<MapPostsScreen> createState() => _MapPostsScreenState();
}

class _MapPostsScreenState extends State<MapPostsScreen> {
  static const LatLng _defaultCenter = LatLng(-2.5489, 118.0149);
  static const double _minZoom = 1;
  static const double _maxZoom = 20;
  static const double _minCenterShiftThreshold = 0.02;
  static const double _minSpanChangeRatioThreshold = 0.35;

  final ClusterManagerId _postClusterManagerId = const ClusterManagerId(
    'post_cluster_manager',
  );
  late final ClusterManager _postClusterManager = ClusterManager(
    clusterManagerId: _postClusterManagerId,
    onClusterTap: _handleClusterTap,
  );

  GoogleMapController? _mapController;
  LatLng _currentTarget = _defaultCenter;
  double _currentZoom = 2;
  final ValueNotifier<LatLngBounds?> _visibleBoundsNotifier =
      ValueNotifier<LatLngBounds?>(null);
  LatLngBounds? _pendingBounds;
  bool _showExploreAreaButton = false;
  int _popularLimit = 20;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _latestDocs =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  List<String> _appliedPopularPostIds = <String>[];
  Timer? _cameraIdleDebounceTimer;
  Timer? _markerRefreshDebounceTimer;
  final Map<String, BitmapDescriptor> _markerIconCache =
      <String, BitmapDescriptor>{};
  final Set<String> _markerIconLoading = <String>{};
  static const TextStyle _panelTitleStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );
  static const TextStyle _panelSubtitleStyle = TextStyle(
    fontSize: 11,
    height: 1.1,
  );

  @override
  void dispose() {
    _mapController?.dispose();
    _visibleBoundsNotifier.dispose();
    _cameraIdleDebounceTimer?.cancel();
    _markerRefreshDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PostService postService = context.read<PostService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Explore Map')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: postService.getPostsForMap(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Failed to load map posts: ${snapshot.error}',
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                  snapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              _latestDocs = docs;
              final LatLngBounds? appliedBounds = _visibleBoundsNotifier.value;
              final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
              docsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
                for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                    in docs)
                  doc.id: doc,
              };
              List<QueryDocumentSnapshot<Map<String, dynamic>>> popularInZone =
                  _appliedPopularPostIds
                      .map((String id) => docsById[id])
                      .whereType<QueryDocumentSnapshot<Map<String, dynamic>>>()
                      .toList();
              if (_appliedPopularPostIds.isEmpty || popularInZone.isEmpty) {
                popularInZone = _getPopularPostsInVisibleZone(
                  docs,
                  bounds: appliedBounds,
                  limit: _popularLimit,
                );
              }
              final Set<Marker> markers = <Marker>{};
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in popularInZone) {
                final Map<String, dynamic> data = doc.data();
                final LatLng? point = _extractLatLng(data);
                if (point == null) {
                  continue;
                }
                final String imageUrl = data['imageUrl']?.toString() ?? '';
                _ensureMarkerIcon(postId: doc.id, imageUrl: imageUrl);

                markers.add(
                  Marker(
                    markerId: MarkerId(doc.id),
                    position: point,
                    clusterManagerId: _postClusterManagerId,
                    icon:
                        _markerIconCache[doc.id] ??
                        BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueAzure,
                        ),
                    infoWindow: InfoWindow(
                      title: _buildMarkerTitle(data),
                      snippet: _buildMarkerSnippet(data),
                    ),
                    onTap: () => _showPostPreview(data),
                  ),
                );
              }

              return Column(
                children: <Widget>[
                  Expanded(
                    child: Stack(
                      children: <Widget>[
                        GoogleMap(
                          key: const ValueKey<String>('explore_map'),
                          initialCameraPosition: CameraPosition(
                            target: _currentTarget,
                            zoom: _currentZoom,
                          ),
                          minMaxZoomPreference: const MinMaxZoomPreference(
                            _minZoom,
                            _maxZoom,
                          ),
                          onMapCreated: (GoogleMapController controller) {
                            _mapController = controller;
                            _captureVisibleBounds(applyToPanel: true);
                          },
                          onCameraMove: (CameraPosition position) {
                            _currentTarget = position.target;
                            _currentZoom = position.zoom;
                          },
                          onCameraIdle: _onCameraIdleDebounced,
                          clusterManagers: <ClusterManager>{
                            _postClusterManager,
                          },
                          markers: markers,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: true,
                          zoomGesturesEnabled: true,
                        ),
                        if (markers.isEmpty)
                          Positioned(
                            left: 16,
                            right: 16,
                            top: 12,
                            child: Material(
                              borderRadius: BorderRadius.circular(10),
                              color: AppColors.white.withValues(
                                alpha: 0.92,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Text(
                                  'No post with location yet.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        if (_showExploreAreaButton)
                          Positioned(
                            top: 12,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: FilledButton.icon(
                                onPressed: _exploreThisArea,
                                icon: const Icon(Icons.explore_outlined),
                                label: const Text('Explore this area'),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 12,
                          bottom: 16,
                          child: Column(
                            children: <Widget>[
                              FloatingActionButton.small(
                                heroTag: 'map-zoom-in',
                                onPressed: _zoomIn,
                                child: const Icon(Icons.add),
                              ),
                              const SizedBox(height: 8),
                              FloatingActionButton.small(
                                heroTag: 'map-zoom-out',
                                onPressed: _zoomOut,
                                child: const Icon(Icons.remove),
                              ),
                              const SizedBox(height: 8),
                              FloatingActionButton.small(
                                heroTag: 'map-current-location',
                                onPressed: _moveToCurrentLocation,
                                child: const Icon(Icons.my_location),
                              ),
                              const SizedBox(height: 8),
                              FloatingActionButton.small(
                                heroTag: 'map-world',
                                onPressed: _focusToWorld,
                                child: const Icon(Icons.public),
                              ),
                              const SizedBox(height: 8),
                              FloatingActionButton.small(
                                heroTag: 'map-fit-all',
                                onPressed: () => _focusToAllMarkers(markers),
                                child: const Icon(Icons.center_focus_strong),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildPopularPostsPanel(
                    popularInZone,
                    hasAnyPost: popularInZone.isNotEmpty,
                  ),
                ],
              );
            },
      ),
    );
  }

  void _exploreThisArea() {
    if (_pendingBounds == null) {
      return;
    }
    _visibleBoundsNotifier.value = _pendingBounds;
    _refreshAppliedPopularPostIds();
    if (mounted) {
      setState(() => _showExploreAreaButton = false);
    }
  }

  void _refreshAppliedPopularPostIds() {
    final LatLngBounds? bounds = _visibleBoundsNotifier.value;
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> popularInZone =
        _getPopularPostsInVisibleZone(
          _latestDocs,
          bounds: bounds,
          limit: _popularLimit,
        );
    _appliedPopularPostIds = popularInZone
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id)
        .toList();
  }

  String _buildMarkerTitle(Map<String, dynamic> data) {
    final String username = data['username']?.toString() ?? 'Post';
    final String caption = data['content']?.toString() ?? '';
    if (caption.isEmpty) {
      return username;
    }
    final String shortCaption = caption.length > 16
        ? '${caption.substring(0, 16)}...'
        : caption;
    return '$username • $shortCaption';
  }

  String _buildMarkerSnippet(Map<String, dynamic> data) {
    final String location = data['location']?.toString() ?? '';
    final List<dynamic> hashtags =
        data['hashtags'] as List<dynamic>? ?? <dynamic>[];
    final String tags = hashtags
        .take(2)
        .map((dynamic tag) => tag.toString())
        .join(' ');
    if (location.isNotEmpty && tags.isNotEmpty) {
      return '$location | $tags';
    }
    final String value = location.isNotEmpty ? location : tags;
    if (value.length <= 20) {
      return value;
    }
    return '${value.substring(0, 20)}...';
  }

  void _showPostPreview(Map<String, dynamic> data) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if ((data['imageUrl']?.toString() ?? '').isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  data['imageUrl'].toString(),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 10),
            Text(
              data['content']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              data['username']?.toString() ?? 'Anonymous',
              style: TextStyle(color: AppColors.gray700),
            ),
            const SizedBox(height: 6),
            Text(
              data['location']?.toString() ?? '',
              style: TextStyle(color: AppColors.gray700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: (data['hashtags'] as List<dynamic>? ?? <dynamic>[])
                  .map((dynamic tag) => Text(tag.toString()))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ensureMarkerIcon({
    required String postId,
    required String imageUrl,
  }) async {
    if (imageUrl.isEmpty ||
        _markerIconCache.containsKey(postId) ||
        _markerIconLoading.contains(postId)) {
      return;
    }

    _markerIconLoading.add(postId);
    try {
      final BitmapDescriptor icon = await _createCustomMarkerIcon(imageUrl);
      if (!mounted) {
        return;
      }
      _markerIconCache[postId] = icon;
      _scheduleMarkerRefresh();
    } catch (_) {
      // Fallback to default marker when image fetch/render fails.
    } finally {
      _markerIconLoading.remove(postId);
    }
  }

  void _scheduleMarkerRefresh() {
    _markerRefreshDebounceTimer?.cancel();
    _markerRefreshDebounceTimer = Timer(
      const Duration(milliseconds: 120),
      () {
        if (!mounted) {
          return;
        }
        setState(() {});
      },
    );
  }

  Future<BitmapDescriptor> _createCustomMarkerIcon(String imageUrl) async {
    final Uri uri = Uri.parse(imageUrl);
    final http.Response response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to download image');
    }

    final Uint8List bytes = response.bodyBytes;
    final ui.Codec codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 60,
      targetHeight: 60,
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    const double canvasSize = 80;
    const double avatarRadius = 21;
    const double borderRadius = 23.5;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    const Offset center = Offset(canvasSize / 2, 30);

    final Paint shadowPaint = Paint()..color = AppColors.shadowLow;
    canvas.drawCircle(center.translate(0, 4), borderRadius, shadowPaint);

    final Paint borderPaint = Paint()..color = AppColors.white;
    canvas.drawCircle(center, borderRadius, borderPaint);

    final Path avatarClip = Path()
      ..addOval(Rect.fromCircle(center: center, radius: avatarRadius));
    canvas.save();
    canvas.clipPath(avatarClip);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCircle(center: center, radius: avatarRadius),
      Paint(),
    );
    canvas.restore();

    final Path pointerPath = Path()
      ..moveTo(canvasSize / 2, 75)
      ..lineTo(canvasSize / 2 - 8, 51)
      ..lineTo(canvasSize / 2 + 8, 51)
      ..close();
    canvas.drawPath(pointerPath, Paint()..color = AppColors.gray700);

    final ui.Image markerImage = await recorder.endRecording().toImage(
      canvasSize.toInt(),
      canvasSize.toInt(),
    );
    final ByteData? pngBytes = await markerImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (pngBytes == null) {
      throw Exception('Failed to encode marker image');
    }

    return BitmapDescriptor.bytes(pngBytes.buffer.asUint8List());
  }

  Future<void> _moveToCurrentLocation() async {
    final GoogleMapController? controller = _mapController;
    if (controller == null) {
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition();
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          14,
        ),
      );
      _currentTarget = LatLng(position.latitude, position.longitude);
      _currentZoom = 14;
    } catch (_) {
      // Ignore when permission/service is not available.
    }
  }

  Future<void> _zoomIn() async {
    await _zoomBy(1);
  }

  Future<void> _zoomOut() async {
    await _zoomBy(-1);
  }

  Future<void> _zoomBy(double delta) async {
    final GoogleMapController? controller = _mapController;
    if (controller == null) {
      return;
    }

    double baseZoom = _currentZoom;
    try {
      baseZoom = await controller.getZoomLevel();
    } catch (_) {
      // Fallback to locally tracked zoom.
    }

    final double target = (baseZoom + delta).clamp(_minZoom, _maxZoom);
    if ((target - baseZoom).abs() < 0.0001) {
      return;
    }
    _currentZoom = target;
    await controller.animateCamera(CameraUpdate.zoomTo(target));
  }

  Future<void> _focusToAllMarkers(Set<Marker> markers) async {
    final GoogleMapController? controller = _mapController;
    if (controller == null || markers.isEmpty) {
      return;
    }

    if (markers.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(markers.first.position, 12),
      );
      return;
    }

    double minLat = markers.first.position.latitude;
    double maxLat = markers.first.position.latitude;
    double minLng = markers.first.position.longitude;
    double maxLng = markers.first.position.longitude;

    for (final Marker marker in markers) {
      final double lat = marker.position.latitude;
      final double lng = marker.position.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
  }

  Future<void> _focusToWorld() async {
    final GoogleMapController? controller = _mapController;
    if (controller == null) {
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(
          target: LatLng(0, 0),
          zoom: 1,
        ),
      ),
    );
    _currentTarget = const LatLng(0, 0);
    _currentZoom = 1;

    await Future<void>.delayed(const Duration(milliseconds: 220));
    await _captureVisibleBounds(applyToPanel: true);
    _refreshAppliedPopularPostIds();
    if (mounted && _showExploreAreaButton) {
      setState(() => _showExploreAreaButton = false);
    }
  }

  void _handleClusterTap(Cluster cluster) {
    final GoogleMapController? controller = _mapController;
    if (controller == null) {
      return;
    }

    controller.animateCamera(CameraUpdate.newLatLngBounds(cluster.bounds, 64));
  }

  void _onCameraIdleDebounced() {
    _cameraIdleDebounceTimer?.cancel();
    _cameraIdleDebounceTimer = Timer(
      const Duration(milliseconds: 250),
      () => _captureVisibleBounds(applyToPanel: false),
    );
  }

  Future<void> _captureVisibleBounds({required bool applyToPanel}) async {
    final GoogleMapController? controller = _mapController;
    if (controller == null) {
      return;
    }
    try {
      final LatLngBounds bounds = await controller.getVisibleRegion();
      if (!mounted) {
        return;
      }
      if (!_isValidBounds(bounds)) {
        return;
      }
      final LatLngBounds? old = _visibleBoundsNotifier.value;
      if (old != null &&
          (old.southwest.latitude - bounds.southwest.latitude).abs() < 0.0001 &&
          (old.southwest.longitude - bounds.southwest.longitude).abs() <
              0.0001 &&
          (old.northeast.latitude - bounds.northeast.latitude).abs() < 0.0001 &&
          (old.northeast.longitude - bounds.northeast.longitude).abs() <
              0.0001) {
        return;
      }
      if (!applyToPanel && old != null && !_isSignificantBoundsChange(old, bounds)) {
        if (mounted && _showExploreAreaButton) {
          setState(() => _showExploreAreaButton = false);
        }
        return;
      }
      _pendingBounds = bounds;
      if (applyToPanel || old == null) {
        _visibleBoundsNotifier.value = bounds;
        _refreshAppliedPopularPostIds();
        if (mounted && _showExploreAreaButton) {
          setState(() => _showExploreAreaButton = false);
        }
        return;
      }
      if (mounted && !_showExploreAreaButton) {
        setState(() => _showExploreAreaButton = true);
      }
    } catch (_) {
      // Ignore occasional platform map bounds errors.
    }
  }

  bool _isValidBounds(LatLngBounds bounds) {
    final double latSpan =
        (bounds.northeast.latitude - bounds.southwest.latitude).abs();
    final double lngSpan =
        _wrapLongitudeDelta(
          bounds.northeast.longitude - bounds.southwest.longitude,
        ).abs();
    if (latSpan < 0.000001 && lngSpan < 0.000001) {
      return false;
    }
    return true;
  }

  bool _isSignificantBoundsChange(LatLngBounds old, LatLngBounds next) {
    final double oldCenterLat =
        (old.southwest.latitude + old.northeast.latitude) / 2;
    final double oldCenterLng =
        (old.southwest.longitude + old.northeast.longitude) / 2;
    final double nextCenterLat =
        (next.southwest.latitude + next.northeast.latitude) / 2;
    final double nextCenterLng =
        (next.southwest.longitude + next.northeast.longitude) / 2;

    final double centerShift =
        (oldCenterLat - nextCenterLat).abs() +
        (oldCenterLng - nextCenterLng).abs();

    final double oldLatSpan =
        (old.northeast.latitude - old.southwest.latitude).abs();
    final double oldLngSpan =
        _wrapLongitudeDelta(old.northeast.longitude - old.southwest.longitude)
            .abs();
    final double nextLatSpan =
        (next.northeast.latitude - next.southwest.latitude).abs();
    final double nextLngSpan =
        _wrapLongitudeDelta(next.northeast.longitude - next.southwest.longitude)
            .abs();

    final double oldSpan = oldLatSpan + oldLngSpan;
    final double nextSpan = nextLatSpan + nextLngSpan;
    final double spanBase = oldSpan <= 0.000001 ? 0.000001 : oldSpan;
    final double spanChangeRatio = (nextSpan - oldSpan).abs() / spanBase;

    return centerShift >= _minCenterShiftThreshold ||
        spanChangeRatio >= _minSpanChangeRatioThreshold;
  }

  double _wrapLongitudeDelta(double delta) {
    final double raw = delta.abs();
    if (raw <= 180) {
      return raw;
    }
    return 360 - raw;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>>
  _getPopularPostsInVisibleZone(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required LatLngBounds? bounds,
    required int limit,
  }) {
    int scoreOf(Map<String, dynamic> data) {
      return (data['likes'] as List<dynamic>? ?? <dynamic>[]).length +
          (data['commentCount'] as int? ?? 0) +
          (data['shareCount'] as int? ?? 0);
    }

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> inZone =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final LatLng? point = _extractLatLng(doc.data());
      if (point == null) {
        continue;
      }
      if (bounds == null || _isInsideBounds(point, bounds)) {
        inZone.add(doc);
      }
    }

    inZone.sort((a, b) {
      return scoreOf(b.data()).compareTo(scoreOf(a.data()));
    });
    if (inZone.length <= limit) {
      return inZone;
    }
    return inZone.take(limit).toList();
  }

  bool _isInsideBounds(LatLng point, LatLngBounds bounds) {
    final bool latOk =
        point.latitude >= bounds.southwest.latitude &&
        point.latitude <= bounds.northeast.latitude;

    final double swLng = bounds.southwest.longitude;
    final double neLng = bounds.northeast.longitude;
    final bool lngOk;
    if (swLng <= neLng) {
      lngOk = point.longitude >= swLng && point.longitude <= neLng;
    } else {
      lngOk = point.longitude >= swLng || point.longitude <= neLng;
    }
    return latOk && lngOk;
  }

  LatLng? _extractLatLng(Map<String, dynamic> data) {
    final GeoPoint? geo = data['geo'] as GeoPoint?;
    if (geo != null) {
      return LatLng(geo.latitude, geo.longitude);
    }

    final String location = data['location']?.toString().trim() ?? '';
    if (location.isEmpty || !location.contains(',')) {
      return null;
    }

    final List<String> parts = location.split(',');
    if (parts.length < 2) {
      return null;
    }
    final double? lat = double.tryParse(parts[0].trim());
    final double? lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) {
      return null;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return null;
    }
    return LatLng(lat, lng);
  }

  Widget _buildPopularPostsPanel(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> posts, {
    required bool hasAnyPost,
  }) {
    if (!hasAnyPost) {
      return Container(
        height: 170,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.gray200)),
        ),
        child: const Center(
          child: Text(
            'No posts in this map area.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.gray200)),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: <Widget>[
                const Icon(Icons.local_fire_department_outlined, size: 18),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Popular in this map area',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                PopupMenuButton<int>(
                  tooltip: 'Popular list size',
                  initialValue: _popularLimit,
                  onSelected: (int value) {
                    if (value == _popularLimit) {
                      return;
                    }
                    setState(() {
                      _popularLimit = value;
                      _refreshAppliedPopularPostIds();
                    });
                  },
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<int>>[
                        PopupMenuItem<int>(value: 10, child: Text('Top 10')),
                        PopupMenuItem<int>(value: 20, child: Text('Top 20')),
                        PopupMenuItem<int>(value: 50, child: Text('Top 50')),
                      ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gray300),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Top $_popularLimit',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              itemCount: posts.length,
              separatorBuilder: (BuildContext context, int index) =>
                  Divider(height: 1, color: AppColors.gray200),
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> data = posts[index].data();
                final String imageUrl = data['imageUrl']?.toString() ?? '';
                final String caption = data['content']?.toString() ?? '';
                final int likes =
                    (data['likes'] as List<dynamic>? ?? <dynamic>[]).length;
                final int comments = data['commentCount'] as int? ?? 0;
                final int shares = data['shareCount'] as int? ?? 0;
                final LatLng? point = _extractLatLng(data);

                return ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(
                    horizontal: -2,
                    vertical: -2,
                  ),
                  minLeadingWidth: 36,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.gray200,
                    backgroundImage: imageUrl.isNotEmpty
                        ? CachedNetworkImageProvider(imageUrl)
                        : null,
                    child: imageUrl.isEmpty
                        ? const Icon(Icons.image_outlined, size: 16)
                        : null,
                  ),
                  title: Text(
                    caption.isEmpty ? '(No caption)' : caption,
                    style: _panelTitleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Likes $likes • Comments $comments • Shares $shares',
                    style: _panelSubtitleStyle,
                  ),
                  onTap: () {
                    _showPostPreview(data);
                    if (point != null) {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(
                          point,
                          14,
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
