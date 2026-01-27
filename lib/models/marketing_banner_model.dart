import 'package:cloud_firestore/cloud_firestore.dart';

class MarketingBannerModel {
  final String id;
  final String imageUrl;
  final String title;
  final String? targetRoute; // e.g., '/product-detail/123' or '/category/AC'
  final bool isActive;
  final int priority; // Higher number = earlier in slider
  final DateTime createdAt;

  MarketingBannerModel({
    required this.id,
    required this.imageUrl,
    required this.title,
    this.targetRoute,
    this.isActive = true,
    this.priority = 0,
    required this.createdAt,
  });

  factory MarketingBannerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MarketingBannerModel(
      id: doc.id,
      imageUrl: data['imageUrl'] ?? '',
      title: data['title'] ?? '',
      targetRoute: data['targetRoute'],
      isActive: data['isActive'] ?? true,
      priority: data['priority'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': imageUrl,
      'title': title,
      'targetRoute': targetRoute,
      'isActive': isActive,
      'priority': priority,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
