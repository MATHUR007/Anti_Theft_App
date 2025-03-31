import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';

class UserReportScreen extends StatefulWidget {
  @override
  _UserReportScreenState createState() => _UserReportScreenState();
}

class _UserReportScreenState extends State<UserReportScreen> {
  String _reportText = "Fetching user data...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateUserReport();
  }

  Future<void> _generateUserReport() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final userData = await Supabase.instance.client
          .from('Snatcher Database')
          .select()
          .eq('"auth.uid"', user.id) // changed from 'auth.id' to 'auth.uid'
          .single();

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (e) {
        print('Error fetching location: $e');
      }

      String report = """
      User Report
      -----------
      Full Name: ${userData['full_name'] ?? 'Not available'}
      Email: ${userData['email'] ?? 'Not available'}
      Date of Birth: ${userData['date_of_birth'] ?? 'Not available'}
      Phone Number: ${userData['phone_number'] ?? 'Not available'}
      
      Device Information:
      IMEI: ${userData['imei_number'] ?? 'Not available'}
      Model: ${userData['model_number_manufacturer'] ?? 'Not available'}
      Carrier: ${userData['carrier_information'] ?? 'Not available'}
      
      Last Location:
      Latitude: ${position?.latitude ?? 'Not available'}
      Longitude: ${position?.longitude ?? 'Not available'}
      """;

      setState(() {
        _reportText = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _reportText = "User data not found.";
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _downloadReport() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/user_report.txt');
    await file.writeAsString(_reportText);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report downloaded to ${file.path}')),
    );
  }

  void _shareReport() {
    Share.share(_reportText, subject: "User Report");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("User Report")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : Expanded(
                    child: SingleChildScrollView(
                      child: Text(_reportText, style: TextStyle(fontSize: 16)),
                    ),
                  ),
            SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _shareReport,
                  child: Text("Share Report"),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _downloadReport,
                  child: Text("Download Report"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
