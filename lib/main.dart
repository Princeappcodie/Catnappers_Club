import 'package:Catnappers_club/screens/referral_screen.dart';
import 'package:Catnappers_club/screens/subscription_screen.dart';
import 'package:Catnappers_club/services/referral_service.dart';
import 'package:Catnappers_club/services/temp_cache_service.dart';
import 'package:Catnappers_club/setting.dart';
import 'package:Catnappers_club/spalsh.dart';
import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Alarm.dart';
import 'Signup.dart';
import 'Subscription.dart';
import 'home.dart';
import 'login.dart';
import 'dart:async';
import 'dart:ui';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Alarm.init();

  // 🧹 Clear temp cache on new session start 🧹 //
  await TempCacheService.clearCache();

  final referralService = ReferralService();
  referralService.initAppLinks();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final StreamSubscription _alarmSubscription;

  @override
  void initState() {
    super.initState();
    _alarmSubscription = Alarm.ringStream.stream.listen((alarmSettings) {
      if (alarmSettings.id == 42) {
        _handleAlarmRing();
      }
    });
  }

  void _handleAlarmRing() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AlarmDialogScreen()),
          (route) => false,
    );
  }


  @override
  void dispose() {
    _alarmSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Catnappers',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final double scale = mq.textScaleFactor;
        final double capped = Platform.isIOS ? scale.clamp(1.0, 1.1) : scale.clamp(1.0, 1.2);
        return MediaQuery(
          data: mq.copyWith(textScaleFactor: capped),
          child: child ?? const SizedBox.shrink(),
        );
      },

      // 🔐 SINGLE ENTRY POINT FOR AUTH 🔐 //
      home: const AuthWrapper(),

      routes: {
        '/SplashScreen': (context) => const SplashScreen(),
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

/// 🔐 AUTH GATEKEEPER (FINAL & CORRECT) 🔐 ///
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // ⏳ Waiting for Firebase auth state ⏳ //
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // ✅ User exists locally (verification happens in Homescreen) ✅ //
        if (snapshot.hasData) {
          return const Homescreen();
        }
        // ❌ Not logged in ❌ //
        return const LoginScreen();
      },
    );
  }
}

class AlarmDialogScreen extends StatelessWidget {
  const AlarmDialogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.6),
      body: Center(
        child: AlertDialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          contentPadding: EdgeInsets.zero,
          content: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.55),
                      Colors.grey.shade200.withOpacity(0.45),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.6),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.alarm, size: 32, color: Colors.black87),
                    const SizedBox(height: 16),
                    const Text(
                      'Nap Complete 🌙',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You took a mindful break.\nYour body & mind thank you ✨',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.7),
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await Alarm.stop(42);
                          navigatorKey.currentState?.pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const Homescreen()),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'STOP ALARM',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}