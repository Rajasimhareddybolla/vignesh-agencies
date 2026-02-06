import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/cart_item_model.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Place a new order with stock validation
  /// Uses Firestore transaction to ensure atomicity
  Future<String> placeOrder({
    required String userId,
    required List<CartItemModel> cartItems,
    required double totalAmount,
    required AddressModel address,
    String paymentMethod = 'COD',
    double shippingFee = 0.0,
  }) async {
    // Use transaction to validate stock and create order atomically
    return await _firestore.runTransaction<String>((transaction) async {
      // Step 1: Validate stock for all items
      final productDocs = <String, DocumentSnapshot>{};
      
      for (final item in cartItems) {
        final productRef = _firestore.collection('catalog_products').doc(item.product.id);
        final productDoc = await transaction.get(productRef);
        productDocs[item.product.id] = productDoc;
        
        if (!productDoc.exists) {
          throw Exception('${item.product.name} is no longer available');
        }
        
        final data = productDoc.data() as Map<String, dynamic>;
        final isActive = data['isActive'] ?? true;
        final trackInventory = data['trackInventory'] ?? true;
        final stockQuantity = data['stockQuantity'] ?? 0;
        
        if (!isActive) {
          throw Exception('${item.product.name} is no longer available');
        }
        
        if (trackInventory && stockQuantity < item.quantity) {
          if (stockQuantity <= 0) {
            throw Exception('${item.product.name} is out of stock');
          } else {
            throw Exception('Only $stockQuantity units of ${item.product.name} available');
          }
        }
      }
      
      // Step 2: Decrement stock for all items
      for (final item in cartItems) {
        final productDoc = productDocs[item.product.id]!;
        final data = productDoc.data() as Map<String, dynamic>;
        final trackInventory = data['trackInventory'] ?? true;
        
        if (trackInventory) {
          final productRef = _firestore.collection('catalog_products').doc(item.product.id);
          transaction.update(productRef, {
            'stockQuantity': FieldValue.increment(-item.quantity),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      
      // Step 3: Create order items
      final orderItems = cartItems.map((item) {
        return OrderItem(
          productId: item.product.id,
          variationId: item.variation?.id,
          productName: item.product.name,
          productImage: item.product.images.isNotEmpty ? item.product.images.first : '',
          category: item.product.categoryId,
          selectedAttributes: item.variation?.attributes ?? {},
          quantity: item.quantity,
          price: item.price,
          warrantyMonths: item.product.warrantyMonths,
          sku: item.variation?.sku,
        );
      }).toList();

      // Step 4: Create order
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
        version: 1,
        shippingFee: shippingFee,
      );

      transaction.set(orderRef, order.toFirestore());
      return orderRef.id;
    });
  }

  /// Validate cart items without placing order
  /// Returns a map of productId -> error message for items with issues
  Future<Map<String, String>> validateCart(List<CartItemModel> cartItems) async {
    final issues = <String, String>{};
    
    for (final item in cartItems) {
      final productDoc = await _firestore
          .collection('catalog_products')
          .doc(item.product.id)
          .get();
      
      if (!productDoc.exists) {
        issues[item.product.id] = '${item.product.name} is no longer available';
        continue;
      }
      
      final data = productDoc.data()!;
      final isActive = data['isActive'] ?? true;
      final trackInventory = data['trackInventory'] ?? true;
      final stockQuantity = data['stockQuantity'] ?? 0;
      final currentPrice = data['offerPrice']?.toDouble() ?? data['basePrice']?.toDouble() ?? 0;
      
      if (!isActive) {
        issues[item.product.id] = '${item.product.name} is no longer available';
      } else if (trackInventory && stockQuantity < item.quantity) {
        if (stockQuantity <= 0) {
          issues[item.product.id] = '${item.product.name} is out of stock';
        } else {
          issues[item.product.id] = 'Only $stockQuantity units of ${item.product.name} available';
        }
      }
      
      // Check if price has changed significantly (more than 1 rupee difference)
      if ((currentPrice - item.price).abs() > 1) {
        issues['${item.product.id}_price'] = 'Price of ${item.product.name} has changed from ₹${item.price.toStringAsFixed(0)} to ₹${currentPrice.toStringAsFixed(0)}';
      }
    }
    
    return issues;
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
