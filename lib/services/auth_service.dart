import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/referral_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache for admin status to avoid repeated Firestore calls
  bool? _cachedIsAdmin;
  String? _cachedAdminUserId;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  String? get resolvedUserId {
    // If not logged in
    if (currentUser == null) return null;

    // NOTE: This property doesn't resolve linked IDs synchronously
    // because we can't await here.
    // For writes, you should use (await authService.getResolvedUserId()) ?? currentUser.uid
    return currentUser!.uid;
  }

  // Get the TRUE User ID (resolving linked accounts)
  Future<String> getResolvedUserId() async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated');

    // First, check if we've already resolved it in memory?
    // Ideally we fetch from DB or check a cache.
    // Since this is critical for writes, we'll fetch the document to be safe
    // or rely on userModel if already loaded.

    // Fast path: Check the stream first if we can? No, stream is separate.

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null &&
          data.containsKey('linkedAccountId') &&
          data['linkedAccountId'] != null) {
        return data['linkedAccountId'] as String;
      }
    }
    return user.uid;
  }

  // Phone Auth - Send OTP
  // Set to true for testing (uses 123456 as OTP), false for production (real SMS)
  static const bool testMode = true; // 👈 TEST MODE ENABLED

  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerify,
  }) async {
    // Test mode - skip Firebase and use bypass flow
    if (testMode) {
      // Simulate a small delay then trigger codeSent with test verificationId
      await Future.delayed(const Duration(milliseconds: 500));
      onCodeSent('test-verification-id');
      return;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 120), // Increased timeout
        verificationCompleted: (PhoneAuthCredential credential) async {
          onAutoVerify(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          // Better error messages
          String errorMsg = e.message ?? 'Verification failed';
          if (e.code == 'too-many-requests' || errorMsg.contains('blocked')) {
            errorMsg = 'Too many attempts. Please try again in a few hours.';
          } else if (e.code == 'invalid-phone-number') {
            errorMsg = 'Invalid phone number format.';
          } else if (errorMsg.contains('BILLING')) {
            errorMsg = 'Service unavailable. Please contact support.';
          }
          onError(errorMsg);
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Auto-retrieval timeout - this is normal, no action needed
        },
      );
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('blocked') || errorMsg.contains('unusual')) {
        errorMsg = 'Too many attempts. Please try again later.';
      }
      onError(errorMsg);
    }
  }

  // Phone Auth - Verify OTP
  Future<UserCredential?> verifyOTP({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      final userCredential = await _auth.signInWithCredential(credential);

      // Create or update user document
      if (userCredential.user != null) {
        await _createOrUpdateUser(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with credential (for Android auto-verification)
  Future<UserCredential?> signInWithCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _createOrUpdateUser(userCredential.user!);
      }
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Bypass OTP verification - accepts 123456 for any phone number
  // This creates a custom user session without Firebase Phone Auth
  Future<bool> bypassOTPVerification({
    required String phoneNumber,
    required String otp,
  }) async {
    // Only accept 123456 as valid OTP
    if (otp != '123456') {
      return false;
    }

    try {
      // Sign in anonymously FIRST to get permissions
      final userCredential = await _auth.signInAnonymously();

      if (userCredential.user == null) {
        return false;
      }

      final uid = userCredential.user!.uid;

      // Check if user document exists for this phone number
      // We search for ALL users with this phone number to find the "original" one.
      final existingUserQuery =
          await _firestore
              .collection('users')
              .where('phone', isEqualTo: phoneNumber)
              .get();

      if (existingUserQuery.docs.isNotEmpty) {
        String? targetUserId;

        // Find the best candidate:
        // 1. Must NOT be a proxy/linked account itself
        // 2. Prefer the one created earliest (original)

        final candidates =
            existingUserQuery.docs.where((doc) {
              final data = doc.data();
              // Exclude if it has linkedAccountId
              return !data.containsKey('linkedAccountId');
            }).toList();

        if (candidates.isNotEmpty) {
          // Sort by createdAt just in case to find the oldest
          candidates.sort((a, b) {
            final aTime =
                (a.data()['createdAt'] as Timestamp?)?.toDate() ??
                DateTime.now();
            final bTime =
                (b.data()['createdAt'] as Timestamp?)?.toDate() ??
                DateTime.now();
            return aTime.compareTo(bTime);
          });
          targetUserId = candidates.first.id;
        } else {
          // Fallback: verification found users but they are all proxies?
          // This is weird. Pick the first one from the original query as a fallback.
          // Or maybe we should just create a new one? No, let's link to the first one found.
          targetUserId = existingUserQuery.docs.first.id;
        }

        if (targetUserId != null) {
          // Link our current session to this target user ID
          await _firestore.collection('users').doc(uid).set({
            'linkedAccountId': targetUserId,
            'phone': phoneNumber,
            'lastLoginAt': Timestamp.now(),
            'isProxy': true,
          }, SetOptions(merge: true));

          // Update target user's last login
          await _firestore.collection('users').doc(targetUserId).update({
            'lastLoginAt': Timestamp.now(),
          });
        }
      } else {
        // No existing user found. Create a new one at the current UID.

        // NOW check if user document exists for this anonymous user (unlikely unless reused)
        final userDoc = await _firestore.collection('users').doc(uid).get();

        if (!userDoc.exists) {
          // Create new user document
          final newUser = UserModel(
            id: uid,
            displayName: 'User',
            email: '',
            phone: phoneNumber,
            referralCode: UserModel.generateReferralCode(),
            isAdmin: false,
            createdAt: DateTime.now(),
            lastLoginAt: DateTime.now(),
          );
          await _firestore
              .collection('users')
              .doc(uid)
              .set(newUser.toFirestore());
        } else {
          // Update existing user's last login
          await _firestore.collection('users').doc(uid).update({
            'lastLoginAt': Timestamp.now(),
            'phone': phoneNumber,
          });
        }
      }

      return true;
    } catch (e) {
      print('Bypass OTP error: $e');
      return false;
    }
  }

  // Bypass admin login - creates admin session without Firebase Email Auth
  Future<bool> bypassAdminLogin() async {
    try {
      // Sign in anonymously
      final userCredential = await _auth.signInAnonymously();

      if (userCredential.user == null) {
        return false;
      }

      final uid = userCredential.user!.uid;

      // Create admin user document
      final adminUser = UserModel(
        id: uid,
        displayName: 'Vignesh Agencies Admin',
        email: 'admin@vigneshagencies.in',
        referralCode: 'VA-ADMIN',
        isAdmin: true,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(uid)
          .set(adminUser.toFirestore());

      return true;
    } catch (e) {
      print('Bypass admin login error: $e');
      return false;
    }
  }

  // Email/Password Sign In (for admins)
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Check if user document exists, if not create it as admin
        final userDoc =
            await _firestore
                .collection('users')
                .doc(userCredential.user!.uid)
                .get();

        if (!userDoc.exists) {
          // Auto-create admin document for email/password users
          final newAdmin = UserModel(
            id: userCredential.user!.uid,
            displayName: userCredential.user!.displayName ?? 'Admin',
            email: email,
            referralCode: 'VA-ADMIN',
            isAdmin: true,
            createdAt: DateTime.now(),
            lastLoginAt: DateTime.now(),
          );
          await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .set(newAdmin.toFirestore());
        } else {
          await _updateLastLogin(userCredential.user!.uid);
        }
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Email/Password Sign Up (for admins)
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(displayName);
        await _createOrUpdateUser(
          userCredential.user!,
          isAdmin: true,
          displayName: displayName,
        );
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Create or update user document in Firestore
  Future<void> _createOrUpdateUser(
    User firebaseUser, {
    bool isAdmin = false,
    String? displayName,
  }) async {
    final userRef = _firestore.collection('users').doc(firebaseUser.uid);
    final userDoc = await userRef.get();

    if (!userDoc.exists) {
      // Create new user document
      final newUser = UserModel(
        id: firebaseUser.uid,
        displayName: displayName ?? firebaseUser.displayName ?? 'User',
        email: firebaseUser.email ?? '',
        photoUrl: firebaseUser.photoURL,
        phone: firebaseUser.phoneNumber,
        referralCode: UserModel.generateReferralCode(),
        isAdmin: isAdmin,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );
      await userRef.set(newUser.toFirestore());
    } else {
      // Update last login
      await userRef.update({
        'lastLoginAt': Timestamp.now(),
        if (firebaseUser.phoneNumber != null) 'phone': firebaseUser.phoneNumber,
      });
    }
  }

  Future<void> _updateLastLogin(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'lastLoginAt': Timestamp.now(),
    });
  }

  // Get user model from Firestore
  Future<UserModel?> getUserModel() async {
    if (currentUser == null) return null;

    final doc =
        await _firestore.collection('users').doc(currentUser!.uid).get();
    if (doc.exists) {
      final data = doc.data();
      // Check for linked account (Bypass Mode)
      if (data != null && data.containsKey('linkedAccountId')) {
        final linkedId = data['linkedAccountId'];
        final linkedDoc =
            await _firestore.collection('users').doc(linkedId).get();
        if (linkedDoc.exists) {
          return UserModel.fromFirestore(linkedDoc);
        }
      }
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  // Stream of user model
  Stream<UserModel?> userModelStream() {
    if (currentUser == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .snapshots()
        .asyncMap((doc) async {
          if (!doc.exists) return null;

          final data = doc.data();
          // Check for linked account (Bypass Mode)
          if (data != null && data.containsKey('linkedAccountId')) {
            final linkedId = data['linkedAccountId'];
            final linkedDoc =
                await _firestore.collection('users').doc(linkedId).get();
            if (linkedDoc.exists) {
              return UserModel.fromFirestore(linkedDoc);
            }
          }

          return UserModel.fromFirestore(doc);
        });
  }

  // Check if current user is admin (with caching)
  Future<bool> isCurrentUserAdmin() async {
    final user = currentUser;
    if (user == null) return false;
    
    // Return cached value if available and for the same user
    if (_cachedIsAdmin != null && _cachedAdminUserId == user.uid) {
      return _cachedIsAdmin!;
    }
    
    // Fetch and cache admin status
    final userModel = await getUserModel();
    _cachedIsAdmin = userModel?.isAdmin ?? false;
    _cachedAdminUserId = user.uid;
    
    return _cachedIsAdmin!;
  }
  
  // Clear admin cache (call when user data might have changed)
  void clearAdminCache() {
    _cachedIsAdmin = null;
    _cachedAdminUserId = null;
  }

  // Sign out
  Future<void> signOut() async {
    // Clear cache on sign out
    _cachedIsAdmin = null;
    _cachedAdminUserId = null;
    await _auth.signOut();
  }

  // Password reset
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Update user profile
  Future<void> updateUserProfile({String? displayName, String? phone}) async {
    if (currentUser == null) return;

    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (phone != null) updates['phone'] = phone;

    if (updates.isNotEmpty) {
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .update(updates);
    }

    if (displayName != null) {
      await currentUser!.updateDisplayName(displayName);
    }
  }

  // Redeem Referral Code
  Future<void> redeemReferral(String code) async {
    final userId = await getResolvedUserId();
    final userDoc = await _firestore.collection('users').doc(userId).get();

    // Check if valid user
    if (!userDoc.exists) throw Exception('User not found');

    // Check if already redeemed
    final userData = userDoc.data()!;
    if (userData['referredBy'] != null) {
      throw Exception('You have already redeemed a referral code');
    }

    // Find referrer
    final referrerQuery =
        await _firestore
            .collection('users')
            .where('referralCode', isEqualTo: code)
            .limit(1)
            .get();

    if (referrerQuery.docs.isEmpty) {
      throw Exception('Invalid referral code');
    }

    final referrerDoc = referrerQuery.docs.first;
    if (referrerDoc.id == userId) {
      throw Exception('You cannot use your own referral code');
    }

    // Create Referral Record
    final referral = ReferralModel(
      id: '', // Generated by Firestore
      referrerId: referrerDoc.id,
      refereeId: userId,
      referralCode: code,
      status: ReferralStatus.pending,
      createdAt: DateTime.now(),
      refereeName: userData['displayName'],
      refereePhone: userData['phone'],
    );

    // Batch write for atomicity
    final batch = _firestore.batch();

    // 1. Create referral
    final referralRef = _firestore.collection('referrals').doc();
    batch.set(referralRef, referral.toFirestore());

    // 2. Update current user (referee)
    batch.update(userDoc.reference, {
      'referredBy': referrerDoc.id,
      'referralCodeUsed': code,
    });

    await batch.commit();
  }
}
