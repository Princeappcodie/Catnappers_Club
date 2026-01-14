import 'dart:io';
import 'dart:ui';
import 'package:Catnappers/Subscription.dart';
import 'package:Catnappers/home.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'services/referral_service.dart';
import 'login.dart';

class Setting extends StatefulWidget {
  const Setting({Key? key}) : super(key: key);

  @override
  State<Setting> createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  File? _profileImage;
  String? _imageUrl;
  final ImagePicker _picker = ImagePicker();

  String _appVersion = "";
  String _buildNumber = "";

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _printAppVersion();
  }

  void _printAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    setState(() {
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });

    print("======= APP INFO =======");
    print("Version: ${packageInfo.version}");
    print("Build Number: ${packageInfo.buildNumber}");
    print("========================");
  }

  void _loadProfileImage() {
    final user = _auth.currentUser;
    if (user != null) {
      _firestore.collection('users').doc(user.uid).snapshots().listen((doc) {
        if (doc.exists && doc.data()?['profileImage'] != null) {
          setState(() {
            _imageUrl = doc['profileImage'];
          });
        }
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    File imageFile = File(pickedFile.path);
    setState(() => _profileImage = imageFile);

    await _uploadImage(imageFile);
  }

  Future<void> _uploadImage(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final ref = FirebaseStorage.instance.ref().child('profile_images/${user.uid}.jpg');
      await ref.putFile(imageFile);

      String downloadUrl = await ref.getDownloadURL();

      await _firestore.collection('users').doc(user.uid).set(
        {'profileImage': downloadUrl},
        SetOptions(merge: true),
      );

      setState(() => _imageUrl = downloadUrl);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    }
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.logout, color: Colors.redAccent, size: 28),
              SizedBox(width: 10),
              Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text('Are you sure you want to log out?'),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black87,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                try {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error logging out: $e')),
                  );
                }
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Responsive values
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    final double profileImageSize = width * 0.35; // ~140 on average phone
    final double buttonWidth = width * 0.55; // ~200
    final double titleFontSize = width * 0.07;
    final double nameFontSize = width * 0.045;
    final double versionFontSize = width * 0.028;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/2rotate.jpeg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: height * 0.1), // Space for version text
                    child: Column(
                      children: [
                        SizedBox(height: height * 0.05), // ~35
                        Text(
                          "Settings",
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: height * 0.04),

                        // Profile Image
                        Center(
                          child: Stack(
                            children: [
                              Container(
                                width: profileImageSize,
                                height: profileImageSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.2),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.5),
                                    width: 2,
                                  ),
                                  image: DecorationImage(
                                    image: _profileImage != null
                                        ? FileImage(_profileImage!)
                                        : (_imageUrl != null
                                        ? NetworkImage(_imageUrl!)
                                        : const AssetImage('assets/logo.jpeg')) as ImageProvider,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.5),
                                      width: 2,
                                    ),
                                  ),
                                  child: IconButton(
                                    iconSize: profileImageSize * 0.18,
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: _pickImage,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: height * 0.025),
                        Text(
                          "Name",
                          style: TextStyle(
                            fontSize: nameFontSize,
                            color: Colors.white,
                          ),
                        ),

                        SizedBox(height: height * 0.055),

                        // Logout Button
                        SizedBox(
                          width: buttonWidth,
                          child: ElevatedButton(
                            onPressed: _showLogoutConfirmationDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              padding: EdgeInsets.symmetric(vertical: height * 0.02),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Logout',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                        ),

                        SizedBox(height: height * 0.055),

                        // Subscribe Button
                        SizedBox(
                          width: buttonWidth,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const Subscription()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              padding: EdgeInsets.symmetric(vertical: height * 0.02),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Subscribe',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                        ),

                        SizedBox(height: height * 0.02),

                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => Homescreen()),
                            );
                          },
                          child: const Text(
                            'Skip & Continue',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),

                        SizedBox(height: height * 0.02),

                        TextButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/referral');
                          },
                          icon: const Icon(Icons.share, color: Colors.white70, size: 20),
                          label: const Text(
                            'Share App',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),

                        SizedBox(height: height * 0.08), // Extra bottom padding
                      ],
                    ),
                  ),

                  // App Version at bottom center
                  Positioned(
                    bottom: height * 0.05,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        "v$_appVersion ($_buildNumber)",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: versionFontSize,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}