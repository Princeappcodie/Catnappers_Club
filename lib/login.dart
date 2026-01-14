import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io' show Platform;
import 'dart:ui';
import 'Signup.dart';
import 'home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ================= EMAIL LOGIN =================
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Homescreen()),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed.';
      if (e.code == 'user-not-found') {
        message = 'No user found with this email.';
      } else if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'Incorrect password.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================= GOOGLE LOGIN =================
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 🔒 BLOCK wrong provider
      final methods = await FirebaseAuth.instance
          .fetchSignInMethodsForEmail(googleUser.email);

      if (methods.isNotEmpty && !methods.contains('google.com')) {
        throw FirebaseAuthException(
          code: 'wrong-provider',
          message: 'Please login using email & password',
        );
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred =
      await FirebaseAuth.instance.signInWithCredential(credential);

      await _handleSocialLogin(userCred.user!);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Homescreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================= APPLE LOGIN =================
  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);

    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCred =
      await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      await _handleSocialLogin(userCred.user!);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Homescreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apple login failed'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================= SAFE SOCIAL LOGIN HANDLER =================
  Future<void> _handleSocialLogin(User user) async {
    final firestoreRef =
    FirebaseFirestore.instance.collection('users').doc(user.uid);

    final firestoreSnap = await firestoreRef.get();

    // 🔴 FIX: Re-create user data if deleted earlier
    if (!firestoreSnap.exists) {
      final now = DateTime.now();
      final trialEnd = now.add(const Duration(days: 7));

      // Firestore
      await firestoreRef.set({
        'name': user.displayName ?? 'No Name',
        'email': user.email ?? '',
        'phone': '',
        'phoneVerified': false,
        'isSubscribed': false,
        'trialEndsAt': trialEnd.toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Realtime DB
      await FirebaseDatabase.instance.ref('users/${user.uid}').set({
        'name': user.displayName ?? 'No Name',
        'email': user.email ?? '',
        'phone': '',
        'createdAt': now.toIso8601String(),
        'trialEndsAt': trialEnd.toIso8601String(),
      });
    }
  }

  // ================= UI (UNCHANGED) =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/2rotate.jpeg'),
            fit: BoxFit.cover,
            colorFilter:
            ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken),
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: _buildLoginCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Log In',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 30),

            TextFormField(
              controller: _emailController,
              validator: (v) => v!.contains('@') ? null : 'Enter valid email',
              style: const TextStyle(color: Colors.white),
              decoration: _input('Email', Icons.email),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              validator: (v) => v!.isEmpty ? 'Password required' : null,
              style: const TextStyle(color: Colors.white),
              decoration: _input('Password', Icons.lock).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.blue)
                    : const Text('Login', style: TextStyle(fontSize: 18)),
              ),
            ),

            const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12), // 👈 increase width here
                child: IconButton(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  icon: ClipOval(
                    child: Image.asset(
                      'assets/google.jpeg',
                      width: 49,
                      height: 45,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              if (Platform.isIOS)
                IconButton(
                  onPressed: _isLoading ? null : _signInWithApple,
                  icon: const Icon(Icons.apple, size: 48, color: Colors.white),
                ),
            ],
          ),

            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SignupScreen()),
              ),
              child: const Text(
                "Don't have an account? Sign Up",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _input(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
      ),
    );
  }
}
