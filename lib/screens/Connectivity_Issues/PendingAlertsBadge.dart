import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ConnectivityService.dart';

class PendingAlertsBadge extends StatefulWidget {
  @override
  _PendingAlertsBadgeState createState() => _PendingAlertsBadgeState();
}

class _PendingAlertsBadgeState extends State<PendingAlertsBadge> {
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _checkPendingCount();
  }

  Future<void> _checkPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingAlerts = prefs.getStringList('pendingAlerts') ?? [];

    setState(() {
      _pendingCount = pendingAlerts.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingCount == 0) {
      return SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        // Try to send pending alerts
        ConnectivityService().checkAndSendPendingAlerts();

        // Show details in a dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Pending Alerts'),
            content: Text(
                'You have $_pendingCount unsent emergency alerts that will be automatically sent when your device is back online.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Refresh the count
                  _checkPendingCount();
                },
                child: Text('OK'),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text(
              '$_pendingCount pending',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
