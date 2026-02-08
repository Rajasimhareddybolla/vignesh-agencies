import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../../app/theme.dart';
import '../../models/order_model.dart';
import '../../models/catalog_product_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/cart_service.dart';

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
              Text(
                'Order not found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
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
    final canCancel =
        order.status == OrderStatus.pending ||
        order.status == OrderStatus.confirmed;
    final isDelivered = order.status == OrderStatus.delivered;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Order #${order.id.substring(order.id.length - 6).toUpperCase()}',
        ),
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...order.items.map((item) => _buildOrderItemCard(context, item)),

              const SizedBox(height: 24),

              // Price Summary
              _buildPriceSummary(context, order),

              const SizedBox(height: 24),

              // Delivery Address
              _buildAddressCard(context, order),

              const SizedBox(height: 16),

              // Download Invoice
              _buildDownloadInvoiceButton(context, order),

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
    // Calculate estimated delivery (3-5 business days from order date)
    final estimatedDelivery = order.orderedAt.add(const Duration(days: 5));
    final estimatedText =
        'Expected by ${DateFormat('MMM d').format(estimatedDelivery)}';

    // Check if order was cancelled or returned - show different timeline
    if (order.status == OrderStatus.cancelled) {
      return _buildCancelledTimeline(context, order);
    }

    if (order.status == OrderStatus.returned) {
      return _buildReturnedTimeline(context, order);
    }

    final steps = [
      _TimelineStep(
        title: 'Order Placed',
        subtitle: DateFormat('MMM d, yyyy • h:mm a').format(order.orderedAt),
        isCompleted: true,
        isFirst: true,
        icon: Icons.receipt_long_outlined,
      ),
      _TimelineStep(
        title: 'Confirmed',
        subtitle:
            order.status.index >= OrderStatus.confirmed.index
                ? 'Your order has been confirmed'
                : 'Awaiting confirmation',
        isCompleted: order.status.index >= OrderStatus.confirmed.index,
        isCurrent: order.status == OrderStatus.confirmed,
        icon: Icons.check_circle_outline,
      ),
      _TimelineStep(
        title: 'Shipped',
        subtitle:
            order.status.index >= OrderStatus.shipped.index
                ? order.trackingNumber != null
                    ? 'Tracking: ${order.trackingNumber}'
                    : 'Your order is on the way!'
                : 'Will be shipped soon',
        isCompleted: order.status.index >= OrderStatus.shipped.index,
        isCurrent: order.status == OrderStatus.shipped,
        icon: Icons.local_shipping_outlined,
      ),
      _TimelineStep(
        title: 'Delivered',
        subtitle:
            order.deliveredAt != null
                ? DateFormat('MMM d, yyyy • h:mm a').format(order.deliveredAt!)
                : estimatedText,
        isCompleted: order.status == OrderStatus.delivered,
        isCurrent: order.status == OrderStatus.delivered,
        isLast: true,
        icon: Icons.verified_outlined,
      ),
    ];

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
              const Icon(Icons.timeline, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Order Timeline',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (order.status != OrderStatus.delivered)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    estimatedText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...steps.map((step) => _buildTimelineItem(context, step)),
        ],
      ),
    );
  }

  Widget _buildCancelledTimeline(BuildContext context, OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.error.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.error.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.cancel_outlined,
                  color: AppTheme.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Cancelled',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.error,
                        fontSize: 16,
                      ),
                    ),
                    if (order.cancelledAt != null)
                      Text(
                        DateFormat(
                          'MMM d, yyyy • h:mm a',
                        ).format(order.cancelledAt!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (order.cancellationReason != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cancellation Reason',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.cancellationReason!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
          if (order.cancelledBy != null) ...[
            const SizedBox(height: 12),
            Text(
              'Cancelled by: ${order.cancelledBy == 'admin' ? 'Administrator' : 'You'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReturnedTimeline(BuildContext context, OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warning.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.assignment_return_outlined,
                  color: AppTheme.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Order Returned',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warning,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'This order has been returned. If you have any questions, please contact support.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, _TimelineStep step) {
    final isActive = step.isCompleted || step.isCurrent;
    final activeColor = step.isCompleted ? AppTheme.success : AppTheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? activeColor : Colors.transparent,
                border: Border.all(
                  color: isActive ? activeColor : AppTheme.borderLight,
                  width: 2,
                ),
              ),
              child: Icon(
                step.isCompleted ? Icons.check : step.icon,
                size: 16,
                color:
                    isActive ? Colors.white : AppTheme.textSecondary(context),
              ),
            ),
            if (!step.isLast)
              Container(
                width: 2,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors:
                        step.isCompleted
                            ? [AppTheme.success, AppTheme.success]
                            : [AppTheme.borderLight, AppTheme.borderLight],
                  ),
                ),
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
                Row(
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.w500,
                        color:
                            isActive
                                ? AppTheme.textPrimary(context)
                                : AppTheme.textSecondary(context),
                        fontSize: 15,
                      ),
                    ),
                    if (step.isCurrent && !step.isCompleted) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Current',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
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
              placeholder:
                  (context, url) => Container(
                    color: AppTheme.background(context),
                    child: Icon(
                      Icons.image,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
              errorWidget:
                  (context, url, error) => Container(
                    color: AppTheme.background(context),
                    child: Icon(
                      Icons.broken_image,
                      color: AppTheme.textSecondary(context),
                    ),
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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
    final shipping = order.shippingFee;
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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildPriceRow(
            context,
            'Subtotal',
            '₹${subtotal.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 8),
          _buildPriceRow(
            context,
            'Shipping',
            shipping == 0 ? 'FREE' : '₹${shipping.toStringAsFixed(0)}',
            valueColor: AppTheme.success,
          ),
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
              color: AppTheme.background(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.payment,
                  size: 18,
                  color: AppTheme.textSecondary(context),
                ),
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

  Widget _buildPriceRow(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 16),
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            order.address.name,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
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
        label: const Text(
          'Cancel Order',
          style: TextStyle(color: AppTheme.error),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.error),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterWarrantyButton(BuildContext context, OrderModel order) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          if (order.items.isEmpty) return;

          if (order.items.length == 1) {
            // Single item - Go directly to registration
            context.pushNamed(
              'add-product',
              extra: {
                'sourceOrder': order,
                'sourceOrderItem': order.items.first,
              },
            );
          } else {
            // Multiple items - Show selection bottom sheet
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder:
                  (context) => Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Item to Register',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: order.items.length,
                            separatorBuilder: (ctx, i) => const Divider(),
                            itemBuilder: (context, index) {
                              final item = order.items[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: item.productImage,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorWidget:
                                        (_, __, ___) => const Icon(
                                          Icons.image_not_supported,
                                        ),
                                  ),
                                ),
                                title: Text(item.productName),
                                subtitle: Text(item.category),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.pop(context); // Close bottom sheet
                                  context.pushNamed(
                                    'add-product',
                                    extra: {
                                      'sourceOrder': order,
                                      'sourceOrderItem': item,
                                    },
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
        },
        icon: const Icon(Icons.verified_user_outlined),
        label: const Text('Register for Warranty'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildReorderButton(BuildContext context, OrderModel order) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _handleReorder(context, order),
        icon: const Icon(Icons.replay),
        label: const Text('Reorder Items'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _handleReorder(BuildContext context, OrderModel order) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final firestoreService = context.read<FirestoreService>();
      final cartService = context.read<CartService>();

      int addedCount = 0;
      int unavailableCount = 0;
      List<String> unavailableItems = [];

      for (final item in order.items) {
        // Fetch the current product from Firestore
        final product = await firestoreService.getCatalogProduct(
          item.productId,
        );

        if (product == null || !product.isActive) {
          unavailableCount++;
          unavailableItems.add(item.productName);
          continue;
        }

        // Find the variation if any
        ProductVariation? variation;
        if (item.variationId != null && product.variations.isNotEmpty) {
          try {
            variation = product.variations.firstWhere(
              (v) => v.id == item.variationId,
            );
          } catch (_) {
            // Variation not found, try to find one with matching attributes
            for (final v in product.variations) {
              bool matches = true;
              for (final attr in item.selectedAttributes.entries) {
                if (v.attributes[attr.key] != attr.value) {
                  matches = false;
                  break;
                }
              }
              if (matches) {
                variation = v;
                break;
              }
            }
          }
        }

        // Check stock
        final inStock = cartService.isProductInStock(product, variation);
        if (!inStock) {
          unavailableCount++;
          unavailableItems.add(item.productName);
          continue;
        }

        // Add to cart
        cartService.addToCart(
          product,
          variation: variation,
          quantity: item.quantity,
        );
        addedCount++;
      }

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Show result
      if (context.mounted) {
        if (addedCount > 0 && unavailableCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    '$addedCount item${addedCount > 1 ? 's' : ''} added to cart',
                  ),
                ],
              ),
              backgroundColor: AppTheme.success,
              action: SnackBarAction(
                label: 'View Cart',
                textColor: Colors.white,
                onPressed: () => context.pushNamed('cart'),
              ),
            ),
          );
        } else if (addedCount > 0 && unavailableCount > 0) {
          _showReorderResultDialog(context, addedCount, unavailableItems);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('None of the items are currently available'),
              backgroundColor: AppTheme.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showReorderResultDialog(
    BuildContext context,
    int addedCount,
    List<String> unavailableItems,
  ) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: AppTheme.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Partial Reorder')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$addedCount item${addedCount > 1 ? 's' : ''} added to cart.',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Text(
                  'The following items are unavailable:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 8),
                ...unavailableItems.map(
                  (name) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.remove_circle_outline,
                          size: 14,
                          color: AppTheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  context.pushNamed('cart');
                },
                child: const Text('View Cart'),
              ),
            ],
          ),
    );
  }

  Widget _buildDownloadInvoiceButton(BuildContext context, OrderModel order) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _saveInvoice(context, order),
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Download'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _shareInvoice(context, order),
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveInvoice(BuildContext context, OrderModel order) async {
    try {
      final pdf = await _generateInvoicePdf(order);
      final bytes = await pdf.save();
      final fileName =
          'vignesh_agencies_invoice_${order.id.substring(order.id.length - 6).toUpperCase()}.pdf';

      // Get downloads directory
      Directory? directory;
      if (Platform.isAndroid) {
        // Android: Save to public Downloads folder
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        // iOS: Save to app documents
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access storage');
      }

      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invoice saved to ${Platform.isAndroid ? 'Downloads' : 'Documents'}',
            ),
            backgroundColor: AppTheme.success,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () {
                Printing.layoutPdf(onLayout: (_) => bytes, name: fileName);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving invoice: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _shareInvoice(BuildContext context, OrderModel order) async {
    try {
      final pdf = await _generateInvoicePdf(order);
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'vignesh_agencies_invoice_${order.id.substring(order.id.length - 6).toUpperCase()}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating invoice: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<pw.Document> _generateInvoicePdf(OrderModel order) async {
    final pdf = pw.Document();

    // Calculate totals
    final subtotal = order.items.fold<double>(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'VIGNESH AGENCIES',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Premium Home Appliances',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'No. 123, Main Road\nChennai, Tamil Nadu - 600001\nPhone: +91 99999 99999',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue100,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Order #${order.id.substring(order.id.length - 6).toUpperCase()}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      DateFormat('MMMM dd, yyyy').format(order.orderedAt),
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 30),

            // Bill To Section
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BILL TO',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        order.address.name,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        order.address.phone,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${order.address.street}\n${order.address.city}, ${order.address.state} - ${order.address.pincode}',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ORDER DETAILS',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      _pdfLabelValue('Status', order.status.displayName),
                      _pdfLabelValue(
                        'Payment',
                        order.paymentMethod == 'COD'
                            ? 'Cash on Delivery'
                            : order.paymentMethod,
                      ),
                      _pdfLabelValue('Items', '${order.items.length}'),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 30),

            // Items Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(4),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _pdfTableHeader('Item'),
                    _pdfTableHeader('Qty'),
                    _pdfTableHeader('Price'),
                    _pdfTableHeader('Total'),
                  ],
                ),
                // Item Rows
                ...order.items.map(
                  (item) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              item.productName,
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            if (item.selectedAttributes.isNotEmpty)
                              pw.Text(
                                item.selectedAttributes.entries
                                    .map((e) => '${e.key}: ${e.value}')
                                    .join(' • '),
                                style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.grey600,
                                ),
                              ),
                            if (item.warrantyMonths > 0)
                              pw.Text(
                                'Warranty: ${item.warrantyMonths} months',
                                style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.grey600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      _pdfTableCell('${item.quantity}'),
                      _pdfTableCell('Rs.${item.price.toStringAsFixed(0)}'),
                      _pdfTableCell(
                        'Rs.${(item.price * item.quantity).toStringAsFixed(0)}',
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // Totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.SizedBox(
                  width: 200,
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Subtotal',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.Text(
                            'Rs.${subtotal.toStringAsFixed(0)}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Shipping',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.Text(
                            order.shippingFee == 0
                                ? 'FREE'
                                : 'Rs.${order.shippingFee.toStringAsFixed(0)}',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.green700,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Divider(color: PdfColors.grey300),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'Rs.${order.totalAmount.toStringAsFixed(0)}',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 40),

            // Footer
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'Thank you for shopping with Vignesh Agencies!',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'For queries, contact us at support@vigneshagencies.com',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  // PDF helper methods
  pw.Widget _pdfTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _pdfTableCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.right,
      ),
    );
  }

  pw.Widget _pdfLabelValue(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Text(
            '$label: ',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, OrderModel order) {
    String? selectedReason;
    String customReason = '';

    showDialog(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.cancel_outlined,
                          color: AppTheme.error,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Cancel Order'),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Please select a reason for cancellation:',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 16),
                        ...OrderModel.cancellationReasons.map(
                          (reason) => RadioListTile<String>(
                            title: Text(
                              reason,
                              style: const TextStyle(fontSize: 14),
                            ),
                            value: reason,
                            groupValue: selectedReason,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedReason = value;
                              });
                            },
                          ),
                        ),
                        if (selectedReason == 'Other') ...[
                          const SizedBox(height: 8),
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Please specify your reason...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            maxLines: 2,
                            onChanged: (value) => customReason = value,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.warning.withAlpha(50),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: AppTheme.warning,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This action cannot be undone.',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.warning,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Keep Order'),
                    ),
                    FilledButton(
                      onPressed:
                          selectedReason == null
                              ? null
                              : () async {
                                final reason =
                                    selectedReason == 'Other' &&
                                            customReason.isNotEmpty
                                        ? customReason
                                        : selectedReason;
                                Navigator.pop(dialogContext);
                                try {
                                  final authService =
                                      context.read<AuthService>();
                                  final firestoreService =
                                      context.read<FirestoreService>();
                                  final userId =
                                      await authService.getResolvedUserId();

                                  await firestoreService.cancelOrder(
                                    order.id,
                                    userId,
                                    reason: reason,
                                  );

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Order cancelled successfully',
                                        ),
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
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            selectedReason == null
                                ? AppTheme.error.withAlpha(100)
                                : AppTheme.error,
                      ),
                      child: const Text('Cancel Order'),
                    ),
                  ],
                ),
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
  final bool isCurrent;
  final IconData icon;

  _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    this.isFirst = false,
    this.isLast = false,
    this.isCurrent = false,
    this.icon = Icons.check_circle_outline,
  });
}
