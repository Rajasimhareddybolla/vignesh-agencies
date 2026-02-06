import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_appliance_model.dart';
import '../models/service_request_model.dart';
import '../models/referral_model.dart';
import '../models/user_model.dart';
import '../models/catalog_product_model.dart';
import '../models/order_model.dart';
import '../models/marketing_banner_model.dart';
import '../models/support_message_model.dart';
import '../models/agent_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============== CATEGORIES ==============

  // Get all categories
  Stream<List<String>> getCategories() {
    return _firestore.collection('categories').orderBy('name').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => doc['name'] as String).toList();
    });
  }

  // Add a new category
  Future<void> addCategory(String categoryName) async {
    // Check if exists to avoid duplicates
    final query =
        await _firestore
            .collection('categories')
            .where('name', isEqualTo: categoryName)
            .get();

    if (query.docs.isEmpty) {
      await _firestore.collection('categories').add({
        'name': categoryName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Delete a category (Optional for now, but good to have)
  Future<void> deleteCategory(String categoryName) async {
    final query =
        await _firestore
            .collection('categories')
            .where('name', isEqualTo: categoryName)
            .get();

    for (var doc in query.docs) {
      await doc.reference.delete();
    }
  }

  // ============== SUPPORT MESSAGES ==============

  // Send a support message
  Future<void> sendSupportMessage(SupportMessageModel message) async {
    await _firestore.collection('support_messages').add(message.toFirestore());
  }

  // Get user by ID
  Future<UserModel?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.exists ? UserModel.fromFirestore(doc) : null;
  }

  // ============== MARKETING BANNERS ==============

  // Get active marketing banners
  Stream<List<MarketingBannerModel>> getMarketingBanners() {
    return _firestore
        .collection('marketing_banners')
        .where('isActive', isEqualTo: true)
        .orderBy('priority', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MarketingBannerModel.fromFirestore(doc))
              .toList();
        });
  }

  // Get all marketing banners (Admin)
  Stream<List<MarketingBannerModel>> getAllMarketingBanners() {
    return _firestore
        .collection('marketing_banners')
        .orderBy('priority', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MarketingBannerModel.fromFirestore(doc))
              .toList();
        });
  }

  // Add marketing banner
  Future<void> addMarketingBanner(MarketingBannerModel banner) async {
    await _firestore.collection('marketing_banners').add(banner.toFirestore());
  }

  // Delete marketing banner
  Future<void> deleteMarketingBanner(String bannerId) async {
    await _firestore.collection('marketing_banners').doc(bannerId).delete();
  }

  // Toggle banner status
  Future<void> toggleBannerStatus(String bannerId, bool isActive) async {
    await _firestore.collection('marketing_banners').doc(bannerId).update({
      'isActive': isActive,
    });
  }

  // ============== PRODUCTS ==============

  // Stream of user's products
  Stream<List<UserApplianceModel>> getUserProducts(String userId) {
    return _firestore
        .collection('products')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final docs =
              snapshot.docs
                  .map((doc) => UserApplianceModel.fromFirestore(doc))
                  .toList();
          docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return docs;
        });
  }

  // Add a new product
  Future<String> addProduct(UserApplianceModel product) async {
    final docRef = await _firestore
        .collection('products')
        .add(product.toFirestore());
    return docRef.id;
  }

  // Update product status (admin)
  Future<void> updateProductStatus({
    required String productId,
    required ProductStatus status,
    String? validatedBy,
    String? rejectionReason,
  }) async {
    final docRef = _firestore.collection('products').doc(productId);

    // Check for referral trigger when warranty becomes active
    if (status == ProductStatus.active) {
      final productDoc = await docRef.get();
      if (productDoc.exists) {
        final product = UserApplianceModel.fromFirestore(productDoc);
        await _processReferralForProduct(product);
      }
    }

    await docRef.update({
      'status': status.firestoreValue,
      'validatedBy': validatedBy,
      'validatedAt': status == ProductStatus.active ? Timestamp.now() : null,
      'rejectionReason': rejectionReason,
    });
  }

  // Update product purchase date and recalculate warranty (admin)
  Future<void> updateProductPurchaseDate(
    String productId,
    DateTime newDate,
  ) async {
    final docRef = _firestore.collection('products').doc(productId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final oldPurchase = (data['purchaseDate'] as Timestamp).toDate();
    final oldWarrantyEnd = (data['warrantyEndDate'] as Timestamp).toDate();
    // Preserve warranty duration
    final duration = oldWarrantyEnd.difference(oldPurchase);
    final newWarrantyEnd = newDate.add(duration);

    await docRef.update({
      'purchaseDate': Timestamp.fromDate(newDate),
      'warrantyEndDate': Timestamp.fromDate(newWarrantyEnd),
    });
  }

  /// Process referral commission when a user's first product is validated
  Future<void> _processReferralForProduct(UserApplianceModel product) async {
    try {
      // Find pending referral for this user (where they are the referee)
      final referralsQuery =
          await _firestore
              .collection('referrals')
              .where('refereeId', isEqualTo: product.userId)
              .where('status', isEqualTo: 'pending')
              .limit(1)
              .get();

      if (referralsQuery.docs.isNotEmpty) {
        final referralDoc = referralsQuery.docs.first;
        const commission = 100.0; // Fixed commission reward

        // 1. Update Referral Status
        await referralDoc.reference.update({
          'status': 'purchased',
          'commission': commission,
          'purchaseAmount': product.purchaseAmount ?? 0,
          'purchasedAt': FieldValue.serverTimestamp(),
        });

        // 2. Update Referrer's Wallet
        final referrerId = referralDoc.data()['referrerId'];
        if (referrerId != null) {
          await _firestore.collection('users').doc(referrerId).update({
            'totalEarnings': FieldValue.increment(commission),
            'pendingPayout': FieldValue.increment(commission),
          });
        }
      }
    } catch (e) {
      print('Error processing referral: $e');
      // Non-blocking error
    }
  }

  // Get products pending validation (admin)
  Stream<List<UserApplianceModel>> getPendingProducts() {
    return _firestore
        .collection('products')
        .where('status', isEqualTo: 'pending_validation')
        .snapshots()
        .map((snapshot) {
          final docs =
              snapshot.docs
                  .map((doc) => UserApplianceModel.fromFirestore(doc))
                  .toList();
          docs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return docs;
        });
  }

  // Get User Appliances (Admin/User)
  Stream<List<UserApplianceModel>> getUserAppliances(String userId) {
    return _firestore
        .collection('products')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserApplianceModel.fromFirestore(doc))
              .toList();
        });
  }

  // Expire User Appliance (Admin)
  Future<void> expireUserAppliance(String productId) async {
    await _firestore.collection('products').doc(productId).update({
      'status': ProductStatus.expired.firestoreValue,
      'warrantyEndDate': Timestamp.now(), // Expire immediately
    });
  }

  // Get all products (admin)
  Stream<List<UserApplianceModel>> getAllProducts() {
    return _firestore
        .collection('products')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => UserApplianceModel.fromFirestore(doc))
                  .toList(),
        );
  }

  // Get single product
  Future<UserApplianceModel?> getProduct(String productId) async {
    final doc = await _firestore.collection('products').doc(productId).get();
    return doc.exists ? UserApplianceModel.fromFirestore(doc) : null;
  }

  // ============== SERVICE REQUESTS ==============

  // Stream of user's service requests
  Stream<List<ServiceRequestModel>> getUserServiceRequests(String userId) {
    return _firestore
        .collection('service_requests')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final docs =
              snapshot.docs
                  .map((doc) => ServiceRequestModel.fromFirestore(doc))
                  .toList();
          docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return docs;
        });
  }

  // Stream of service requests for a specific product/appliance
  Stream<List<ServiceRequestModel>> getProductServiceRequests(
    String productId,
  ) {
    return _firestore
        .collection('service_requests')
        .where('productId', isEqualTo: productId)
        .snapshots()
        .map((snapshot) {
          final docs =
              snapshot.docs
                  .map((doc) => ServiceRequestModel.fromFirestore(doc))
                  .toList();
          docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return docs;
        });
  }

  // Create a new service request
  Future<String> createServiceRequest(ServiceRequestModel request) async {
    final docRef = await _firestore
        .collection('service_requests')
        .add(request.toFirestore());
    return docRef.id;
  }

  // Update service request status (admin)
  Future<void> updateServiceRequestStatus({
    required String requestId,
    required ServiceRequestStatus status,
    String? assignedProvider,
    String? technicianName,
    String? technicianPhone,
    String? technicianAddress,
    String? resolutionNotes,
    String? adminVoiceNoteUrl,
  }) async {
    final updates = <String, dynamic>{'status': status.firestoreValue};

    if (assignedProvider != null)
      updates['assignedProvider'] = assignedProvider;
    if (technicianName != null) updates['technicianName'] = technicianName;
    if (technicianPhone != null) updates['technicianPhone'] = technicianPhone;
    if (technicianAddress != null)
      updates['technicianAddress'] = technicianAddress;
    if (resolutionNotes != null) updates['resolutionNotes'] = resolutionNotes;
    if (adminVoiceNoteUrl != null)
      updates['adminVoiceNoteUrl'] = adminVoiceNoteUrl;

    if (status == ServiceRequestStatus.assigned) {
      updates['assignedAt'] = Timestamp.now();
    } else if (status == ServiceRequestStatus.resolved) {
      updates['resolvedAt'] = Timestamp.now();
    } else if (status == ServiceRequestStatus.completed) {
      updates['completedAt'] = Timestamp.now();
    }

    await _firestore
        .collection('service_requests')
        .doc(requestId)
        .update(updates);
  }

  // Update Estimated Completion Date (Admin)
  Future<void> updateServiceRequestEstimatedDate(
    String requestId,
    DateTime date,
  ) async {
    await _firestore.collection('service_requests').doc(requestId).update({
      'estimatedCompletionDate': Timestamp.fromDate(date),
    });
  }

  // Get all service requests (admin)
  Stream<List<ServiceRequestModel>> getAllServiceRequests({
    ServiceRequestStatus? filterStatus,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(
      'service_requests',
    );

    if (filterStatus != null) {
      query = query.where('status', isEqualTo: filterStatus.firestoreValue);
    }

    return query.snapshots().map((snapshot) {
      final docs =
          snapshot.docs
              .map((doc) => ServiceRequestModel.fromFirestore(doc))
              .toList();
      docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return docs;
    });
  }

  // Get single service request
  Future<ServiceRequestModel?> getServiceRequest(String requestId) async {
    final doc =
        await _firestore.collection('service_requests').doc(requestId).get();
    return doc.exists ? ServiceRequestModel.fromFirestore(doc) : null;
  }

  // Get single service request as stream (for real-time updates)
  Stream<ServiceRequestModel?> getServiceRequestStream(String requestId) {
    return _firestore
        .collection('service_requests')
        .doc(requestId)
        .snapshots()
        .map(
          (doc) => doc.exists ? ServiceRequestModel.fromFirestore(doc) : null,
        );
  }

  // Get pending service requests count
  Future<int> getPendingRequestsCount() async {
    final snapshot =
        await _firestore
            .collection('service_requests')
            .where('status', isEqualTo: 'pending')
            .count()
            .get();
    return snapshot.count ?? 0;
  }

  // Submit feedback for a completed service request (Phase 3)
  Future<void> submitServiceFeedback({
    required String requestId,
    required int rating,
    String? comment,
  }) async {
    await _firestore.collection('service_requests').doc(requestId).update({
      'rating': rating,
      'feedbackComment': comment,
      'feedbackSubmittedAt': FieldValue.serverTimestamp(),
      'feedbackRequested': false,
    });
  }

  // Mark service request as completed by user (Phase 3)
  Future<void> markServiceRequestCompleted(String requestId) async {
    await _firestore.collection('service_requests').doc(requestId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'feedbackRequested': true,
    });
  }

  // ============== REFERRALS ==============

  // Stream of user's referrals
  Stream<List<ReferralModel>> getUserReferrals(String userId) {
    return _firestore
        .collection('referrals')
        .where('referrerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final docs =
              snapshot.docs
                  .map((doc) => ReferralModel.fromFirestore(doc))
                  .toList();
          docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return docs;
        });
  }

  // Get all referrals (Admin)
  Stream<List<ReferralModel>> getAllReferrals() {
    return _firestore.collection('referrals').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ReferralModel.fromFirestore(doc))
          .toList();
    });
  }

  // Approve referral and set reward coins
  Future<void> approveReferral(String referralId, int rewardCoins) async {
    await _firestore.collection('referrals').doc(referralId).update({
      'status': 'approved',
      'adminApproved': true,
      'rewardCoins': rewardCoins,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  // Create a referral when new user signs up with code
  Future<String> createReferral({
    required String referrerId,
    required String refereeId,
    required String referralCode,
    String? refereeName,
    String? refereePhone,
  }) async {
    final referral = ReferralModel(
      id: '',
      referrerId: referrerId,
      refereeId: refereeId,
      referralCode: referralCode,
      status: ReferralStatus.pending,
      createdAt: DateTime.now(),
      refereeName: refereeName,
      refereePhone: refereePhone,
    );

    final docRef = await _firestore
        .collection('referrals')
        .add(referral.toFirestore());
    return docRef.id;
  }

  // Update referral status when purchase is made
  Future<void> updateReferralToPurchased({
    required String referralId,
    required double purchaseAmount,
  }) async {
    final commission =
        ReferralModel.fixedCommission; // or calculate based on purchase

    await _firestore.collection('referrals').doc(referralId).update({
      'status': 'purchased',
      'purchaseAmount': purchaseAmount,
      'commission': commission,
      'purchasedAt': Timestamp.now(),
    });

    // Update referrer's pending payout
    final referral =
        await _firestore.collection('referrals').doc(referralId).get();
    final referrerId = referral.data()?['referrerId'];
    if (referrerId != null) {
      await _firestore.collection('users').doc(referrerId).update({
        'pendingPayout': FieldValue.increment(commission),
      });
    }
  }

  // Mark referral as paid (admin)
  Future<void> markReferralPaid(String referralId) async {
    final referral =
        await _firestore.collection('referrals').doc(referralId).get();
    final referralData = referral.data();

    if (referralData != null) {
      final commission = referralData['commission'] ?? 0.0;
      final referrerId = referralData['referrerId'];

      await _firestore.collection('referrals').doc(referralId).update({
        'status': 'paid',
        'paidAt': Timestamp.now(),
      });

      // Update user's earnings and pending payout
      if (referrerId != null) {
        await _firestore.collection('users').doc(referrerId).update({
          'totalEarnings': FieldValue.increment(commission),
          'pendingPayout': FieldValue.increment(-commission),
        });
      }
    }
  }

  // Get users with pending payouts (admin)
  Stream<List<UserModel>> getUsersWithPendingPayouts() {
    return _firestore
        .collection('users')
        .where('pendingPayout', isGreaterThan: 0)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
  }

  // Mark user payout as complete (admin)
  Future<void> markUserPayoutComplete(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final pendingPayout = userDoc.data()?['pendingPayout'] ?? 0.0;

    // Mark all pending referrals for this user as paid
    final pendingReferrals =
        await _firestore
            .collection('referrals')
            .where('referrerId', isEqualTo: userId)
            .where('status', isEqualTo: 'purchased')
            .get();

    final batch = _firestore.batch();
    for (final doc in pendingReferrals.docs) {
      batch.update(doc.reference, {
        'status': 'paid',
        'paidAt': Timestamp.now(),
      });
    }

    // Update user's totals
    batch.update(_firestore.collection('users').doc(userId), {
      'totalEarnings': FieldValue.increment(pendingPayout),
      'pendingPayout': 0,
    });

    await batch.commit();
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String userId,
    required String displayName,
    String? email,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{
      'displayName': displayName,
      'lastLoginAt': Timestamp.now(),
    };
    if (email != null && email.isNotEmpty) {
      updates['email'] = email;
    }
    if (photoUrl != null) {
      updates['photoUrl'] = photoUrl;
    }
    await _firestore.collection('users').doc(userId).update(updates);
  }

  // ============== DASHBOARD STATS (Admin) ==============

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final pendingRequests =
          await _firestore
              .collection('service_requests')
              .where('status', isEqualTo: 'pending')
              .count()
              .get();

      final pendingRegistrations =
          await _firestore
              .collection('products')
              .where('status', isEqualTo: 'pending_validation')
              .count()
              .get();

      // Count ALL users for now to ensure numbers show up
      // The 'isProxy' query requires a composite index and might exclude docs where the field is missing
      final totalUsers = await _firestore.collection('users').count().get();

      final usersWithPayouts =
          await _firestore
              .collection('users')
              .where('pendingPayout', isGreaterThan: 0)
              .get();

      double totalPendingPayouts = 0;
      for (final doc in usersWithPayouts.docs) {
        totalPendingPayouts += (doc.data()['pendingPayout'] ?? 0).toDouble();
      }

      // Count total and resolved service requests
      final totalRequests =
          await _firestore.collection('service_requests').count().get();

      final resolvedRequests =
          await _firestore
              .collection('service_requests')
              .where('status', whereIn: ['resolved', 'completed'])
              .count()
              .get();

      return {
        'pendingRequests': pendingRequests.count ?? 0,
        'pendingRegistrations': pendingRegistrations.count ?? 0,
        'totalUsers': totalUsers.count ?? 0,
        'pendingPayouts': totalPendingPayouts,
        'totalRequests': totalRequests.count ?? 0,
        'resolvedRequests': resolvedRequests.count ?? 0,
      };
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return {
        'pendingRequests': 0,
        'pendingRegistrations': 0,
        'totalUsers': 0,
        'pendingPayouts': 0.0,
        'totalRequests': 0,
        'resolvedRequests': 0,
      };
    }
  }

  // Get recent activity for dashboard
  Stream<List<Map<String, dynamic>>> getRecentActivity({int limit = 10}) {
    return _firestore
        .collection('service_requests')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
          final activities = <Map<String, dynamic>>[];

          for (final doc in snapshot.docs) {
            final request = ServiceRequestModel.fromFirestore(doc);
            activities.add({
              'type': 'service_request',
              'title': 'Service Request ${request.ticketNumber}',
              'description': request.issueType,
              'status': request.status.displayName,
              'timestamp': request.createdAt,
            });
          }

          return activities;
        });
  }

  // Lookup user by referral code
  Future<UserModel?> getUserByReferralCode(String code) async {
    final snapshot =
        await _firestore
            .collection('users')
            .where('referralCode', isEqualTo: code)
            .limit(1)
            .get();

    if (snapshot.docs.isNotEmpty) {
      return UserModel.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  // ============== CATALOG (Admin & User) ==============

  // Get all catalog products (Active only - for Users)
  Stream<List<CatalogProductModel>> getCatalogProducts({
    String? categoryId,
    String? searchQuery,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('catalog_products')
        .where('isActive', isEqualTo: true);

    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }

    return query.snapshots().map((snapshot) {
      var products =
          snapshot.docs
              .map((doc) => CatalogProductModel.fromFirestore(doc))
              .toList();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final queryLower = searchQuery.toLowerCase();
        products =
            products.where((p) {
              return p.name.toLowerCase().contains(queryLower) ||
                  p.brand.toLowerCase().contains(queryLower);
            }).toList();
      }

      return products;
    });
  }

  // Get ALL catalog products (For Admin)
  Stream<List<CatalogProductModel>> getAdminCatalogProducts() {
    return _firestore
        .collection('catalog_products')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => CatalogProductModel.fromFirestore(doc))
                  .toList(),
        );
  }

  // Get single catalog product
  Future<CatalogProductModel?> getCatalogProduct(String id) async {
    final doc = await _firestore.collection('catalog_products').doc(id).get();
    return doc.exists ? CatalogProductModel.fromFirestore(doc) : null;
  }

  // Add catalog product (Admin)
  Future<void> addCatalogProduct(CatalogProductModel product) async {
    // If ID is empty, let Firestore generate it, but we usually want to set it in the model
    // Here we assume the model has 'id' empty, so we add and update, or set id before.
    // Better: use .doc().set() if we generate ID locally, or .add() if not.
    // Let's us .add() and then update the ID field if needed, or just rely on doc ID.
    // However, our model has 'id' field.
    final docRef = _firestore.collection('catalog_products').doc();
    final productWithId = product.copyWith(id: docRef.id);
    await docRef.set(productWithId.toFirestore());
  }

  // Update catalog product (Admin)
  Future<void> updateCatalogProduct(CatalogProductModel product) async {
    await _firestore
        .collection('catalog_products')
        .doc(product.id)
        .update(product.toFirestore());
  }

  // Delete catalog product
  Future<void> deleteCatalogProduct(String id) async {
    await _firestore.collection('catalog_products').doc(id).delete();
  }

  // ============== ORDERS ==============

  // Place a new Order
  Future<String> placeOrder(OrderModel order) async {
    // 1. Create Order
    final docRef = _firestore.collection('orders').doc();
    final orderWithId = OrderModel(
      id: docRef.id,
      userId: order.userId,
      items: order.items,
      totalAmount: order.totalAmount,
      status: order.status,
      paymentMethod: order.paymentMethod,
      address: order.address,
      orderedAt: order.orderedAt,
      deliveredAt: order.deliveredAt,
      trackingNumber: order.trackingNumber,
      shippingFee: order.shippingFee,
    );

    await docRef.set(orderWithId.toFirestore());

    // 2. (Optional) Auto-register appliances if warranty starts immediately?
    // Usually warranty starts from delivery. So we handle that on 'delivered' status.

    return docRef.id;
  }

  // Get User Orders
  Stream<List<OrderModel>> getUserOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('orderedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => OrderModel.fromFirestore(doc))
                  .toList(),
        );
  }

  // Get Single Order by ID
  Future<OrderModel?> getOrder(String orderId) async {
    final doc = await _firestore.collection('orders').doc(orderId).get();
    return doc.exists ? OrderModel.fromFirestore(doc) : null;
  }

  // Get all users (Admin)
  Stream<List<UserModel>> getAllUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    });
  }

  // Get All Orders (Admin)
  Stream<List<OrderModel>> getAllOrders({OrderStatus? status}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('orders')
        .orderBy('orderedAt', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status.firestoreValue);
    }

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList(),
    );
  }

  // Update Order Status (Admin) - With concurrency control
  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus status, {
    String? trackingNumber,
    int? expectedVersion,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore.collection('orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final currentVersion = orderDoc.data()?['version'] ?? 1;
      if (expectedVersion != null && currentVersion != expectedVersion) {
        throw Exception(
          'Order was modified by another user. Please refresh and try again.',
        );
      }

      final updates = <String, dynamic>{
        'status': status.firestoreValue,
        'version': currentVersion + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == OrderStatus.delivered) {
        updates['deliveredAt'] = Timestamp.now();

        // Calculate and credit 5% digital coins
        final orderData = orderDoc.data()!;
        final totalAmount = (orderData['totalAmount'] ?? 0).toDouble();
        final userId = orderData['userId'] as String;
        final coins = (totalAmount * 0.05).round();

        if (coins > 0) {
          final userRef = _firestore.collection('users').doc(userId);
          transaction.update(userRef, {
            'digitalCoins': FieldValue.increment(coins),
          });
        }
      }
      if (trackingNumber != null) {
        updates['trackingNumber'] = trackingNumber;
      }

      transaction.update(orderRef, updates);
    });

    // Note: Auto-registration removed. Users should manually register their
    // appliances via the "Register for Warranty" button in order details,
    // so they can upload their warranty/bill proof.
    // if (status == OrderStatus.delivered) {
    //   await _autoRegisterAppliancesFromOrder(orderId);
    // }
  }

  // Update Order Expected Delivery Date (Admin)
  Future<void> updateOrderExpectedDeliveryDate(
    String orderId,
    DateTime date,
  ) async {
    await _firestore.collection('orders').doc(orderId).update({
      'expectedDeliveryDate': Timestamp.fromDate(date),
    });
  }

  // Cancel Order (User) - Only allowed before shipping, with reason
  Future<void> cancelOrder(
    String orderId,
    String userId, {
    String? reason,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore.collection('orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) throw Exception('Order not found');

      final order = OrderModel.fromFirestore(orderDoc);

      // Validate ownership
      if (order.userId != userId) {
        throw Exception('You can only cancel your own orders');
      }

      // Only allow cancellation before shipping
      if (order.status == OrderStatus.shipped ||
          order.status == OrderStatus.delivered) {
        throw Exception('Cannot cancel order after it has been shipped');
      }

      if (order.status == OrderStatus.cancelled) {
        throw Exception('Order is already cancelled');
      }

      // Restore stock for cancelled items
      for (final item in order.items) {
        final productRef = _firestore
            .collection('catalog_products')
            .doc(item.productId);
        final productDoc = await transaction.get(productRef);

        if (productDoc.exists) {
          final trackInventory = productDoc.data()?['trackInventory'] ?? true;
          if (trackInventory) {
            transaction.update(productRef, {
              'stockQuantity': FieldValue.increment(item.quantity),
            });
          }
        }
      }

      transaction.update(orderRef, {
        'status': OrderStatus.cancelled.firestoreValue,
        'cancelledAt': Timestamp.now(),
        'cancelledBy': 'user',
        'cancellationReason': reason,
        'version': FieldValue.increment(1),
      });
    });
  }

  // Auto-register appliances when order is delivered
  Future<void> _autoRegisterAppliancesFromOrder(String orderId) async {
    final orderDoc = await _firestore.collection('orders').doc(orderId).get();
    if (!orderDoc.exists) return;

    final order = OrderModel.fromFirestore(orderDoc);

    // Check if we already registered these (idempotency check could be added,
    // but for now we assume this runs once on status change)

    final batch = _firestore.batch();

    for (var item in order.items) {
      // For each quantity
      for (int i = 0; i < item.quantity; i++) {
        final newApplianceRef = _firestore.collection('products').doc();

        final warrantyEndDate = DateTime.now().add(
          Duration(days: item.warrantyMonths * 30),
        );

        final appliance = UserApplianceModel(
          id: newApplianceRef.id,
          userId: order.userId,
          category: item.category, // Use category from order item
          productName: item.productName,
          modelNumber:
              item.selectedAttributes.values.join(' ') +
              (item.sku != null ? ' (${item.sku})' : ''),
          purchaseDate: DateTime.now(), // Delivered date = start of warranty
          warrantyEndDate: warrantyEndDate,
          status: ProductStatus.active, // Auto-active
          validatedBy: 'SYSTEM',
          validatedAt: DateTime.now(),
          createdAt: DateTime.now(),
          purchaseAmount: item.price,
          storeLocation: 'Online Store',
        );

        batch.set(newApplianceRef, appliance.toFirestore());
      }
    }

    await batch.commit();

    // 🎁 Process referral commission for online purchases
    await _processReferralForOrderDelivery(order.userId, order.totalAmount);
  }

  /// Process referral commission when an order is delivered (for online purchases)
  Future<void> _processReferralForOrderDelivery(
    String userId,
    double orderAmount,
  ) async {
    try {
      // Find pending referral for this user (where they are the referee)
      final referralsQuery =
          await _firestore
              .collection('referrals')
              .where('refereeId', isEqualTo: userId)
              .where('status', isEqualTo: 'pending')
              .limit(1)
              .get();

      if (referralsQuery.docs.isNotEmpty) {
        final referralDoc = referralsQuery.docs.first;
        const commission = 100.0; // Fixed commission reward

        // 1. Update Referral Status
        await referralDoc.reference.update({
          'status': 'purchased',
          'commission': commission,
          'purchaseAmount': orderAmount,
          'purchasedAt': FieldValue.serverTimestamp(),
        });

        // 2. Update Referrer's Wallet
        final referrerId = referralDoc.data()['referrerId'];
        if (referrerId != null) {
          await _firestore.collection('users').doc(referrerId).update({
            'totalEarnings': FieldValue.increment(commission),
            'pendingPayout': FieldValue.increment(commission),
          });
        }

        print(
          'Referral commission processed for order delivery: User $userId, Referrer $referrerId',
        );
      }
    } catch (e) {
      print('Error processing referral for order delivery: $e');
      // Non-blocking error - don't fail the order delivery
    }
  }

  // ============== AGENTS ==============

  // Get all active agents
  Stream<List<AgentModel>> getActiveAgents() {
    // Note: Using client-side filter to avoid composite index requirement
    return _firestore.collection('agents').snapshots().map((snapshot) {
      final agents =
          snapshot.docs
              .map((doc) => AgentModel.fromFirestore(doc))
              .where((agent) => agent.isActive)
              .toList();
      // Sort by name client-side
      agents.sort((a, b) => a.name.compareTo(b.name));
      return agents;
    });
  }

  // Get all agents (admin)
  Stream<List<AgentModel>> getAllAgents() {
    return _firestore
        .collection('agents')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AgentModel.fromFirestore(doc))
              .toList();
        });
  }

  // Add a new agent
  Future<String> addAgent(AgentModel agent) async {
    final docRef = await _firestore
        .collection('agents')
        .add(agent.toFirestore());
    return docRef.id;
  }

  // Update an agent
  Future<void> updateAgent(AgentModel agent) async {
    await _firestore
        .collection('agents')
        .doc(agent.id)
        .update(agent.toFirestore());
  }

  // Delete an agent
  Future<void> deleteAgent(String agentId) async {
    await _firestore.collection('agents').doc(agentId).delete();
  }

  // Toggle agent active status
  Future<void> toggleAgentStatus(String agentId, bool isActive) async {
    await _firestore.collection('agents').doc(agentId).update({
      'isActive': isActive,
    });
  }

  // Update agent's last assigned timestamp
  Future<void> updateAgentLastAssigned(String agentId) async {
    await _firestore.collection('agents').doc(agentId).update({
      'lastAssignedAt': Timestamp.now(),
    });
  }

  // Get single agent
  Future<AgentModel?> getAgent(String agentId) async {
    final doc = await _firestore.collection('agents').doc(agentId).get();
    return doc.exists ? AgentModel.fromFirestore(doc) : null;
  }

  // Force refresh user stats by reading latest data
  Future<void> refreshUserStats(String userId) async {
    // Trigger a fresh read from Firestore to update any cached streams
    // This helps ensure the UI reflects the latest data
    await _firestore
        .collection('users')
        .doc(userId)
        .get(const GetOptions(source: Source.server));
    await _firestore
        .collection('products')
        .where('userId', isEqualTo: userId)
        .get(const GetOptions(source: Source.server));
    await _firestore
        .collection('service_requests')
        .where('userId', isEqualTo: userId)
        .get(const GetOptions(source: Source.server));
  }

  // ============== STOCK MANAGEMENT ==============

  /// Get products with low stock (Admin)
  Stream<List<CatalogProductModel>> getLowStockProducts() {
    return _firestore
        .collection('catalog_products')
        .where('trackInventory', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CatalogProductModel.fromFirestore(doc))
              .where((product) => product.isLowStock || product.isOutOfStock)
              .toList()
            ..sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));
        });
  }

  /// Get out of stock products count
  Future<int> getOutOfStockCount() async {
    final snapshot =
        await _firestore
            .collection('catalog_products')
            .where('trackInventory', isEqualTo: true)
            .where('isActive', isEqualTo: true)
            .where('stockQuantity', isLessThanOrEqualTo: 0)
            .count()
            .get();
    return snapshot.count ?? 0;
  }

  /// Get low stock products count
  Future<int> getLowStockCount() async {
    final snapshot =
        await _firestore
            .collection('catalog_products')
            .where('trackInventory', isEqualTo: true)
            .where('isActive', isEqualTo: true)
            .get();

    int count = 0;
    for (final doc in snapshot.docs) {
      final stockQty = doc.data()['stockQuantity'] ?? 0;
      final threshold = doc.data()['lowStockThreshold'] ?? 5;
      if (stockQty > 0 && stockQty <= threshold) {
        count++;
      }
    }
    return count;
  }

  /// Update stock quantity for a product
  Future<void> updateProductStock(String productId, int newQuantity) async {
    await _firestore.collection('catalog_products').doc(productId).update({
      'stockQuantity': newQuantity,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Increment stock quantity (for restocking)
  Future<void> incrementProductStock(String productId, int quantity) async {
    await _firestore.collection('catalog_products').doc(productId).update({
      'stockQuantity': FieldValue.increment(quantity),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Decrement stock quantity (for sales)
  Future<void> decrementProductStock(String productId, int quantity) async {
    await _firestore.collection('catalog_products').doc(productId).update({
      'stockQuantity': FieldValue.increment(-quantity),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Validate stock availability for cart items
  /// Returns a map of productId -> error message for items with issues
  Future<Map<String, String>> validateCartStock(
    List<Map<String, dynamic>> cartItems,
  ) async {
    final issues = <String, String>{};

    for (final item in cartItems) {
      final productId = item['productId'] as String;
      final requestedQty = item['quantity'] as int;
      final productName = item['productName'] as String? ?? 'Product';

      final productDoc =
          await _firestore.collection('catalog_products').doc(productId).get();

      if (!productDoc.exists) {
        issues[productId] = '$productName is no longer available';
        continue;
      }

      final data = productDoc.data()!;
      final isActive = data['isActive'] ?? true;
      final trackInventory = data['trackInventory'] ?? true;
      final stockQuantity = data['stockQuantity'] ?? 0;

      if (!isActive) {
        issues[productId] = '$productName is no longer available';
      } else if (trackInventory && stockQuantity < requestedQty) {
        if (stockQuantity <= 0) {
          issues[productId] = '$productName is out of stock';
        } else {
          issues[productId] =
              'Only $stockQuantity units of $productName available';
        }
      }
    }

    return issues;
  }

  /// Place order with stock validation and decrement (atomic transaction)
  Future<String> placeOrderWithStockValidation({
    required OrderModel order,
    required List<Map<String, dynamic>> cartItems,
  }) async {
    return await _firestore.runTransaction<String>((transaction) async {
      // First, validate and collect all product docs
      final productDocs = <String, DocumentSnapshot>{};

      for (final item in cartItems) {
        final productId = item['productId'] as String;
        final productRef = _firestore
            .collection('catalog_products')
            .doc(productId);
        final productDoc = await transaction.get(productRef);
        productDocs[productId] = productDoc;
      }

      // Validate stock for all items
      for (final item in cartItems) {
        final productId = item['productId'] as String;
        final requestedQty = item['quantity'] as int;
        final productName = item['productName'] as String? ?? 'Product';
        final productDoc = productDocs[productId]!;

        if (!productDoc.exists) {
          throw Exception('$productName is no longer available');
        }

        final data = productDoc.data() as Map<String, dynamic>;
        final isActive = data['isActive'] ?? true;
        final trackInventory = data['trackInventory'] ?? true;
        final stockQuantity = data['stockQuantity'] ?? 0;

        if (!isActive) {
          throw Exception('$productName is no longer available');
        }

        if (trackInventory && stockQuantity < requestedQty) {
          if (stockQuantity <= 0) {
            throw Exception('$productName is out of stock');
          } else {
            throw Exception(
              'Only $stockQuantity units of $productName available',
            );
          }
        }
      }

      // All validation passed - decrement stock
      for (final item in cartItems) {
        final productId = item['productId'] as String;
        final requestedQty = item['quantity'] as int;
        final productDoc = productDocs[productId]!;
        final data = productDoc.data() as Map<String, dynamic>;
        final trackInventory = data['trackInventory'] ?? true;

        if (trackInventory) {
          final productRef = _firestore
              .collection('catalog_products')
              .doc(productId);
          transaction.update(productRef, {
            'stockQuantity': FieldValue.increment(-requestedQty),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Create the order
      final orderRef = _firestore.collection('orders').doc();
      final orderWithId = OrderModel(
        id: orderRef.id,
        userId: order.userId,
        items: order.items,
        totalAmount: order.totalAmount,
        status: order.status,
        paymentMethod: order.paymentMethod,
        address: order.address,
        orderedAt: order.orderedAt,
        deliveredAt: order.deliveredAt,
        trackingNumber: order.trackingNumber,
        version: 1,
      );

      transaction.set(orderRef, orderWithId.toFirestore());

      return orderRef.id;
    });
  }
}
