import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    return Scaffold(
      body: StreamBuilder<UserModel?>(
        stream: authService.userModelStream(),
        builder: (context, snapshot) {
          final user = snapshot.data;

          return CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.of(context).padding.top + 20,
                    20,
                    24,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.primary, AppTheme.primaryLight],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Profile Avatar
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.white,
                          backgroundImage: user?.photoUrl != null
                              ? NetworkImage(user!.photoUrl!)
                              : null,
                          child: user?.photoUrl == null
                              ? Text(
                                  (user?.displayName ?? 'U')
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user?.displayName ?? 'User',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.phone ?? user?.email ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Stats Card
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Row(
                        children: [
                          _StatItem(
                            icon: Icons.inventory_2,
                            label: 'Products',
                            value: '3',
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppTheme.borderLight,
                          ),
                          _StatItem(
                            icon: Icons.build,
                            label: 'Requests',
                            value: '2',
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppTheme.borderLight,
                          ),
                          _StatItem(
                            icon: Icons.people,
                            label: 'Referrals',
                            value: '5',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Menu Items
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondaryLight,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _MenuCard(
                        children: [
                          _MenuItem(
                            icon: Icons.person_outline,
                            title: 'Edit Profile',
                            onTap: () => context.pushNamed('edit-profile'),
                          ),
                          _MenuItem(
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.error,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                '3',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            onTap: () => context.push('/notifications'),
                          ),
                          _MenuItem(
                            icon: Icons.location_on_outlined,
                            title: 'Saved Addresses',
                            onTap: () => context.push('/saved-addresses'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      Text(
                        'Support',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondaryLight,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _MenuCard(
                        children: [
                          _MenuItem(
                            icon: Icons.help_outline,
                            title: 'Help Center',
                            onTap: () => context.push('/help-center'),
                          ),
                          _MenuItem(
                            icon: Icons.chat_outlined,
                            title: 'Contact Support',
                            onTap: () => context.push('/contact-support'),
                          ),
                          _MenuItem(
                            icon: Icons.description_outlined,
                            title: 'Terms & Conditions',
                            onTap: () => context.push('/terms'),
                          ),
                          _MenuItem(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy Policy',
                            onTap: () => context.push('/privacy'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Logout Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Logout'),
                                content: const Text(
                                  'Are you sure you want to logout?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Logout'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await authService.signOut();
                              if (context.mounted) {
                                context.go('/login');
                              }
                            }
                          },
                          icon: const Icon(Icons.logout, color: AppTheme.error),
                          label: const Text(
                            'Logout',
                            style: TextStyle(color: AppTheme.error),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.error),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // App Version
                      Center(
                        child: Text(
                          'Version 1.0.0',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondaryLight),
                        ),
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primary, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondaryLight),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> children;

  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 20),
      ),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      trailing:
          trailing ??
          const Icon(Icons.chevron_right, color: AppTheme.textSecondaryLight),
      onTap: onTap,
    );
  }
}
