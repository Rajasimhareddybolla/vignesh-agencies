import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme.dart';
import '../../models/product_model.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';

class WarrantyValidationScreen extends StatelessWidget {
  const WarrantyValidationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Warranty Validation',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Review and validate product registrations',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),

            // Pending Registrations List
            Expanded(
              child: StreamBuilder<List<ProductModel>>(
                stream: firestoreService.getPendingProducts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
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
                              color: AppTheme.successLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              size: 48,
                              color: AppTheme.success,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'All caught up!',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No pending registrations to validate',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.textSecondaryLight),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      return _ProductValidationCard(
                        product: products[index],
                        onApprove: () =>
                            _approveProduct(context, products[index]),
                        onReject: () =>
                            _showRejectDialog(context, products[index]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveProduct(
    BuildContext context,
    ProductModel product,
  ) async {
    final firestoreService = context.read<FirestoreService>();
    final authService = context.read<AuthService>();

    await firestoreService.updateProductStatus(
      productId: product.id,
      status: ProductStatus.active,
      validatedBy: authService.currentUser?.uid,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Product approved successfully!'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _showRejectDialog(
    BuildContext context,
    ProductModel product,
  ) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Registration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final firestoreService = context.read<FirestoreService>();
      final authService = context.read<AuthService>();

      await firestoreService.updateProductStatus(
        productId: product.id,
        status: ProductStatus.rejected,
        validatedBy: authService.currentUser?.uid,
        rejectionReason: reasonController.text.isNotEmpty
            ? reasonController.text
            : 'Invalid documentation',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product registration rejected'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}

class _ProductValidationCard extends StatefulWidget {
  final ProductModel product;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ProductValidationCard({
    required this.product,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_ProductValidationCard> createState() => _ProductValidationCardState();
}

class _ProductValidationCardState extends State<_ProductValidationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
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
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusMd),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Product Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      ProductModel.getProductImage(widget.product.category),
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Product Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.productName,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Model: ${widget.product.modelNumber}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondaryLight),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Submitted ${DateFormat('MMM d, yyyy').format(widget.product.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.textSecondaryLight,
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.textSecondaryLight,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Details
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Details Grid
                  Row(
                    children: [
                      Expanded(
                        child: _DetailItem(
                          label: 'Category',
                          value: widget.product.category,
                        ),
                      ),
                      Expanded(
                        child: _DetailItem(
                          label: 'Purchase Date',
                          value: DateFormat(
                            'MMM d, yyyy',
                          ).format(widget.product.purchaseDate),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DetailItem(
                          label: 'Warranty Until',
                          value: DateFormat(
                            'MMM d, yyyy',
                          ).format(widget.product.warrantyEndDate),
                        ),
                      ),
                      if (widget.product.serialNumber != null)
                        Expanded(
                          child: _DetailItem(
                            label: 'Serial Number',
                            value: widget.product.serialNumber!,
                          ),
                        ),
                    ],
                  ),

                  // Bill Image
                  if (widget.product.billImageUrl != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Bill / Warranty Document',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: widget.product.billImageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: AppTheme.backgroundLight,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onReject,
                          icon: const Icon(Icons.close, color: AppTheme.error),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                            side: const BorderSide(color: AppTheme.error),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.onApprove,
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondaryLight),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
