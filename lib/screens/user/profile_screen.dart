import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../models/user_model.dart';
import '../../models/user_appliance_model.dart';
import '../../models/service_request_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/common/premium_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
                    child: _buildPremiumHeader(context, user),
                  ),
                ),
              ),

              // Stats Card
              SliverToBoxAdapter(
                child: StaggeredFadeIn(
                  index: 0,
                  child: _buildStatsCard(context, user),
                ),
              ),

              // Menu Items
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StaggeredFadeIn(
                        index: 1,
                        child: _buildMenuSection(context, 'Account', [
                          _PremiumMenuItem(
                            icon: Icons.person_outline,
                            title: 'Edit Profile',
                            subtitle: 'Update your personal information',
                            iconColor: AppTheme.primary,
                            onTap: () => context.pushNamed('edit-profile'),
                          ),
                          _PremiumMenuItem(
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            subtitle: 'Manage your notification preferences',
                            iconColor: AppTheme.warning,
                            onTap: () => context.push('/notifications'),
                          ),
                          _PremiumMenuItem(
                            icon: Icons.location_on_outlined,
                            title: 'Saved Addresses',
                            subtitle: 'Manage your service addresses',
                            iconColor: AppTheme.success,
                            onTap: () => context.push('/saved-addresses'),
                          ),
                          _PremiumMenuItem(
                            icon: Icons.redeem,
                            title: 'Redeem Referral Code',
                            subtitle: 'Enter code to get rewards',
                            iconColor: Colors.purple,
                            onTap: () => _showRedeemDialog(context),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      StaggeredFadeIn(
                        index: 2,
                        child: _buildMenuSection(context, 'App Settings', [
                          _PremiumMenuItem(
                            icon: Icons.dark_mode_outlined,
                            title: 'Theme',
                            subtitle: 'Light / Dark / System',
                            iconColor: const Color(0xFF8B5CF6),
                            onTap: () {
                              final themeProvider =
                                  context.read<ThemeProvider>();
                              showDialog(
                                context: context,
                                builder: (context) => _ThemeSelectionDialog(
                                  currentTheme: themeProvider.themeMode,
                                  onThemeSelected: (mode) {
                                    themeProvider.setThemeMode(mode);
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          ),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      StaggeredFadeIn(
                        index: 3,
                        child: _buildMenuSection(context, 'Support', [
                          _PremiumMenuItem(
                            icon: Icons.help_outline,
                            title: 'Help Center',
                            subtitle: 'FAQs and support articles',
                            iconColor: AppTheme.accent1,
                            onTap: () => context.push('/help-center'),
                          ),
                          _PremiumMenuItem(
                            icon: Icons.chat_outlined,
                            title: 'Contact Support',
                            subtitle: 'Get in touch with our team',
                            iconColor: AppTheme.accent2,
                            onTap: () => context.push('/contact-support'),
                          ),
                          _PremiumMenuItem(
                            icon: Icons.description_outlined,
                            title: 'Terms & Conditions',
                            iconColor: AppTheme.textSecondary(context),
                            onTap: () => context.push('/terms'),
                          ),
                          _PremiumMenuItem(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy Policy',
                            iconColor: AppTheme.textSecondary(context),
                            onTap: () => context.push('/privacy'),
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

  Widget _buildPremiumHeader(BuildContext context, UserModel? user) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 20,
        20,
        50,
      ),
      decoration: BoxDecoration(gradient: AppTheme.primaryGradientExtended),
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
          Positioned(
            left: -30,
            bottom: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(10),
              ),
            ),
          ),
          // Content
          Column(
            children: [
              // Avatar with gradient border
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
                  radius: 48,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      user?.photoUrl != null
                          ? NetworkImage(user!.photoUrl!)
                          : null,
                  child:
                      user?.photoUrl == null
                          ? Text(
                            (user?.displayName ?? 'U')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 40,
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
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            user?.phone ?? user?.email ?? '',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, UserModel? user) {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final userId = user?.id;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primary.withAlpha(15),
              AppTheme.primaryLight.withAlpha(8),
            ],
          ),
          border: Border.all(color: AppTheme.primary.withAlpha(30), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withAlpha(15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withAlpha(240),
            borderRadius: BorderRadius.circular(23),
          ),
          child: Row(
            children: [
              // Appliances count
              StreamBuilder<List<UserApplianceModel>>(
                stream:
                    userId != null
                        ? firestoreService.getUserProducts(userId)
                        : Stream.value([]),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return _StatItem(
                    icon: Icons.inventory_2,
                    label: 'Appliances',
                    value: '$count',
                    color: AppTheme.primary,
                  );
                },
              ),
              Container(
                width: 1,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.border(context).withAlpha(0),
                      AppTheme.border(context),
                      AppTheme.border(context).withAlpha(0),
                    ],
                  ),
                ),
              ),
              // Requests count
              StreamBuilder<List<ServiceRequestModel>>(
                stream:
                    userId != null
                        ? firestoreService.getUserServiceRequests(userId)
                        : Stream.value([]),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return _StatItem(
                    icon: Icons.build_circle,
                    label: 'Requests',
                    value: '$count',
                    color: AppTheme.warning,
                  );
                },
              ),
              Container(
                width: 1,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.border(context).withAlpha(0),
                      AppTheme.border(context),
                      AppTheme.border(context).withAlpha(0),
                    ],
                  ),
                ),
              ),
              // Rewards (from referrals)
              StreamBuilder<UserModel?>(
                stream: authService.userModelStream(),
                builder: (context, snapshot) {
                  final earnings = snapshot.data?.totalEarnings ?? 0;
                  return _StatItem(
                    icon: Icons.card_giftcard,
                    label: 'Rewards',
                    value: '₹${earnings.toStringAsFixed(0)}',
                    color: AppTheme.success,
                  );
                },
              ),
            ],
          ),
        ),
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
                  color: AppTheme.textSecondary(context),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border(context).withAlpha(150)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withAlpha(8),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 8,
                offset: const Offset(0, 2),
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
                      color: AppTheme.border(context).withAlpha(100),
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
                'VIGNESH AGENCIES SERVICE HUB',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary(context).withAlpha(150),
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
              color: AppTheme.textSecondary(context).withAlpha(120),
            ),
          ),
        ],
      ),
    );
  }

  void _showRedeemDialog(BuildContext context) {
    final controller = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Redeem Referral Code'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter a referral code from a friend to unlock special benefits.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Referral Code',
                        hintText: 'e.g. VA-1234',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed:
                        isLoading
                            ? null
                            : () async {
                              final code = controller.text.trim();
                              if (code.isEmpty) return;

                              setState(() => isLoading = true);
                              try {
                                await context
                                    .read<AuthService>()
                                    .redeemReferral(code);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Referral code redeemed successfully!',
                                      ),
                                      backgroundColor: AppTheme.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.toString().replaceAll(
                                          'Exception: ',
                                          '',
                                        ),
                                      ),
                                      backgroundColor: AppTheme.error,
                                    ),
                                  );
                                }
                              } finally {
                                if (context.mounted)
                                  setState(() => isLoading = false);
                              }
                            },
                    child:
                        isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Redeem'),
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
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          AnimatedCounter(
            value: int.tryParse(value) ?? 0,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary(context)),
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
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary(context)),
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
                color: AppTheme.textSecondary(context),
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

class _ThemeSelectionDialog extends StatelessWidget {
  final ThemeMode currentTheme;
  final Function(ThemeMode) onThemeSelected;

  const _ThemeSelectionDialog({
    required this.currentTheme,
    required this.onThemeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Theme',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            _buildThemeOption(
              context,
              'System Default',
              ThemeMode.system,
              Icons.brightness_auto,
            ),
            const SizedBox(height: 12),
            _buildThemeOption(
              context,
              'Light Mode',
              ThemeMode.light,
              Icons.light_mode,
            ),
            const SizedBox(height: 12),
            _buildThemeOption(
              context,
              'Dark Mode',
              ThemeMode.dark,
              Icons.dark_mode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String title,
    ThemeMode mode,
    IconData icon,
  ) {
    final isSelected = currentTheme == mode;
    return InkWell(
      onTap: () => onThemeSelected(mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : Theme.of(context).dividerColor.withAlpha(50),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary(context),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.primary
                    : Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
