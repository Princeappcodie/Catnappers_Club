import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'dart:math' as math;
import 'home.dart';
import 'login.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io' show Platform;

import 'models/authmanager.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _otpSent = false;

  String? _verificationId;
  String _selectedCountryCode = '+1';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ================= SEND OTP =================
  Future<void> _sendOTP() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter phone to receive OTP (optional)')),
      );
      return;
    }
    if (!RegExp(r'^\d{7,15}$').hasMatch(rawPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valid phone required (7–15 digits)')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phoneNumber = _selectedCountryCode + _phoneController.text.trim();

      // 🔒 Check phone uniqueness (Realtime DB)
      final dbRef = FirebaseDatabase.instance.ref('users');
      final snapshot =
      await dbRef.orderByChild('phone').equalTo(phoneNumber).once();

      if (snapshot.snapshot.exists) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number already registered')),
        );
        return;
      }

      // 🔒 Check email uniqueness
      // (Optional) Email uniqueness check can be deferred to signup

      // 📲 Send OTP (NO user creation here)
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,

        verificationCompleted: (_) {
          // ❌ DO NOTHING (CRITICAL FIX)
        },

        verificationFailed: (e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: ${e.message}')),
          );
        },

        codeSent: (verificationId, _) {
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('OTP sent to $phoneNumber')),
          );
        },

        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString().substring(0, math.min(100, e.toString().length))}',
          ),
        ),
      );
    }
  }

  // ================= VERIFY OTP ================= //
  Future<void> _verifyOTP() async {
    if (_verificationId == null) return;

    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );

      await _createUserWithVerifiedPhone(credential);
    } catch (_) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP')),
      );
    }
  }

  // ================= CREATE USER =================
  Future<void> _createUserWithVerifiedPhone(
      PhoneAuthCredential phoneCredential) async {
    User? createdUser;

    try {
      final auth = FirebaseAuth.instance;

      final userCred = await auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      createdUser = userCred.user!;
      await createdUser.updateDisplayName(_nameController.text.trim());

      // 🔐 Enforce phone uniqueness
      await createdUser.linkWithCredential(phoneCredential);

      await _migrateGuestData(createdUser);
      await _saveUserData(createdUser);
      await AuthManager.setLoggedIn();


      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Homescreen()),
      );
    } catch (e) {
      // 🧹 Clean ghost user
      if (createdUser != null) {
        await createdUser.delete();
      }

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup failed: $e')),
      );
    }
  }

  // ================= CREATE USER (EMAIL ONLY) =================
  Future<void> _createUserEmailOnly() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    User? createdUser;
    try {
      final auth = FirebaseAuth.instance;
      final userCred = await auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      createdUser = userCred.user!;
      await createdUser.updateDisplayName(_nameController.text.trim());

      await _migrateGuestData(createdUser);
      await _saveUserData(createdUser);
      await AuthManager.setLoggedIn();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Homescreen()),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup failed: $e')),
      );
      // Do not delete user here; creation failed
    }
  }

  // ================= SAVE USER DATA =================
  Future<void> _saveUserData(User user) async {
    final now = DateTime.now();
    final trialEnd = now.add(const Duration(days: 7));

    final phoneRaw = _phoneController.text.trim();
    final phoneValue =
        phoneRaw.isEmpty ? null : _selectedCountryCode + phoneRaw;

    final rtdbData = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'createdAt': now.toIso8601String(),
      'trialEndsAt': trialEnd.toIso8601String(),
    };
    if (phoneValue != null) {
      rtdbData['phone'] = phoneValue;
    }
    await FirebaseDatabase.instance.ref('users/${user.uid}').set(rtdbData);

    final firestoreData = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'trialEndsAt': trialEnd.toIso8601String(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (phoneValue != null) {
      firestoreData['phone'] = phoneValue;
    }
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(firestoreData, SetOptions(merge: true));
  }

  Future<void> _migrateGuestData(User user) async {
    final guestId = await AuthManager.getGuestId();
    if (guestId == null) return;
    try {
      final guestDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(guestId)
          .get();
      if (guestDoc.exists) {
        final data = guestDoc.data() ?? {};
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({...data, 'guestSourceId': guestId, 'isGuest': false}, SetOptions(merge: true));
        await FirebaseFirestore.instance
            .collection('users')
            .doc(guestId)
            .delete();
      }
      final guestRtdbSnap = await FirebaseDatabase.instance
          .ref('users/$guestId')
          .get();
      if (guestRtdbSnap.exists) {
        final data = Map<String, dynamic>.from(guestRtdbSnap.value as Map);
        await FirebaseDatabase.instance
            .ref('users/${user.uid}')
            .update({...data, 'guestSourceId': guestId});
        await FirebaseDatabase.instance
            .ref('users/$guestId')
            .remove();
      }
    } catch (_) {}
  }

  // ================= GOOGLE SIGN IN ================= //
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred =
      await FirebaseAuth.instance.signInWithCredential(credential);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCred.user!.uid)
          .set({
        'email': userCred.user!.email,
        'name': userCred.user!.displayName,
        'phoneVerified': false,
        'isSubscribed': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      await AuthManager.setLoggedIn();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Homescreen()),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed: $e')),
      );
    }
  }

  // ================= APPLE SIGN IN =================
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

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCred.user!.uid)
          .set({
        'email': userCred.user!.email,
        'name': userCred.user!.displayName,
        'phoneVerified': false,
        'isSubscribed': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      await AuthManager.setLoggedIn();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Homescreen()),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apple Sign-In failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/2rotate.jpeg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken),
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.1), blurRadius: 10, spreadRadius: 5)],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Sign Up', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 20),

                    // Name
                    TextFormField(controller: _nameController, decoration: _inputDecoration('Name', Icons.person), style: const TextStyle(color: Colors.white), validator: (v) => v!.isEmpty ? 'Enter name' : null),
                    const SizedBox(height: 20),

                    // Email
                    TextFormField(controller: _emailController, decoration: _inputDecoration('Email', Icons.email), keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Colors.white), validator: (v) => !v!.contains('@') ? 'Valid email required' : null),
                    const SizedBox(height: 20),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: _inputDecoration('Password', Icons.lock).copyWith(
                        suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 120, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: _isLoading ? null : _createUserEmailOnly,
                      child: _isLoading
                          ? const SizedBox(width: 25, height: 10, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Sign Up', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,color: Colors.black)),
                    ),


                    const SizedBox(height: 15),
                    const Text(
                      '(Phone verification is optional)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white
                        ,
                        fontStyle: FontStyle.italic,
                      ),
                    ),


                    const SizedBox(height: 20),

                    // Phone + Country Code (FIXED OVERFLOW) //
                    Row(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 130),
                          child: CountryCodePicker(
                            onChanged: (c) => _selectedCountryCode = c.dialCode ?? '+1',
                            initialSelection: 'US',
                            favorite: const ['+1', 'US', '+91', 'IN'],
                            showFlag: true,
                            textStyle: const TextStyle(color: Colors.white),
                            padding: EdgeInsets.zero,
                            builder: (c) => Container(
                              height: 58,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(border: Border.all(color: Colors.white), borderRadius: BorderRadius.circular(10)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (c?.flagUri != null) Image.asset(c!.flagUri!, package: 'country_code_picker', width: 28),
                                  const SizedBox(width: 6),
                                  Text(c?.dialCode ?? '+1', style: const TextStyle(color: Colors.white)),
                                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            decoration: _inputDecoration('Phone Number', Icons.phone),
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: Colors.white),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              return !RegExp(r'^\d{7,15}$').hasMatch(v.trim())
                                  ? 'Valid phone (7-15 digits)'
                                  : null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    TextButton(onPressed: _isLoading || _otpSent ? null : _sendOTP, child: Text('Send OTP', style: TextStyle(color: _isLoading || _otpSent ? Colors.white54 : Colors.white70, decoration: TextDecoration.underline))),

                    if (_otpSent) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _otpController,
                        decoration: _inputDecoration('6-Digit OTP', Icons.vpn_key),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        validator: (v) => v == null || v.length != 6 ? 'Enter 6 digits' : null,
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                        onPressed: _isLoading ? null : _verifyOTP,
                        child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Verify OTP & Sign Up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    const Divider(color: Colors.white54, indent: 20, endIndent: 20),
                    const SizedBox(height: 5),
                    const Text('Continue with', style: TextStyle(color: Colors.white)),
                    const Icon(Icons.arrow_downward, color: Colors.white, size: 18),
                    const SizedBox(height: 5),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(onPressed: _isLoading ? null : _signInWithGoogle, icon: ClipOval(child: Image.asset('assets/google.jpeg', width: 48, height: 48, fit: BoxFit.cover))),
                        const SizedBox(width: 0),
                        if (Platform.isIOS)
                          IconButton(onPressed: _isLoading ? null : _signInWithApple, icon: const Icon(Icons.apple, size: 50, color: Colors.white)),
                      ],
                    ),

                    TextButton(
                      onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: const Text('Already have an account? Login', style: TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('OR', style: TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      onPressed: () async {
                        await AuthManager.setGuest();

                        if (!mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const Homescreen()),
                        );
                      },
                      child: const Text(
                        '“Continue as guest”',
                        style: TextStyle(color: Colors.white),
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

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white),
      prefixIcon: Icon(icon, color: Colors.white),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white, width: 2)),
    );
  }
}
