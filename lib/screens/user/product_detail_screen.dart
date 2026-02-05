import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/cart_service.dart';
import '../../app/theme.dart';
import '../../models/catalog_product_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/premium_widgets.dart';
import '../../widgets/user/checkout_sheet.dart'; // To be created

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final CatalogProductModel? product;

  const ProductDetailScreen({super.key, required this.productId, this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  CatalogProductModel? _product;
  bool _isLoading = true;
  int _currentImageIndex = 0;
  int _quantity = 1;

  // Selection State
  ProductVariation? _selectedVariation;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _product = widget.product;
      _isLoading = false;
      _initDefaultSelection();
    } else {
      _fetchProduct();
    }
  }

  void _initDefaultSelection() {
    if (_product != null && _product!.variations.isNotEmpty) {
      _selectedVariation = _product!.variations.first;
    }
  }

  Future<void> _fetchProduct() async {
    final service = context.read<FirestoreService>();
    final product = await service.getCatalogProduct(widget.productId);
    if (mounted) {
      setState(() {
        _product = product;
        _isLoading = false;
        _initDefaultSelection();
      });
    }
  }

  double get _currentPrice {
    if (_selectedVariation != null) {
      return _selectedVariation!.offerPrice ?? _selectedVariation!.price;
    }
    return _product?.offerPrice ?? _product?.basePrice ?? 0;
  }

  double? get _originalPrice {
    if (_selectedVariation != null) {
      // Only show if there is an offer price
      return _selectedVariation!.offerPrice != null
          ? _selectedVariation!.price
          : null;
    }
    return _product?.offerPrice != null ? _product?.basePrice : null;
  }

  /// Gets the current stock quantity based on selected variation or product
  int get _currentStock {
    if (_selectedVariation != null) {
      return _selectedVariation!.stockQuantity;
    }
    return _product?.stockQuantity ?? 0;
  }

  /// Checks if the current selection is in stock
  bool get _isCurrentInStock {
    if (_selectedVariation != null) {
      return _selectedVariation!.isInStock;
    }
    return _product?.isInStock ?? false;
  }

  /// Checks if the current selection is low stock
  bool get _isCurrentLowStock {
    if (_selectedVariation != null) {
      // Variation low stock check (stock > 0 but <= 5)
      return _selectedVariation!.stockQuantity > 0 &&
          _selectedVariation!.stockQuantity <= 5;
    }
    return _product?.isLowStock ?? false;
  }

  /// Gets the max quantity user can add
  int get _maxQuantity {
    if (_product?.trackInventory == false) return 99; // No limit
    return _currentStock > 0 ? _currentStock : 0;
  }

  void _handleBuyNow() {
    if (_product == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => CheckoutSheet(
            product: _product!,
            selectedVariation: _selectedVariation,
            price: _currentPrice,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Product not found')),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand & Title
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _product!.brand.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _product!.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),

                  // Ratings
                  const SizedBox(height: 12),

                  // Ratings removed as per requirement
                  /*
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '${_product!.rating} (${_product!.reviewCount} Reviews)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  */
                  const SizedBox(height: 24),
                  // Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${_currentPrice.toStringAsFixed(0)}',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_originalPrice != null) ...[
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '₹${_originalPrice!.toStringAsFixed(0)}',
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: AppTheme.textSecondary(context),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Stock Status Badge
                  const SizedBox(height: 16),
                  _buildStockStatusBadge(),

                  // Quantity Selector (only show if in stock)
                  if (_isCurrentInStock) ...[
                    const SizedBox(height: 20),
                    _buildQuantitySelector(),
                  ],

                  const SizedBox(height: 24),
                  // Variations (Simplified for now - just listing if any)
                  if (_product!.variations.isNotEmpty) ...[
                    const Text(
                      'Variations',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children:
                          _product!.variations.map((v) {
                            final isSelected = _selectedVariation?.id == v.id;
                            final label = v.attributes.values.join(' - ');
                            return ChoiceChip(
                              label: Text(label),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedVariation = v;
                                    // Reset quantity when variation changes
                                    _quantity = 1;
                                  });
                                }
                              },
                              selectedColor: AppTheme.primary.withAlpha(30),
                              labelStyle: TextStyle(
                                color:
                                    isSelected
                                        ? AppTheme.primary
                                        : Colors.black,
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Description
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _product!.description,
                    style: TextStyle(
                      color: AppTheme.textSecondary(context),
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Specifications
                  if (_product!.specifications.isNotEmpty) ...[
                    Text(
                      'Specifications',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderLight),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children:
                            _product!.specifications.entries.map((e) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppTheme.borderLight.withAlpha(
                                        100,
                                      ),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        e.key,
                                        style: TextStyle(
                                          color: AppTheme.textSecondary(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        e.value,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Highlights
                  if (_product!.highlights.isNotEmpty) ...[
                    Text(
                      'Highlights',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._product!.highlights.map(
                      (h) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: AppTheme.success,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(h)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 100), // Bottom padding for FAB
                  ],
                ],
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
      bottomNavigationBar: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          child:
              _isCurrentInStock
                  ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            if (_product != null) {
                              for (int i = 0; i < _quantity; i++) {
                                context.read<CartService>().addToCart(
                                  _product!,
                                  variation: _selectedVariation,
                                );
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _quantity == 1
                                        ? 'Added to Cart'
                                        : 'Added $_quantity items to Cart',
                                  ),
                                ),
                              );
                              // Reset quantity after adding
                              setState(() => _quantity = 1);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: AppTheme.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _quantity > 1
                                ? 'Add $_quantity to Cart'
                                : 'Add to Cart',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _handleBuyNow,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor: AppTheme.primary.withAlpha(100),
                          ),
                          child: const Text(
                            'Buy Now',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                  : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, color: Colors.grey),
                        SizedBox(height: 4),
                        Text(
                          'Currently Out of Stock',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'We\'ll notify you when available',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            CarouselSlider(
              options: CarouselOptions(
                height: 340, // Slightly more than expanded height to cover
                viewportFraction: 1.0,
                onPageChanged:
                    (index, reason) =>
                        setState(() => _currentImageIndex = index),
              ),
              items:
                  _product!.images.isNotEmpty
                      ? _product!.images
                          .map(
                            (url) => CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                          .toList()
                      : [
                        Container(
                          color: AppTheme.background(context),
                          child: const Center(
                            child: Icon(Icons.image, size: 50),
                          ),
                        ),
                      ],
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children:
                    _product!.images.asMap().entries.map((entry) {
                      return Container(
                        width: 8.0,
                        height: 8.0,
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(
                            _currentImageIndex == entry.key ? 0.9 : 0.4,
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Colors.white, // Opaque back button
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      actions: [
        // Cart Button with Badge
        Consumer<CartService>(
          builder: (context, cart, _) {
            return Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.shopping_cart_outlined,
                      color: Colors.black,
                    ),
                    onPressed: () => context.push('/cart'),
                  ),
                  if (cart.itemCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          '${cart.itemCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        // Share Button
        Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.black),
            onPressed: () {
              if (_product != null) {
                // TODO: Generate deep link
                Share.share(
                  'Check out ${_product!.name} on Vignesh Agencies! only for ₹${_currentPrice.toStringAsFixed(0)}\n\nhttps://vigneshagencies.in/product?id=${_product!.id}',
                );
              }
            },
          ),
        ),
      ],
    );
  }

  /// Builds the stock status badge
  Widget _buildStockStatusBadge() {
    if (!_product!.trackInventory) {
      // Not tracking inventory, show as available
      return _buildStatusContainer(
        icon: Icons.check_circle,
        color: AppTheme.success,
        text: 'In Stock',
      );
    }

    if (!_isCurrentInStock) {
      return _buildStatusContainer(
        icon: Icons.cancel,
        color: AppTheme.error,
        text: 'Out of Stock',
        subText: 'This item is currently unavailable',
      );
    }

    if (_isCurrentLowStock) {
      return _buildStatusContainer(
        icon: Icons.warning_amber,
        color: AppTheme.warning,
        text: 'Only $_currentStock left!',
        subText: 'Order soon before it\'s gone',
      );
    }

    return _buildStatusContainer(
      icon: Icons.check_circle,
      color: AppTheme.success,
      text: 'In Stock',
      subText:
          _product!.estimatedDeliveryDays > 0
              ? 'Delivery in ${_product!.estimatedDeliveryDays} days'
              : null,
    );
  }

  Widget _buildStatusContainer({
    required IconData icon,
    required Color color,
    required String text,
    String? subText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (subText != null) ...[
                const SizedBox(height: 2),
                Text(
                  subText,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the quantity selector widget
  Widget _buildQuantitySelector() {
    return Row(
      children: [
        Text(
          'Quantity',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary(context),
          ),
        ),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderLight),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _buildQuantityButton(
                icon: Icons.remove,
                onPressed:
                    _quantity > 1 ? () => setState(() => _quantity--) : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$_quantity',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              _buildQuantityButton(
                icon: Icons.add,
                onPressed:
                    _quantity < _maxQuantity
                        ? () => setState(() => _quantity++)
                        : null,
              ),
            ],
          ),
        ),
        if (_maxQuantity < 99 && _maxQuantity > 0) ...[
          const SizedBox(width: 12),
          Text(
            'Max: $_maxQuantity',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary(context),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 20,
          color:
              onPressed != null
                  ? AppTheme.primary
                  : AppTheme.textSecondary(context),
        ),
      ),
    );
  }
}
