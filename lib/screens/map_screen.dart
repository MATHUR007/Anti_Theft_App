import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  LatLng _currentPosition = LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _getLocationFromFirestore();
  }

  Future<void> _getLocationFromFirestore() async {
    FirebaseFirestore.instance
        .collection('locations')
        .doc('device_id')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          _currentPosition = LatLng(
            snapshot.data()?['latitude'],
            snapshot.data()?['longitude'],
          );
        });
        _mapController.animateCamera(
          CameraUpdate.newLatLng(_currentPosition),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Track Device'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _currentPosition,
          zoom: 14,
        ),
        onMapCreated: (controller) {
          _mapController = controller;
        },
        markers: {
          Marker(
            markerId: MarkerId('current_location'),
            position: _currentPosition,
          ),
        },
      ),
    );
  }
}
