import 'package:Catnappers_club/Subscription.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'Signup.dart';
import 'home.dart';
import 'login.dart';
import 'models/authmanager.dart';

class Setting extends StatefulWidget {
  const Setting({Key? key}) : super(key: key);

  @override
  State<Setting> createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  String _appVersion = "";
  String _buildNumber = "";

  /// 🔹  USER TYPE
  bool _isGuestUser = false;
  bool _guestLoaded = false;

  bool get isGuest => _isGuestUser;


  /// 🔒 Disable + fade wrapper
  Widget disabledWrapper({
    required bool enabled,
    required Widget child,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: child,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _printAppVersion();
    _loadGuestStatus();
  }

  void _printAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }
  //////////////////////////////
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      _showError('Could not open link');
    }
  }

////////////////////////////////
  Future<void> _loadGuestStatus() async {
    final isGuest = await AuthManager.isGuest();
    if (!mounted) return;

    setState(() {
      _isGuestUser = isGuest;
      _guestLoaded = true;
    });
  }
/////////////////////////////////////////
  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              await AuthManager.clear();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
              );
            },
            child: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  /// 🔥 DELETE ACCOUNT CONFIRMATION
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: const Text(
          'This will permanently delete your account and all associated data.\n\n'
              'This action cannot be undone.\n\n'
              'Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.green,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAccount();
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔥 DELETE CURRENT USER (AUTH + FIRESTORE)  🔥 ///
  Future<void> _deleteAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final uid = user.uid;

      // 1️⃣ Delete Firestore data
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete();

      // 2️⃣ Delete Firebase Auth user
      await user.delete();

      // 3️⃣ Go to Login
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showError(
          'For security reasons, please log in again to delete your account.',
        );
      } else {
        _showError(e.message ?? 'Failed to delete account.');
      }
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_guestLoaded) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    final profileImageSize = width * 0.45;
    final nameFontSize = width * 0.08;
    final versionFontSize = width * 0.028;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/2rotate.jpeg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          color: Colors.black.withOpacity(0.55),
          child: Column(
            children: [
              SizedBox(height: height * 0.06),

              /// 🔵 PROFILE IMAGE (TOP CENTER) 🔵///
              Container(
                width: profileImageSize,
                height: profileImageSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                  image: const DecorationImage(
                    image: AssetImage('assets/sleeping-cat-3.jpeg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              SizedBox(height: height * 0.025),

              /// 👤 NAME 👤///
              Text(
                "Catnapper's World",
                style: TextStyle(
                  fontSize: nameFontSize,
                  color: Colors.white,
                  fontWeight: FontWeight.w300,
                ),
              ),

              SizedBox(height: height * 0.03),

              /// 🔽  REMAINING SCREEN CONTAINER   🔽 ///
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      /// 🔹 SCROLLABLE BUTTON AREA
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: width * 0.08,
                            vertical: height * 0.04,
                          ),
                          child: Column(
                            children: [
                              ///🟢 SIGNUP (GUEST ONLY) 🟢///
                              if (isGuest) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const SignupScreen(),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                      Colors.white.withOpacity(0.25),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    child: const Text(
                                      'SignUp',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: height * 0.01),
                              ],

                              /// 🔴 LOGOUT 🔴 ///
                              disabledWrapper(
                                enabled: !isGuest,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                    _showLogoutConfirmationDialog,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                      Colors.white.withOpacity(0.2),
                                      padding:
                                      const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    child: const Text(
                                      'Logout',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: height * 0.02),

                              /// 🔴 SUBSCRIBE  🔴 ///
                              disabledWrapper(
                                enabled: true,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                          const Subscription(),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                      Colors.white.withOpacity(0.2),
                                      padding:
                                      const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    child: const Text(
                                      'Subscribe',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: height * 0.02),
                              /// 🔄 RESTORE PURCHASES
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                     Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const Subscription(highlightRestore: true),
                                        ),
                                      ).then((_) {
                                       // Optional: refresh state if needed
                                     });
                                   },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.2),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child: const Text(
                                    'Restore Purchases',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: height * 0.02),

                              /// 🔴 DELETE PROFILE
                              disabledWrapper(
                                enabled: !isGuest,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _showDeleteAccountDialog,

                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                      Colors.white.withOpacity(0.2),
                                      padding:
                                      const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    child: const Text(
                                      'Delete Profile',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: height * 0.06),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () {
                                  _openUrl('https://forms.gle/5gKDyqXXNsdJRZ6j9');
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min, // keeps the row compact
                                  children: const [
                                    Icon(
                                      Icons.feedback,           // or Icons.mail, Icons.comment, Icons.send, etc.
                                      size: 20,
                                      color: Colors.white70,
                                    ),
                                    SizedBox(width: 3),        // space between icon and text
                                    Text(
                                      'Send Feedback',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,           // optional: adjust if needed
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      /// 🔽 FIXED BOTTOM CONTENT (INSIDE CONTAINER) 🔽 ///
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: height * 0.02,
                          // top: height * 0.01,
                        ),
                        child: Column(
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => Homescreen()),
                                );
                              },
                              child: const Text(
                                'Skip & Continue',
                                style:
                                TextStyle(color: Colors.white70, fontSize: 14,),

                              ),
                            ),

                            disabledWrapper(
                              enabled: !isGuest,
                              child: TextButton.icon(
                                onPressed: () =>
                                    Navigator.pushNamed(
                                        context, '/referral'),
                                icon: const Icon(Icons.share,
                                    color: Colors.white70),
                                label: const Text(
                                  'Share App',
                                  style: TextStyle(
                                      color: Colors.white70),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            /// 🔢 VERSION
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    _openUrl('https://catnappers.club/privacy-policy.html');
                                  },
                                  child: const Text(
                                    'Privacy Policy',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 22),
                                TextButton(
                                  onPressed: () {
                                    _openUrl('https://catnappers.club/terms-of-use.html');
                                  },
                                  child: const Text(
                                    'Terms of Use',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "v$_appVersion ($_buildNumber)",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: versionFontSize,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}