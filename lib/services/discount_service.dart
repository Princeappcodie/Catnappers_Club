import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/referral_service.dart';

class DiscountService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ReferralService _referralService = ReferralService();
  
  // Calculate the discounted price based on the original price and user's discount
  Future<double> calculateDiscountedPrice(double originalPrice) async {
    final discountPercentage = await _referralService.getUserDiscount();
    if (discountPercentage <= 0) return originalPrice;
    
    final discountAmount = originalPrice * (discountPercentage / 100);
    return originalPrice - discountAmount;
  }
  
  // Apply discount to a subscription purchase
  Future<Map<String, dynamic>> applyDiscountToSubscription({
    required String subscriptionId,
    required double originalPrice,
    required String referralCode,
  }) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'User not authenticated',
          'finalPrice': originalPrice,
        };
      }
      
      // Get user's applied discount
      final discountPercentage = await _referralService.getUserDiscount();
      if (discountPercentage <= 0) {
        return {
          'success': false,
          'message': 'No discount available',
          'finalPrice': originalPrice,
        };
      }
      
      // Calculate discounted price
      final discountAmount = originalPrice * (discountPercentage / 100);
      final finalPrice = originalPrice - discountAmount;
      
      // Record the redemption
      final redemptionSuccess = await _referralService.recordRedemption(
        referralCode,
        subscriptionId,
        discountPercentage,
      );
      
      if (!redemptionSuccess) {
        return {
          'success': false,
          'message': 'Failed to record redemption',
          'finalPrice': originalPrice,
        };
      }
      
      // Return the discount information
      return {
        'success': true,
        'message': 'Discount applied successfully',
        'originalPrice': originalPrice,
        'discountPercentage': discountPercentage,
        'discountAmount': discountAmount,
        'finalPrice': finalPrice,
      };
    } catch (e) {
      debugPrint('Error applying discount: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'finalPrice': originalPrice,
      };
    }
  }
  
  // Check if user has an available discount
  Future<bool> hasAvailableDiscount() async {
    final discountPercentage = await _referralService.getUserDiscount();
    return discountPercentage > 0;
  }
  
  // Get discount information for display
  Future<Map<String, dynamic>> getDiscountInfo() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {'hasDiscount': false};
      }
      
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        return {'hasDiscount': false};
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final discountPercentage = userData['referralDiscount'] ?? 0;
      final referralCode = userData['appliedReferralCode'];
      
      if (discountPercentage <= 0 || referralCode == null) {
        return {'hasDiscount': false};
      }
      
      return {
        'hasDiscount': true,
        'discountPercentage': discountPercentage,
        'referralCode': referralCode,
      };
    } catch (e) {
      debugPrint('Error getting discount info: $e');
      return {'hasDiscount': false};
    }
  }
}