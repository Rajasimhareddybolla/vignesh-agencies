import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme.dart';
import '../../models/order_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderModel? _order;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final firestoreService = context.read<FirestoreService>();
      final order = await firestoreService.getOrder(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
              const SizedBox(height: 16),
              Text('Order not found', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final order = _order!;
    final canCancel = order.status == OrderStatus.pending || 
                      order.status == OrderStatus.confirmed;
    final isDelivered = order.status == OrderStatus.delivered;

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${order.id.substring(order.id.length - 6).toUpperCase()}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrder,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              _buildStatusCard(context, order),
              
              const SizedBox(height: 24),

              // Order Timeline
              _buildOrderTimeline(context, order),

              const SizedBox(height: 24),

              // Items Section
              Text(
                'Items (${order.items.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...order.items.map((item) => _buildOrderItemCard(context, item)),

              const SizedBox(height: 24),

              // Price Summary
              _buildPriceSummary(context, order),

              const SizedBox(height: 24),

              // Delivery Address
              _buildAddressCard(context, order),

              const SizedBox(height: 24),

              // Action Buttons
              if (canCancel) _buildCancelButton(context, order),
              
              if (isDelivered) ...[
                _buildRegisterWarrantyButton(context, order),
                const SizedBox(height: 12),
                _buildReorderButton(context, order),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, OrderModel order) {
    Color statusColor;
    IconData statusIcon;
    String statusMessage;

    switch (order.status) {
      case OrderStatus.pending:
        statusColor = AppTheme.warning;
        statusIcon = Icons.schedule;
        statusMessage = 'Your order is being processed';
        break;
      case OrderStatus.confirmed:
        statusColor = AppTheme.infoDark;
        statusIcon = Icons.check_circle;
        statusMessage = 'Order confirmed! Preparing for shipment';
        break;
      case OrderStatus.shipped:
        statusColor = AppTheme.primary;
        statusIcon = Icons.local_shipping;
        statusMessage = 'Your order is on the way';
        break;
      case OrderStatus.delivered:
        statusColor = AppTheme.success;
        statusIcon = Icons.verified;
        statusMessage = 'Order delivered successfully';
        break;
      case OrderStatus.cancelled:
        statusColor = AppTheme.error;
        statusIcon = Icons.cancel;
        statusMessage = 'Order was cancelled';
        break;
      case OrderStatus.returned:
        statusColor = AppTheme.neutral;
        statusIcon = Icons.assignment_return;
        statusMessage = 'Order was returned';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withAlpha(200)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.status.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusMessage,
                  style: TextStyle(
                    color: Colors.white.withAlpha(220),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTimeline(BuildContext context, OrderModel order) {
    final steps = [
      _TimelineStep(
        title: 'Order Placed',
        subtitle: DateFormat('MMM d, yyyy • h:mm a').format(order.orderedAt),
        isCompleted: true,
        isFirst: true,
      ),
      _TimelineStep(
        title: 'Confirmed',
        subtitle: order.status.index >= OrderStatus.confirmed.index 
            ? 'Order confirmed' 
            : 'Pending confirmation',
        isCompleted: order.status.index >= OrderStatus.confirmed.index,
      ),
      _TimelineStep(
        title: 'Shipped',
        subtitle: order.status.index >= OrderStatus.shipped.index
            ? 'Out for delivery'
            : 'Awaiting shipment',
        isCompleted: order.status.index >= OrderStatus.shipped.index,
      ),
      _TimelineStep(
        title: 'Delivered',
        subtitle: order.deliveredAt != null
            ? DateFormat('MMM d, yyyy').format(order.deliveredAt!)
            : 'Estimated in 3-5 days',
        isCompleted: order.status == OrderStatus.delivered,
        isLast: true,
      ),
    ];

    // Don't show timeline for cancelled/returned
    if (order.status == OrderStatus.cancelled || order.status == OrderStatus.returned) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Timeline',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...steps.map((step) => _buildTimelineItem(context, step)),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, _TimelineStep step) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: step.isCompleted ? AppTheme.success : AppTheme.borderLight,
                border: Border.all(
                  color: step.isCompleted ? AppTheme.success : AppTheme.borderLight,
                  width: 2,
                ),
              ),
              child: step.isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            if (!step.isLast)
              Container(
                width: 2,
                height: 40,
                color: step.isCompleted ? AppTheme.success : AppTheme.borderLight,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: step.isLast ? 0 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: step.isCompleted 
                        ? AppTheme.textPrimary(context) 
                        : AppTheme.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItemCard(BuildContext context, OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: item.productImage,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: AppTheme.backgroundLight,
                child: Icon(Icons.image, color: AppTheme.textSecondary(context)),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppTheme.backgroundLight,
                child: Icon(Icons.broken_image, color: AppTheme.textSecondary(context)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (item.selectedAttributes.isNotEmpty)
                  Text(
                    item.selectedAttributes.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join(' • '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${item.price.toStringAsFixed(0)} × ${item.quantity}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
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

  Widget _buildPriceSummary(BuildContext context, OrderModel order) {
    final subtotal = order.items.fold<double>(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );
    final shipping = 0.0; // Free shipping
    final total = order.totalAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price Details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildPriceRow(context, 'Subtotal', '₹${subtotal.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          _buildPriceRow(context, 'Shipping', shipping == 0 ? 'FREE' : '₹${shipping.toStringAsFixed(0)}',
              valueColor: AppTheme.success),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          _buildPriceRow(
            context,
            'Total',
            '₹${total.toStringAsFixed(0)}',
            isBold: true,
            valueColor: AppTheme.primary,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
              Icon(Icons.payment, size: 18, color: AppTheme.textSecondary(context)),
                const SizedBox(width: 8),
                Text(
                  'Payment: ${order.paymentMethod == 'COD' ? 'Cash on Delivery' : order.paymentMethod}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(BuildContext context, String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildAddressCard(BuildContext context, OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Delivery Address',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            order.address.name,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            order.address.phone,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${order.address.street}\n${order.address.city}, ${order.address.state} - ${order.address.pincode}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton(BuildContext context, OrderModel order) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showCancelDialog(context, order),
        icon: const Icon(Icons.cancel_outlined, color: AppTheme.error),
        label: const Text('Cancel Order', style: TextStyle(color: AppTheme.error)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.error),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildRegisterWarrantyButton(BuildContext context, OrderModel order) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => context.pushNamed('add-product'),
        icon: const Icon(Icons.verified_user_outlined),
        label: const Text('Register for Warranty'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildReorderButton(BuildContext context, OrderModel order) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => context.pushNamed('product-catalog'),
        icon: const Icon(Icons.replay),
        label: const Text('Browse More Products'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Order?'),
        content: Text(
          'Are you sure you want to cancel this order?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('No, Keep Order'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final authService = context.read<AuthService>();
                final firestoreService = context.read<FirestoreService>();
                final userId = await authService.getResolvedUserId();
                
                await firestoreService.cancelOrder(order.id, userId);
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Order cancelled successfully'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                  // Refresh the order
                  _loadOrder();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to cancel: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Yes, Cancel Order'),
          ),
        ],
      ),
    );
  }
}

class _TimelineStep {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isFirst;
  final bool isLast;

  _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    this.isFirst = false,
    this.isLast = false,
  });
}
