import 'package:cloud_firestore/cloud_firestore.dart';

enum ProductStatus {
  pendingValidation,
  active,
  expiringSoon,
  expired,
  rejected,
}

extension ProductStatusExtension on ProductStatus {
  String get displayName {
    switch (this) {
      case ProductStatus.pendingValidation:
        return 'Pending Validation';
      case ProductStatus.active:
        return 'Active Warranty';
      case ProductStatus.expiringSoon:
        return 'Expiring Soon';
      case ProductStatus.expired:
        return 'Warranty Expired';
      case ProductStatus.rejected:
        return 'Rejected';
    }
  }

  String get firestoreValue {
    switch (this) {
      case ProductStatus.pendingValidation:
        return 'pending_validation';
      case ProductStatus.active:
        return 'active';
      case ProductStatus.expiringSoon:
        return 'expiring_soon';
      case ProductStatus.expired:
        return 'expired';
      case ProductStatus.rejected:
        return 'rejected';
    }
  }

  static ProductStatus fromString(String value) {
    switch (value) {
      case 'pending_validation':
        return ProductStatus.pendingValidation;
      case 'active':
        return ProductStatus.active;
      case 'expiring_soon':
        return ProductStatus.expiringSoon;
      case 'expired':
        return ProductStatus.expired;
      case 'rejected':
        return ProductStatus.rejected;
      default:
        return ProductStatus.pendingValidation;
    }
  }
}

class UserApplianceModel {
  final String id;
  final String userId;
  final String category;
  final String productName;
  final String modelNumber;
  final String? serialNumber;
  final DateTime purchaseDate;
  final DateTime warrantyEndDate;
  final String? billImageUrl;
  final ProductStatus status;
  final String? validatedBy;
  final DateTime? validatedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final double? purchaseAmount;
  final String? storeLocation;
  final String? linkedOrderId;

  UserApplianceModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.productName,
    required this.modelNumber,
    this.serialNumber,
    required this.purchaseDate,
    required this.warrantyEndDate,
    this.billImageUrl,
    this.status = ProductStatus.pendingValidation,
    this.validatedBy,
    this.validatedAt,
    this.rejectionReason,
    required this.createdAt,
    this.purchaseAmount,
    this.storeLocation,
    this.linkedOrderId,
  });

  factory UserApplianceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserApplianceModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      category: data['category'] ?? '',
      productName: data['productName'] ?? '',
      modelNumber: data['modelNumber'] ?? '',
      serialNumber: data['serialNumber'],
      purchaseDate:
          (data['purchaseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      warrantyEndDate:
          (data['warrantyEndDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      billImageUrl: data['billImageUrl'],
      status: ProductStatusExtension.fromString(
        data['status'] ?? 'pending_validation',
      ),
      validatedBy: data['validatedBy'],
      validatedAt: (data['validatedAt'] as Timestamp?)?.toDate(),
      rejectionReason: data['rejectionReason'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      purchaseAmount: (data['purchaseAmount'] ?? 0).toDouble(),
      storeLocation: data['storeLocation'],
      linkedOrderId: data['linkedOrderId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'category': category,
      'productName': productName,
      'modelNumber': modelNumber,
      'serialNumber': serialNumber,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'warrantyEndDate': Timestamp.fromDate(warrantyEndDate),
      'billImageUrl': billImageUrl,
      'status': status.firestoreValue,
      'validatedBy': validatedBy,
      'validatedAt':
          validatedAt != null ? Timestamp.fromDate(validatedAt!) : null,
      'rejectionReason': rejectionReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'purchaseAmount': purchaseAmount,
      'storeLocation': storeLocation,
      'linkedOrderId': linkedOrderId,
    };
  }

  UserApplianceModel copyWith({
    String? category,
    String? productName,
    String? modelNumber,
    String? serialNumber,
    DateTime? purchaseDate,
    DateTime? warrantyEndDate,
    String? billImageUrl,
    ProductStatus? status,
    String? validatedBy,
    DateTime? validatedAt,
    String? rejectionReason,
    double? purchaseAmount,
    String? storeLocation,
    String? linkedOrderId,
  }) {
    return UserApplianceModel(
      id: id,
      userId: userId,
      category: category ?? this.category,
      productName: productName ?? this.productName,
      modelNumber: modelNumber ?? this.modelNumber,
      serialNumber: serialNumber ?? this.serialNumber,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      warrantyEndDate: warrantyEndDate ?? this.warrantyEndDate,
      billImageUrl: billImageUrl ?? this.billImageUrl,
      status: status ?? this.status,
      validatedBy: validatedBy ?? this.validatedBy,
      validatedAt: validatedAt ?? this.validatedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt,
      purchaseAmount: purchaseAmount ?? this.purchaseAmount,
      storeLocation: storeLocation ?? this.storeLocation,
      linkedOrderId: linkedOrderId ?? this.linkedOrderId,
    );
  }

  bool get isUnderWarranty {
    return DateTime.now().isBefore(warrantyEndDate) &&
        status == ProductStatus.active;
  }

  bool get isExpiringSoon {
    final daysUntilExpiry = warrantyEndDate.difference(DateTime.now()).inDays;
    return daysUntilExpiry > 0 &&
        daysUntilExpiry <= 30 &&
        status == ProductStatus.active;
  }

  int get daysUntilExpiry {
    return warrantyEndDate.difference(DateTime.now()).inDays;
  }

  // Product image assets (local) - Generic fallback
  static String getProductImage(String category) {
    // We can map some known ones if we want, or just return a default
    // User requested to remove "fan/oven" etc.
    // For now, let's keep a generic set or just one default.
    return 'assets/images/water_heater.png'; // Default placeholder
  }
}
