import 'package:cloud_firestore/cloud_firestore.dart';

class Business {
  final String id;
  final String name;
  final String type;
  final double latitude;
  final double longitude;
  final double rating;
  final String? profileImage;
  final List<Map<String, dynamic>>? services;
  final List<Map<String, dynamic>>? businessHours;

  Business({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.rating,
    this.profileImage,
    this.services,
    this.businessHours,
  });

  factory Business.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final location = data['location'];

    return Business(
      id: doc.id,
      name: data['username'] ?? 'Unnamed Business',
      type: data['businessType'] ?? 'unknown',
      latitude: location['latitude'] ?? 0.0,
      longitude: location['longitude'] ?? 0.0,
      rating: (data['rating'] ?? 0.0).toDouble(),
      profileImage: data['profileImage'],
      services: List<Map<String, dynamic>>.from(data['services'] ?? []),
      businessHours: List<Map<String, dynamic>>.from(data['businessHours'] ?? []),
    );
  }
}