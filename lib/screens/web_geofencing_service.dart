import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' show asin, cos, pi, pow, sin, sqrt;

class WebGeofenceService {
  // Singleton pattern
  static final WebGeofenceService _instance = WebGeofenceService._internal();
  factory WebGeofenceService() => _instance;
  WebGeofenceService._internal();

  // Properties
  final List<WebGeofence> _geofences = [];
  StreamSubscription<Position>? _positionStream;
  final SupabaseClient _supabase = Supabase.instance.client;

  // Initialize the service
  Future<void> initialize() async {
    if (!kIsWeb) {
      throw Exception('This service is designed for Flutter web only');
    }

    // Request permission
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requestedPermission = await Geolocator.requestPermission();
      if (requestedPermission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    // Load geofences from Supabase if needed
    await _loadGeofencesFromSupabase();

    // Start position tracking
    _startPositionTracking();
  }

  // Load geofences from Supabase
  Future<void> _loadGeofencesFromSupabase() async {
    try {
      final data = await _supabase.from('geofences').select();

      _geofences.clear();
      for (final fence in data) {
        _geofences.add(WebGeofence(
          id: fence['id'],
          latitude: fence['latitude'],
          longitude: fence['longitude'],
          radius: fence['radius'],
        ));
      }
    } catch (e) {
      print('Error loading geofences: $e');
    }
  }

  // Start tracking position
  void _startPositionTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(_onPositionUpdate);
  }

  // Handle position updates
  void _onPositionUpdate(Position position) {
    final currentLocation = WebLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: DateTime.now(),
    );

    // Check all geofences
    for (final fence in _geofences) {
      final distance = _calculateDistance(
        position.latitude,
        position.longitude,
        fence.latitude,
        fence.longitude,
      );

      final bool wasInside = fence.isInside;
      final bool isNowInside = distance <= fence.radius;

      // Update state and trigger events
      if (wasInside != isNowInside) {
        fence.isInside = isNowInside;

        if (isNowInside) {
          _triggerGeofenceEvent(fence, WebGeofenceEvent.enter, currentLocation);
        } else {
          _triggerGeofenceEvent(fence, WebGeofenceEvent.exit, currentLocation);
        }
      } else if (isNowInside) {
        _triggerGeofenceEvent(fence, WebGeofenceEvent.dwell, currentLocation);
      }
    }
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // in meters

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = pow(sin(dLat / 2), 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * pow(sin(dLon / 2), 2);
    final double c = 2 * asin(sqrt(a));

    return earthRadius * c; // Distance in meters
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  // Trigger geofence event and notify listeners
  void _triggerGeofenceEvent(
      WebGeofence fence, WebGeofenceEvent event, WebLocation location) {
    print(
        'Geofence triggered: ${fence.id} - ${event.name} at location: $location');

    // Call the callback if registered
    fence.callback?.call(event, location);

    // Log event to Supabase if needed
    _logEventToSupabase(fence, event, location);
  }

  // Log event to Supabase
  Future<void> _logEventToSupabase(
      WebGeofence fence, WebGeofenceEvent event, WebLocation location) async {
    try {
      await _supabase.from('geofence_events').insert({
        'geofence_id': fence.id,
        'event_type': event.name,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'timestamp': location.timestamp.toIso8601String(),
      });
    } catch (e) {
      print('Error logging event to Supabase: $e');
    }
  }

  // Add a geofence
  Future<void> addGeofence(
      String id,
      double latitude,
      double longitude,
      double radius,
      void Function(WebGeofenceEvent, WebLocation)? callback) async {
    final fence = WebGeofence(
      id: id,
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      callback: callback,
    );

    _geofences.add(fence);

    // Save to Supabase
    try {
      await _supabase.from('geofences').insert({
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
      });
    } catch (e) {
      print('Error saving geofence to Supabase: $e');
    }
  }

  // Remove a geofence
  Future<void> removeGeofence(String id) async {
    _geofences.removeWhere((fence) => fence.id == id);

    // Remove from Supabase
    try {
      await _supabase.from('geofences').delete().eq('id', id);
    } catch (e) {
      print('Error removing geofence from Supabase: $e');
    }
  }

  // Dispose the service
  void dispose() {
    _positionStream?.cancel();
  }
}

// Models
class WebGeofence {
  final String id;
  final double latitude;
  final double longitude;
  final double radius; // in meters
  bool isInside = false;
  final void Function(WebGeofenceEvent, WebLocation)? callback;

  WebGeofence({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.callback,
  });
}

class WebLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  WebLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'WebLocation(lat: $latitude, lng: $longitude, accuracy: $accuracy)';
  }
}

enum WebGeofenceEvent {
  enter,
  exit,
  dwell,
}
