import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  bool _isProcessingPendingAlerts = false;

  void initialize(BuildContext context) {
    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        // We're back online, try to send pending alerts
        _processPendingAlerts();
      }
    });

    // Check for pending alerts when initialized
    _processPendingAlerts();
  }

  Future<void> _processPendingAlerts() async {
    // Prevent multiple simultaneous processing
    if (_isProcessingPendingAlerts) return;

    _isProcessingPendingAlerts = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingAlerts = prefs.getStringList('pendingAlerts') ?? [];

      if (pendingAlerts.isEmpty) {
        _isProcessingPendingAlerts = false;
        return;
      }

      // Check if we actually have connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _isProcessingPendingAlerts = false;
        return;
      }

      print("Processing ${pendingAlerts.length} pending alerts");

      List<String> remainingAlerts = [];

      for (final alertJson in pendingAlerts) {
        try {
          final alertData = json.decode(alertJson);
          final callable =
              FirebaseFunctions.instance.httpsCallable('sendEmergencyEmail');
          final result = await callable.call(alertData);

          if (!result.data['success']) {
            // Keep in the list if it failed
            remainingAlerts.add(alertJson);
            print("Alert failed to send: ${result.data['error']}");
          } else {
            print("Successfully sent queued alert");
          }
        } catch (e) {
          // Keep in the list if exception occurred
          remainingAlerts.add(alertJson);
          print("Exception sending queued alert: $e");
        }
      }

      // Update the list with only unsent alerts
      await prefs.setStringList('pendingAlerts', remainingAlerts);
    } catch (e) {
      print("Error processing pending alerts: $e");
    } finally {
      _isProcessingPendingAlerts = false;
    }
  }

  // Allow manual triggering of processing
  void checkAndSendPendingAlerts() {
    _processPendingAlerts();
  }
}
