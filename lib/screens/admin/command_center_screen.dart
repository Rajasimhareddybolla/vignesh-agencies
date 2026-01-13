import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/premium_widgets.dart';

class CommandCenterScreen extends StatefulWidget {
  const CommandCenterScreen({super.key});

  @override
  State<CommandCenterScreen> createState() => _CommandCenterScreenState();
}

class _CommandCenterScreenState extends State<CommandCenterScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;

  @override
  void initState() {
    super.initState();
    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          setState(() {});
          await Future.delayed(const Duration(seconds: 1));
        },
        color: AppTheme.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Premium Header
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _headerAnimationController,
                child: _buildPremiumHeader(context),
              ),
            ),

            // Stats Grid
            SliverToBoxAdapter(
              child: FutureBuilder<Map<String, dynamic>>(
                future: firestoreService.getDashboardStats(),
                builder: (context, snapshot) {
                  final stats = snapshot.data ?? {};
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Dashboard',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PulsingDot(color: AppTheme.success, size: 6),
                                  SizedBox(width: 4),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: AppTheme.success,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: StaggeredFadeIn(
                                index: 0,
                                child: _PremiumStatCard(
                                  title: 'Pending Requests',
                                  value:
                                      (stats['pendingRequests'] as num?)
                                          ?.toInt() ??
                                      0,
                                  icon: Icons.build_circle,
                                  color: AppTheme.warning,
                                  onTap: () =>
                                      context.goNamed('admin-requests'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StaggeredFadeIn(
                                index: 1,
                                child: _PremiumStatCard(
                                  title: 'Registrations',
                                  value:
                                      (stats['pendingRegistrations'] as num?)
                                          ?.toInt() ??
                                      0,
                                  icon: Icons.verified,
                                  color: AppTheme.primary,
                                  onTap: () =>
                                      context.goNamed('admin-warranty'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StaggeredFadeIn(
                                index: 2,
                                child: _PremiumStatCard(
                                  title: 'Total Users',
                                  value:
                                      (stats['totalUsers'] as num?)?.toInt() ??
                                      0,
                                  icon: Icons.people,
                                  color: AppTheme.success,
                                  onTap: () {},
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StaggeredFadeIn(
                                index: 3,
                                child: _PremiumStatCard(
                                  title: 'Payouts',
                                  value:
                                      (stats['pendingPayouts'] as num?)
                                          ?.toInt() ??
                                      0,
                                  prefix: '₹',
                                  icon: Icons.payments,
                                  color: AppTheme.accent1,
                                  onTap: () => context.goNamed('admin-payouts'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Quick Actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildQuickActions(context),
                  ],
                ),
              ),
            ),

            // Recent Activity
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Activity',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.goNamed('admin-requests'),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View All'),
                    ),
                  ],
                ),
              ),
            ),

            StreamBuilder<List<Map<String, dynamic>>>(
              stream: firestoreService.getRecentActivity(limit: 5),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }

                final activities = snapshot.data ?? [];

                if (activities.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _buildEmptyActivity(context),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => StaggeredFadeIn(
                        index: index,
                        child: _PremiumActivityCard(
                          activity: activities[index],
                        ),
                      ),
                      childCount: activities.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context) {
    final authService = context.read<AuthService>();
    final greeting = _getGreeting();

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        24,
      ),
      decoration: BoxDecoration(
        gradient: AppTheme.adminGradient,
      ),
      child: Stack(
        children: [
          // Decorative elements
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withAlpha(20),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(5),
              ),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withAlpha(40),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.admin_panel_settings,
                                    color: AppTheme.primaryLight,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'ADMIN',
                                    style: TextStyle(
                                      color: AppTheme.primaryLight,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          greeting,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white.withAlpha(180)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Command Center',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat(
                            'EEEE, MMMM d, yyyy',
                          ).format(DateTime.now()),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white.withAlpha(120)),
                        ),
                      ],
                    ),
                  ),
                  _AdminAvatar(),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 👋';
    if (hour < 17) return 'Good Afternoon ☀️';
    return 'Good Evening 🌙';
  }

  Widget _buildQuickActions(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _PremiumQuickAction(
            icon: Icons.build,
            label: 'Service\nRequests',
            color: AppTheme.warning,
            onTap: () {
              HapticFeedback.lightImpact();
              context.goNamed('admin-requests');
            },
          ),
          const SizedBox(width: 12),
          _PremiumQuickAction(
            icon: Icons.verified_user,
            label: 'Warranty\nValidation',
            color: AppTheme.primary,
            onTap: () {
              HapticFeedback.lightImpact();
              context.goNamed('admin-warranty');
            },
          ),
          const SizedBox(width: 12),
          _PremiumQuickAction(
            icon: Icons.payments,
            label: 'Payout\nManager',
            color: const Color(0xFF8B5CF6),
            onTap: () {
              HapticFeedback.lightImpact();
              context.goNamed('admin-payouts');
            },
          ),
          const SizedBox(width: 12),
          _PremiumQuickAction(
            icon: Icons.analytics,
            label: 'View\nReports',
            color: AppTheme.success,
            onTap: () {
              HapticFeedback.lightImpact();
              context.goNamed('admin-reports');
            },
          ),
          const SizedBox(width: 12),
          _PremiumQuickAction(
            icon: Icons.campaign,
            label: 'Send\nNotification',
            color: const Color(0xFFEC4899),
            onTap: () {
              HapticFeedback.lightImpact();
              context.goNamed('admin-notifications');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivity(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inbox_outlined,
                size: 48,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No recent activity',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Activity will appear here as users interact',
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

class _AdminAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 8,
      itemBuilder: (context) => [
        _buildMenuItem(context, 'profile', Icons.person_outline, 'Profile'),
        _buildMenuItem(
          context,
          'settings',
          Icons.settings_outlined,
          'Settings',
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          context,
          'logout',
          Icons.logout,
          'Logout',
          isDestructive: true,
        ),
      ],
      onSelected: (value) async {
        HapticFeedback.mediumImpact();
        switch (value) {
          case 'profile':
            // Navigate to admin profile/edit profile
            context.push('/edit-profile');
            break;
          case 'settings':
            // Navigate to profile which has settings
            context.push('/profile');
            break;
          case 'logout':
            await authService.signOut();
            if (context.mounted) {
              context.go('/login');
            }
            break;
        }
      },
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [AppTheme.primary, AppTheme.primaryLight],
          ),
        ),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a2e),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.admin_panel_settings,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    BuildContext context,
    String value,
    IconData icon,
    String label, {
    bool isDestructive = false,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDestructive ? AppTheme.error : AppTheme.textPrimaryLight,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDestructive ? AppTheme.error : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumStatCard extends StatefulWidget {
  final String title;
  final int value;
  final String? prefix;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PremiumStatCard({
    required this.title,
    required this.value,
    this.prefix,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_PremiumStatCard> createState() => _PremiumStatCardState();
}

class _PremiumStatCardState extends State<_PremiumStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: 1 - (_controller.value * 0.02),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withAlpha(
                      (30 + _controller.value * 50).toInt(),
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                          gradient: LinearGradient(
                            colors: [
                              widget.color.withAlpha(40),
                              widget.color.withAlpha(20),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(widget.icon, color: widget.color, size: 22),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        color: AppTheme.textSecondaryLight.withAlpha(100),
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AnimatedCounter(
                    value: widget.value,
                    prefix: widget.prefix,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PremiumQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PremiumQuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withAlpha(40), color.withAlpha(20)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;

  const _PremiumActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withAlpha(30),
                  AppTheme.primaryLight.withAlpha(20),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.build_outlined,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['title'] ?? 'Activity',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  activity['description'] ?? '',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(activity['status']).withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  activity['status'] ?? '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _getStatusColor(activity['status']),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _getTimeAgo(activity['timestamp'] as DateTime?),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryLight.withAlpha(150),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return AppTheme.warning;
      case 'assigned':
        return AppTheme.primary;
      case 'resolved':
        return AppTheme.success;
      case 'escalated':
        return AppTheme.error;
      default:
        return AppTheme.textSecondaryLight;
    }
  }

  String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return DateFormat('MMM d').format(dateTime);
  }
}
