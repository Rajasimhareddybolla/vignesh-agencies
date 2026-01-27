import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/cart_item_model.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Place a new order
  Future<String> placeOrder({
    required String userId,
    required List<CartItemModel> cartItems,
    required double totalAmount,
    required AddressModel address,
    String paymentMethod = 'COD',
  }) async {
    try {
      // Convert CartItems to OrderItems
      final orderItems =
          cartItems.map((item) {
            return OrderItem(
              productId: item.product.id,
              variationId: item.variation?.id,
              productName: item.product.name,
              productImage:
                  item.product.images.isNotEmpty
                      ? item.product.images.first
                      : '',
              selectedAttributes: item.variation?.attributes ?? {},
              quantity: item.quantity,
              price: item.price,
              warrantyMonths: item.product.warrantyMonths,
              sku: item.variation?.sku,
            );
          }).toList();

      final orderRef = _firestore.collection('orders').doc();

      final order = OrderModel(
        id: orderRef.id,
        userId: userId,
        items: orderItems,
        totalAmount: totalAmount,
        status: OrderStatus.pending,
        address: address,
        orderedAt: DateTime.now(),
        paymentMethod: paymentMethod,
      );

      await orderRef.set(order.toFirestore());
      return orderRef.id;
    } catch (e) {
      throw Exception('Failed to place order: $e');
    }
  }

  // Get user orders stream
  Stream<List<OrderModel>> getUserOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('orderedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList();
        });
  }

  // Get single order
  Future<OrderModel?> getOrder(String orderId) async {
    final doc = await _firestore.collection('orders').doc(orderId).get();
    if (doc.exists) {
      return OrderModel.fromFirestore(doc);
    }
    return null;
  }
}
