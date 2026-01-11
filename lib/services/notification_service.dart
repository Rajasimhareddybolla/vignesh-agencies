import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/promo_notification_model.dart';

/// Service for managing push notifications
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send a promotional notification to all users
  Future<void> sendPromoNotification(PromoNotification notification) async {
    // Store notification in Firestore
    final docRef = await _firestore
        .collection('promo_notifications')
        .add(notification.toFirestore());

    // Also add to each user's notifications collection
    if (notification.targetUserIds != null) {
      // Send to specific users
      for (final userId in notification.targetUserIds!) {
        await _addNotificationToUser(userId, docRef.id, notification);
      }
    } else {
      // Send to all users
      final users = await _firestore.collection('users').get();
      for (final user in users.docs) {
        await _addNotificationToUser(user.id, docRef.id, notification);
      }
    }
  }

  Future<void> _addNotificationToUser(
    String userId,
    String notificationId,
    PromoNotification notification,
  ) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
          'promoId': notificationId,
          'title': notification.title,
          'body': notification.body,
          'imageUrl': notification.imageUrl,
          'type': notification.type,
          'discountPercent': notification.discountPercent,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  /// Get all promotional notifications
  Stream<List<PromoNotification>> getPromoNotifications() {
    return _firestore
        .collection('promo_notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PromoNotification.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get user notifications
  Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  /// Mark notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  /// Get unread count
  Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Delete a promotional notification
  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection('promo_notifications')
        .doc(notificationId)
        .delete();
  }
}
