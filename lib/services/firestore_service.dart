import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../models/service_request_model.dart';
import '../models/referral_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user by ID
  Future<UserModel?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.exists ? UserModel.fromFirestore(doc) : null;
  }

  // ============== PRODUCTS ==============

  // Stream of user's products
  Stream<List<ProductModel>> getUserProducts(String userId) {
    return _firestore
        .collection('products')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) {
            final docs = snapshot.docs
                .map((doc) => ProductModel.fromFirestore(doc))
                .toList();
            docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return docs;
          },
        );
  }

  // Add a new product
  Future<String> addProduct(ProductModel product) async {
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
    await _firestore.collection('products').doc(productId).update({
      'status': status.firestoreValue,
      'validatedBy': validatedBy,
      'validatedAt': status == ProductStatus.active ? Timestamp.now() : null,
      'rejectionReason': rejectionReason,
    });
  }

  // Get products pending validation (admin)
  Stream<List<ProductModel>> getPendingProducts() {
    return _firestore
        .collection('products')
        .where('status', isEqualTo: 'pending_validation')
        .snapshots()
        .map(
          (snapshot) {
            final docs = snapshot.docs
                .map((doc) => ProductModel.fromFirestore(doc))
                .toList();
            docs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            return docs;
          },
        );
  }

  // Get all products (admin)
  Stream<List<ProductModel>> getAllProducts() {
    return _firestore
        .collection('products')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProductModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get single product
  Future<ProductModel?> getProduct(String productId) async {
    final doc = await _firestore.collection('products').doc(productId).get();
    return doc.exists ? ProductModel.fromFirestore(doc) : null;
  }

  // ============== SERVICE REQUESTS ==============

  // Stream of user's service requests
  Stream<List<ServiceRequestModel>> getUserServiceRequests(String userId) {
    return _firestore
        .collection('service_requests')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) {
            final docs = snapshot.docs
                .map((doc) => ServiceRequestModel.fromFirestore(doc))
                .toList();
            docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return docs;
          },
        );
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
    String? resolutionNotes,
  }) async {
    final updates = <String, dynamic>{'status': status.firestoreValue};

    if (assignedProvider != null)
      updates['assignedProvider'] = assignedProvider;
    if (technicianName != null) updates['technicianName'] = technicianName;
    if (resolutionNotes != null) updates['resolutionNotes'] = resolutionNotes;

    if (status == ServiceRequestStatus.assigned) {
      updates['assignedAt'] = Timestamp.now();
    } else if (status == ServiceRequestStatus.resolved) {
      updates['resolvedAt'] = Timestamp.now();
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
      final docs = snapshot.docs
          .map((doc) => ServiceRequestModel.fromFirestore(doc))
          .toList();
      docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return docs;
    });
  }

  // Get single service request
  Future<ServiceRequestModel?> getServiceRequest(String requestId) async {
    final doc = await _firestore
        .collection('service_requests')
        .doc(requestId)
        .get();
    return doc.exists ? ServiceRequestModel.fromFirestore(doc) : null;
  }

  // Get pending service requests count
  Future<int> getPendingRequestsCount() async {
    final snapshot = await _firestore
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
        .map(
          (snapshot) {
            final docs = snapshot.docs
                .map((doc) => ReferralModel.fromFirestore(doc))
                .toList();
            docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return docs;
          },
        );
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
    final referral = await _firestore
        .collection('referrals')
        .doc(referralId)
        .get();
    final referrerId = referral.data()?['referrerId'];
    if (referrerId != null) {
      await _firestore.collection('users').doc(referrerId).update({
        'pendingPayout': FieldValue.increment(commission),
      });
    }
  }

  // Mark referral as paid (admin)
  Future<void> markReferralPaid(String referralId) async {
    final referral = await _firestore
        .collection('referrals')
        .doc(referralId)
        .get();
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
    final pendingReferrals = await _firestore
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
  }) async {
    final updates = <String, dynamic>{
      'displayName': displayName,
      'lastLoginAt': Timestamp.now(),
    };
    if (email != null && email.isNotEmpty) {
      updates['email'] = email;
    }
    await _firestore.collection('users').doc(userId).update(updates);
  }

  // ============== DASHBOARD STATS (Admin) ==============

  Future<Map<String, dynamic>> getDashboardStats() async {
    final pendingRequests = await _firestore
        .collection('service_requests')
        .where('status', isEqualTo: 'pending')
        .count()
        .get();

    final pendingRegistrations = await _firestore
        .collection('products')
        .where('status', isEqualTo: 'pending_validation')
        .count()
        .get();

    final totalUsers = await _firestore.collection('users').count().get();

    final usersWithPayouts = await _firestore
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
    final snapshot = await _firestore
        .collection('users')
        .where('referralCode', isEqualTo: code)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return UserModel.fromFirestore(snapshot.docs.first);
    }
    return null;
  }
}
