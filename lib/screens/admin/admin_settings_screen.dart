import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/premium_widgets.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    return Scaffold(
      body: StreamBuilder<UserModel?>(
        stream: authService.userModelStream(),
        builder: (context, snapshot) {
          final user = snapshot.data;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Premium Header
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _headerController,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.1),
                      end: Offset.zero,
                    ).animate(_headerController),
                    child: _buildHeader(context, user),
                  ),
                ),
              ),

              // Settings Menu
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StaggeredFadeIn(
                        index: 0,
                        child: _buildMenuSection(context, 'Account', [
                          _PremiumMenuItem(
                            icon: Icons.person_outline,
                            title: 'Edit Profile',
                            subtitle: 'Update your admin information',
                            iconColor: AppTheme.primary,
                            onTap: () => context.push('/edit-profile'),
                          ),
                          _PremiumMenuItem(
                            icon: Icons.notifications_outlined,
                            title: 'Notification Settings',
                            subtitle: 'Configure admin alerts',
                            iconColor: AppTheme.warning,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Notification settings coming soon',
                                  ),
                                ),
                              );
                            },
                          ),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      StaggeredFadeIn(
                        index: 1,
                        child: _buildMenuSection(context, 'App Settings', [
                          _PremiumMenuItem(
                            icon: Icons.dark_mode_outlined,
                            title: 'Theme',
                            subtitle: 'Light / Dark / System',
                            iconColor: const Color(0xFF8B5CF6),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Theme settings coming soon'),
                                ),
                              );
                            },
                          ),
                          _PremiumMenuItem(
                            icon: Icons.language_outlined,
                            title: 'Language',
                            subtitle: 'English',
                            iconColor: AppTheme.infoDark,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Language settings coming soon',
                                  ),
                                ),
                              );
                            },
                          ),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      StaggeredFadeIn(
                        index: 2,
                        child: _buildMenuSection(context, 'Support', [
                          _PremiumMenuItem(
                            icon: Icons.help_outline,
                            title: 'Help Center',
                            subtitle: 'FAQs and support articles',
                            iconColor: AppTheme.accent1,
                            onTap: () => context.push('/help-center'),
                          ),
                          _PremiumMenuItem(
                            icon: Icons.info_outline,
                            title: 'About',
                            subtitle: 'App info and version',
                            iconColor: AppTheme.textSecondaryLight,
                            onTap: () {
                              showAboutDialog(
                                context: context,
                                applicationName: 'Vignesh Agencies Admin',
                                applicationVersion: '1.0.0',
                                applicationLegalese: '© 2024 Vignesh Agencies.',
                              );
                            },
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),
                      StaggeredFadeIn(
                        index: 3,
                        child: _buildLogoutButton(context, authService),
                      ),
                      const SizedBox(height: 16),
                      _buildAppVersion(context),
                      const SizedBox(height: 24),
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

  Widget _buildHeader(BuildContext context, UserModel? user) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 20,
        20,
        30,
      ),
      decoration: BoxDecoration(gradient: AppTheme.adminGradient),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -50,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(15),
              ),
            ),
          ),
          // Content
          Column(
            children: [
              // Avatar
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.white, Colors.white70],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFF1a1a2e),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user?.displayName ?? 'Admin',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(40),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified,
                      color: AppTheme.primaryLight,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Administrator',
                      style: TextStyle(
                        color: AppTheme.primaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(
    BuildContext context,
    String title,
    List<Widget> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondaryLight,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderLight.withAlpha(150)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withAlpha(8),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i < items.length - 1)
                    Divider(
                      height: 1,
                      indent: 70,
                      endIndent: 16,
                      color: AppTheme.borderLight.withAlpha(100),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthService authService) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          HapticFeedback.mediumImpact();
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => _LogoutConfirmDialog(),
          );

          if (confirm == true) {
            await authService.signOut();
            if (context.mounted) {
              context.go('/login');
            }
          }
        },
        icon: const Icon(Icons.logout, color: AppTheme.error),
        label: const Text('Logout', style: TextStyle(color: AppTheme.error)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.error),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildAppVersion(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 20,
                height: 2,
                color: AppTheme.primary.withAlpha(50),
              ),
              const SizedBox(width: 8),
              Text(
                'VIGNESH AGENCIES ADMIN',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondaryLight.withAlpha(150),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 2,
                color: AppTheme.primary.withAlpha(50),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Version 1.0.0',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryLight.withAlpha(120),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  const _PremiumMenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [iconColor.withAlpha(30), iconColor.withAlpha(15)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
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
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondaryLight),
          ],
        ),
      ),
    );
  }
}

class _LogoutConfirmDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout, color: AppTheme.error, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              'Logout',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to logout?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
