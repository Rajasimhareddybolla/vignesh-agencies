import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../models/order_model.dart';
import '../../../services/firestore_service.dart';
import '../../../widgets/common/premium_widgets.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Orders'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1),
        ),
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: firestoreService.getAllOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return const Center(child: Text('No orders found'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              return _OrderCard(order: orders[index]);
            },
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final totalItems = order.items.fold(0, (sum, i) => sum + i.quantity);

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${order.id.substring(order.id.length - 6).toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              _StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('MMM d, yyyy • h:mm a').format(order.orderedAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Divider(),
          
          // Items Summary
          Text(
            '$totalItems Items • ₹${order.totalAmount.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Customer: ${order.address.name}',
             style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondaryLight),
          ),
          
          const SizedBox(height: 16),
          // Actions
          if (order.status == OrderStatus.pending)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                   firestoreService.updateOrderStatus(order.id, OrderStatus.confirmed);
                },
                child: const Text('Confirm Order'),
              ),
            ),
          
           if (order.status == OrderStatus.confirmed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                   firestoreService.updateOrderStatus(order.id, OrderStatus.delivered);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                child: const Text('Mark Delivered (COD Received)'),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch(status) {
      case OrderStatus.pending: color = AppTheme.warning; break;
      case OrderStatus.confirmed: color = AppTheme.primary; break;
      case OrderStatus.delivered: color = AppTheme.success; break;
      case OrderStatus.cancelled: color = AppTheme.error; break;
      default: color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
