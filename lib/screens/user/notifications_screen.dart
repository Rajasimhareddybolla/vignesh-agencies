import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Mock notifications
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': '1',
      'title': 'Service Request Update',
      'body':
          'Your service request #SR-1001 has been assigned to a technician.',
      'time': '2 hours ago',
      'isRead': false,
      'type': 'service',
    },
    {
      'id': '2',
      'title': 'Welcome to V-Guard',
      'body':
          'Thanks for joining V-Guard District Service Hub! Register your products to get started.',
      'time': '1 day ago',
      'isRead': true,
      'type': 'info',
    },
    {
      'id': '3',
      'title': 'Warranty Expiring Soon',
      'body':
          'The warranty for your Victo 15L Heater expires in 30 days. Renew now!',
      'time': '2 days ago',
      'isRead': true,
      'type': 'warning',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications'),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: () {
                setState(() {
                  for (var n in _notifications) {
                    n['isRead'] = true;
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read'),
                  ),
                );
              },
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_off_outlined,
                      size: 40,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Notifications',
                    style: Theme.of(context).textTheme.titleLarge,
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
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                final isRead = notification['isRead'] as bool;

                return Dismissible(
                  key: Key(notification['id'] as String),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    color: AppTheme.error,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    setState(() {
                      _notifications.removeAt(index);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notification removed')),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isRead
                          ? Colors.transparent
                          : AppTheme.primary.withOpacity(0.05),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: _getIconColor(
                          notification['type'] as String,
                        ).withOpacity(0.1),
                        child: Icon(
                          _getIcon(notification['type'] as String),
                          color: _getIconColor(notification['type'] as String),
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification['title'] as String,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                  ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            notification['body'] as String,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textSecondaryLight),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notification['time'] as String,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppTheme.textSecondaryLight,
                                  fontSize: 10,
                                ),
                          ),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          notification['isRead'] = true;
                        });
                        // TODO: Navigate based on notification type
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'service':
        return Icons.build_circle_outlined;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'info':
      default:
        return Icons.info_outline;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'service':
        return AppTheme.primary;
      case 'warning':
        return AppTheme.warning;
      case 'info':
      default:
        return Colors.blue;
    }
  }
}
