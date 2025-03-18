import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BlacklistNumberScreen extends StatefulWidget {
  @override
  _BlacklistNumberScreenState createState() => _BlacklistNumberScreenState();
}

class _BlacklistNumberScreenState extends State<BlacklistNumberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imeiController = TextEditingController();
  String _result = '';

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> _checkBlacklist() async {
    final imei = _imeiController.text;

    try {
      final response = await _supabase
          .from('blacklisted_imeis')
          .select()
          .eq('imei', imei)
          .single();

      if (response == null) {
        setState(() {
          _result = 'IMEI not found';
        });
      } else {
        final data = response;
        setState(() {
          _result = data['status'] == 'blacklisted'
              ? 'Blacklisted'
              : 'Not Blacklisted';
        });
      }
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Blacklist Checker'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _imeiController,
                decoration: InputDecoration(labelText: 'Enter IMEI Number'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an IMEI number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _checkBlacklist();
                  }
                },
                child: Text('Check'),
              ),
              SizedBox(height: 20),
              Text(_result),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _imeiController.dispose();
    super.dispose();
  }
}
