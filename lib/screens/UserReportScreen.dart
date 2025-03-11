import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

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
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      setState(() {
        _reportText = "User data not found.";
        _isLoading = false;
      });
      return;
    }

    Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

    String report = """
    User Report
    -----------
    Full Name: ${userData['full_name']}
    Email: ${userData['email']}
    Date of Birth: ${userData['dob']}
    
    Device Information:
    IMEI: ${userData['device_info']['imei']}
    Model: ${userData['device_info']['model']}
    Carrier: ${userData['device_info']['carrier']}
    
    Last Known Location:
    Latitude: ${userData['location']?['latitude'] ?? 'Not available'}
    Longitude: ${userData['location']?['longitude'] ?? 'Not available'}
    """;

    setState(() {
      _reportText = report;
      _isLoading = false;
    });
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
            ElevatedButton(
              onPressed: _shareReport,
              child: Text("Share Report"),
            ),
          ],
        ),
      ),
    );
  }
}
