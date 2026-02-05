import 'package:cloud_firestore/cloud_firestore.dart';

enum ReferralStatus { pending, approved, purchased, paid }

extension ReferralStatusExtension on ReferralStatus {
  String get displayName {
    switch (this) {
      case ReferralStatus.pending:
        return 'Pending';
      case ReferralStatus.approved:
        return 'Approved';
      case ReferralStatus.purchased:
        return 'Purchased';
      case ReferralStatus.paid:
        return 'Paid';
    }
  }

  String get firestoreValue {
    switch (this) {
      case ReferralStatus.pending:
        return 'pending';
      case ReferralStatus.approved:
        return 'approved';
      case ReferralStatus.purchased:
        return 'purchased';
      case ReferralStatus.paid:
        return 'paid';
    }
  }

  static ReferralStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return ReferralStatus.pending;
      case 'approved':
        return ReferralStatus.approved;
      case 'purchased':
        return ReferralStatus.purchased;
      case 'paid':
        return ReferralStatus.paid;
      default:
        return ReferralStatus.pending;
    }
  }
}

class ReferralModel {
  final String id;
  final String referrerId;
  final String refereeId;
  final String referralCode;
  final ReferralStatus status;
  final double commission;
  final double? purchaseAmount;
  final DateTime createdAt;
  final DateTime? purchasedAt;
  final DateTime? paidAt;

  // Referee details (denormalized)
  final String? refereeName;
  final String? refereePhone;

  // Phase 2: Admin Approval
  final bool adminApproved;
  final int rewardCoins;

  ReferralModel({
    required this.id,
    required this.referrerId,
    required this.refereeId,
    required this.referralCode,
    this.status = ReferralStatus.pending,
    this.commission = 0.0,
    this.purchaseAmount,
    required this.createdAt,
    this.purchasedAt,
    this.paidAt,
    this.refereeName,
    this.refereePhone,
    this.adminApproved = false,
    this.rewardCoins = 0,
  });

  factory ReferralModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReferralModel(
      id: doc.id,
      referrerId: data['referrerId'] ?? '',
      refereeId: data['refereeId'] ?? '',
      referralCode: data['referralCode'] ?? '',
      status: ReferralStatusExtension.fromString(data['status'] ?? 'pending'),
      commission: (data['commission'] ?? 0).toDouble(),
      purchaseAmount: (data['purchaseAmount'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      purchasedAt: (data['purchasedAt'] as Timestamp?)?.toDate(),
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
      refereeName: data['refereeName'],
      refereePhone: data['refereePhone'],
      adminApproved: data['adminApproved'] ?? false,
      rewardCoins: (data['rewardCoins'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'referrerId': referrerId,
      'refereeId': refereeId,
      'referralCode': referralCode,
      'status': status.firestoreValue,
      'commission': commission,
      'purchaseAmount': purchaseAmount,
      'createdAt': Timestamp.fromDate(createdAt),
      'purchasedAt':
          purchasedAt != null ? Timestamp.fromDate(purchasedAt!) : null,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'refereeName': refereeName,
      'refereePhone': refereePhone,
      'adminApproved': adminApproved,
      'rewardCoins': rewardCoins,
    };
  }

  ReferralModel copyWith({
    ReferralStatus? status,
    double? commission,
    double? purchaseAmount,
    DateTime? purchasedAt,
    DateTime? paidAt,
    String? refereeName,
    String? refereePhone,
  }) {
    return ReferralModel(
      id: id,
      referrerId: referrerId,
      refereeId: refereeId,
      referralCode: referralCode,
      status: status ?? this.status,
      commission: commission ?? this.commission,
      purchaseAmount: purchaseAmount ?? this.purchaseAmount,
      createdAt: createdAt,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      paidAt: paidAt ?? this.paidAt,
      refereeName: refereeName ?? this.refereeName,
      refereePhone: refereePhone ?? this.refereePhone,
    );
  }

  // Default commission rate (can be configured)
  static const double defaultCommissionRate = 0.05; // 5%
  static const double fixedCommission = 500.0; // ₹500 per referral
}
