import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/premium_widgets.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondaryLight,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: const [Tab(text: 'Active'), Tab(text: 'History')],
        ),
      ),
      body: StreamBuilder<UserModel?>(
        stream: authService.userModelStream(),
        builder: (context, userSnapshot) {
          final effectiveUserId =
              userSnapshot.data?.id ?? authService.currentUser?.uid;

          if (effectiveUserId == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<List<OrderModel>>(
            stream: firestoreService.getUserOrders(effectiveUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Could not load orders.\n${snapshot.error}'),
                );
              }

              final allOrders = snapshot.data ?? [];

              final activeOrders =
                  allOrders.where((order) {
                    return order.status == OrderStatus.pending ||
                        order.status == OrderStatus.confirmed ||
                        order.status == OrderStatus.shipped;
                  }).toList();

              final historyOrders =
                  allOrders.where((order) {
                    return order.status == OrderStatus.delivered ||
                        order.status == OrderStatus.cancelled ||
                        order.status == OrderStatus.returned;
                  }).toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  _OrdersList(orders: activeOrders, isActive: true),
                  _OrdersList(orders: historyOrders, isActive: false),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<OrderModel> orders;
  final bool isActive;

  const _OrdersList({required this.orders, required this.isActive});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActive ? Icons.local_shipping_outlined : Icons.history,
                size: 64,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isActive ? 'No active orders' : 'No order history',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              isActive
                  ? 'Your ongoing orders will appear here'
                  : 'Your past orders will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryLight,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.goNamed('home'),
                child: const Text('Start Shopping'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return StaggeredFadeIn(
          index: index,
          child: _PremiumOrderCard(order: orders[index]),
        );
      },
    );
  }
}

class _PremiumOrderCard extends StatelessWidget {
  final OrderModel order;

  const _PremiumOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final totalItems = order.items.fold(0, (sum, i) => sum + i.quantity);
    final isDelivered = order.status == OrderStatus.delivered;
    final canCancel = order.status == OrderStatus.pending || 
                      order.status == OrderStatus.confirmed;

    return PremiumCard(
      onTap: () {
        // TODO: Navigate to Order Detail Screen
        // context.pushNamed('order-detail', pathParameters: {'id': order.id});
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: ID and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${order.id.substring(order.id.length - 6).toUpperCase()}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              _StatusBadge(status: order.status),
            ],
          ),

          const SizedBox(height: 12),

          // Image Preview List
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: order.items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = order.items[index];
                return Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.borderLight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: item.productImage,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) => Container(
                            color: AppTheme.backgroundLight,
                            child: const Icon(
                              Icons.image,
                              size: 20,
                              color: AppTheme.textSecondaryLight,
                            ),
                          ),
                      errorWidget:
                          (context, url, error) => Container(
                            color: AppTheme.backgroundLight,
                            child: const Icon(
                              Icons.broken_image,
                              size: 20,
                              color: AppTheme.textSecondaryLight,
                            ),
                          ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Info Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM d, yyyy').format(order.orderedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$totalItems Items',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              Text(
                '₹${order.totalAmount.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),

          // Action Buttons
          if (isDelivered) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Navigate to Add Product Screen with pre-filled data
                  // Usually we pick the first item or let user choose.
                  // For simplicity, we just open Add Product for now.
                  // In a real app, we'd pass the order item details.
                  context.pushNamed('add-product');
                },
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: const Text('Register for Service / Warranty'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                ),
              ),
            ),
          ],
          // Cancel Button for pending/confirmed orders
          if (canCancel) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showCancelDialog(context, order),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancel Order'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: const BorderSide(color: AppTheme.error),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: Text(
          'Are you sure you want to cancel Order #${order.id.substring(order.id.length - 6).toUpperCase()}?\n\nThis action cannot be undone.',
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
              backgroundColor: AppTheme.error,
            ),
            child: const Text('Yes, Cancel Order'),
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
    IconData icon;

    switch (status) {
      case OrderStatus.pending:
        color = AppTheme.warning;
        icon = Icons.schedule;
        break;
      case OrderStatus.confirmed:
        color = AppTheme.infoDark;
        icon = Icons.check_circle_outline;
        break;
      case OrderStatus.shipped:
        color = AppTheme.primary;
        icon = Icons.local_shipping_outlined;
        break;
      case OrderStatus.delivered:
        color = AppTheme.success;
        icon = Icons.verified_outlined;
        break;
      case OrderStatus.cancelled:
        color = AppTheme.error;
        icon = Icons.cancel_outlined;
        break;
      case OrderStatus.returned:
        color = AppTheme.neutral;
        icon = Icons.assignment_return_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
