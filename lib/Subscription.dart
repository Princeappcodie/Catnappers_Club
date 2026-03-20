import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/authmanager.dart';
import 'home.dart';

class Subscription extends StatefulWidget {
  final bool highlightRestore;
  const Subscription({Key? key, this.highlightRestore = false}) : super(key: key);

  @override
  State<Subscription> createState() => _SubscriptionState();
}

class _SubscriptionState extends State<Subscription> {
  bool _isProcessing = false;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  String? _error;
  String? _selectedProductId;

  String get _monthlyId => 'catnappers.subscription.monthly';
  String get _yearlyId  => 'catnappers.subscription.yearly';
  String get _lifetimeId {
    if (Platform.isIOS) {
      return 'Catnappers_club_lifetime'; // iOS
    } else {
      return 'catnappers_club_lifetime'; // Android
    }
  }

  Set<String> get _kProductIds => {
    _monthlyId,
    _yearlyId,
    _lifetimeId,
  };

  bool _showHighlight = false;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
    _initialize();
    
    if (widget.highlightRestore) {
      setState(() => _showHighlight = true);
      // Stop highlighting after some time //
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showHighlight = false);
      });
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        // Just checking prefs, but not using the value locally in this widget anymore //
        prefs.getBool('local_isSubscribed') ?? false;
      });
    }
  }

  Future<void> _initialize() async {
    // Check if in-app purchases are available //
    _isAvailable = await InAppPurchase.instance.isAvailable();
    if (mounted) {
      setState(() {
        _isAvailable = _isAvailable;
      });
    }
    if (!_isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('In-app purchases not available')),
        );
      }
      return;
    }

    // Fetch product details //
    final ProductDetailsResponse response =
    await InAppPurchase.instance.queryProductDetails(_kProductIds);

    if (response.error != null) {
      print('Product query error: ${response.error!.message}');
      if (mounted) {
        setState(() {
          _error = response.error!.message;
        });
      }
      return;
    }

    if (response.productDetails.isEmpty) {
      print('No products found. Make sure product ID matches App Store Connect/Google Play Console exactly.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No products found')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _products = response.productDetails;
      });
      print('Products fetched: ${_products.map((p) => p.title).toList()}');
    }

    // Listen to purchase updates //
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        InAppPurchase.instance.purchaseStream;
    _subscription = purchaseUpdated.listen(
          (purchases) {
        for (final purchase in purchases) {
          _handlePurchase(purchase);
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Purchase stream error: $error')),
          );
        }
      },
    );
  }

  Future<void> _updateUserSubscription(PurchaseDetails purchase) async {
    final user = FirebaseAuth.instance.currentUser;

    DateTime now = DateTime.now();
    String planType;
    bool isLifetime = false;

    // Determine plan type based on product ID //
    if (purchase.productID == _monthlyId) {
      planType = 'monthly';
    } else if (purchase.productID == _yearlyId) {
      planType = 'yearly';
    } else if (purchase.productID == _lifetimeId) {
      planType = 'lifetime';
      isLifetime = true;
    } else {
      planType = 'unknown';
    }

    final verification = purchase.verificationData;
    
    // Core change: We do NOT calculate an end date manually.
    // "Subscription is valid if Apple says so" via the purchase/restore event.
    // We store the status, and rely on 'restorePurchases' to re-validate if needed.
    final subscriptionData = {
      'isSubscribed': true,
      'isLifetime': isLifetime,
      'subscriptionPlan': planType,
      'subscriptionProductId': purchase.productID,
      'subscriptionStartDate': now.toIso8601String(), // Record start/restore time
      'subscriptionEndDate': FieldValue.delete(), // Remove any manual expiry date
      'lastPurchaseToken': purchase.purchaseID,
      'transactionDate': purchase.transactionDate,
      'verificationSource': verification.source.toString(),
      'localVerificationData': verification.localVerificationData,
      'serverVerificationData': verification.serverVerificationData,
      'purchaseStatus': purchase.status.toString(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('local_isSubscribed', true);
      await prefs.setString('local_subscriptionPlan', planType);
      await prefs.setBool('local_isLifetime', isLifetime);
      // Remove local manual expiry //
      await prefs.remove('local_subscriptionEndDate');
      await prefs.setString('local_subscriptionStartDate', now.toIso8601String());


      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(subscriptionData, SetOptions(merge: true));

        // Sync to Realtime DB (optional, but keeping consistency) //
        final realtimeUpdate = {
          'isSubscribed': true,
          'isLifetime': isLifetime,
          'subscriptionPlan': planType,
          'subscriptionEndDate': null, // Clear it //
          'purchaseToken': verification.serverVerificationData,
        };
        
        await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(user.uid)
            .update(realtimeUpdate);
            
      } else {
        final guestId = await AuthManager.getOrCreateGuestId();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(guestId)
            .set({
              ...subscriptionData,
              'isGuest': true,
              'guestId': guestId,
            }, SetOptions(merge: true));
            
        await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(guestId)
            .update({
              'isSubscribed': true,
              'isLifetime': isLifetime,
              'subscriptionPlan': planType,
              'subscriptionEndDate': null,
              'purchaseToken': verification.serverVerificationData,
              'guestId': guestId,
            });
      }
    } catch (e) {
      print('Error updating subscription in Firebase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update subscription record: $e')),
        );
      }
    }
  }

  void _handlePurchase(PurchaseDetails purchase) async {
    if (_selectedProductId == null || purchase.productID != _selectedProductId) {
      // For restored purchases, we might not have _selectedProductId set, //
      // so we should check if it matches one of our known products //
      if (!_kProductIds.contains(purchase.productID)) {
        return;
      }
    }

    print('Handling purchase for ${purchase.productID}');

    switch (purchase.status) {
      case PurchaseStatus.purchased:
        print('Purchase successful.');
        
        // Update Firebase with subscription details //
        await _updateUserSubscription(purchase);

        if (mounted) {
           Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const Homescreen(isAuthenticatedUser: true),
            ),
          );
        }
        break;

      case PurchaseStatus.restored:
        await _updateUserSubscription(purchase);
        _showStatusDialog(true, 'Purchase restored successfully');
        break;

      case PurchaseStatus.error:
        _showStatusDialog(false, 'Sorry, purchase not restored: ${purchase.error?.message}');
        break;

      case PurchaseStatus.canceled:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase canceled')),
        );
        break;

      case PurchaseStatus.pending:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase is pending')),
        );
        break;
    }

    if (purchase.pendingCompletePurchase) {
      InAppPurchase.instance.completePurchase(purchase);
    }

    // Reset selection after handling //
    setState(() {
      _selectedProductId = null;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _showStatusDialog(bool success, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: success ? Colors.green : Colors.red,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Icon(
                        success ? Icons.check_circle : Icons.error_outline,
                        color: success ? Colors.green : Colors.red,
                        size: 80,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Auto-dispose after 3 seconds //
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        if (success) {
          // If successful, navigate to home //
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const Homescreen()),
          );
        }
      }
    });
  }

  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      _showStatusDialog(false, 'In-app purchases not available');
      return;
    }
    try {
      if (mounted) setState(() => _isProcessing = true);
      
      // Set a timeout to show a message if nothing is restored //
      bool restoredAny = false;
      
      final StreamSubscription<List<PurchaseDetails>> tempSub = 
          InAppPurchase.instance.purchaseStream.listen((purchases) {
            if (purchases.any((p) => p.status == PurchaseStatus.restored)) {
              restoredAny = true;
            }
          });

      await InAppPurchase.instance.restorePurchases();
      
      // Wait a bit for the stream to process restored items //
      await Future.delayed(const Duration(seconds: 2));
      await tempSub.cancel();

      if (!restoredAny && mounted) {
        _showStatusDialog(false, 'No previous purchases found to restore');
      }
    } catch (e) {
      if (mounted) {
        _showStatusDialog(false, 'Error restoring purchases: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
  //////////////////////////////////////////////////////////////////
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {

    }
  }
  //////////////////////////////////////////////////////////////////

  Future<void> _buyProduct(String productId, bool isSubscription) async {
    if (!_isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('In-app purchases not available')),
        );
      }
      return;
    }
    try {
      if (mounted) {
        setState(() {
          _isProcessing = true;
          _selectedProductId = productId; // Track which button is pressed //
        });
      }
      final productDetailsResponse =
      await InAppPurchase.instance.queryProductDetails({productId});

      if (productDetailsResponse.productDetails.isEmpty ||
          productDetailsResponse.notFoundIDs.contains(productId)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product not found')),
          );
        }
        if (mounted) setState(() => _isProcessing = false);
        return;
      }
      final ProductDetails productDetails =
          productDetailsResponse.productDetails.first;
      
      final PurchaseParam purchaseParam =
      PurchaseParam(productDetails: productDetails);

      // Subscription or lifetime both use non-consumable in this setup //
      await InAppPurchase.instance
          .buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      final errorString = e.toString();

      // 🔹 If user cancelled (iOS StoreKit) //
      if (errorString.contains('userCancelled') ||
          errorString.contains('purchase_cancelled')) {
        // Do nothing – this is normal behavior
        print('User cancelled the purchase');
      } else {
        // Real error //
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase failed. Please try again.'),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _selectedProductId = null;
        });
      }
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
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.5),
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Subscription',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Divider(
                          color: Colors.white12,
                          thickness: 1,
                        ),

                        const SizedBox(height: 30),
                        const Text(
                          'Get unlimited Access to:',
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.only(left: 35.0),
                          child: Column(
                            children: [
                              _buildFeatureItem('100+ guided nap musics'),
                              const SizedBox(height: 15),
                              _buildFeatureItem('Daily Live Nap'),
                              const SizedBox(height: 15),
                              _buildFeatureItem('Offline Access to Nap music'),
                            ],
                          ),
                        ),


                        const SizedBox(height: 40),

                        const SizedBox(height: 30),

                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.green,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Monthly Subscription',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _products.any((p) => p.id == _monthlyId)
                                    ? '(${_products
                                    .firstWhere((p) => p.id == _monthlyId)
                                    .price}/month)'
                                    : '(\$12.99/month)',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Get full access to premium features with a monthly subscription.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (
                                              context) => const Homescreen()),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[300],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                      ),
                                      child: const Text('Try Free',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _isProcessing &&
                                        _selectedProductId == _monthlyId
                                        ? const Center(
                                        child: CircularProgressIndicator())
                                        : ElevatedButton(
                                      onPressed: () =>
                                          _buyProduct(_monthlyId, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                      ),
                                      child: const Text('Subscribe',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.green,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Yearly Subscription',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _products.any((p) => p.id == _yearlyId)
                                    ? '(${_products
                                    .firstWhere((p) => p.id == _yearlyId)
                                    .price}/year)'
                                    : '(\$99.99/year)',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Get full access to premium features with a yearly subscription.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        if (mounted) {
                                          ScaffoldMessenger
                                              .of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Free trial not available yet')),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[300],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                      ),
                                      child: const Text('Try Free',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _isProcessing &&
                                        _selectedProductId == _yearlyId
                                        ? const Center(
                                        child: CircularProgressIndicator())
                                        : ElevatedButton(
                                      onPressed: () =>
                                          _buyProduct(_yearlyId, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                      ),
                                      child: const Text('Subscribe',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.green,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Lifetime Subscription',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _products.any((p) => p.id == _lifetimeId)
                                    ? '(${_products
                                    .firstWhere((p) => p.id == _lifetimeId)
                                    .price}/Onetime)'
                                    : '(\$249.99/Onetime)',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Get full access to premium features with a Lifetime subscription.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        if (mounted) {
                                          ScaffoldMessenger
                                              .of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Free trial not available yet')),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[300],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                      ),
                                      child: const Text('Try Free',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _isProcessing &&
                                        _selectedProductId == _lifetimeId
                                        ? const Center(
                                        child: CircularProgressIndicator())
                                        : ElevatedButton(
                                      onPressed: () =>
                                          _buyProduct(_lifetimeId, false),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                      ),
                                      child: const Text('Subscribe',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          Platform.isIOS
                              ? '• Payment will be charged to your Apple ID account at confirmation of purchase.\n'
                              '• Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period.\n'
                              '• Your account will be charged for renewal within 24 hours prior to the end of the current period.\n'
                              '• You can manage and cancel your subscriptions in your Account Settings on the App Store after purchase.'
                              : '• Payment will be charged to your Google Play account at confirmation of purchase.\n'
                              '• Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period.\n'
                              '• Your account will be charged for renewal within 24 hours prior to the end of the current period.\n'
                              '• You can manage and cancel your subscriptions in your Google Play Account settings after purchase.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 20),
                          Text(
                            'Error: $_error',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
              _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: _showHighlight ? Colors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: _showHighlight
                      ? Border.all(color: Colors.white, width: 2)
                      : Border.all(color: Colors.transparent, width: 2),
                ),
                child: TextButton(
                  onPressed: restorePurchases,
                  child: Text(
                    'Restore Purchases',
                    style: TextStyle(
                      color: _showHighlight ? Colors.white : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const Homescreen()),
                    );
                  },
                  child: const Text(
                    'Skip & Continue',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Row(
      children: [
        const Icon(
          Icons.star_border,
          color: Colors.white,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}