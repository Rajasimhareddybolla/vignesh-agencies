import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/promo_notification_model.dart';

/// Service for managing push notifications
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send a promotional notification to all users
  Future<void> sendPromoNotification(PromoNotification notification) async {
    // Store notification in Firestore (Broadcast)
    final docRef = await _firestore
        .collection('promo_notifications')
        .add(notification.toFirestore());

    // Only add to specific user's notifications collection if targeted
    if (notification.targetUserIds != null) {
      // Send to specific users
      for (final userId in notification.targetUserIds!) {
        await _addNotificationToUser(userId, docRef.id, notification);
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
          (snapshot) =>
              snapshot.docs
                  .map((doc) => PromoNotification.fromFirestore(doc))
                  .toList(),
        );
  }

  /// Get user notifications (Combines Personal + Global Broadcasts)
  Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
    // Stream 1: Personal notifications
    final personalStream = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .transform(
          StreamTransformer<
            QuerySnapshot<Map<String, dynamic>>,
            List<Map<String, dynamic>>
          >.fromHandlers(
            handleData: (snapshot, sink) {
              sink.add(
                snapshot.docs.map((doc) {
                  final data = doc.data();
                  return {'id': doc.id, ...data};
                }).toList(),
              );
            },
            handleError: (error, stackTrace, sink) {
              print('Error getting personal notifications: $error');
              sink.add(<Map<String, dynamic>>[]);
            },
          ),
        );

    // Stream 2: Global active promos (Broadcasts)
    final globalStream = _firestore
        .collection('promo_notifications')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .transform(
          StreamTransformer<
            QuerySnapshot<Map<String, dynamic>>,
            List<Map<String, dynamic>>
          >.fromHandlers(
            handleData: (snapshot, sink) {
              sink.add(
                snapshot.docs.map((doc) {
                  final data = doc.data();
                  return {'id': doc.id, ...data};
                }).toList(),
              );
            },
            handleError: (error, stackTrace, sink) {
              print('Error getting global notifications: $error');
              sink.add(<Map<String, dynamic>>[]);
            },
          ),
        );

    // Stream 3: Read receipts for global promos
    final readReceiptsStream = _firestore
        .collection('users')
        .doc(userId)
        .collection('read_notifications')
        .snapshots()
        .transform(
          StreamTransformer<
            QuerySnapshot<Map<String, dynamic>>,
            Set<String>
          >.fromHandlers(
            handleData: (snapshot, sink) {
              sink.add(snapshot.docs.map((doc) => doc.id).toSet());
            },
            handleError: (error, stackTrace, sink) {
              print('Error getting read receipts: $error');
              sink.add(<String>{});
            },
          ),
        );

    return _combineStreams<
      List<Map<String, dynamic>>,
      List<Map<String, dynamic>>,
      Set<String>,
      List<Map<String, dynamic>>
    >(personalStream, globalStream, readReceiptsStream, (
      List<Map<String, dynamic>> personalDocs,
      List<Map<String, dynamic>> globalDocsRaw,
      Set<String> readIds,
    ) {
      // 3. Parse Global Promos
      final globalDocs =
          globalDocsRaw
              .map((data) {
                // Check targeting
                final targetList = data['targetUserIds'];
                if (targetList != null) {
                  // Targeted notifications are handled by personal stream
                  return null;
                }

                final id = data['id'] as String;
                // If this global promo ID is in readIds, mark read=true
                final isRead = readIds.contains(id);

                return {
                  'id': id,
                  'promoId': id,
                  'title': data['title'] ?? '',
                  'body': data['body'] ?? '',
                  'imageUrl': data['imageUrl'],
                  'type': data['type'] ?? 'announcement',
                  'discountPercent': data['discountPercent'],
                  'read': isRead,
                  'createdAt': data['createdAt'],
                  'isGlobal': true,
                };
              })
              .where((doc) => doc != null)
              .cast<Map<String, dynamic>>()
              .toList();

      // 4. Merge and Sort
      final all = [...personalDocs, ...globalDocs];
      all.sort((a, b) {
        final tA = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final tB = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return tB.compareTo(tA);
      });

      return all;
    });
  }

  /// Mark notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    // Check if it exists in personal notifications first
    final personalRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId);

    final doc = await personalRef.get();

    if (doc.exists) {
      await personalRef.update({'read': true});
    } else {
      // It must be a global notification. Create a read receipt.
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('read_notifications')
          .doc(notificationId)
          .set({'readAt': FieldValue.serverTimestamp()});
    }
  }

  /// Get unread count
  Stream<int> getUnreadCount(String userId) {
    return getUserNotifications(userId)
        .map((list) {
          final count = list.where((n) {
            final read = n['read'];
            return read != true;
          }).length;
          return count;
        })
        .handleError((error) {
          print('NotificationService: getUnreadCount error for $userId: $error');
          return 0;
        });
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    // 1. Mark all personal notifications as read
    final personalNotifs =
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .where('read', isEqualTo: false)
            .get();

    final batch = _firestore.batch();
    for (final doc in personalNotifs.docs) {
      batch.update(doc.reference, {'read': true});
    }

    // 2. Get all global notifications and mark them as read
    final globalNotifs =
        await _firestore
            .collection('promo_notifications')
            .where('isActive', isEqualTo: true)
            .get();

    // Create read receipts for global notifications
    for (final doc in globalNotifs.docs) {
      final readReceiptRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('read_notifications')
          .doc(doc.id);
      batch.set(readReceiptRef, {
        'readAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// Delete a promotional notification
  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection('promo_notifications')
        .doc(notificationId)
        .delete();
  }

  Stream<T> _combineStreams<A, B, C, T>(
    Stream<A> streamA,
    Stream<B> streamB,
    Stream<C> streamC,
    T Function(A a, B b, C c) combiner,
  ) {
    final controller = StreamController<T>();
    A? lastA;
    B? lastB;
    C? lastC;
    bool hasA = false;
    bool hasB = false;
    bool hasC = false;

    void update() {
      if (hasA && hasB && hasC) {
        try {
          if (lastA != null && lastB != null && lastC != null) {
             controller.add(combiner(lastA as A, lastB as B, lastC as C));
          }
        } catch (e) {
          print('NotificationService: Error combining streams: $e');
          controller.addError(e);
        }
      }
    }

    final subA = streamA.listen(
      (a) {
        lastA = a;
        hasA = true;
        update();
      },
      onError: (e) => controller.addError(e),
    );
    
    final subB = streamB.listen(
      (b) {
        lastB = b;
        hasB = true;
        update();
      },
      onError: (e) => controller.addError(e),
    );
    
    final subC = streamC.listen(
      (c) {
        lastC = c;
        hasC = true;
        update();
      },
      onError: (e) => controller.addError(e),
    );

    controller.onCancel = () {
      subA.cancel();
      subB.cancel();
      subC.cancel();
    };

    return controller.stream;
  }
}
