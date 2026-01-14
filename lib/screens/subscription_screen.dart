import 'package:flutter/material.dart';
import '../services/discount_service.dart';
import '../services/referral_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final DiscountService _discountService = DiscountService();
  final ReferralService _referralService = ReferralService();
  final TextEditingController _referralCodeController = TextEditingController();
  
  bool _isLoading = false;
  bool _hasDiscount = false;
  int _discountPercentage = 0;
  String? _appliedReferralCode;
  
  // Subscription plans according to  original pricse //
  final List<Map<String, dynamic>> _subscriptionPlans = [
    {
      'id': 'monthly',
      'name': 'Monthly',
      'originalPrice': 12.99,
      'discountedPrice': 12.99,
      'period': 'month',
      'features': ['Full access to all features', 'Cancel anytime'],
    },
    {
      'id': 'yearly',
      'name': 'Yearly',
      'originalPrice': 99.99,
      'discountedPrice': 99.99,
      'period': 'year',
      'features': ['Full access to all features', '1 Year free', 'Priority support'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDiscountInfo();
  }
  
  @override
  void dispose() {
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadDiscountInfo() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final discountInfo = await _discountService.getDiscountInfo();
      
      if (discountInfo['hasDiscount']) {
        setState(() {
          _hasDiscount = true;
          _discountPercentage = discountInfo['discountPercentage'];
          _appliedReferralCode = discountInfo['referralCode'];
        });
        
        // Update discounted prices
        _updateDiscountedPrices();
      }
    } catch (e) {
      debugPrint('Error loading discount info: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _updateDiscountedPrices() {
    if (_discountPercentage <= 0) return;
    
    setState(() {
      for (final plan in _subscriptionPlans) {
        final originalPrice = plan['originalPrice'] as double;
        final discountAmount = originalPrice * (_discountPercentage / 100);
        plan['discountedPrice'] = originalPrice - discountAmount;
      }
    });
  }

  Future<void> _applyReferralCode() async {
    final code = _referralCodeController.text.trim();
    if (code.isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await _referralService.applyReferralCode(code);
      
      if (success) {
        // Reload discount info
        await _loadDiscountInfo();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Referral code applied! You got $_discountPercentage% off!'))
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid or expired referral code'))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'))
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _processSubscription(Map<String, dynamic> plan) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // In a real app, you would integrate with a payment provider here
      // For this example, we'll just simulate a successful purchase
      
      if (_hasDiscount && _appliedReferralCode != null) {
        // Apply the discount and record the redemption
        final result = await _discountService.applyDiscountToSubscription(
          subscriptionId: plan['id'],
          originalPrice: plan['originalPrice'],
          referralCode: _appliedReferralCode!,
        );
        
        if (result['success']) {
          // Navigate to success screen or show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Subscription purchased with ${_discountPercentage}% discount!'))
            );
            
            // In a real app, navigate to a success screen
            // Navigator.pushReplacementNamed(context, '/subscription-success');
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${result['message']}'))
            );
          }
        }
      } else {
        // Process regular subscription without discount
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subscription purchased successfully!'))
          );
          
          // In a real app, navigate to a success screen
          // Navigator.pushReplacementNamed(context, '/subscription-success');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'))
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a Plan'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Your Subscription',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose the plan that works best for you',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Subscription plans
                  ..._subscriptionPlans.map((plan) => _buildSubscriptionCard(plan)),
                  
                  const SizedBox(height: 32),
                  
                  // Referral code section
                  if (!_hasDiscount) _buildReferralCodeSection(),
                  
                  // Discount info
                  if (_hasDiscount) _buildDiscountInfoSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> plan) {
    final originalPrice = plan['originalPrice'] as double;
    final discountedPrice = plan['discountedPrice'] as double;
    final hasDiscount = _hasDiscount && discountedPrice < originalPrice;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plan['name'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasDiscount)
                      Text(
                        '\$${originalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                        ),
                      ),
                    Text(
                      '\$${discountedPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: hasDiscount ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: hasDiscount ? Colors.green : null,
                      ),
                    ),
                    Text(
                      'per ${plan['period']}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(
              (plan['features'] as List).length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(plan['features'][index]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _processSubscription(plan),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Subscribe for \$${discountedPrice.toStringAsFixed(2)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralCodeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Have a Referral Code?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _referralCodeController,
                decoration: const InputDecoration(
                  hintText: 'Enter referral code',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _applyReferralCode,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            Navigator.pushNamed(context, '/referral');
          },
          child: const Text('Don\'t have a code? Refer friends and earn rewards!'),
        ),
      ],
    );
  }

  Widget _buildDiscountInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.discount, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Discount Applied: $_discountPercentage% Off',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Referral code: $_appliedReferralCode',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/referral');
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Share your own referral code with friends!'),
          ),
        ],
      ),
    );
  }
}