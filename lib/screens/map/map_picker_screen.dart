import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPickerResult {
  const MapPickerResult({required this.point, required this.label});

  final LatLng point;
  final String label;
}

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, this.initialPoint});

  final LatLng? initialPoint;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const LatLng _defaultPoint = LatLng(-6.200000, 106.816666);

  LatLng? _selectedPoint;
  bool _isResolvingInitialLocation = false;
  GoogleMapController? _mapController;
  late CameraPosition _initialCameraPosition;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint;
    _initialCameraPosition = CameraPosition(
      target: widget.initialPoint ?? _defaultPoint,
      zoom: 12,
    );
    _setInitialPosition();
  }

  Future<void> _setInitialPosition() async {
    if (widget.initialPoint != null) {
      return;
    }

    setState(() => _isResolvingInitialLocation = true);
    try {
      final Position position = await _getCurrentPosition();
      if (!mounted) return;
      final LatLng target = LatLng(position.latitude, position.longitude);
      _selectedPoint ??= target;
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 14),
        ),
      );
      if (_mapController == null) {
        setState(() {
          _initialCameraPosition = CameraPosition(
            target: target,
            zoom: 14,
          );
        });
      }
    } catch (_) {
      // Fall back to default camera position.
    } finally {
      if (mounted) {
        setState(() => _isResolvingInitialLocation = false);
      }
    }
  }

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

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        actions: <Widget>[
          TextButton(
            onPressed: _selectedPoint == null
                ? null
                : () {
                    final LatLng point = _selectedPoint!;
                    final String label =
                        '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
                    Navigator.pop(
                      context,
                      MapPickerResult(point: point, label: label),
                    );
                  },
            child: const Text('Use this point'),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            onTap: (LatLng point) {
              setState(() => _selectedPoint = point);
            },
            markers: _selectedPoint == null
                ? <Marker>{}
                : <Marker>{
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: _selectedPoint!,
                    ),
                  },
          ),
          if (_isResolvingInitialLocation)
            const Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Getting current location...'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
