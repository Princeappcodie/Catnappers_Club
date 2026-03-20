import 'package:flutter/material.dart';
import '../models/dynamic_dialogue_model.dart';

class DynamicDialogue extends StatelessWidget {
  final DynamicDialogueModel config;

  const DynamicDialogue({
    Key? key,
    required this.config,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Print the URL to debug
    debugPrint('DynamicDialogue: Attempting to load image from URL: ${config.imageUrl}');
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: _buildDialogueContent(context),
    );
  }

  Widget _buildDialogueContent(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      decoration: BoxDecoration(
        // Beautiful Reddish Orange Gradient Background
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.orange.shade50,
            Colors.red.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildImageSection(),
          _buildTextContent(context),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    // Trim the URL and remove any accidentally added backticks or quotes
    final cleanUrl = config.imageUrl.trim().replaceAll('`', '').replaceAll('"', '').replaceAll("'", "");
    
    if (cleanUrl.isEmpty) {
      return const SizedBox(height: 20);
    }

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          cleanUrl,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 220,
              color: Colors.white,
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('DynamicDialogue: Image failed to load: $error');
            return Container(
              height: 220,
              color: Colors.grey.shade100,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported_rounded, 
                       size: 60, color: Colors.deepOrange.shade200),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Unable to load image. Check your internet connection or URL.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.deepOrange.shade300, fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decorative line
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.deepOrange.shade100,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            config.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFFD84315), // Deep Orange 800
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            config.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              color: Colors.red.shade900.withOpacity(0.8),
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          // Gradient Button
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7043), Color(0xFFD84315)], // Deep Orange 400 to 800
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepOrange.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Got it!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
