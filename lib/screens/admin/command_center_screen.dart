import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class CommandCenterScreen extends StatelessWidget {
  const CommandCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Command Center',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  _AdminAvatar(),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Stats Cards
              FutureBuilder<Map<String, dynamic>>(
                future: firestoreService.getDashboardStats(),
                builder: (context, snapshot) {
                  final stats = snapshot.data ?? {};
                  
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Pending Requests',
                              value: '${stats['pendingRequests'] ?? 0}',
                              icon: Icons.build_circle,
                              color: AppTheme.warning,
                              onTap: () => context.goNamed('admin-requests'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _StatCard(
                              title: 'Pending Registrations',
                              value: '${stats['pendingRegistrations'] ?? 0}',
                              icon: Icons.verified,
                              color: AppTheme.primary,
                              onTap: () => context.goNamed('admin-warranty'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Total Users',
                              value: '${stats['totalUsers'] ?? 0}',
                              icon: Icons.people,
                              color: AppTheme.success,
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _StatCard(
                              title: 'Pending Payouts',
                              value: '₹${NumberFormat('#,##0').format(stats['pendingPayouts'] ?? 0)}',
                              icon: Icons.payments,
                              color: const Color(0xFF8B5CF6),
                              onTap: () => context.goNamed('admin-payouts'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 32),
              
              // Quick Actions
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.build,
                      label: 'Service Requests',
                      onTap: () => context.goNamed('admin-requests'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.verified_user,
                      label: 'Warranty Validation',
                      onTap: () => context.goNamed('admin-warranty'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.analytics,
                      label: 'Reports',
                      onTap: () => context.goNamed('admin-reports'),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Recent Activity
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Activity',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.goNamed('admin-requests'),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: firestoreService.getRecentActivity(limit: 5),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final activities = snapshot.data ?? [];

                  if (activities.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 48,
                              color: AppTheme.textSecondaryLight.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No recent activity',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Column(
                      children: activities.asMap().entries.map((entry) {
                        final activity = entry.value;
                        final isLast = entry.key == activities.length - 1;
                        
                        return Column(
                          children: [
                            _ActivityItem(
                              title: activity['title'] ?? '',
                              description: activity['description'] ?? '',
                              status: activity['status'] ?? '',
                              timestamp: activity['timestamp'] as DateTime,
                            ),
                            if (!isLast) const Divider(height: 1),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              const Icon(Icons.person_outline, size: 20),
              const SizedBox(width: 12),
              Text('Profile', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              const Icon(Icons.settings_outlined, size: 20),
              const SizedBox(width: 12),
              Text('Settings', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout, size: 20, color: AppTheme.error),
              const SizedBox(width: 12),
              Text('Logout', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.error)),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        if (value == 'logout') {
          await authService.signOut();
          if (context.mounted) {
            context.go('/login');
          }
        }
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.admin_panel_settings,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.borderLight),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                Icon(
                  Icons.arrow_forward,
                  color: AppTheme.textSecondaryLight.withOpacity(0.5),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String title;
  final String description;
  final String status;
  final DateTime timestamp;

  const _ActivityItem({
    required this.title,
    required this.description,
    required this.status,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.build_outlined,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warningLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getTimeAgo(timestamp),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryLight,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }
}
