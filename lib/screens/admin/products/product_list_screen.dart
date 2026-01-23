import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../app/theme.dart';
import '../../../models/catalog_product_model.dart';
import '../../../services/firestore_service.dart';
import '../../../widgets/common/premium_widgets.dart';

class AdminProductListScreen extends StatefulWidget {
  const AdminProductListScreen({super.key});

  @override
  State<AdminProductListScreen> createState() => _AdminProductListScreenState();
}

class _AdminProductListScreenState extends State<AdminProductListScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Premium Header
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _headerController,
                  child: _buildHeader(context),
                ),
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search products...',
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: AppTheme.primary),
                      ),
                    ),
                  ),
                ),
              ),

              // Product Grid
              StreamBuilder<List<CatalogProductModel>>(
                stream: firestoreService.getAdminCatalogProducts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  var products = snapshot.data ?? [];

                  // Filter locally for smoother experience
                  if (_searchQuery.isNotEmpty) {
                    final query = _searchQuery.toLowerCase();
                    products = products.where((p) {
                      return p.name.toLowerCase().contains(query) ||
                          p.brand.toLowerCase().contains(query);
                    }).toList();
                  }

                  if (products.isEmpty) {
                    return SliverFillRemaining(
                        child: _buildEmptyState(context));
                  }

                  return SliverPadding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 0, 20, 100), // Bottom padding for FAB
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return StaggeredFadeIn(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildProductCard(
                                  context, products[index], firestoreService),
                            ),
                          );
                        },
                        childCount: products.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          // Floating Action Button
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton.extended(
              onPressed: () => context.pushNamed('admin-add-product'),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 24),
      decoration: BoxDecoration(
        gradient: AppTheme.adminGradient,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(15),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Product Catalog',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: Text(
                    'Manage your inventory and products',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withAlpha(200),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined,
                size: 48, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'No Products Found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search'
                : 'Add your first product to the catalog',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryLight,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, CatalogProductModel product,
      FirestoreService firestoreService) {
    return PremiumCard(
      onTap: () => context.pushNamed('admin-edit-product', extra: product),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: product.images.isNotEmpty
                  ? product.images.first
                  : 'https://via.placeholder.com/150', // Placeholder
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: AppTheme.backgroundLight,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppTheme.backgroundLight,
                child: const Icon(Icons.image_not_supported),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _StatusChip(isActive: product.isActive),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${product.basePrice.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.category,
                        size: 14, color: AppTheme.textSecondaryLight),
                    const SizedBox(width: 4),
                    Text(
                      product.categoryId, // Should map to readable name ideally
                      style: Theme.of(context).textTheme.caption?.copyWith(
                            color: AppTheme.textSecondaryLight,
                          ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.layers,
                        size: 14, color: AppTheme.textSecondaryLight),
                    const SizedBox(width: 4),
                    Text(
                      '${product.variations.length} Variants',
                      style: Theme.of(context).textTheme.caption?.copyWith(
                            color: AppTheme.textSecondaryLight,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isActive;

  const _StatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.success.withAlpha(30)
            : AppTheme.error.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: isActive ? AppTheme.success : AppTheme.error,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
