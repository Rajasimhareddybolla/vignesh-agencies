import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class AllAppliancesScreen extends StatelessWidget {
  const AllAppliancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('My Appliances'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.pushNamed('add-product'),
          ),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: authService.userModelStream(),
        builder: (context, userSnapshot) {
          final effectiveUserId = userSnapshot.data?.id ?? authService.currentUser?.uid;

          return StreamBuilder<List<ProductModel>>(
            stream: effectiveUserId != null
                ? firestoreService.getUserProducts(effectiveUserId)
                : Stream.value([]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Handle errors gracefully
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppTheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Unable to load products',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please check your connection',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => context.pushNamed('add-product'),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Product'),
                      ),
                    ],
                  ),
                );
              }

              final products = snapshot.data ?? [];

              if (products.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                        'No appliances yet',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                  Text(
                    'Register your V-Guard products to\nmanage warranties and service requests',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.pushNamed('add-product'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Product'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _ProductCard(product: product);
            },
          );
            },
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;

  const _ProductCard({required this.product});

  String _getCategoryImage(String category) {
    switch (category.toLowerCase()) {
      case 'water heater':
        return 'assets/images/water_heater.png';
      case 'stabilizer':
        return 'assets/images/stabilizer.png';
      case 'inverter':
        return 'assets/images/inverter.png';
      case 'fan':
        return 'assets/images/fan.png';
      case 'air cooler':
        return 'assets/images/air_cooler.png';
      case 'kitchen appliances':
        return 'assets/images/kitchen_appliances.png';
      case 'solar products':
        return 'assets/images/solar_products.png';
      case 'wiring & cables':
        return 'assets/images/wiring_cables.png';
      case 'switchgear':
        return 'assets/images/switchgear.png';
      case 'ups':
        return 'assets/images/ups.png';
      case 'motor':
        return 'assets/images/motor.png';
      case 'pump':
        return 'assets/images/pump.png';
      default:
        return 'assets/images/water_heater.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWarrantyActive = product.warrantyEndDate.isAfter(DateTime.now());
    final daysRemaining = product.warrantyEndDate
        .difference(DateTime.now())
        .inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // Product Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    _getCategoryImage(product.category),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.devices,
                        color: AppTheme.primary,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.productName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Model: ${product.modelNumber}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: product.status),
              ],
            ),
          ),

          const Divider(height: 1),

          // Warranty Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Purchase Date',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy').format(product.purchaseDate),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: AppTheme.borderLight),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Warranty Status',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondaryLight),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              isWarrantyActive
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              size: 16,
                              color: isWarrantyActive
                                  ? AppTheme.success
                                  : AppTheme.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isWarrantyActive
                                  ? '$daysRemaining days left'
                                  : 'Expired',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: isWarrantyActive
                                        ? AppTheme.success
                                        : AppTheme.error,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.pushNamed(
                    'service-request',
                    pathParameters: {'productId': product.id},
                  );
                },
                icon: const Icon(Icons.build_outlined, size: 18),
                label: const Text('Request Service'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ProductStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case ProductStatus.active:
        bgColor = AppTheme.successLight;
        textColor = AppTheme.success;
        label = 'Active';
        break;
      case ProductStatus.pendingValidation:
        bgColor = AppTheme.warningLight;
        textColor = AppTheme.warning;
        label = 'Pending';
        break;
      case ProductStatus.rejected:
        bgColor = AppTheme.errorLight;
        textColor = AppTheme.error;
        label = 'Rejected';
        break;
      case ProductStatus.expired:
        bgColor = AppTheme.neutralLight;
        textColor = AppTheme.neutral;
        label = 'Expired';
        break;
      case ProductStatus.expiringSoon:
        bgColor = AppTheme.warningLight;
        textColor = AppTheme.warning;
        label = 'Expiring';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
