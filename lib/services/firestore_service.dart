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
  Stream<List<ServiceRequestModel>> getProductServiceRequests(String productId) {
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
  }) async {
    final updates = <String, dynamic>{'status': status.firestoreValue};

    if (assignedProvider != null)
      updates['assignedProvider'] = assignedProvider;
    if (technicianName != null) updates['technicianName'] = technicianName;
    if (technicianPhone != null) updates['technicianPhone'] = technicianPhone;
    if (technicianAddress != null)
      updates['technicianAddress'] = technicianAddress;
    if (resolutionNotes != null) updates['resolutionNotes'] = resolutionNotes;

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

    return {
      'pendingRequests': pendingRequests.count ?? 0,
      'pendingRegistrations': pendingRegistrations.count ?? 0,
      'totalUsers': totalUsers.count ?? 0,
      'pendingPayouts': totalPendingPayouts,
    };
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

  // Update Order Status (Admin)
  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus status, {
    String? trackingNumber,
  }) async {
    final updates = <String, dynamic>{'status': status.firestoreValue};

    if (status == OrderStatus.delivered) {
      updates['deliveredAt'] = Timestamp.now();
    }
    if (trackingNumber != null) {
      updates['trackingNumber'] = trackingNumber;
    }

    await _firestore.collection('orders').doc(orderId).update(updates);

    // If Delivered, Automatically Register Valid Appliances
    if (status == OrderStatus.delivered) {
      await _autoRegisterAppliancesFromOrder(orderId);
    }
  }

  // Cancel Order (User) - Only allowed before shipping
  Future<void> cancelOrder(String orderId, String userId) async {
    final orderDoc = await _firestore.collection('orders').doc(orderId).get();
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

    await _firestore.collection('orders').doc(orderId).update({
      'status': OrderStatus.cancelled.firestoreValue,
      'cancelledAt': Timestamp.now(),
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
    return _firestore
        .collection('agents')
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AgentModel.fromFirestore(doc))
              .toList();
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
    await _firestore.collection('users').doc(userId).get(
      const GetOptions(source: Source.server),
    );
    await _firestore.collection('products')
        .where('userId', isEqualTo: userId)
        .get(const GetOptions(source: Source.server));
    await _firestore.collection('service_requests')
        .where('userId', isEqualTo: userId)
        .get(const GetOptions(source: Source.server));
  }
}
