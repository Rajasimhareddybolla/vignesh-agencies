import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app/theme.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final userId = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () async {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Text('All notifications marked as read'),
                    ],
                  ),
                  backgroundColor: AppTheme.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
          ),
        ],
      ),
      body: userId == null
          ? _buildEmptyState(context)
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _notificationService.getUserNotifications(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notifications = snapshot.data ?? [];

                if (notifications.isEmpty) {
                  return _buildEmptyState(context);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _PremiumNotificationCard(
                      notification: notification,
                      onTap: () async {
                        // Mark as read
                        if (notification['read'] != true) {
                          await _notificationService.markAsRead(
                            userId,
                            notification['id'],
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withAlpha(30),
                  AppTheme.primaryLight.withAlpha(20),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Notifications',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'You have no new notifications at this time.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumNotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const _PremiumNotificationCard({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRead = notification['read'] == true;
    final type = notification['type'] as String? ?? 'info';
    final discountPercent = notification['discountPercent'];
    final imageUrl = notification['imageUrl'] as String?;
    final createdAt = notification['createdAt'];

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : AppTheme.primary.withAlpha(8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isRead
                ? AppTheme.borderLight
                : AppTheme.primary.withAlpha(50),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image banner if promo offer
            if (_shouldShowBanner(type)) _buildOfferBanner(context, type),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getTypeColor(type).withAlpha(40),
                          _getTypeColor(type).withAlpha(20),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _getTypeIcon(type),
                      color: _getTypeColor(type),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Text Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification['title'] ?? 'Notification',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: isRead
                                          ? FontWeight.w500
                                          : FontWeight.w700,
                                    ),
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification['body'] ?? '',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.textSecondaryLight,
                                height: 1.4,
                              ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),

                        // Footer row
                        Row(
                          children: [
                            if (discountPercent != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${(discountPercent as num).toInt()}% OFF',
                                  style: const TextStyle(
                                    color: AppTheme.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Icon(
                              Icons.schedule,
                              size: 12,
                              color: AppTheme.textSecondaryLight.withAlpha(150),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(createdAt),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: AppTheme.textSecondaryLight
                                        .withAlpha(150),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowBanner(String type) {
    return type == 'offer' || type == 'festival';
  }

  Widget _buildOfferBanner(BuildContext context, String type) {
    // Use local assets based on type
    String assetPath;
    if (notification['title']?.toString().toLowerCase().contains('diwali') ==
        true) {
      assetPath = 'assets/images/diwali_offer.png';
    } else if (notification['title']?.toString().toLowerCase().contains(
          'christmas',
        ) ==
        true) {
      assetPath = 'assets/images/christmas_sale.png';
    } else if (notification['title']?.toString().toLowerCase().contains(
          'flash',
        ) ==
        true) {
      assetPath = 'assets/images/flash_sale.png';
    } else {
      assetPath = 'assets/images/diwali_offer.png'; // default
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Image.asset(
        assetPath,
        height: 120,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_getTypeColor(type), _getTypeColor(type).withAlpha(180)],
            ),
          ),
          child: Center(
            child: Icon(_getTypeIcon(type), color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'offer':
        return Icons.local_offer;
      case 'festival':
        return Icons.celebration;
      case 'reminder':
        return Icons.notifications_active;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'service':
        return Icons.build_circle_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'offer':
        return AppTheme.accent3;
      case 'festival':
        return AppTheme.accent4;
      case 'reminder':
        return AppTheme.primary;
      case 'warning':
        return AppTheme.warning;
      case 'service':
        return AppTheme.success;
      default:
        return AppTheme.info;
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'Just now';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return 'Just now';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d').format(dateTime);
  }
}
