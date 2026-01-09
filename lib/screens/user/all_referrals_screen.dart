import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../models/referral_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class AllReferralsScreen extends StatelessWidget {
  const AllReferralsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('All Referrals'),
      ),
      body: StreamBuilder<List<ReferralModel>>(
        stream: authService.currentUser != null
            ? firestoreService.getUserReferrals(authService.currentUser!.uid)
            : Stream.value([]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final referrals = snapshot.data ?? [];

          if (referrals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: AppTheme.textSecondaryLight.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No referrals yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: referrals.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final referral = referrals[index];
              return _ReferralCard(referral: referral);
            },
          );
        },
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  final ReferralModel referral;

  const _ReferralCard({required this.referral});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    Color statusBgColor;
    String statusText;

    switch (referral.status) {
      case ReferralStatus.pending:
        statusColor = AppTheme.warning;
        statusBgColor = AppTheme.warningLight;
        statusText = 'Pending';
        break;
      case ReferralStatus.purchased:
        statusColor = AppTheme.success;
        statusBgColor = AppTheme.successLight;
        statusText = 'Purchased';
        break;
      case ReferralStatus.paid:
        statusColor = AppTheme.primary;
        statusBgColor = AppTheme.primary.withOpacity(0.1);
        statusText = 'Paid';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getAvatarColor(referral.refereeName ?? 'U'),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (referral.refereeName ?? 'U').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  referral.refereeName ?? 'Unknown',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat(
                    'MMM dd, yyyy • hh:mm a',
                  ).format(referral.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (referral.status != ReferralStatus.pending)
                Text(
                  '+ ₹ ${NumberFormat('#,##0').format(referral.commission)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                )
              else
                Text(
                  'Pending',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryLight,
                  ),
                ),

              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  statusText,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
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
