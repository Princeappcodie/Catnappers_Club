import 'package:cloud_firestore/cloud_firestore.dart';

class AudioTrack {
  final String trackId; // New field for Firestore document ID
  final String name;
  final String fullAudioUrl;
  final String previewAudioUrl;
  final String category;
  final bool isFree;
  final String description;
  final String bestEnvironment;

  AudioTrack({
    required this.trackId,
    required this.name,
    required this.fullAudioUrl,
    required this.previewAudioUrl,
    required this.category,
    required this.isFree,
    required this.description,
    required this.bestEnvironment,
  });

  factory AudioTrack.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AudioTrack(
      trackId: doc.id, // Store the Firestore document ID
      name: data['name'] ?? '',
      fullAudioUrl: data['fullAudioUrl'] ?? '',
      previewAudioUrl: data['previewAudioUrl'] ?? '',
      category: data['category'] ?? '',
      isFree: data['isFree'] ?? false,
      description: data['description'] ?? 'No description available',
      bestEnvironment: data['bestEnvironment'] ?? 'No environment info available',
    );
  }
}