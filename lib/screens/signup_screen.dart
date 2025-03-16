import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _supabase = Supabase.instance.client;

  // Controllers for User Information
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController(); // Added phone controller

  // Controllers for Device Information
  final _imeiController = TextEditingController();
  final _modelController = TextEditingController();
  final _carrierController = TextEditingController();

  // Controllers for Emergency Contacts
  final _contact1NameController = TextEditingController();
  final _contact1EmailController = TextEditingController();
  final _contact1PhoneController = TextEditingController();

  bool _isLoading = false;
  bool _isTermsAccepted = false;

  // Signup process
  Future<void> _signup() async {
    // Validate all required fields
    if (!_validateFields()) {
      return;
    }

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
      final response = await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.session != null) {
        throw Exception(response.session!);
      }

      // Save user data to Supabase "Snatcher Database" table
      await _saveUserDataToSupabase(response.user!.id); // Pass the user ID

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data saved successfully')),
      );

      // Navigate back to login screen
      Navigator.pop(context);
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

  // Save user data to Supabase "Snatcher Database" table
  Future<void> _saveUserDataToSupabase(String uid) async {
    final response = await _supabase.from('Snatcher Database').insert({
      'auth.uid': uid,
      'full_name': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone_number': _phoneController.text.trim(), // Added phone number
      'date_of_birth': _dobController.text.trim(),
      'imei_number': _imeiController.text.trim(),
      'model_number_manufacturer': _modelController.text.trim(),
      'carrier_information': _carrierController.text.trim(),
      'fav_full_name': _contact1NameController.text.trim(),
      'fav_email': _contact1EmailController.text.trim(),
      'fav_phone_number': _contact1PhoneController.text.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });

    if (response.error != null) {
      throw Exception(response.error!.message);
    }
  }

  // Validate all required fields
  bool _validateFields() {
    if (_fullNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty ||
        _dobController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Please fill in all required user information fields')),
      );
      return false;
    }

    // At least one emergency contact required
    if (_contact1NameController.text.isEmpty ||
        _contact1EmailController.text.isEmpty ||
        _contact1PhoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Please provide at least one emergency contact')),
      );
      return false;
    }

    return true;
  }

  // Terms and conditions dialog
  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Terms and Conditions'),
        content: SingleChildScrollView(
          child: Text(
              'By using this application, you agree to the following terms and conditions:\n\n'
              '1. You consent to the collection and storage of the personal information provided during signup.\n\n'
              '2. Your emergency contacts may be notified in case of emergency situations as determined by the application.\n\n'
              '3. Device information is collected for the purpose of identifying your device in emergency situations.\n\n'
              '4. You are responsible for ensuring that the information provided is accurate and up-to-date.\n\n'
              '5. The application does not guarantee immediate emergency response or intervention.\n\n'
              '6. Your data will be handled in accordance with our Privacy Policy.\n\n'
              '7. This site is protected by reCAPTCHA and the Google Privacy Policy and Terms of Service apply.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
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
            _buildTextField(_phoneController, 'Phone Number', Icons.phone),
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
                'Emergency Contact 1 (Required)'),
            SizedBox(height: 20),

            // Security Note (for reCAPTCHA v3)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.blue.shade900),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This form is protected by reCAPTCHA v3 to ensure you\'re not a robot.',
                      style: TextStyle(color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
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
                  child: GestureDetector(
                    onTap: () {
                      _showTermsAndConditions();
                    },
                    child: Text(
                      'I agree to the Terms and Conditions',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        decoration: TextDecoration.underline,
                      ),
                    ),
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
            SizedBox(height: 20),
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

  @override
  void dispose() {
    // Dispose all controllers
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dobController.dispose();
    _imeiController.dispose();
    _modelController.dispose();
    _carrierController.dispose();
    _contact1NameController.dispose();
    _contact1EmailController.dispose();
    _contact1PhoneController.dispose();
    super.dispose();
  }
}
