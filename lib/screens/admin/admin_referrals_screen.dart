import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../models/referral_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/status_badge.dart';

class AdminReferralsScreen extends StatefulWidget {
  const AdminReferralsScreen({super.key});

  @override
  State<AdminReferralsScreen> createState() => _AdminReferralsScreenState();
}

class _AdminReferralsScreenState extends State<AdminReferralsScreen> {
  ReferralStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Referral Management'),
        actions: [
          PopupMenuButton<ReferralStatus?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (status) {
              setState(() {
                _filterStatus = status;
              });
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(value: null, child: Text('All')),
                  ...ReferralStatus.values.map(
                    (status) => PopupMenuItem(
                      value: status,
                      child: Text(status.displayName),
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: StreamBuilder<List<ReferralModel>>(
        stream: firestoreService.getAllReferrals(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          var referrals = snapshot.data ?? [];

          // Filter
          if (_filterStatus != null) {
            referrals =
                referrals.where((r) => r.status == _filterStatus).toList();
          }

          // Sort by creation date descending
          referrals.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (referrals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: AppTheme.textSecondary(context).withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No referrals found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: referrals.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _AdminReferralCard(referral: referrals[index]);
            },
          );
        },
      ),
    );
  }
}

class _AdminReferralCard extends StatelessWidget {
  final ReferralModel referral;

  const _AdminReferralCard({required this.referral});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final isPending = referral.status == ReferralStatus.pending;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Code: ${referral.referralCode}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              StatusBadge.referralStatus(referral.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(referral.refereeName ?? 'Unknown Referee'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.phone, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(referral.refereePhone ?? 'No Phone'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commission',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '₹ ${NumberFormat('#,##0').format(referral.commission)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ),
              if (isPending)
                ElevatedButton(
                  onPressed:
                      () => _showApproveDialog(
                        context,
                        referral,
                        firestoreService,
                      ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Approve'),
                ),
              if (referral.status == ReferralStatus.approved)
                OutlinedButton(
                  onPressed: null, // Placeholder or allow changing reward
                  child: Text('Coins: ${referral.rewardCoins}'),
                ),
            ],
          ),
          const Divider(height: 24),
          Text(
            'Created: ${DateFormat('MMM d, yyyy h:mm a').format(referral.createdAt)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(
    BuildContext context,
    ReferralModel referral,
    FirestoreService service,
  ) {
    final coinController = TextEditingController(text: '100'); // Default coins

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Approve Referral'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Set Reward Coins for Referrer:'),
                TextField(
                  controller: coinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(suffixText: 'Coins'),
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
                  final coins = int.tryParse(coinController.text) ?? 0;
                  await service.approveReferral(referral.id, coins);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Referral Approved!'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                },
                child: const Text('Approve'),
              ),
            ],
          ),
    );
  }
}
