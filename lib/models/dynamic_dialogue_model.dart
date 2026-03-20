import 'package:cloud_firestore/cloud_firestore.dart';

class DynamicDialogueModel {
  final bool show;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime updatedAt;

  DynamicDialogueModel({
    required this.show,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.updatedAt,
  });

  factory DynamicDialogueModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return DynamicDialogueModel(
      show: data['show'] ?? false,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'show': show,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}