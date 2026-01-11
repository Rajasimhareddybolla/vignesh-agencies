import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for promotional notifications
class PromoNotification {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final String? actionUrl;
  final String type; // 'offer', 'festival', 'reminder', 'announcement'
  final double? discountPercent;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActive;
  final List<String>? targetUserIds; // null = send to all

  PromoNotification({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.actionUrl,
    required this.type,
    this.discountPercent,
    required this.createdAt,
    this.expiresAt,
    this.isActive = true,
    this.targetUserIds,
  });

  factory PromoNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PromoNotification(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      imageUrl: data['imageUrl'],
      actionUrl: data['actionUrl'],
      type: data['type'] ?? 'announcement',
      discountPercent: (data['discountPercent'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: data['expiresAt'] != null
          ? (data['expiresAt'] as Timestamp).toDate()
          : null,
      isActive: data['isActive'] ?? true,
      targetUserIds: data['targetUserIds'] != null
          ? List<String>.from(data['targetUserIds'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'actionUrl': actionUrl,
      'type': type,
      'discountPercent': discountPercent,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isActive': isActive,
      'targetUserIds': targetUserIds,
    };
  }

  /// Pre-defined notification templates
  static PromoNotification diwaliOffer({double discount = 20}) {
    return PromoNotification(
      id: '',
      title: '🪔 Happy Diwali! Special Offer',
      body:
          'Celebrate with ${discount.toInt()}% OFF on all V-Guard products! Limited time offer.',
      type: 'festival',
      discountPercent: discount,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );
  }

  static PromoNotification serviceReminder() {
    return PromoNotification(
      id: '',
      title: '🔧 Service Reminder',
      body:
          'Your appliance is due for routine maintenance. Book a service now!',
      type: 'reminder',
      createdAt: DateTime.now(),
    );
  }

  static PromoNotification warrantyExpiry() {
    return PromoNotification(
      id: '',
      title: '⚠️ Warranty Expiring Soon',
      body: 'Your product warranty is expiring soon. Renew now and save 15%!',
      type: 'reminder',
      discountPercent: 15,
      createdAt: DateTime.now(),
    );
  }

  static PromoNotification newProduct() {
    return PromoNotification(
      id: '',
      title: '🆕 New Product Launch!',
      body:
          'Check out our new range of energy-efficient appliances. Register now for exclusive offers!',
      type: 'announcement',
      createdAt: DateTime.now(),
    );
  }
}
