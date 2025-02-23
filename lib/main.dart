import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart'; // Import your LoginScreen file

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase for web
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyC1EwzQtYq6VIhbSJFrIQKpK2XFdM0HvBc",
      authDomain: "snatcher-5c6d9.firebaseapp.com",
      projectId: "snatcher-5c6d9",
      storageBucket: "snatcher-5c6d9.appspot.com",
      messagingSenderId: "27950161623",
      appId: "1:27950161623:web:dacee3dc110ea5b3ed5a92",
      measurementId: "G-WEE9Z5KSDK",
    ),
  );

  runApp(SnatcherApp());
}

class SnatcherApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snatcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade900, Colors.blue.shade400],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // App Icon or Logo
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.security_rounded,
                    size: 60,
                    color: Colors.blue.shade900,
                  ),
                ),
                SizedBox(height: 20),

                // App Title
                Text(
                  'Welcome to Snatcher!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),

                // App Description
                Text(
                  'Snatcher is your ultimate companion to safeguard your mobile devices and data. '
                  'Track your device in real-time, secure your data, and collaborate with authorities to recover stolen devices.',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 40),

                // Get Started Button
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    backgroundColor: Colors.white,
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Footer Text
                Text(
                  'Protect your phone, protect your life.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
