import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dynamic_dialogue_model.dart';

class DynamicDialogueService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _lastShownKey = 'last_dynamic_dialogue_shown_time';

  /// Fetches the current dynamic dialogue config from Firestore.
  /// Using a fixed document path: 'config/dynamic_dialogue'
  Future<DynamicDialogueModel?> getDialogueConfig() async {
    try {
      print('DynamicDialogue: Fetching config from Firestore...');
      final doc = await _firestore.collection('config').doc('dynamic_dialogue').get();
      if (!doc.exists) {
        print('DynamicDialogue: Document does not exist at config/dynamic_dialogue');
        return null;
      }
      print('DynamicDialogue: Config fetched successfully');
      return DynamicDialogueModel.fromFirestore(doc);
    } catch (e) {
      print('DynamicDialogue: Error fetching config: $e');
      return null;
    }
  }

  /// Checks if the dialogue should be shown based on the 'show' flag in Firestore
  /// and the 'once every 2 days' rule.
  Future<bool> shouldShowDialogue(DynamicDialogueModel config) async {
    if (!config.show) {
      print('DynamicDialogue: show flag is FALSE in Firestore');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastShownMs = prefs.getInt(_lastShownKey);
    
    if (lastShownMs == null) {
      print('DynamicDialogue: Never shown before, returning TRUE');
      return true;
    }

    final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownMs);
    final now = DateTime.now();
    final difference = now.difference(lastShown);

    print('DynamicDialogue: Last shown ${difference.inHours} hours ago');

    // If it's been more than 2 days (48 hours)
    bool shouldShow = difference.inDays >= 2;
    print('DynamicDialogue: Should show based on 2-day rule? $shouldShow');
    return shouldShow;
  }

  /// Updates the last shown time in SharedPreferences.
  Future<void> markAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastShownKey, DateTime.now().millisecondsSinceEpoch);
  }
}
