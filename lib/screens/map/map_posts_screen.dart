import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/services/post_service.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:sincerelysea/utils/post_location_label.dart';

class MapPostsScreen extends StatefulWidget {
  const MapPostsScreen({super.key});

  @override
  State<MapPostsScreen> createState() => _MapPostsScreenState();
}

class _MapPostsScreenState extends State<MapPostsScreen> {
  static const LatLng _defaultCenter = LatLng(-2.5489, 118.0149);
  static const double _minZoom = 1;
  static const double _maxZoom = 19;
  static const double _minCenterShiftThreshold = 0.02;
  static const double _minSpanChangeRatioThreshold = 0.35;

  final MapController _mapController = MapController();
  LatLng _currentCenter = _defaultCenter;
  double _currentZoom = 2;

  LatLngBounds? _appliedBounds;
  LatLngBounds? _pendingBounds;
  bool _showExploreAreaButton = false;
  int _popularLimit = 20;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _latestDocs =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  List<String> _appliedPopularPostIds = <String>[];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _renderedPopularInZone =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];

  Timer? _cameraIdleDebounceTimer;

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
    _cameraIdleDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PostService postService = context.read<PostService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Explore Map')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: postService.getPostsForMap(),
        builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (snapshot.hasError && _latestDocs.isEmpty) {
            return Center(
              child: Text('Failed to load map posts: ${snapshot.error}'),
            );
          }

          final bool isRefreshingWithCache =
              snapshot.connectionState == ConnectionState.waiting &&
              _latestDocs.isNotEmpty;

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
              snapshot.data?.docs ?? _latestDocs;

          if (docs.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          _latestDocs = docs;
          final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> docsById =
              <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
                for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs)
                  doc.id: doc,
              };

          List<QueryDocumentSnapshot<Map<String, dynamic>>> popularInZone =
              _appliedPopularPostIds
                  .map((String id) => docsById[id])
                  .whereType<QueryDocumentSnapshot<Map<String, dynamic>>>()
                  .toList();

          if (_appliedPopularPostIds.isEmpty || popularInZone.isEmpty) {
            popularInZone = _getPopularPostsInBounds(
              docs,
              bounds: _appliedBounds,
              limit: _popularLimit,
            );
          }

          final bool keepPreviousPopular =
              isRefreshingWithCache &&
              popularInZone.isEmpty &&
              _renderedPopularInZone.isNotEmpty;
          if (keepPreviousPopular) {
            popularInZone = _renderedPopularInZone;
          } else {
            _renderedPopularInZone = popularInZone;
          }

          final List<Marker> markers = <Marker>[];
          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in popularInZone) {
            final Map<String, dynamic> data = doc.data();
            final LatLng? point = _extractLatLng(data);
            if (point == null) {
              continue;
            }
            final String imageUrl = data['imageUrl']?.toString() ?? '';
            markers.add(
              Marker(
                key: ValueKey<String>('post-marker-${doc.id}'),
                point: point,
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => _showPostPreview(data),
                  child: _PostAvatarMarker(imageUrl: imageUrl),
                ),
              ),
            );
          }

          return Column(
            children: <Widget>[
              Expanded(
                child: Stack(
                  children: <Widget>[
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentCenter,
                        initialZoom: _currentZoom,
                        minZoom: _minZoom,
                        maxZoom: _maxZoom,
                        onMapEvent: (MapEvent event) {
                          _currentCenter = event.camera.center;
                          _currentZoom = event.camera.zoom;
                          _onCameraChangedDebounced();
                        },
                      ),
                      children: <Widget>[
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.sincerelysea',
                        ),
                        MarkerClusterLayerWidget(
                          options: MarkerClusterLayerOptions(
                            markers: markers,
                            maxClusterRadius: 45,
                            size: const Size(44, 44),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(52),
                            builder: (BuildContext context, List<Marker> cluster) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: AppColors.black.withValues(alpha: 0.86),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.white, width: 2),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${cluster.length}',
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    if (markers.isEmpty && !isRefreshingWithCache)
                      Positioned(
                        left: 16,
                        right: 16,
                        top: 12,
                        child: Material(
                          borderRadius: BorderRadius.circular(10),
                          color: AppColors.white.withValues(alpha: 0.92),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Text(
                              'No post with location yet.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    if (isRefreshingWithCache)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          color: AppColors.black.withValues(alpha: 0.8),
                          backgroundColor: AppColors.gray300,
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

  void _onCameraChangedDebounced() {
    _cameraIdleDebounceTimer?.cancel();
    _cameraIdleDebounceTimer = Timer(
      const Duration(milliseconds: 250),
      () => _captureVisibleBounds(applyToPanel: false),
    );
  }

  void _captureVisibleBounds({required bool applyToPanel}) {
    if (!mounted) {
      return;
    }

    final LatLngBounds bounds = _mapController.camera.visibleBounds;
    if (!_isValidBounds(bounds)) {
      return;
    }

    final LatLngBounds? old = _appliedBounds;
    if (!applyToPanel && old != null && !_isSignificantBoundsChange(old, bounds)) {
      if (_showExploreAreaButton) {
        setState(() => _showExploreAreaButton = false);
      }
      return;
    }

    _pendingBounds = bounds;
    if (applyToPanel || old == null) {
      _appliedBounds = bounds;
      _refreshAppliedPopularPostIds();
      if (_showExploreAreaButton) {
        setState(() => _showExploreAreaButton = false);
      }
      return;
    }

    if (!_showExploreAreaButton) {
      setState(() => _showExploreAreaButton = true);
    }
  }

  void _exploreThisArea() {
    if (_pendingBounds == null) {
      return;
    }
    _appliedBounds = _pendingBounds;
    _refreshAppliedPopularPostIds();
    if (mounted) {
      setState(() => _showExploreAreaButton = false);
    }
  }

  void _refreshAppliedPopularPostIds() {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> popularInZone =
        _getPopularPostsInBounds(
          _latestDocs,
          bounds: _appliedBounds,
          limit: _popularLimit,
        );
    _appliedPopularPostIds = popularInZone
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id)
        .toList();
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      final Position position = await Geolocator.getCurrentPosition();
      final LatLng point = LatLng(position.latitude, position.longitude);
      _currentCenter = point;
      _currentZoom = 14;
      _mapController.move(point, 14);
      _captureVisibleBounds(applyToPanel: false);
    } catch (_) {
      // Ignore when permission/service is not available.
    }
  }

  void _zoomIn() {
    final double target = (_currentZoom + 1).clamp(_minZoom, _maxZoom);
    _currentZoom = target;
    _mapController.move(_currentCenter, target);
  }

  void _zoomOut() {
    final double target = (_currentZoom - 1).clamp(_minZoom, _maxZoom);
    _currentZoom = target;
    _mapController.move(_currentCenter, target);
  }

  void _focusToWorld() {
    _currentCenter = const LatLng(0, 0);
    _currentZoom = 1;
    _mapController.move(_currentCenter, _currentZoom);
    _captureVisibleBounds(applyToPanel: true);
    _refreshAppliedPopularPostIds();
    if (mounted && _showExploreAreaButton) {
      setState(() => _showExploreAreaButton = false);
    }
  }

  bool _isValidBounds(LatLngBounds bounds) {
    final double latSpan = (bounds.north - bounds.south).abs();
    final double lngSpan = _wrapLongitudeDelta(bounds.east - bounds.west).abs();
    return !(latSpan < 0.000001 && lngSpan < 0.000001);
  }

  bool _isSignificantBoundsChange(LatLngBounds old, LatLngBounds next) {
    final double oldCenterLat = (old.south + old.north) / 2;
    final double oldCenterLng = (old.west + old.east) / 2;
    final double nextCenterLat = (next.south + next.north) / 2;
    final double nextCenterLng = (next.west + next.east) / 2;

    final double centerShift =
        (oldCenterLat - nextCenterLat).abs() + (oldCenterLng - nextCenterLng).abs();

    final double oldLatSpan = (old.north - old.south).abs();
    final double oldLngSpan = _wrapLongitudeDelta(old.east - old.west).abs();
    final double nextLatSpan = (next.north - next.south).abs();
    final double nextLngSpan = _wrapLongitudeDelta(next.east - next.west).abs();

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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _getPopularPostsInBounds(
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

    inZone.sort((a, b) => scoreOf(b.data()).compareTo(scoreOf(a.data())));
    if (inZone.length <= limit) {
      return inZone;
    }
    return inZone.take(limit).toList();
  }

  bool _isInsideBounds(LatLng point, LatLngBounds bounds) {
    final bool latOk = point.latitude >= bounds.south && point.latitude <= bounds.north;

    final double west = bounds.west;
    final double east = bounds.east;
    final bool lngOk;
    if (west <= east) {
      lngOk = point.longitude >= west && point.longitude <= east;
    } else {
      lngOk = point.longitude >= west || point.longitude <= east;
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

  void _showPostPreview(Map<String, dynamic> data) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if ((data['imageUrl']?.toString() ?? '').isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: data['imageUrl'].toString(),
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
            FutureBuilder<String>(
              future: resolvePostLocationLabel(data),
              builder: (
                BuildContext context,
                AsyncSnapshot<String> snapshot,
              ) {
                final String fallback = data['location']?.toString() ?? '';
                final String resolved =
                    snapshot.data?.trim().isNotEmpty == true
                    ? snapshot.data!.trim()
                    : fallback;
                return Text(
                  resolved,
                  style: TextStyle(color: AppColors.gray700),
                );
              },
            ),
          ],
        ),
      ),
    );
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                  minLeadingWidth: 36,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.gray200,
                    backgroundImage:
                        imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl) : null,
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
                      _currentCenter = point;
                      _currentZoom = 14;
                      _mapController.move(point, 14);
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

class _PostAvatarMarker extends StatelessWidget {
  const _PostAvatarMarker({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gray700, width: 1.2),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: AppColors.shadowLow, blurRadius: 3, offset: Offset(0, 1.5)),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: ClipOval(
        child: imageUrl.isEmpty
            ? const SizedBox.expand(
                child: ColoredBox(
                  color: AppColors.gray300,
                  child: Icon(Icons.image_outlined, size: 15),
                ),
              )
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: 36,
                height: 36,
                memCacheWidth: 120,
                memCacheHeight: 120,
                errorWidget: (context, url, error) => const ColoredBox(
                  color: AppColors.gray300,
                  child: Icon(Icons.broken_image_outlined, size: 15),
                ),
              ),
      ),
    );
  }
}
