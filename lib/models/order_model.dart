import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  pending,
  confirmed,
  shipped,
  delivered,
  cancelled,
  returned,
}

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.returned:
        return 'Returned';
    }
  }

  String get firestoreValue {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.shipped:
        return 'shipped';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.returned:
        return 'returned';
    }
  }

  static OrderStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'shipped':
        return OrderStatus.shipped;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'returned':
        return OrderStatus.returned;
      default:
        return OrderStatus.pending;
    }
  }
}

class OrderModel {
  final String id;
  final String userId;
  final List<OrderItem> items;
  final double totalAmount;
  final OrderStatus status;
  final String paymentMethod; // Always 'COD' for now
  final AddressModel address;
  final DateTime orderedAt;
  final DateTime? deliveredAt;
  final String? trackingNumber;

  OrderModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalAmount,
    this.status = OrderStatus.pending,
    this.paymentMethod = 'COD',
    required this.address,
    required this.orderedAt,
    this.deliveredAt,
    this.trackingNumber,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((i) => OrderItem.fromMap(i))
              .toList() ??
          [],
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      status: OrderStatusExtension.fromString(data['status'] ?? 'pending'),
      paymentMethod: data['paymentMethod'] ?? 'COD',
      address: AddressModel.fromMap(data['address'] ?? {}),
      orderedAt:
          (data['orderedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      trackingNumber: data['trackingNumber'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'items': items.map((i) => i.toMap()).toList(),
      'totalAmount': totalAmount,
      'status': status.firestoreValue,
      'paymentMethod': paymentMethod,
      'address': address.toMap(),
      'orderedAt': Timestamp.fromDate(orderedAt),
      'deliveredAt':
          deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'trackingNumber': trackingNumber,
    };
  }
}

class OrderItem {
  final String productId;
  final String? variationId;
  final String productName;
  final String productImage;
  final Map<String, String> selectedAttributes; // e.g. {"Color": "Red"}
  final int quantity;
  final double price; // Price at time of purchase
  final int warrantyMonths; // Warranty at time of purchase

  OrderItem({
    required this.productId,
    this.variationId,
    required this.productName,
    required this.productImage,
    required this.selectedAttributes,
    required this.quantity,
    required this.price,
    required this.warrantyMonths,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      variationId: map['variationId'],
      productName: map['productName'] ?? '',
      productImage: map['productImage'] ?? '',
      selectedAttributes:
          Map<String, String>.from(map['selectedAttributes'] ?? {}),
      quantity: map['quantity'] ?? 1,
      price: (map['price'] ?? 0).toDouble(),
      warrantyMonths: map['warrantyMonths'] ?? 12,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'variationId': variationId,
      'productName': productName,
      'productImage': productImage,
      'selectedAttributes': selectedAttributes,
      'quantity': quantity,
      'price': price,
      'warrantyMonths': warrantyMonths,
    };
  }
}

class AddressModel {
  final String name;
  final String phone;
  final String street;
  final String city;
  final String state;
  final String pincode;
  final String type; // Home, Work

  AddressModel({
    required this.name,
    required this.phone,
    required this.street,
    required this.city,
    required this.state,
    required this.pincode,
    this.type = 'Home',
  });

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      street: map['street'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      pincode: map['pincode'] ?? '',
      type: map['type'] ?? 'Home',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'street': street,
      'city': city,
      'state': state,
      'pincode': pincode,
      'type': type,
    };
  }
}
