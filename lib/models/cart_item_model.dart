import 'catalog_product_model.dart';

class CartItemModel {
  final CatalogProductModel product;
  final ProductVariation? variation;
  int quantity;

  CartItemModel({required this.product, this.variation, this.quantity = 1});

  double get price =>
      variation?.offerPrice ??
      variation?.price ??
      product.offerPrice ??
      product.basePrice;

  double get totalPrice => price * quantity;

  String get variationText {
    if (variation == null) return '';
    return variation!.attributes.entries.map((e) => e.value).join(', ');
  }
}
