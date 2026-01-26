import 'package:flutter/foundation.dart';
import '../models/catalog_product_model.dart';
import '../models/cart_item_model.dart';

class CartService extends ChangeNotifier {
  final List<CartItemModel> _items = [];

  List<CartItemModel> get items => List.unmodifiable(_items);

  double get totalAmount =>
      _items.fold(0, (sum, item) => sum + item.totalPrice);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  void addToCart(
    CatalogProductModel product, {
    ProductVariation? variation,
    int quantity = 1,
  }) {
    // Check if item already exists
    final index = _items.indexWhere(
      (item) =>
          item.product.id == product.id && item.variation?.id == variation?.id,
    );

    if (index >= 0) {
      _items[index].quantity += quantity;
    } else {
      _items.add(
        CartItemModel(
          product: product,
          variation: variation,
          quantity: quantity,
        ),
      );
    }
    notifyListeners();
  }

  void removeFromCart(CartItemModel item) {
    _items.remove(item);
    notifyListeners();
  }

  void updateQuantity(CartItemModel item, int newQuantity) {
    if (newQuantity <= 0) {
      removeFromCart(item);
      return;
    }
    item.quantity = newQuantity;
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
