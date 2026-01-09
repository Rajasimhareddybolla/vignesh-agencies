import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(child: _buildHeader(context, authService)),

          // Quick Actions
          SliverToBoxAdapter(child: _buildQuickActions(context)),

          // My Appliances Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Appliances',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.pushNamed('all-appliances'),
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),
          ),

          // Appliances List
          StreamBuilder<List<ProductModel>>(
            stream: authService.currentUser != null
                ? firestoreService.getUserProducts(authService.currentUser!.uid)
                : Stream.value([]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                );
              }

              final products = snapshot.data ?? [];

              if (products.isEmpty) {
                return SliverToBoxAdapter(child: _buildEmptyState(context));
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildApplianceCard(context, products[index]),
                    ),
                    childCount: products.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),

      // Floating Action Button
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.fabShadow,
        ),
        child: FloatingActionButton.large(
          onPressed: () => context.pushNamed('add-product'),
          backgroundColor: AppTheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.add, size: 32, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthService authService) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderLight.withOpacity(0.5)),
        ),
      ),
      child: StreamBuilder<UserModel?>(
        stream: authService.userModelStream(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          final displayName = user?.displayName ?? 'User';

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {
                        // TODO: Notifications
                      },
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Request Service Card
              Expanded(
                child: _QuickActionCard(
                  title: 'Request\nService',
                  icon: Icons.home_repair_service,
                  isPrimary: true,
                  onTap: () {
                    // Show product picker for service request
                    _showProductPicker(context);
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Refer a Friend Card
              Expanded(
                child: _QuickActionCard(
                  title: 'Refer a\nFriend',
                  icon: Icons.volunteer_activism,
                  isPrimary: false,
                  onTap: () => context.pushNamed('referral'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showProductPicker(BuildContext context) {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Appliance',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<ProductModel>>(
                stream: authService.currentUser != null
                    ? firestoreService.getUserProducts(
                        authService.currentUser!.uid,
                      )
                    : Stream.value([]),
                builder: (context, snapshot) {
                  // Show loading indicator while fetching
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final products = snapshot.data ?? [];

                  if (products.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              size: 48,
                              color: AppTheme.textSecondaryLight,
                            ),
                            const SizedBox(height: 16),
                            const Text('No products registered yet'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                context.pushNamed('add-product');
                              },
                              child: const Text('Add Product'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              ProductModel.getProductImage(product.category),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 48,
                                    height: 48,
                                    color: AppTheme.backgroundLight,
                                    child: const Icon(
                                      Icons.devices,
                                      color: AppTheme.textSecondaryLight,
                                    ),
                                  ),
                            ),
                          ),
                          title: Text(product.productName),
                          subtitle: Text('Model: ${product.modelNumber}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pop(context);
                            context.pushNamed(
                              'service-request',
                              pathParameters: {'productId': product.id},
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Appliances Yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Register your V-Guard products to track\nwarranty and request service',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.pushNamed('add-product'),
            icon: const Icon(Icons.add),
            label: const Text('Add Your First Product'),
          ),
        ],
      ),
    );
  }

  Widget _buildApplianceCard(BuildContext context, ProductModel product) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.cardShadow,
      ),
      child: InkWell(
        onTap: () {
          // Navigate to product details or service request
          context.pushNamed(
            'service-request',
            pathParameters: {'productId': product.id},
          );
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Row(
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Image.asset(
                ProductModel.getProductImage(product.category),
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 80,
                  height: 80,
                  color: AppTheme.backgroundLight,
                  child: const Icon(
                    Icons.devices,
                    color: AppTheme.textSecondaryLight,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.productName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Model: ${product.modelNumber}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildStatusBadge(context, product),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: AppTheme.textSecondaryLight),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, ProductModel product) {
    Color backgroundColor;
    Color textColor;
    IconData? icon;
    String text;

    switch (product.status) {
      case ProductStatus.active:
        if (product.isExpiringSoon) {
          backgroundColor = AppTheme.warningLight;
          textColor = AppTheme.warning;
          icon = Icons.warning;
          text = 'Expiring Soon';
        } else {
          backgroundColor = AppTheme.successLight;
          textColor = AppTheme.success;
          icon = null;
          text = 'Active Warranty';
        }
        break;
      case ProductStatus.pendingValidation:
        backgroundColor = AppTheme.primary.withOpacity(0.1);
        textColor = AppTheme.primary;
        icon = Icons.hourglass_empty;
        text = 'Pending Validation';
        break;
      case ProductStatus.expired:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade600;
        icon = Icons.history;
        text = 'Warranty Expired';
        break;
      case ProductStatus.rejected:
        backgroundColor = AppTheme.errorLight;
        textColor = AppTheme.error;
        icon = Icons.cancel;
        text = 'Rejected';
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade600;
        text = product.status.displayName;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: isPrimary ? null : Border.all(color: AppTheme.borderLight),
          boxShadow: isPrimary ? AppTheme.fabShadow : AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isPrimary
                    ? Colors.white.withOpacity(0.2)
                    : AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                color: isPrimary ? Colors.white : AppTheme.primary,
                size: 24,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isPrimary ? Colors.white : AppTheme.textPrimaryLight,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
