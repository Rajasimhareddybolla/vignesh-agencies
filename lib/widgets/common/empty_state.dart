import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// A reusable empty state widget for displaying when lists are empty
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionText;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionText,
    this.onAction,
  });

  /// Factory for empty products
  factory EmptyState.noProducts({VoidCallback? onAddProduct}) {
    return EmptyState(
      icon: Icons.inventory_2_outlined,
      title: 'No Appliances Yet',
      subtitle:
          'Register your V-Guard products to track\nwarranty and request service',
      actionText: 'Add Your First Product',
      onAction: onAddProduct,
    );
  }

  /// Factory for empty service requests
  factory EmptyState.noRequests() {
    return const EmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'No Service Requests',
      subtitle: 'Your service requests will appear here',
    );
  }

  /// Factory for empty referrals
  factory EmptyState.noReferrals() {
    return const EmptyState(
      icon: Icons.people_outline,
      title: 'No Referrals Yet',
      subtitle: 'Start referring friends to earn rewards',
    );
  }

  /// Factory for empty notifications
  factory EmptyState.noNotifications() {
    return const EmptyState(
      icon: Icons.notifications_outlined,
      title: 'No Notifications',
      subtitle: 'You\'re all caught up!',
    );
  }

  /// Factory for search with no results
  factory EmptyState.noSearchResults() {
    return const EmptyState(
      icon: Icons.search_off,
      title: 'No Results Found',
      subtitle: 'Try adjusting your search or filters',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: AppTheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionText!),
            ),
          ],
        ],
      ),
    );
  }
}
