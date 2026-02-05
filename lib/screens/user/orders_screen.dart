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
          unselectedLabelColor: AppTheme.textSecondary(context),
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

class _OrdersList extends StatefulWidget {
  final List<OrderModel> orders;
  final bool isActive;

  const _OrdersList({required this.orders, required this.isActive});

  @override
  State<_OrdersList> createState() => _OrdersListState();
}

class _OrdersListState extends State<_OrdersList> {
  String _searchQuery = '';
  OrderStatus? _selectedStatus;
  DateTimeRange? _selectedDateRange;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<OrderModel> get _filteredOrders {
    var filtered = widget.orders;

    // Filter by search query (order ID or product name)
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((order) {
            final queryLower = _searchQuery.toLowerCase();
            final orderIdMatch = order.id.toLowerCase().contains(queryLower);
            final productMatch = order.items.any(
              (item) => item.productName.toLowerCase().contains(queryLower),
            );
            return orderIdMatch || productMatch;
          }).toList();
    }

    // Filter by status
    if (_selectedStatus != null) {
      filtered =
          filtered.where((order) => order.status == _selectedStatus).toList();
    }

    // Filter by date range
    if (_selectedDateRange != null) {
      filtered =
          filtered.where((order) {
            return order.orderedAt.isAfter(
                  _selectedDateRange!.start.subtract(const Duration(days: 1)),
                ) &&
                order.orderedAt.isBefore(
                  _selectedDateRange!.end.add(const Duration(days: 1)),
                );
          }).toList();
    }

    return filtered;
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedStatus = null;
      _selectedDateRange = null;
    });
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedStatus != null ||
      _selectedDateRange != null;

  @override
  Widget build(BuildContext context) {
    if (widget.orders.isEmpty && !_hasActiveFilters) {
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
                widget.isActive ? Icons.local_shipping_outlined : Icons.history,
                size: 64,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isActive ? 'No active orders' : 'No order history',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isActive
                  ? 'Your ongoing orders will appear here'
                  : 'Your past orders will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary(context),
              ),
            ),
            if (widget.isActive) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pushNamed('product-catalog'),
                child: const Text('Start Shopping'),
              ),
            ],
          ],
        ),
      );
    }

    final filteredOrders = _filteredOrders;

    return Column(
      children: [
        // Search and Filter Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search by order ID or product name...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon:
                      _searchQuery.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                          : null,
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Date Range Filter
                    _FilterChip(
                      icon: Icons.calendar_today,
                      label:
                          _selectedDateRange != null
                              ? '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}'
                              : 'Date Range',
                      isSelected: _selectedDateRange != null,
                      onTap: () => _showDateRangePicker(context),
                    ),
                    const SizedBox(width: 8),
                    // Status Filter Chips
                    ..._getStatusFilters().map(
                      (status) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          icon: _getStatusIcon(status),
                          label: status.displayName,
                          isSelected: _selectedStatus == status,
                          onTap: () {
                            setState(() {
                              _selectedStatus =
                                  _selectedStatus == status ? null : status;
                            });
                          },
                        ),
                      ),
                    ),
                    if (_hasActiveFilters)
                      _FilterChip(
                        icon: Icons.clear_all,
                        label: 'Clear All',
                        isSelected: false,
                        isDestructive: true,
                        onTap: _clearFilters,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Results Count
        if (_hasActiveFilters)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${filteredOrders.length} order${filteredOrders.length != 1 ? 's' : ''} found',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),

        // Orders List
        Expanded(
          child:
              filteredOrders.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: AppTheme.textSecondary(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No orders match your filters',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Clear filters'),
                        ),
                      ],
                    ),
                  )
                  : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredOrders.length,
                    separatorBuilder:
                        (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return StaggeredFadeIn(
                        index: index,
                        child: _PremiumOrderCard(order: filteredOrders[index]),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  List<OrderStatus> _getStatusFilters() {
    if (widget.isActive) {
      return [OrderStatus.pending, OrderStatus.confirmed, OrderStatus.shipped];
    } else {
      return [
        OrderStatus.delivered,
        OrderStatus.cancelled,
        OrderStatus.returned,
      ];
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.schedule;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline;
      case OrderStatus.shipped:
        return Icons.local_shipping_outlined;
      case OrderStatus.delivered:
        return Icons.verified_outlined;
      case OrderStatus.cancelled:
        return Icons.cancel_outlined;
      case OrderStatus.returned:
        return Icons.assignment_return_outlined;
    }
  }

  Future<void> _showDateRangePicker(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange:
          _selectedDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDestructive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isDestructive
            ? AppTheme.error
            : (isSelected ? AppTheme.primary : AppTheme.textSecondary(context));

    return Material(
      color:
          isSelected
              ? AppTheme.primary.withAlpha(25)
              : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.borderLight,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
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
    final canCancel =
        order.status == OrderStatus.pending ||
        order.status == OrderStatus.confirmed;

    return PremiumCard(
      onTap: () {
        context.pushNamed(
          'order-detail',
          pathParameters: {'orderId': order.id},
        );
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
                            color: AppTheme.background(context),
                            child: Icon(
                              Icons.image,
                              size: 20,
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                      errorWidget:
                          (context, url, error) => Container(
                            color: AppTheme.background(context),
                            child: Icon(
                              Icons.broken_image,
                              size: 20,
                              color: AppTheme.textSecondary(context),
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
                      color: AppTheme.textSecondary(context),
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
                  if (order.items.isEmpty) return;

                  if (order.items.length == 1) {
                    // Single item - Go directly
                    context.pushNamed(
                      'add-product',
                      extra: {
                        'sourceOrder': order,
                        'sourceOrderItem': order.items.first,
                      },
                    );
                  } else {
                    // Multi items - Show selection sheet
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
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
                                    separatorBuilder:
                                        (ctx, i) => const Divider(),
                                    itemBuilder: (context, index) {
                                      final item = order.items[index];
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                        trailing: const Icon(
                                          Icons.chevron_right,
                                        ),
                                        onTap: () {
                                          Navigator.pop(context); // Close sheet
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
                      const Expanded(
                        child: Text(
                          'Cancel Order',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order.id.substring(order.id.length - 6).toUpperCase()}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Please select a reason for cancellation:',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 12),
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
