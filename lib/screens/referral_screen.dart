import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/referral_service.dart';
import '../models/referral_model.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({Key? key}) : super(key: key);

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final ReferralService _referralService = ReferralService();
  ReferralModel? _userReferral;
  bool _isLoading = true;
  String? _dynamicLink;

  @override
  void initState() {
    super.initState();
    _loadReferralData();
    _referralService.initAppLinks();
  }

  Future<void> _loadReferralData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get or create user's referral //
      final referral = await _referralService.getUserReferral() ?? 
                       await _referralService.createReferral();
      
      if (referral != null) {
        final dynamicLink = await _referralService.createDynamicLink(referral.referrerCode);
        
        setState(() {
          _userReferral = referral;
          _dynamicLink = dynamicLink?.toString();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load referral data'))
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'))
        );
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard!'))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Refer a Friend'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userReferral == null
              ? const Center(child: Text('Failed to load referral data'))
              : _buildReferralContent(),
    );
  }

  Widget _buildReferralContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header image
          Image.asset(
            'assets/sleeping-cat-3.jpeg',
            height: 200,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 200,
              color: Colors.grey[200],
              child: Center(

              ),
            ),
          ),
          const SizedBox(height: 2),
          
          // Title //
          Text(
            'Share with Friends',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Description //

          Text(
            'Invite your friends to join Catnappers Club. They\'ll get ${_userReferral!.discountPercentage}% off their subscription, and you\'ll earn rewards!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          
          // Referral code card  //
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Your Referral Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _userReferral!.referrerCode,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => _copyToClipboard(_userReferral!.referrerCode),
                        tooltip: 'Copy code',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Used ${_userReferral!.usageCount} of ${_userReferral!.maxUsage} times',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Share button //
          ElevatedButton.icon(
            onPressed: () => _referralService.shareReferralLink(context),
            icon: const Icon(Icons.share),
            label: const Text('Share with Friends'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          
          if (_dynamicLink != null) ...[
            const SizedBox(height: 24),
            const Text(
              'Or share this link:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _copyToClipboard(_dynamicLink!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _dynamicLink!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.blue[700]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.copy, size: 18, color: Colors.blue[700]),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
          // How it works section //
          const Text(
            'How It Works',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildHowItWorksStep(
            icon: Icons.share,
            title: 'Share Your Code',
            description: 'Send your unique referral code to friends',
          ),
          _buildHowItWorksStep(
            icon: Icons.person_add,
            title: 'Friend Signs Up',
            description: 'They enter your code during registration',
          ),
          _buildHowItWorksStep(
            icon: Icons.discount,
            title: 'Both Get Rewards',
            description: 'They get a discount, you earn points',
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksStep({
    required IconData icon,
    required String title,
    required String description,
  }) {

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Theme.of(context).primaryColor),
          ),

          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}