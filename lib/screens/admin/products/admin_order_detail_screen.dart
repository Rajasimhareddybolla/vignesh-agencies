import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../../../app/theme.dart';
import '../../../models/order_model.dart';
import '../../../services/firestore_service.dart';
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
                        'Name',
                        _order.address.name,
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
                // Order Summary within Items card? Or separate?
                // Let's verify Total Amount
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primary.withAlpha(50)),
                  ),
                  child: Row(
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
                        '₹${_order.totalAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
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
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expected delivery date updated')),
      );
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
