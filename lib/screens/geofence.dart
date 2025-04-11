import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'web_geofencing_service.dart'; // Make sure to rename your geofence file

class GeofenceScreen extends StatefulWidget {
  @override
  _GeofenceScreenState createState() => _GeofenceScreenState();
}

class _GeofenceScreenState extends State<GeofenceScreen> {
  final WebGeofenceService _geofenceService = WebGeofenceService();
  final List<Map<String, dynamic>> _geofences = [];
  bool _isLoading = true;
  Position? _currentPosition;
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initGeofencing();
  }

  Future<void> _initGeofencing() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _geofenceService.initialize();
      await _loadGeofences();
      await _getCurrentPosition();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing geofencing: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadGeofences() async {
    try {
      final data = await Supabase.instance.client.from('geofences').select();
      if (mounted) {
        setState(() {
          _geofences.clear();
          for (final fence in data) {
            _geofences.add(fence);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading geofences: $e')),
        );
      }
    }
  }

  Future<void> _getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting current position: $e')),
        );
      }
    }
  }

  Future<void> _addGeofence() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Current position not available')),
      );
      return;
    }

    final id = _idController.text.trim();
    final radiusText = _radiusController.text.trim();

    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter an ID')),
      );
      return;
    }

    if (radiusText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a radius')),
      );
      return;
    }

    final radius = double.tryParse(radiusText);
    if (radius == null || radius <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid radius')),
      );
      return;
    }

    try {
      await _geofenceService.addGeofence(
        id,
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        radius,
        (event, location) {
          // Show a notification when geofence events occur
          print('Geofence event: ${event.name} at $location');
          // You could add local notifications here
        },
      );

      // Clear form and reload geofences
      _idController.clear();
      _radiusController.clear();
      await _loadGeofences();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Geofence added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding geofence: $e')),
      );
    }
  }

  Future<void> _removeGeofence(String id) async {
    try {
      await _geofenceService.removeGeofence(id);
      await _loadGeofences();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Geofence removed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing geofence: $e')),
      );
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Geofence Management'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create New Geofence',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          TextField(
                            controller: _idController,
                            decoration: InputDecoration(
                              labelText: 'Geofence ID',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          SizedBox(height: 12),
                          TextField(
                            controller: _radiusController,
                            decoration: InputDecoration(
                              labelText: 'Radius (meters)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          SizedBox(height: 12),
                          Text(_currentPosition != null
                              ? 'Current Position: Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}'
                              : 'Current position not available'),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _addGeofence,
                            child: Text('Add Geofence at Current Location'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Active Geofences',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: _geofences.isEmpty
                        ? Center(child: Text('No geofences yet'))
                        : ListView.builder(
                            itemCount: _geofences.length,
                            itemBuilder: (context, index) {
                              final fence = _geofences[index];
                              return Card(
                                child: ListTile(
                                  title: Text(fence['id']),
                                  subtitle: Text(
                                      'Lat: ${fence['latitude'].toStringAsFixed(6)}, Lng: ${fence['longitude'].toStringAsFixed(6)}, Radius: ${fence['radius']}m'),
                                  trailing: IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () =>
                                        _removeGeofence(fence['id']),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
