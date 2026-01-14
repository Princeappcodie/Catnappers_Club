import 'package:cloud_firestore/cloud_firestore.dart';

class ReferralModel {
  final String id;
  final String referrerId;
  final String referrerCode;
  final int discountPercentage;
  final int usageCount;
  final int maxUsage;
  final DateTime createdAt;
  final DateTime? expiryDate;
  final List<String> redeemedBy;

  ReferralModel({
    required this.id,
    required this.referrerId,
    required this.referrerCode,
    this.discountPercentage = 10, // Default 10% discount
    this.usageCount = 0,
    this.maxUsage = 10, // Default max usage limit
    required this.createdAt,
    this.expiryDate,
    this.redeemedBy = const [],
  });

  // Create from Firebase document
  factory ReferralModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ReferralModel(
      id: doc.id,
      referrerId: data['referrerId'] ?? '',
      referrerCode: data['referrerCode'] ?? '',
      discountPercentage: data['discountPercentage'] ?? 10,
      usageCount: data['usageCount'] ?? 0,
      maxUsage: data['maxUsage'] ?? 10,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiryDate: data['expiryDate'] != null 
          ? (data['expiryDate'] as Timestamp).toDate() 
          : null,
      redeemedBy: List<String>.from(data['redeemedBy'] ?? []),
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'referrerId': referrerId,
      'referrerCode': referrerCode,
      'discountPercentage': discountPercentage,
      'usageCount': usageCount,
      'maxUsage': maxUsage,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'redeemedBy': redeemedBy,
    };
  }

  // Check if referral is valid
  bool isValid() {
    final now = DateTime.now();
    return usageCount < maxUsage && 
           (expiryDate == null || expiryDate!.isAfter(now));
  }

  // Create a copy with updated fields
  ReferralModel copyWith({
    String? id,
    String? referrerId,
    String? referrerCode,
    int? discountPercentage,
    int? usageCount,
    int? maxUsage,
    DateTime? createdAt,
    DateTime? expiryDate,
    List<String>? redeemedBy,
  }) {
    return ReferralModel(
      id: id ?? this.id,
      referrerId: referrerId ?? this.referrerId,
      referrerCode: referrerCode ?? this.referrerCode,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      usageCount: usageCount ?? this.usageCount,
      maxUsage: maxUsage ?? this.maxUsage,
      createdAt: createdAt ?? this.createdAt,
      expiryDate: expiryDate ?? this.expiryDate,
      redeemedBy: redeemedBy ?? this.redeemedBy,
    );
  }
}

// Model for tracking referral redemptions
class ReferralRedemption {
  final String id;
  final String referralId;
  final String userId;
  final DateTime redeemedAt;
  final int discountApplied;
  final String subscriptionId;

  ReferralRedemption({
    required this.id,
    required this.referralId,
    required this.userId,
    required this.redeemedAt,
    required this.discountApplied,
    required this.subscriptionId,
  });

  factory ReferralRedemption.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ReferralRedemption(
      id: doc.id,
      referralId: data['referralId'] ?? '',
      userId: data['userId'] ?? '',
      redeemedAt: (data['redeemedAt'] as Timestamp).toDate(),
      discountApplied: data['discountApplied'] ?? 0,
      subscriptionId: data['subscriptionId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'referralId': referralId,
      'userId': userId,
      'redeemedAt': Timestamp.fromDate(redeemedAt),
      'discountApplied': discountApplied,
      'subscriptionId': subscriptionId,
    };
  }
}