import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward().whenComplete(() => _checkAuthState());
  }

  Future<void> _checkAuthState() async {
    // Ensure Firebase is initialized
    try {
      await Firebase.initializeApp();
    } catch (e) {
      print('Firebase initialization error: $e');
      // Optionally show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing app: $e')),
        );
      }
      return;
    }

    // Check if user is signed in
    User? user = FirebaseAuth.instance.currentUser;

    if (mounted) {
      if (user != null) {
        // User is signed in, navigate to Homescreen
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // User is not signed in, navigate to LoginScreen
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/2rotate.jpeg'),
            fit: BoxFit.cover,
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.0),
                  Colors.black.withOpacity(0.0),
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 280,
                      height: 280,
                      child: Center(
                        child: Image.asset(
                          'assets/sleeping-cat-3.jpeg',
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 80),
                  // SlideTransition(
                  //   position: _slideAnimation,
                  //   child: Container(
                  //     width: 250,
                  //     height: 50,
                  //     decoration: BoxDecoration(
                  //       color: Colors.white.withOpacity(0.2),
                  //       borderRadius: BorderRadius.circular(15),
                  //       border: Border.all(
                  //         color: Colors.white.withOpacity(0.5),
                  //         width: 1,
                  //       ),
                  //     ),
                      // child: TextButton(
                      //   onPressed: () {
                      //     // Manually navigate to LoginScreen if button is pressed
                      //     Navigator.pushReplacementNamed(context, '/login');
                      //   },
                      //   child: Text(
                      //     'Get Started',
                      //     style: TextStyle(
                      //       color: Colors.white,
                      //       fontSize: 18,
                      //       fontWeight: FontWeight.w500,
                      //     ),
                      //   ),
                      // ),
                    // ),
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}