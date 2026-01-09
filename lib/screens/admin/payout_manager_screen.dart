import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

class PayoutManagerScreen extends StatelessWidget {
  const PayoutManagerScreen({super.key});

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
                    'Referral Payouts',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage pending referral commissions',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            
            // Summary Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: StreamBuilder<List<UserModel>>(
                stream: firestoreService.getUsersWithPendingPayouts(),
                builder: (context, snapshot) {
                  final users = snapshot.data ?? [];
                  final totalPending = users.fold<double>(
                    0,
                    (sum, user) => sum + user.pendingPayout,
                  );
                  
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Pending Payouts',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹ ${NumberFormat('#,##0').format(totalPending)}',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.payments,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Users with Pending Payouts
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Users with Pending Payouts',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: firestoreService.getUsersWithPendingPayouts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = snapshot.data ?? [];

                  if (users.isEmpty) {
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
                            'All payouts cleared!',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No pending referral commissions',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      return _PayoutCard(
                        user: users[index],
                        onMarkPaid: () => _markAsPaid(context, users[index]),
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

  Future<void> _markAsPaid(BuildContext context, UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payout'),
        content: Text(
          'Mark ₹${NumberFormat('#,##0').format(user.pendingPayout)} as paid to ${user.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final firestoreService = context.read<FirestoreService>();
      await firestoreService.markUserPayoutComplete(user.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payout marked as complete for ${user.displayName}'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    }
  }
}

class _PayoutCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onMarkPaid;

  const _PayoutCard({
    required this.user,
    required this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getAvatarColor(user.displayName),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.displayName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.phone ?? user.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Total: ₹${NumberFormat('#,##0').format(user.totalEarnings)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Pending Amount & Action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹ ${NumberFormat('#,##0').format(user.pendingPayout)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: onMarkPaid,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('Mark Paid'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
      const Color(0xFF3F51B5),
      const Color(0xFF2196F3),
      const Color(0xFF009688),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }
}
