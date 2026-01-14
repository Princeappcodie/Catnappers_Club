import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';

class Subscription extends StatefulWidget {
  const Subscription({Key? key}) : super(key: key);

  @override
  State<Subscription> createState() => _SubscriptionState();
}

class _SubscriptionState extends State<Subscription> {
  bool _isProcessing = false;
  late final StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  String? _error;
  String? _selectedProductId;
  bool _isMonthlyProcessing = false;
  bool _isYearlyProcessing = false;
  bool _isLifetimeProcessing = false;



  // Define product IDs for each subscription type
  final Set<String> _kProductIds = {
    'Catnappers_Subscription_monthly',
    'Catnappers_Subscription_yearly', 
    'Catnappers_club_lifetime'
  };

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Check if in-app purchases are available
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

    // Fetch product details
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

    // Listen to purchase updates
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

  void _handlePurchase(PurchaseDetails purchase) {
    if (_selectedProductId == null || purchase.productID != _selectedProductId) {
      // Ignore purchases not related to the button clicked
      return;
    }

    print('Handling purchase for $_selectedProductId');

    switch (purchase.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        print('Purchase successful or restored.');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Homescreen()),
        );
        break;

      case PurchaseStatus.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: ${purchase.error?.message ?? "Unknown"}')),
        );
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

    // Reset selection after handling
    setState(() {
      _selectedProductId = null;
    });
  }


  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void restorePurchases() async {
    if (!_isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('In-app purchases not available')),
        );
      }
      return;
    }
    try {
      if (mounted) setState(() => _isProcessing = true);
      await InAppPurchase.instance.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchases restored')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restoring purchases: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

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
          _selectedProductId = productId; // Track which button is pressed
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

      // Subscription or lifetime both use non-consumable in this setup
      await InAppPurchase.instance
          .buyNonConsumable(purchaseParam: purchaseParam);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _selectedProductId = null; // Reset after completion
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
                          padding: const EdgeInsets.only(left: 30.0),
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
                        // Container(
                        //   decoration: BoxDecoration(
                        //     border: Border(
                        //       top: BorderSide(color: Colors.white.withOpacity(0.1)),
                        //       bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                        //     ),
                        //   ),
                        //   width: double.infinity,
                        //   child: TextButton(
                        //     onPressed: () {
                        //       print('Apply Coupons clicked');
                        //     },
                        //     style: TextButton.styleFrom(
                        //       padding: const EdgeInsets.symmetric(vertical: 8),
                        //     ),
                        //     child: const Row(
                        //       mainAxisAlignment: MainAxisAlignment.center,
                        //       children: [
                        //         Text(
                        //           'Apply Coupons',
                        //           style: TextStyle(
                        //             color: Colors.white,
                        //             fontSize: 16,
                        //             fontWeight: FontWeight.w500,
                        //           ),
                        //         ),
                        //         SizedBox(width: 20),
                        //         Icon(
                        //           Icons.arrow_forward_ios,
                        //           color: Colors.white,
                        //           size: 16,
                        //         ),
                        //       ],
                        //     ),
                        //   ),
                        // ),
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
                                _products.any((p) => p.id == 'catnappers_club_product')
                                    ? '(${_products.firstWhere((p) => p.id == 'catnappers_club_product').price}/month)'
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
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                                content: Text('Free trial not available yet')),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[300],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      child: const Text('Try Free', style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _isProcessing && _selectedProductId == 'catnappers_club_product'
                                        ? const Center(child: CircularProgressIndicator())
                                        : ElevatedButton(
                                      onPressed: () => _buyProduct('catnappers_club_product', true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      child: const Text('Subscribe', style: TextStyle(fontSize: 12)),
                                    ),
                                  ),

                                ],
                              ),
                              const SizedBox(height: 20),
                              TextButton(
                                onPressed: restorePurchases,
                                child: const Text(
                                  'Restore Purchases',
                                  style: TextStyle(color: Colors.green),
                                ),
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
                                _products.any((p) => p.id == 'Catnappers_Subscription_yearly')
                                    ? '(${_products.firstWhere((p) => p.id == 'Catnappers_Subscription_yearly').price}/year)'
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
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                                content: Text('Free trial not available yet')),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[300],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      child: const Text('Try Free', style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _isProcessing && _selectedProductId == 'catnappers_subscription_yearly'
                                        ? const Center(child: CircularProgressIndicator())
                                        : ElevatedButton(
                                      onPressed: () => _buyProduct('catnappers_subscription_yearly', true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      child: const Text('Subscribe', style: TextStyle(fontSize: 12)),
                                    ),
                                  ),

                                ],
                              ),
                              const SizedBox(height: 20),
                              TextButton(
                                onPressed: restorePurchases,
                                child: const Text(
                                  'Restore Purchases',
                                  style: TextStyle(color: Colors.green),
                                ),
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
                                _products.any((p) => p.id == 'Catnappers_club_lifetime')
                                    ? '(${_products.firstWhere((p) => p.id == 'Catnappers_club_lifetime').price}/Onetime)'
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
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                                content: Text('Free trial not available yet')),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[300],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      child: const Text('Try Free', style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _isProcessing && _selectedProductId == 'catnappers_club_lifetime'
                                        ? const Center(child: CircularProgressIndicator())
                                        : ElevatedButton(
                                      onPressed: () => _buyProduct('catnappers_club_lifetime', false),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      child: const Text('Subscribe', style: TextStyle(fontSize: 12)),
                                    ),
                                  ),

                                ],
                              ),
                              const SizedBox(height: 20),
                              // TextButton(
                              //   onPressed: restorePurchases,
                              //   child: const Text(
                              //     'Restore Purchases',
                              //     style: TextStyle(color: Colors.green),
                              //   ),
                              // ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Note: Your subscription will auto-renew  until canceled(Monthly/Yearly).',
                          textAlign: TextAlign.center,
                          style: TextStyle(
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


              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const Homescreen()),
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
          Icons.star,
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