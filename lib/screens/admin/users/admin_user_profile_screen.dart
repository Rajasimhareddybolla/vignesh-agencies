import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/order_model.dart';
import '../../../models/service_request_model.dart';
import '../../../models/referral_model.dart';
import '../../../models/user_appliance_model.dart';
import '../../../services/firestore_service.dart';

class AdminUserProfileScreen extends StatelessWidget {
  final String userId;
  final String userName;

  const AdminUserProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(userName),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Orders'),
              Tab(text: 'Service Requests'),
              Tab(text: 'Products'),
              Tab(text: 'Referrals'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OrdersTab(userId: userId),
            _ServiceRequestsTab(userId: userId),
            _ProductsTab(userId: userId),
            _ReferralsTab(userId: userId),
          ],
        ),
      ),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  final String userId;
  const _OrdersTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    return StreamBuilder<List<OrderModel>>(
      stream: firestoreService.getUserOrders(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const Center(child: Text('No orders found'));

        final orders = snapshot.data!;
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return ListTile(
              title: Text(
                'Order #${order.id.substring(order.id.length - 6).toUpperCase()}',
              ),
              subtitle: Text(
                '${order.items.length} items • ₹${order.totalAmount}',
              ),
              trailing: Text(order.status.name.toUpperCase()),
            );
          },
        );
      },
    );
  }
}

class _ServiceRequestsTab extends StatelessWidget {
  final String userId;
  const _ServiceRequestsTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    return StreamBuilder<List<ServiceRequestModel>>(
      stream: firestoreService.getUserServiceRequests(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const Center(child: Text('No service requests found'));

        final requests = snapshot.data!;
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            return ListTile(
              title: Text(req.ticketNumber),
              subtitle: Text(req.issueType),
              trailing: Text(req.status.displayName),
            );
          },
        );
      },
    );
  }
}

class _ReferralsTab extends StatelessWidget {
  final String userId;
  const _ReferralsTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    return StreamBuilder<List<ReferralModel>>(
      stream: firestoreService.getUserReferrals(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const Center(child: Text('No referrals found'));

        final referrals = snapshot.data!;
        return ListView.builder(
          itemCount: referrals.length,
          itemBuilder: (context, index) {
            final ref = referrals[index];
            return ListTile(
              title: Text(ref.refereeName ?? 'Unknown'),
              subtitle: Text('Status: ${ref.status.displayName}'),
              trailing: Text('₹${ref.commission}'),
            );
          },
        );
      },
    );
  }
}

class _ProductsTab extends StatelessWidget {
  final String userId;
  const _ProductsTab({required this.userId});

  Future<void> _expireProduct(BuildContext context, String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Expire Warranty'),
            content: const Text(
              'Are you sure you want to manually expire the warranty for this product? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Expire',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      // ignore: use_build_context_synchronously
      if (!context.mounted) return;

      try {
        await context.read<FirestoreService>().expireUserAppliance(productId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Warranty expired successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    return StreamBuilder<List<UserApplianceModel>>(
      stream: firestoreService.getUserAppliances(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No registered products found'));
        }

        final products = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final isExpired = product.status == ProductStatus.expired;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      isExpired ? Colors.grey[200] : Colors.green[50],
                  child: Icon(
                    Icons.devices,
                    color: isExpired ? Colors.grey : Colors.green,
                  ),
                ),
                title: Text(
                  product.productName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Model: ${product.modelNumber}'),
                    Text('Status: ${product.status.displayName}'),
                  ],
                ),
                trailing:
                    !isExpired
                        ? IconButton(
                          icon: const Icon(
                            Icons.timer_off_outlined,
                            color: Colors.orange,
                          ),
                          tooltip: 'Expire Warranty',
                          onPressed: () => _expireProduct(context, product.id),
                        )
                        : const Icon(Icons.check_circle, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }
}
