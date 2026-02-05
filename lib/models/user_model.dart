import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String? phone;
  final String referralCode;
  final double totalEarnings;
  final double pendingPayout;
  final bool isAdmin;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final int digitalCoins;

  UserModel({
    required this.id,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.phone,
    required this.referralCode,
    this.totalEarnings = 0.0,
    this.pendingPayout = 0.0,
    this.isAdmin = false,
    required this.createdAt,
    this.lastLoginAt,
    this.digitalCoins = 0,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      phone: data['phone'],
      referralCode: data['referralCode'] ?? '',
      totalEarnings: (data['totalEarnings'] ?? 0).toDouble(),
      pendingPayout: (data['pendingPayout'] ?? 0).toDouble(),
      isAdmin: data['isAdmin'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      digitalCoins: data['digitalCoins'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'phone': phone,
      'referralCode': referralCode,
      'totalEarnings': totalEarnings,
      'pendingPayout': pendingPayout,
      'isAdmin': isAdmin,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt':
          lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
    };
  }

  UserModel copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    String? phone,
    String? referralCode,
    double? totalEarnings,
    double? pendingPayout,
    bool? isAdmin,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
      referralCode: referralCode ?? this.referralCode,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      pendingPayout: pendingPayout ?? this.pendingPayout,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  static String generateReferralCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return 'VG-${String.fromCharCodes(List.generate(4, (i) => chars.codeUnitAt((random + i * 7) % chars.length)))}';
  }
}
