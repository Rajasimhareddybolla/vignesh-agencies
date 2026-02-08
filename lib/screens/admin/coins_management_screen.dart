import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

class CoinsManagementScreen extends StatefulWidget {
  const CoinsManagementScreen({super.key});

  @override
  State<CoinsManagementScreen> createState() => _CoinsManagementScreenState();
}

class _CoinsManagementScreenState extends State<CoinsManagementScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coins Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Coin Rate Settings',
            onPressed: () => _showCoinRateDialog(context, firestoreService),
          ),
        ],
      ),
      body: Column(
        children: [
          // Coin Rate Banner
          StreamBuilder<double>(
            stream: firestoreService.coinToRupeeRateStream(),
            builder: (context, snapshot) {
              final rate = snapshot.data ?? 1.0;
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withAlpha(60),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.monetization_on,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Coin Exchange Rate',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '1 Coin = ₹${rate.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () =>
                          _showCoinRateDialog(context, firestoreService),
                    ),
                  ],
                ),
              );
            },
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users by name or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          const SizedBox(height: 12),

          // Users with Coins List
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: firestoreService.getAllUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                var users = snapshot.data ?? [];

                // Filter users with coins > 0
                users = users.where((u) => u.digitalCoins > 0).toList();

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  users = users.where((u) {
                    return u.displayName.toLowerCase().contains(query) ||
                        (u.phone?.toLowerCase().contains(query) ?? false) ||
                        u.email.toLowerCase().contains(query);
                  }).toList();
                }

                // Sort by coins desc
                users.sort((a, b) => b.digitalCoins.compareTo(a.digitalCoins));

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.monetization_on_outlined,
                          size: 64,
                          color: AppTheme.textSecondary(context).withAlpha(80),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users with coins found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  );
                }

                return StreamBuilder<double>(
                  stream: firestoreService.coinToRupeeRateStream(),
                  builder: (context, rateSnapshot) {
                    final rate = rateSnapshot.data ?? 1.0;

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _UserCoinCard(
                          user: users[index],
                          coinRate: rate,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCoinRateDialog(
      BuildContext context, FirestoreService firestoreService) {
    final rateController = TextEditingController();

    // Load current rate
    firestoreService.getCoinToRupeeRate().then((rate) {
      rateController.text = rate.toStringAsFixed(2);
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.currency_rupee, color: Colors.amber),
            ),
            const SizedBox(width: 12),
            const Text('Coin Rate'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set how many rupees 1 coin is worth:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: rateController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '₹ per Coin',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final rate = double.tryParse(rateController.text);
              if (rate != null && rate > 0) {
                await firestoreService.setCoinToRupeeRate(rate);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Coin rate updated: 1 Coin = ₹${rate.toStringAsFixed(2)}'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _UserCoinCard extends StatelessWidget {
  final UserModel user;
  final double coinRate;

  const _UserCoinCard({required this.user, required this.coinRate});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final rupeeValue = user.digitalCoins * coinRate;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withAlpha(50),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primary.withAlpha(30),
                backgroundImage:
                    user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child: user.photoUrl == null
                    ? Text(
                        user.displayName.isNotEmpty
                            ? user.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.phone ?? user.email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary(context),
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on,
                          color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        NumberFormat('#,##0').format(user.digitalCoins),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[800],
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '≈ ₹${NumberFormat('#,##0.00').format(rupeeValue)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showDeductCoinsDialog(
                    context,
                    user,
                    firestoreService,
                  ),
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppTheme.error, size: 18),
                  label: const Text(
                    'Redeem / Deduct',
                    style: TextStyle(color: AppTheme.error, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAddCoinsDialog(
                    context,
                    user,
                    firestoreService,
                  ),
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppTheme.success, size: 18),
                  label: const Text(
                    'Add Coins',
                    style: TextStyle(color: AppTheme.success, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.success),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeductCoinsDialog(
    BuildContext context,
    UserModel user,
    FirestoreService firestoreService,
  ) {
    final coinsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Redeem / Deduct Coins'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${user.displayName} has ${NumberFormat('#,##0').format(user.digitalCoins)} coins',
              style: const TextStyle(color: Colors.grey),
            ),
            Text(
              '(Worth ₹${NumberFormat('#,##0.00').format(user.digitalCoins * coinRate)})',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: coinsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Coins to Deduct',
                suffixText: 'Coins',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.remove_circle_outline),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'These coins will be removed from the user\'s balance. Add the equivalent ₹ value to the bill manually.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              final coins = int.tryParse(coinsController.text) ?? 0;
              if (coins <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid number')),
                );
                return;
              }
              if (coins > user.digitalCoins) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Cannot deduct more than user has')),
                );
                return;
              }

              await firestoreService.deductUserCoins(user.id, coins);
              if (context.mounted) {
                Navigator.pop(context);
                final deductedValue = coins * coinRate;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Deducted $coins coins (₹${deductedValue.toStringAsFixed(2)}) from ${user.displayName}',
                    ),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
            child:
                const Text('Deduct', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddCoinsDialog(
    BuildContext context,
    UserModel user,
    FirestoreService firestoreService,
  ) {
    final coinsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Coins'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${user.displayName} currently has ${NumberFormat('#,##0').format(user.digitalCoins)} coins',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: coinsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Coins to Add',
                suffixText: 'Coins',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.add_circle_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final coins = int.tryParse(coinsController.text) ?? 0;
              if (coins <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid number')),
                );
                return;
              }

              await firestoreService.addUserCoins(user.id, coins);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Added $coins coins to ${user.displayName}'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
