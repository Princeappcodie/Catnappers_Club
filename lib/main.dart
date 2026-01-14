import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:Catnappers/spalsh.dart';
import 'package:Catnappers/signup.dart' hide Homescreen;
import 'package:Catnappers/login.dart';
import 'package:Catnappers/home.dart';
import 'package:Catnappers/alarm.dart';
import 'package:Catnappers/setting.dart';
import 'package:Catnappers/subscription.dart';
import 'package:Catnappers/screens/referral_screen.dart';
import 'package:Catnappers/screens/subscription_screen.dart';
import 'package:Catnappers/services/referral_service.dart';
import 'package:Catnappers/services/temp_cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 🧹 Clear temp cache on new session start
  await TempCacheService.clearCache();

  final referralService = ReferralService();
  referralService.initAppLinks();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Catnappers',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),

      // 🔐 SINGLE ENTRY POINT FOR AUTH
      home: const AuthWrapper(),

      routes: {
        '/signup': (context) => const SignupScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const Homescreen(),
        '/timer': (context) => const TimerScreen(),
        '/settings': (context) => const Setting(),
        '/subscribe': (context) => const Subscription(),
        '/subscription': (context) => const SubscriptionScreen(),
        '/referral': (context) => const ReferralScreen(),
      },
    );
  }
}

/// 🔐 AUTH GATEKEEPER (FINAL & CORRECT)
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // ⏳ Waiting for Firebase auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // ✅ User exists locally (verification happens in Homescreen)
        if (snapshot.hasData) {
          return const Homescreen();
        }

        // ❌ Not logged in
        return const LoginScreen();
      },
    );
  }
}
