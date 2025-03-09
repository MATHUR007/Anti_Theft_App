import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class EmergencyScreen extends StatefulWidget {
  final String? reason;

  EmergencyScreen({this.reason});

  @override
  _EmergencyScreenState createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isSending = false;
  String _statusMessage = '';
  bool _isError = false;
  int _retryCount = 0;
  final int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    _checkPendingAlerts();
  }

  String get _alertTitle {
    if (widget.reason == 'device_stolen') {
      return 'Device Stolen Alert';
    }
    return 'Emergency Alert';
  }

  String get _alertDescription {
    if (widget.reason == 'device_stolen') {
      return 'Press the button to send a device stolen alert to your emergency contacts. They will be notified with your last known location.';
    }
    return 'Press the button to send an emergency alert to your emergency contacts. They will be notified with your current location.';
  }

  String get _buttonText {
    if (widget.reason == 'device_stolen') {
      return 'SEND STOLEN DEVICE ALERT';
    }
    return 'SEND EMERGENCY ALERT';
  }

  void _initializeScreen() {
    if (widget.reason == 'device_stolen') {
      // You could auto-trigger the alert here if needed
    }
  }

  // Check for internet connection
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  // Check and try to send any pending alerts
  Future<void> _checkPendingAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingAlerts = prefs.getStringList('pendingAlerts') ?? [];

      if (pendingAlerts.isEmpty) return;

      bool isConnected = await _checkInternetConnection();
      if (!isConnected) return;

      setState(() {
        _statusMessage = 'Sending pending alerts...';
      });

      for (int i = 0; i < pendingAlerts.length; i++) {
        try {
          final alertData = json.decode(pendingAlerts[i]);
          final callable =
              FirebaseFunctions.instance.httpsCallable('sendEmergencyEmail');
          await callable.call(alertData);

          // Remove sent alert
          pendingAlerts.removeAt(i);
          i--; // Adjust index since we removed an item
        } catch (e) {
          print("Failed to send pending alert: $e");
          // Keep the alert in the list to try again later
        }
      }

      // Save updated list
      await prefs.setStringList('pendingAlerts', pendingAlerts);

      if (pendingAlerts.isEmpty) {
        setState(() {
          _statusMessage = 'All pending alerts sent!';
        });
      } else {
        setState(() {
          _statusMessage = '${pendingAlerts.length} alerts still pending';
        });
      }
    } catch (e) {
      print("Error checking pending alerts: $e");
    }
  }

  // Save alert data for offline case
  Future<void> _saveAlertForLater(Map<String, dynamic> alertData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pendingAlerts = prefs.getStringList('pendingAlerts') ?? [];
      pendingAlerts.add(json.encode(alertData));
      await prefs.setStringList('pendingAlerts', pendingAlerts);

      setState(() {
        _statusMessage = 'Alert saved for later when connection is available';
        _isError = false;
        _isSending = false;
      });
    } catch (e) {
      _setErrorState("Failed to save alert: $e");
    }
  }

  Future<void> sendEmergencyEmail() async {
    setState(() {
      _isSending = true;
      _statusMessage = 'Preparing alert...';
      _isError = false;
      _retryCount = 0;
    });

    try {
      // Check internet connection first
      bool isConnected = await _checkInternetConnection();

      final user = _auth.currentUser;
      if (user == null) {
        _setErrorState('User not logged in');
        return;
      }

      // Get user data - try to use cached data if offline
      DocumentSnapshot<Map<String, dynamic>> userDoc;
      try {
        // Set source to cache if offline, server if online
        Source source = isConnected ? Source.server : Source.cache;
        userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(GetOptions(source: source));
      } catch (e) {
        _setErrorState('Could not access user data: $e');
        return;
      }

      if (!userDoc.exists) {
        _setErrorState('User profile not found');
        return;
      }

      final userData = userDoc.data()!;
      final userName = userData['full_name'] ?? 'User';
      final userEmail = userData['email'];
      final contacts =
          List<Map<String, dynamic>>.from(userData['emergency_contacts'] ?? []);

      if (contacts.isEmpty) {
        _setErrorState('No emergency contacts found');
        return;
      }

      // Get location - might work even if Firebase is offline
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
      } catch (e) {
        // If can't get current position, try last known
        try {
          position = await Geolocator.getLastKnownPosition() ??
              await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.lowest);
        } catch (e) {
          _setErrorState('Could not determine location: $e');
          return;
        }
      }

      // Format location with Google Maps link
      String locationText =
          "Latitude: ${position.latitude}, Longitude: ${position.longitude}";
      String mapsUrl =
          "https://maps.google.com/?q=${position.latitude},${position.longitude}";
      String location = "$locationText\nView on Maps: $mapsUrl";

      // Prepare message based on reason
      String alertMessage;
      if (widget.reason == 'device_stolen') {
        alertMessage =
            "${userName}'s device has been stolen and was last spotted at this location";
      } else {
        alertMessage =
            "${userName} has triggered an emergency alert from their device";
      }

      // Prepare alert data
      final alertData = {
        'userEmail': userEmail,
        'userName': userName,
        'contacts': contacts,
        'location': location,
        'alertMessage': alertMessage,
        'reason': widget.reason ?? 'emergency'
      };

      if (!isConnected) {
        // Save for later if offline
        await _saveAlertForLater(alertData);
        return;
      }

      // Try to send with retries if online
      setState(() {
        _statusMessage = 'Sending alert...';
      });

      while (_retryCount < _maxRetries) {
        try {
          final callable =
              FirebaseFunctions.instance.httpsCallable('sendEmergencyEmail');
          final result = await callable.call(alertData);

          if (result.data['success']) {
            setState(() {
              _isSending = false;
              _statusMessage = 'Alert sent successfully!';
              _isError = false;
            });
            return;
          } else {
            throw Exception(result.data['error']);
          }
        } catch (e) {
          _retryCount++;
          if (_retryCount >= _maxRetries) {
            // If all retries fail, save for later
            await _saveAlertForLater(alertData);
            return;
          }

          // Wait before retry
          setState(() {
            _statusMessage = 'Retry attempt $_retryCount...';
          });
          await Future.delayed(Duration(seconds: 2));
        }
      }
    } catch (e) {
      _setErrorState("Error sending alert: $e");
    }
  }

  void _setErrorState(String message) {
    setState(() {
      _isSending = false;
      _statusMessage = message;
      _isError = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_alertTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _alertDescription,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 30),
              if (_isSending)
                Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text(_statusMessage),
                  ],
                )
              else
                ElevatedButton(
                  onPressed: sendEmergencyEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  ),
                  child: Text(
                    _buttonText,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              SizedBox(height: 20),
              if (_statusMessage.isNotEmpty && !_isSending)
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _isError ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
