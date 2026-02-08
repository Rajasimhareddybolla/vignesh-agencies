import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../../../app/theme.dart';
import '../../../models/order_model.dart';
import '../../../services/firestore_service.dart';
import '../users/admin_user_profile_screen.dart';
// import '../../../widgets/common/premium_widgets.dart'; // Removed as per potential issue

class AdminOrderDetailScreen extends StatefulWidget {
  final OrderModel order;

  const AdminOrderDetailScreen({super.key, required this.order});

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  // We'll keep a local updated order if needed for UI updates without full stream reload
  late OrderModel _order;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    // Using StreamBuilder to keep details live
    return StreamBuilder<List<OrderModel>>(
      stream:
          firestoreService
              .getAllOrders(), // Inefficient but simplest for now given no getOrderById
      builder: (context, snapshot) {
        // Find our specific order from the list if available, else use initial
        if (snapshot.hasData) {
          try {
            _order = snapshot.data!.firstWhere((o) => o.id == _order.id);
          } catch (e) {
            // Order might not be in the list? Keep using initial or stale
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Order #${_order.id.substring(_order.id.length - 6).toUpperCase()}',
            ),
            actions: [
              _buildStatusChip(_order.status),
              const SizedBox(width: 16),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Info Section
                _buildSectionTitle('Customer Details'),
                _buildInfoCard(
                  context,
                  Column(
                    children: [
                      _buildDetailRow(
                        Icons.person,
                        'Name (View Profile)',
                        _order.address.name,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => AdminUserProfileScreen(
                                    userId: _order.userId,
                                    userName: _order.address.name,
                                  ),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 16, thickness: 0.5),
                      _buildDetailRow(
                        Icons.phone,
                        'Phone',
                        _order.address.phone,
                      ),
                      const Divider(height: 16, thickness: 0.5),
                      _buildDetailRow(
                        Icons.location_on,
                        'Address',
                        '${_order.address.street}, ${_order.address.city}, ${_order.address.state} - ${_order.address.pincode}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Order Timeline / Dates
                _buildSectionTitle('Order Timeline'),
                _buildInfoCard(
                  context,
                  Column(
                    children: [
                      _buildDetailRow(
                        Icons.access_time,
                        'Ordered On',
                        DateFormat(
                          'MMM d, yyyy • h:mm a',
                        ).format(_order.orderedAt),
                      ),
                      const Divider(height: 16, thickness: 0.5),
                      _buildDeliveryDateRow(context, firestoreService),
                      if (_order.deliveredAt != null) ...[
                        const Divider(height: 16, thickness: 0.5),
                        _buildDetailRow(
                          Icons.check_circle,
                          'Delivered On',
                          DateFormat(
                            'MMM d, yyyy • h:mm a',
                          ).format(_order.deliveredAt!),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Items Section
                _buildSectionTitle('Order Items (${_order.items.length})'),
                ..._order.items.map((item) => _buildOrderItem(context, item)),

                const SizedBox(height: 12),
                // Delivery Fee Section
                _buildDeliveryFeeSection(context, firestoreService),

                const SizedBox(height: 12),
                // Order Summary
                _buildOrderSummary(context),

                const SizedBox(height: 32),
                // Action Buttons
                _buildActionButtons(context, firestoreService),
                const SizedBox(height: 50),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary(context),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: onTap != null ? AppTheme.primary : null,
                    decoration: onTap != null ? TextDecoration.underline : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryDateRow(
    BuildContext context,
    FirestoreService firestoreService,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.local_shipping_outlined,
          size: 20,
          color: AppTheme.textSecondary(context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expected Delivery',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary(context),
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () => _pickDate(context, firestoreService),
                child: Row(
                  children: [
                    Text(
                      _order.expectedDeliveryDate != null
                          ? DateFormat(
                            'MMM d, yyyy',
                          ).format(_order.expectedDeliveryDate!)
                          : 'Not set',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color:
                            _order.expectedDeliveryDate == null
                                ? AppTheme.warning
                                : AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.edit,
                      size: 14,
                      color: AppTheme.primary.withAlpha(150),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    FirestoreService firestoreService,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _order.expectedDeliveryDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      await firestoreService.updateOrderExpectedDeliveryDate(_order.id, picked);
      // Update local state to refresh UI immediately
      setState(() {
        _order = OrderModel(
          id: _order.id,
          userId: _order.userId,
          items: _order.items,
          totalAmount: _order.totalAmount,
          status: _order.status,
          paymentMethod: _order.paymentMethod,
          address: _order.address,
          orderedAt: _order.orderedAt,
          deliveredAt: _order.deliveredAt,
          trackingNumber: _order.trackingNumber,
          version: _order.version,
          cancellationReason: _order.cancellationReason,
          cancelledAt: _order.cancelledAt,
          cancelledBy: _order.cancelledBy,
          adminNotes: _order.adminNotes,
          assignedTo: _order.assignedTo,
          assignedAt: _order.assignedAt,
          expectedDeliveryDate: picked, // Updated value
          shippingFee: _order.shippingFee,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expected delivery date updated')),
        );
      }
    }
  }

  Widget _buildOrderItem(BuildContext context, OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withAlpha(50)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: item.productImage,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              placeholder:
                  (context, url) => Container(
                    color: AppTheme.background(context),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              errorWidget:
                  (context, url, error) => Container(
                    color: AppTheme.background(context),
                    child: const Icon(Icons.broken_image),
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
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (item.selectedAttributes.isNotEmpty)
                  Text(
                    item.selectedAttributes.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join(', '),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Qty: ${item.quantity}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      '₹${item.price.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildStatusChip(OrderStatus status) {
    Color color;
    switch (status) {
      case OrderStatus.pending:
        color = AppTheme.warning;
        break;
      case OrderStatus.confirmed:
        color = AppTheme.primary;
        break;
      case OrderStatus.shipped:
        color = Colors.blue;
        break;
      case OrderStatus.delivered:
        color = AppTheme.success;
        break;
      case OrderStatus.returned:
        color = AppTheme.warning;
        break;
      case OrderStatus.cancelled:
        color = AppTheme.error;
        break;
    }

    return Chip(
      label: Text(
        status.displayName,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color.withAlpha(30),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildDeliveryFeeSection(
    BuildContext context,
    FirestoreService firestoreService,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.delivery_dining, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Delivery Fee',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const Spacer(),
              if (_order.shippingFee > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '₹${_order.shippingFee.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Not set',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showDeliveryFeeDialog(context, firestoreService),
              icon: const Icon(Icons.edit, size: 16, color: Colors.orange),
              label: Text(
                _order.shippingFee > 0 ? 'Update Delivery Fee' : 'Set Delivery Fee',
                style: const TextStyle(color: Colors.orange),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(BuildContext context) {
    final subtotal = _order.items.fold<double>(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );
    final deliveryFee = _order.shippingFee;
    final grandTotal = _order.totalAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withAlpha(50)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: TextStyle(
                  color: AppTheme.textSecondary(context),
                ),
              ),
              Text('₹${subtotal.toStringAsFixed(0)}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.delivery_dining, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Delivery Fee',
                    style: TextStyle(
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
              Text(
                deliveryFee > 0
                    ? '₹${deliveryFee.toStringAsFixed(0)}'
                    : 'FREE',
                style: TextStyle(
                  color: deliveryFee > 0 ? Colors.orange : AppTheme.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '₹${grandTotal.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeliveryFeeDialog(
    BuildContext context,
    FirestoreService firestoreService,
  ) {
    final controller = TextEditingController(
      text: _order.shippingFee > 0 ? _order.shippingFee.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delivery_dining, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            const Text('Delivery Fee'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set the delivery fee for this order. Customer: ${_order.address.name}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Delivery Fee (₹)',
                prefixText: '₹ ',
                hintText: '0',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            const Text(
              'Set to 0 for free delivery',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final fee = double.tryParse(controller.text) ?? 0;
              await firestoreService.updateOrderDeliveryFee(_order.id, fee);
              final subtotal = _order.items.fold<double>(
                0,
                (sum, item) => sum + (item.price * item.quantity),
              );
              final newTotal = subtotal + fee;
              setState(() {
                _order = OrderModel(
                  id: _order.id,
                  userId: _order.userId,
                  items: _order.items,
                  totalAmount: newTotal,
                  status: _order.status,
                  paymentMethod: _order.paymentMethod,
                  address: _order.address,
                  orderedAt: _order.orderedAt,
                  deliveredAt: _order.deliveredAt,
                  trackingNumber: _order.trackingNumber,
                  version: _order.version,
                  cancellationReason: _order.cancellationReason,
                  cancelledAt: _order.cancelledAt,
                  cancelledBy: _order.cancelledBy,
                  adminNotes: _order.adminNotes,
                  assignedTo: _order.assignedTo,
                  assignedAt: _order.assignedAt,
                  expectedDeliveryDate: _order.expectedDeliveryDate,
                  shippingFee: fee,
                );
              });
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      fee > 0
                          ? 'Delivery fee set to ₹${fee.toStringAsFixed(0)}'
                          : 'Delivery fee removed',
                    ),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    FirestoreService firestoreService,
  ) {
    if (_order.status == OrderStatus.delivered ||
        _order.status == OrderStatus.cancelled ||
        _order.status == OrderStatus.returned) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (_order.status == OrderStatus.pending)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                firestoreService.updateOrderStatus(
                  _order.id,
                  OrderStatus.confirmed,
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Order'),
            ),
          ),
        if (_order.status == OrderStatus.confirmed)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  () => _showShipOrderDialog(context, _order, firestoreService),
              icon: const Icon(Icons.local_shipping),
              label: const Text('Mark as Shipped'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        if (_order.status == OrderStatus.shipped)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  () => _showDeliverOrderDialog(
                    context,
                    _order,
                    firestoreService,
                  ),
              icon: const Icon(Icons.check_circle),
              label: const Text('Mark as Delivered'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  // Copied from AdminOrdersScreen for consistency
  void _showShipOrderDialog(
    BuildContext context,
    OrderModel order,
    FirestoreService firestoreService,
  ) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Ship Order'),
            content: const Text(
              'Mark this order as shipped? The customer will be notified.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  firestoreService.updateOrderStatus(
                    order.id,
                    OrderStatus.shipped,
                  );
                },
                child: const Text('Confirm Shipped'),
              ),
            ],
          ),
    );
  }

  void _showDeliverOrderDialog(
    BuildContext context,
    OrderModel order,
    FirestoreService firestoreService,
  ) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Deliver Order'),
            content: const Text(
              'Confirm delivery? This will register the product warranty for the user.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  firestoreService.updateOrderStatus(
                    order.id,
                    OrderStatus.delivered,
                  );
                },
                child: const Text('Confirm Delivered'),
              ),
            ],
          ),
    );
  }
}
