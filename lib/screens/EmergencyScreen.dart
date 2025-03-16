import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class EmergencyScreen extends StatefulWidget {
  final String? reason;

  EmergencyScreen({this.reason});

  @override
  _EmergencyScreenState createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
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

  Future<bool> _checkInternetConnection() async {
    try {
      // This approach works on more platforms
      if (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isLinux ||
          Platform.isMacOS ||
          Platform.isWindows) {
        try {
          final result = await InternetAddress.lookup('google.com');
          return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        } on SocketException catch (_) {
          return false;
        }
      } else {
        // For web and other platforms, try a different approach
        // This could be a simple HTTP request
        try {
          final response = await http.get(Uri.parse('https://google.com'));
          return response.statusCode == 200;
        } catch (_) {
          return false;
        }
      }
    } catch (_) {
      // Fallback for any other issues
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
          await _supabase.functions
              .invoke('sendEmergencyEmail', body: alertData);

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

  // Store emergency contacts locally for offline use
  Future<void> _cacheEmergencyContacts(
      List<Map<String, dynamic>> contacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('emergency_contacts', json.encode(contacts));
    } catch (e) {
      print("Failed to cache emergency contacts: $e");
    }
  }

  // Get cached emergency contacts
  Future<List<Map<String, dynamic>>> _getCachedEmergencyContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = prefs.getString('emergency_contacts');
      if (contactsJson != null && contactsJson.isNotEmpty) {
        return List<Map<String, dynamic>>.from(json.decode(contactsJson));
      }
    } catch (e) {
      print("Failed to get cached emergency contacts: $e");
    }
    return [];
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

      final user = _supabase.auth.currentUser;
      if (user == null) {
        _setErrorState('User not logged in');
        return;
      }

      // Try to get user data with a more resilient approach
      Map<String, dynamic>? userData;
      String userName = user.userMetadata['full_name'] ?? 'User';
      String userEmail = user.email ?? '';
      List<Map<String, dynamic>> contacts = [];

      try {
        // First try to get from server or cache, whichever is available
        final response =
            await _supabase.from('users').select().eq('id', user.id).single();

        userData = response;
        userName = userData['full_name'] ?? userName;
        userEmail = userData['email'] ?? userEmail;
        contacts = List<Map<String, dynamic>>.from(
            userData['emergency_contacts'] ?? []);

        // Cache contacts for offline use
        if (contacts.isNotEmpty) {
          await _cacheEmergencyContacts(contacts);
        }
      } catch (e) {
        // If that fails, try explicitly from cache
        try {
          final response =
              await _supabase.from('users').select().eq('id', user.id).single();

          userData = response;
          userName = userData['full_name'] ?? userName;
          userEmail = userData['email'] ?? userEmail;
          contacts = List<Map<String, dynamic>>.from(
              userData['emergency_contacts'] ?? []);
        } catch (cacheError) {
          print("Cache access error: $cacheError");
          // Try to get contacts from local storage
          contacts = await _getCachedEmergencyContacts();
        }
      }

      // If we still don't have contacts and we're offline, handle appropriately
      if (contacts.isEmpty) {
        if (!isConnected) {
          setState(() {
            _statusMessage =
                'No emergency contacts available offline. Alert will be saved for later.';
          });
        } else {
          _setErrorState(
              'No emergency contacts found. Please add contacts in your profile.');
          return;
        }
      }

      // Get location - might work even if Supabase is offline
      Position? position;
      String location = "Location unavailable";

      try {
        position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);

        // Format location with Google Maps link
        String locationText =
            "Latitude: ${position.latitude}, Longitude: ${position.longitude}";
        String mapsUrl =
            "https://maps.google.com/?q=${position.latitude},${position.longitude}";
        location = "$locationText\nView on Maps: $mapsUrl";
      } catch (e) {
        // If can't get current position, try last known
        try {
          position = await Geolocator.getLastKnownPosition();
          if (position != null) {
            String locationText =
                "Last known location - Latitude: ${position.latitude}, Longitude: ${position.longitude}";
            String mapsUrl =
                "https://maps.google.com/?q=${position.latitude},${position.longitude}";
            location = "$locationText\nView on Maps: $mapsUrl";
          }
        } catch (e) {
          print("Location error: $e");
          // Continue with unavailable location
        }
      }

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
          await _supabase.functions
              .invoke('sendEmergencyEmail', body: alertData);

          setState(() {
            _isSending = false;
            _statusMessage = 'Alert sent successfully!';
            _isError = false;
          });
          return;
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
