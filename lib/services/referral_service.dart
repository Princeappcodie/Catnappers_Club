import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/referral_model.dart';

class ReferralService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Collection references
  final CollectionReference _referralsCollection = 
      FirebaseFirestore.instance.collection('referrals');
  final CollectionReference _redemptionsCollection = 
      FirebaseFirestore.instance.collection('referral_redemptions');
  
  // Generate a unique referral code //
  String _generateReferralCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }
  
  // Create a new referral for the current user //
  Future<ReferralModel?> createReferral({int discountPercentage = 10, int maxUsage = 10}) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) return null;
      
      // Check if user already has a referral code //
      final existingReferral = await getUserReferral();
      if (existingReferral != null) return existingReferral;
      
      // Generate a unique referral code //
      final referralCode = _generateReferralCode();
      
      // Create the referral document
      final referralData = ReferralModel(
        id: '', // Will be set after document creation //
        referrerId: currentUser.uid,
        referrerCode: referralCode,
        discountPercentage: discountPercentage,
        maxUsage: maxUsage,
        createdAt: DateTime.now(),
      );
      
      // Save to Firestore
      final docRef = await _referralsCollection.add(referralData.toFirestore());
      
      // Return the created referral with the document ID //
      return referralData.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('Error creating referral: $e');
      return null;
    }
  }
  
  // Get the current user's referral //
  Future<ReferralModel?> getUserReferral() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) return null;
      
      final querySnapshot = await _referralsCollection
          .where('referrerId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) return null;
      
      return ReferralModel.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      debugPrint('Error getting user referral: $e');
      return null;
    }
  }
  
  // Get a referral by code //
  Future<ReferralModel?> getReferralByCode(String code) async {
    try {
      final querySnapshot = await _referralsCollection
          .where('referrerCode', isEqualTo: code)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) return null;
      
      return ReferralModel.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      debugPrint('Error getting referral by code: $e');
      return null;
    }
  }
  
  // Create a dynamic link for sharing //
  // AppLinks instance for handling deep links //
  final AppLinks _appLinks = AppLinks();
  
  // Initialize app links handling //
  void initAppLinks() {
    _appLinks.uriLinkStream.listen((Uri uri) {
      // Handle incoming links //
      handleIncomingLink(uri);
    });
  }
  
  // Handle incoming app links //
  void handleIncomingLink(Uri uri) {
    try {
      // Extract referral code from URI //
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty && pathSegments[0] == 'refer') {
        final referralCode = uri.queryParameters['code'];
        if (referralCode != null) {
          // Process the referral code //
          applyReferralCode(referralCode);
        }
      }
    } catch (e) {
      debugPrint('Error handling incoming link: $e');
    }
  }
  
  Future<Uri?> createDynamicLink(String referralCode) async {
    try {
      // Create a URL with your domain //
      // Note: You need to set up app links/universal links with this domain //
      final url = Uri.parse('https://catnappersclub.com/refer?code=$referralCode');
      return url;
    } catch (e) {
      debugPrint('Error creating link: $e');
      return null;
    }
  }
  
  // Share referral link //
  Future<void> shareReferralLink(BuildContext context) async {
    try {
      // Get or create user's referral //
      final referral = await getUserReferral() ?? await createReferral();
      if (referral == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create referral link'))
        );
        return;
      }
      
      // Create dynamic link //
      final dynamicLink = await createDynamicLink(referral.referrerCode);
      if (dynamicLink == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create sharing link'))
        );
        return;
      }
      
      // Share the link //
      await Share.share(
        'Join Catnappers Club using my referral code and get ${referral.discountPercentage}% off your subscription! $dynamicLink',
        subject: 'Catnappers Club Referral',
      );
    } catch (e) {
      debugPrint('Error sharing referral link: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to share referral link'))
      );
    }
  }
  
  // Apply a referral code //
  Future<bool> applyReferralCode(String code) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) return false;
      
      // Get the referral //
      final referral = await getReferralByCode(code);
      if (referral == null || !referral.isValid()) return false;
      
      // Check if user is trying to use their own code //
      if (referral.referrerId == currentUser.uid) return false;
      
      // Check if user has already used this code //
      if (referral.redeemedBy.contains(currentUser.uid)) return false;
      
      // Update the referral document to add this user to redeemedBy list //
      await _referralsCollection.doc(referral.id).update({
        'redeemedBy': FieldValue.arrayUnion([currentUser.uid]),
        'usageCount': FieldValue.increment(1),
      });
      
      // Store the referral code in user's document for later use //
      await _firestore.collection('users').doc(currentUser.uid).update({
        'appliedReferralCode': code,
        'referralDiscount': referral.discountPercentage,
      });
      
      return true;
    } catch (e) {
      debugPrint('Error applying referral code: $e');
      return false;
    }
  }
  
  // Record a successful referral redemption //
  Future<bool> recordRedemption(String referralCode, String subscriptionId, int discountApplied) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) return false;
      
      // Get the referral //
      final referral = await getReferralByCode(referralCode);
      if (referral == null) return false;
      
      // Create redemption record //
      final redemption = ReferralRedemption(
        id: '',
        referralId: referral.id,
        userId: currentUser.uid,
        redeemedAt: DateTime.now(),
        discountApplied: discountApplied,
        subscriptionId: subscriptionId,
      );
      
      // Save redemption to Firestore //
      await _redemptionsCollection.add(redemption.toFirestore());
      
      // Update the referral document //
      await _referralsCollection.doc(referral.id).update({
        'usageCount': FieldValue.increment(1),
        'redeemedBy': FieldValue.arrayUnion([currentUser.uid]),
      });
      
      // Clear the applied referral from user's document //
      await _firestore.collection('users').doc(currentUser.uid).update({
        'appliedReferralCode': FieldValue.delete(),
        'referralDiscount': FieldValue.delete(),
      });
      
      return true;
    } catch (e) {
      debugPrint('Error recording redemption: $e');
      return false;
    }
  }
  
  // Get user's applied discount (if any) //
  Future<int> getUserDiscount() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) return 0;
      
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) return 0;
      
      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['referralDiscount'] ?? 0;
    } catch (e) {
      debugPrint('Error getting user discount: $e');
      return 0;
    }
  }
  
  // Show referral code dialog //
  void showReferralCodeDialog(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Referral Code'),
        content: Text('Do you want to apply referral code $code?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await applyReferralCode(code);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Referral code applied successfully!'))
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to apply referral code'))
                );
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}