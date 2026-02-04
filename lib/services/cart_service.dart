import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/catalog_product_model.dart';
import '../models/cart_item_model.dart';

class CartService extends ChangeNotifier {
  final List<CartItemModel> _items = [];
  String? _userId;
  bool _isLoading = false;

  List<CartItemModel> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;

  double get totalAmount =>
      _items.fold(0, (sum, item) => sum + item.totalPrice);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  /// Initialize cart for a user - loads persisted cart from Firestore
  Future<void> initializeCart(String userId) async {
    if (_userId == userId && _items.isNotEmpty) return; // Already initialized
    
    _userId = userId;
    _isLoading = true;
    notifyListeners();
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('carts')
          .doc(userId)
          .get();
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final itemsJson = data['items'] as List<dynamic>? ?? [];
        
        _items.clear();
        for (final itemJson in itemsJson) {
          try {
            final item = _cartItemFromJson(itemJson as Map<String, dynamic>);
            if (item != null) {
              _items.add(item);
            }
          } catch (e) {
            debugPrint('Error parsing cart item: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }

  /// Clear user context (call on logout)
  void clearUserContext() {
    _userId = null;
    _items.clear();
    notifyListeners();
  }

  void addToCart(
    CatalogProductModel product, {
    ProductVariation? variation,
    int quantity = 1,
  }) {
    // Check stock availability before adding
    final maxStock = _getMaxStock(product, variation);
    
    // Check if item already exists
    final index = _items.indexWhere(
      (item) =>
          item.product.id == product.id && item.variation?.id == variation?.id,
    );

    if (index >= 0) {
      // Check if adding more would exceed stock
      final newQuantity = _items[index].quantity + quantity;
      if (product.trackInventory && newQuantity > maxStock) {
        // Limit to max available stock
        _items[index].quantity = maxStock;
      } else {
        _items[index].quantity += quantity;
      }
    } else {
      // Limit initial quantity to stock if tracking
      final limitedQty = product.trackInventory && quantity > maxStock 
          ? maxStock 
          : quantity;
      
      if (limitedQty > 0) {
        _items.add(
          CartItemModel(
            product: product,
            variation: variation,
            quantity: limitedQty,
          ),
        );
      }
    }
    notifyListeners();
    _persistCart();
  }

  /// Gets the maximum stock available for a product/variation
  int _getMaxStock(CatalogProductModel product, ProductVariation? variation) {
    if (variation != null) {
      return variation.stockQuantity;
    }
    return product.stockQuantity;
  }

  /// Checks if a product is in stock
  bool isProductInStock(CatalogProductModel product, ProductVariation? variation) {
    if (!product.trackInventory) return true;
    if (variation != null) {
      return variation.isInStock;
    }
    return product.isInStock;
  }

  /// Gets available stock for a cart item
  int getAvailableStock(CartItemModel item) {
    if (!item.product.trackInventory) return 999; // No limit
    return _getMaxStock(item.product, item.variation);
  }

  void removeFromCart(CartItemModel item) {
    _items.remove(item);
    notifyListeners();
    _persistCart();
  }

  void updateQuantity(CartItemModel item, int newQuantity) {
    if (newQuantity <= 0) {
      removeFromCart(item);
      return;
    }
    
    // Respect stock limits
    final maxStock = getAvailableStock(item);
    item.quantity = item.product.trackInventory && newQuantity > maxStock 
        ? maxStock 
        : newQuantity;
    
    notifyListeners();
    _persistCart();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
    _persistCart();
  }

  /// Persist cart to Firestore
  Future<void> _persistCart() async {
    if (_userId == null) return;
    
    try {
      final itemsJson = _items.map((item) => _cartItemToJson(item)).toList();
      
      await FirebaseFirestore.instance
          .collection('carts')
          .doc(_userId)
          .set({
            'items': itemsJson,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error persisting cart: $e');
    }
  }

  /// Convert CartItemModel to JSON for storage
  Map<String, dynamic> _cartItemToJson(CartItemModel item) {
    return {
      'product': {
        'id': item.product.id,
        'name': item.product.name,
        'description': item.product.description,
        'categoryId': item.product.categoryId,
        'basePrice': item.product.basePrice,
        'images': item.product.images,
        'brand': item.product.brand,
        'isActive': item.product.isActive,
        'rating': item.product.rating,
        'reviewCount': item.product.reviewCount,
        'specifications': item.product.specifications,
        'highlights': item.product.highlights,
        'warrantyMonths': item.product.warrantyMonths,
        'createdAt': item.product.createdAt.millisecondsSinceEpoch,
        'updatedAt': item.product.updatedAt.millisecondsSinceEpoch,
        'offerPrice': item.product.offerPrice,
        'stockQuantity': item.product.stockQuantity,
        'lowStockThreshold': item.product.lowStockThreshold,
        'trackInventory': item.product.trackInventory,
        'estimatedDeliveryDays': item.product.estimatedDeliveryDays,
        'variations': item.product.variations.map((v) => {
          'id': v.id,
          'attributes': v.attributes,
          'price': v.price,
          'offerPrice': v.offerPrice,
          'warrantyMonths': v.warrantyMonths,
          'sku': v.sku,
          'stockQuantity': v.stockQuantity,
        }).toList(),
      },
      'variation': item.variation != null ? {
        'id': item.variation!.id,
        'attributes': item.variation!.attributes,
        'price': item.variation!.price,
        'offerPrice': item.variation!.offerPrice,
        'warrantyMonths': item.variation!.warrantyMonths,
        'sku': item.variation!.sku,
        'stockQuantity': item.variation!.stockQuantity,
      } : null,
      'quantity': item.quantity,
    };
  }

  /// Convert JSON to CartItemModel
  CartItemModel? _cartItemFromJson(Map<String, dynamic> json) {
    try {
      final productJson = json['product'] as Map<String, dynamic>;
      
      List<ProductVariation> variations = [];
      if (productJson['variations'] != null) {
        variations = (productJson['variations'] as List<dynamic>)
            .map((v) => ProductVariation(
                  id: v['id'] ?? '',
                  attributes: Map<String, String>.from(v['attributes'] ?? {}),
                  price: (v['price'] as num?)?.toDouble() ?? 0,
                  offerPrice: (v['offerPrice'] as num?)?.toDouble(),
                  warrantyMonths: v['warrantyMonths'] as int?,
                  sku: v['sku'] as String?,
                  stockQuantity: v['stockQuantity'] as int? ?? 0,
                ))
            .toList();
      }
      
      final product = CatalogProductModel(
        id: productJson['id'] ?? '',
        name: productJson['name'] ?? '',
        description: productJson['description'] ?? '',
        categoryId: productJson['categoryId'] ?? '',
        basePrice: (productJson['basePrice'] as num?)?.toDouble() ?? 0,
        images: List<String>.from(productJson['images'] ?? []),
        brand: productJson['brand'] ?? 'V-Guard',
        isActive: productJson['isActive'] ?? true,
        rating: (productJson['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: productJson['reviewCount'] as int? ?? 0,
        specifications: Map<String, String>.from(productJson['specifications'] ?? {}),
        highlights: List<String>.from(productJson['highlights'] ?? []),
        warrantyMonths: productJson['warrantyMonths'] as int? ?? 12,
        createdAt: DateTime.fromMillisecondsSinceEpoch(productJson['createdAt'] ?? 0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(productJson['updatedAt'] ?? 0),
        offerPrice: (productJson['offerPrice'] as num?)?.toDouble(),
        stockQuantity: productJson['stockQuantity'] as int? ?? 0,
        lowStockThreshold: productJson['lowStockThreshold'] as int? ?? 5,
        trackInventory: productJson['trackInventory'] as bool? ?? false,
        estimatedDeliveryDays: productJson['estimatedDeliveryDays'] as int? ?? 3,
        variations: variations,
      );
      
      ProductVariation? variation;
      if (json['variation'] != null) {
        final varJson = json['variation'] as Map<String, dynamic>;
        variation = ProductVariation(
          id: varJson['id'] ?? '',
          attributes: Map<String, String>.from(varJson['attributes'] ?? {}),
          price: (varJson['price'] as num?)?.toDouble() ?? 0,
          offerPrice: (varJson['offerPrice'] as num?)?.toDouble(),
          warrantyMonths: varJson['warrantyMonths'] as int?,
          sku: varJson['sku'] as String?,
          stockQuantity: varJson['stockQuantity'] as int? ?? 0,
        );
      }
      
      return CartItemModel(
        product: product,
        variation: variation,
        quantity: json['quantity'] as int? ?? 1,
      );
    } catch (e) {
      debugPrint('Error parsing cart item from JSON: $e');
      return null;
    }
  }
}
