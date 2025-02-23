import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _auth = FirebaseAuth.instance;

  // Controllers for User Information
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dobController = TextEditingController();

  // Controllers for Device Information
  final _imeiController = TextEditingController();
  final _modelController = TextEditingController();
  final _simController = TextEditingController();
  final _carrierController = TextEditingController();

  // Controllers for Emergency Contacts
  final _contact1NameController = TextEditingController();
  final _contact1EmailController = TextEditingController();
  final _contact1PhoneController = TextEditingController();

  final _contact2NameController = TextEditingController();
  final _contact2EmailController = TextEditingController();
  final _contact2PhoneController = TextEditingController();

  final _contact3NameController = TextEditingController();
  final _contact3EmailController = TextEditingController();
  final _contact3PhoneController = TextEditingController();

  bool _isLoading = false;
  bool _isTermsAccepted = false; // Terms and conditions checkbox status

  Future<void> _signup() async {
    if (!_isTermsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must accept the terms and conditions.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Validate passwords
      if (_passwordController.text.trim() !=
          _confirmPasswordController.text.trim()) {
        throw Exception("Passwords do not match");
      }

      // Create user with email and password
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Save user data to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'full_name': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'dob': _dobController.text.trim(),
        'device_info': {
          'imei': _imeiController.text.trim(),
          'model': _modelController.text.trim(),
          'sim': _simController.text.trim(),
          'carrier': _carrierController.text.trim(),
        },
        'emergency_contacts': [
          {
            'name': _contact1NameController.text.trim(),
            'email': _contact1EmailController.text.trim(),
            'phone': _contact1PhoneController.text.trim(),
          },
          {
            'name': _contact2NameController.text.trim(),
            'email': _contact2EmailController.text.trim(),
            'phone': _contact2PhoneController.text.trim(),
          },
          {
            'name': _contact3NameController.text.trim(),
            'email': _contact3EmailController.text.trim(),
            'phone': _contact3PhoneController.text.trim(),
          },
        ],
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup successful!')),
      );
      Navigator.pop(context); // Navigate back to the login screen
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Signup'),
        backgroundColor: Colors.blue.shade900,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Information Section
            Text(
              'User Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            SizedBox(height: 10),
            _buildTextField(_fullNameController, 'Full Name', Icons.person),
            _buildTextField(_emailController, 'Email', Icons.email),
            _buildTextField(_passwordController, 'Password', Icons.lock,
                obscureText: true),
            _buildTextField(
                _confirmPasswordController, 'Confirm Password', Icons.lock,
                obscureText: true),
            _buildTextField(_dobController, 'Date of Birth (DD/MM/YYYY)',
                Icons.calendar_today),
            SizedBox(height: 20),

            // Device Information Section
            Text(
              'Device Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            SizedBox(height: 10),
            _buildTextField(
                _imeiController, 'IMEI Number', Icons.phone_android),
            _buildTextField(
                _modelController, 'Model Name & Manufacturer', Icons.devices),
            _buildTextField(
                _simController, 'SIM Card Number (ICCID)', Icons.sim_card),
            _buildTextField(
                _carrierController, 'Carrier Information', Icons.network_cell),
            SizedBox(height: 20),

            // Emergency Contacts Section
            Text(
              'Emergency Contacts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            SizedBox(height: 10),
            _buildContactSection(
                _contact1NameController,
                _contact1EmailController,
                _contact1PhoneController,
                'Emergency Contact 1'),
            _buildContactSection(
                _contact2NameController,
                _contact2EmailController,
                _contact2PhoneController,
                'Emergency Contact 2'),
            _buildContactSection(
                _contact3NameController,
                _contact3EmailController,
                _contact3PhoneController,
                'Emergency Contact 3'),
            SizedBox(height: 20),

            // Terms and Conditions Checkbox
            Row(
              children: [
                Checkbox(
                  value: _isTermsAccepted,
                  onChanged: (value) {
                    setState(() {
                      _isTermsAccepted = value!;
                    });
                  },
                ),
                Expanded(
                  child: Text(
                    'I agree to the Terms and Conditions',
                    style: TextStyle(color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Signup Button
            Center(
              child: _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _signup,
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                        backgroundColor: Colors.blue.shade900,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        'Signup',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build text fields
  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool obscureText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(icon, color: Colors.blue.shade900),
          labelText: label,
          labelStyle: TextStyle(color: Colors.blue.shade900),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
        obscureText: obscureText,
      ),
    );
  }

  // Helper method to build emergency contact sections
  Widget _buildContactSection(
      TextEditingController nameController,
      TextEditingController emailController,
      TextEditingController phoneController,
      String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade900,
          ),
        ),
        SizedBox(height: 10),
        _buildTextField(nameController, 'Full Name', Icons.person),
        _buildTextField(emailController, 'Email', Icons.email),
        _buildTextField(phoneController, 'Phone Number', Icons.phone),
        SizedBox(height: 10),
      ],
    );
  }
}
