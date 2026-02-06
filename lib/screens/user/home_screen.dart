import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme.dart';
import '../../models/user_appliance_model.dart';
import '../../models/service_request_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../services/warranty_notification_service.dart';

import '../../widgets/common/premium_widgets.dart';
import '../../widgets/user/marketing_slider.dart';
import '../../services/cart_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late Animation<double> _headerAnimation;

  @override
  void initState() {
    super.initState();
    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOut,
    );
    _headerAnimationController.forward();

    // Initialize cart with user's persisted cart data
    _initializeCart();
  }

  Future<void> _initializeCart() async {
    try {
      final authService = context.read<AuthService>();
      final cartService = context.read<CartService>();
      final userId = await authService.getResolvedUserId();
      await cartService.initializeCart(userId);
    } catch (e) {
      // Silently fail - cart will just be empty
      debugPrint('Error initializing cart: $e');
    }
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          // Properly refresh data by invalidating streams
          final authService = context.read<AuthService>();
          final firestoreService = context.read<FirestoreService>();
          final userId = authService.currentUser?.uid;
          if (userId != null) {
            // Force refresh user stats
            await firestoreService.refreshUserStats(userId);
          }
          setState(() {}); // Trigger rebuild to refresh streams
          await Future.delayed(const Duration(milliseconds: 300));
        },
        color: AppTheme.primary,
        child: StreamBuilder<UserModel?>(
          stream: authService.userModelStream(),
          builder: (context, userSnapshot) {
            final effectiveUserId =
                userSnapshot.data?.id ?? authService.currentUser?.uid;

            return StreamBuilder<List<UserApplianceModel>>(
              stream:
                  effectiveUserId != null
                      ? firestoreService.getUserProducts(effectiveUserId)
                      : Stream.value([]),
              builder: (context, productsSnapshot) {
                final products = productsSnapshot.data ?? [];
                final hasProducts = products.isNotEmpty;
                final isLoading =
                    productsSnapshot.connectionState == ConnectionState.waiting;

                // Schedule warranty expiry notifications when products are loaded
                if (products.isNotEmpty &&
                    productsSnapshot.connectionState ==
                        ConnectionState.active) {
                  WarrantyNotificationService.checkAndScheduleNotifications(
                    products,
                  );
                }

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    // Premium Animated Header
                    SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: _headerAnimation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, -0.2),
                            end: Offset.zero,
                          ).animate(_headerAnimation),
                          child: _buildPremiumHeader(
                            context,
                            userSnapshot.data,
                            products,
                          ),
                        ),
                      ),
                    ),

                    // Marketing Slider
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: MarketingSlider(),
                      ),
                    ),

                    // Welcome Section for New Users
                    if (!hasProducts && !isLoading)
                      SliverToBoxAdapter(child: _buildWelcomeSection(context)),

                    // Quick Actions with staggered animation (dynamic based on product count)
                    SliverToBoxAdapter(
                      child: _buildQuickActions(context, hasProducts),
                    ),

                    // My Appliances Header (only show if has products)
                    if (hasProducts)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'My Appliances',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              TextButton.icon(
                                onPressed:
                                    () => context.pushNamed('all-appliances'),
                                icon: const Icon(Icons.grid_view, size: 18),
                                label: const Text('View All'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Appliances List or Empty State
                    if (isLoading)
                      SliverToBoxAdapter(child: _buildShimmerLoading())
                    else if (!hasProducts)
                      SliverToBoxAdapter(child: _buildEmptyState(context))
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => StaggeredFadeIn(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildPremiumApplianceCard(
                                  context,
                                  products[index],
                                ),
                              ),
                            ),
                            childCount: products.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),

      // Premium Floating Action Button
      floatingActionButton: _buildPremiumFAB(context),
    );
  }

  Widget _buildPremiumHeader(
    BuildContext context,
    UserModel? user,
    List<UserApplianceModel> products,
  ) {
    final displayName = user?.displayName ?? 'User';
    final greeting = _getGreeting();
    final firestoreService = context.read<FirestoreService>();

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        24,
      ),
      decoration: BoxDecoration(gradient: AppTheme.primaryGradientExtended),
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
                color: Colors.white.withAlpha(15),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(10),
              ),
            ),
          ),
          // Content - No longer using StreamBuilder here since we receive data from parent
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.go('/profile');
                      },
                      child: Row(
                        children: [
                          // User Avatar
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withAlpha(40),
                              border: Border.all(
                                color: Colors.white.withAlpha(80),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  greeting,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withAlpha(200),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  displayName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Settings Button
                  PremiumIconButton(
                    icon: Icons.settings_outlined,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.go('/profile');
                    },
                    backgroundColor: Colors.white.withAlpha(40),
                    iconColor: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  // Notifications Button with dynamic badge
                  StreamBuilder<int>(
                    stream:
                        user != null
                            ? NotificationService().getUnreadCount(user.id)
                            : Stream.value(0),
                    builder: (context, notifSnapshot) {
                      final unreadCount = notifSnapshot.data ?? 0;
                      return PremiumIconButton(
                        icon: Icons.notifications_outlined,
                        onPressed: () => context.push('/notifications'),
                        backgroundColor: Colors.white.withAlpha(40),
                        iconColor: Colors.white,
                        showBadge: unreadCount > 0,
                        badgeCount: unreadCount,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  // Cart Button
                  Consumer<CartService>(
                    builder: (context, cart, _) {
                      return PremiumIconButton(
                        icon: Icons.shopping_cart_outlined,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          context.push('/cart');
                        },
                        backgroundColor: Colors.white.withAlpha(40),
                        iconColor: Colors.white,
                        showBadge: cart.itemCount > 0,
                        badgeCount: cart.itemCount,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Stats row - Uses passed data directly instead of StreamBuilder
              GlassContainer(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Appliances count - uses passed products list
                    _buildHeaderStat(
                      context,
                      Icons.inventory_2,
                      '${products.length}',
                      'Appliances',
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withAlpha(50),
                    ),
                    // Service requests - still needs a stream but we cache it
                    StreamBuilder<List<ServiceRequestModel>>(
                      stream:
                          user != null
                              ? firestoreService.getUserServiceRequests(user.id)
                              : Stream.value([]),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.length ?? 0;
                        return _buildHeaderStat(
                          context,
                          Icons.build,
                          '$count',
                          'Requests',
                        );
                      },
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withAlpha(50),
                    ),
                    GestureDetector(
                      onTap: () => _showRewardsExplanation(context),
                      child: _buildHeaderStat(
                        context,
                        Icons.card_giftcard,
                        '₹${(user?.totalEarnings ?? 0).toStringAsFixed(0)}',
                        'Rewards',
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

  void _showRewardsExplanation(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.card_giftcard,
                    color: AppTheme.primary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Earn Rewards with Referrals!',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Share your referral code with friends and family. When they register their first appliance, you earn ₹100 in rewards!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.success.withAlpha(30)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppTheme.success,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Rewards can be redeemed as discounts on services',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: AppTheme.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.pushNamed('referral');
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Start Referring'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Maybe Later'),
                ),
              ],
            ),
          ),
    );
  }

  void _showRedeemReferralDialog(BuildContext context) {
    final controller = TextEditingController();
    bool isLoading = false;

    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.redeem, color: Colors.purple),
                    ),
                    const SizedBox(width: 12),
                    const Text('Redeem Code'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter a referral code from a friend to unlock special rewards!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Referral Code',
                        hintText: 'e.g. VG-1234',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.confirmation_number),
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
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Referral code redeemed successfully!',
                                          ),
                                        ],
                                      ),
                                      backgroundColor: AppTheme.success,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
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
                                if (context.mounted) {
                                  setState(() => isLoading = false);
                                }
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

  Widget _buildHeaderStat(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white.withAlpha(180)),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 👋';
    if (hour < 17) return 'Good Afternoon ☀️';
    return 'Good Evening 🌙';
  }

  /// Welcome section for new users - explains both services and store
  Widget _buildWelcomeSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primary.withAlpha(15),
              AppTheme.primaryLight.withAlpha(10),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withAlpha(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.waving_hand,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to Vignesh Agencies!',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your one-stop solution for appliances',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Two feature cards side by side
            Row(
              children: [
                Expanded(
                  child: _WelcomeFeatureCard(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Shop Products',
                    description: 'Browse & buy quality appliances',
                    color: AppTheme.success,
                    onTap: () => context.pushNamed('product-catalog'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _WelcomeFeatureCard(
                    icon: Icons.build_outlined,
                    title: 'Get Services',
                    description: 'Register products for warranty & support',
                    color: AppTheme.primary,
                    onTap: () => context.pushNamed('add-product'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Quick tip
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.infoDark.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.infoDark.withAlpha(30)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: AppTheme.infoDark,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tip: Register your appliances to get warranty tracking & quick service support!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.infoDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Referral code hint
            GestureDetector(
              onTap: () => _showRedeemReferralDialog(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withAlpha(30)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.redeem, color: Colors.purple, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Have a referral code? Tap here to redeem rewards!',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.purple,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.purple,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool hasProducts) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Quick Actions',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.success.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
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
          // Dynamic Quick Actions based on whether user has products
          if (hasProducts)
            // User has products - show service-focused actions
            Row(
              children: [
                Expanded(
                  child: StaggeredFadeIn(
                    index: 0,
                    child: _PremiumQuickActionCard(
                      title: 'Shop\nProducts',
                      icon: Icons.shopping_bag,
                      isPrimary: true,
                      onTap: () => context.pushNamed('product-catalog'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StaggeredFadeIn(
                    index: 1,
                    child: _PremiumQuickActionCard(
                      title: 'Request\nService',
                      icon: Icons.build,
                      isPrimary: false,
                      onTap: () => _showProductPicker(context),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StaggeredFadeIn(
                    index: 2,
                    child: _PremiumQuickActionCard(
                      title: 'Refer &\nEarn',
                      icon: Icons.volunteer_activism,
                      isPrimary: false,
                      onTap: () => context.pushNamed('referral'),
                    ),
                  ),
                ),
              ],
            )
          else
            // New user - show onboarding-focused actions
            Row(
              children: [
                Expanded(
                  child: StaggeredFadeIn(
                    index: 0,
                    child: _PremiumQuickActionCard(
                      title: 'Shop\nProducts',
                      icon: Icons.shopping_bag,
                      isPrimary: true,
                      onTap: () => context.pushNamed('product-catalog'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StaggeredFadeIn(
                    index: 1,
                    child: _PremiumQuickActionCard(
                      title: 'Register\nAppliance',
                      icon: Icons.add_circle,
                      isPrimary: false,
                      onTap: () => context.pushNamed('add-product'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StaggeredFadeIn(
                    index: 2,
                    child: _PremiumQuickActionCard(
                      title: 'Refer &\nEarn',
                      icon: Icons.volunteer_activism,
                      isPrimary: false,
                      onTap: () => context.pushNamed('referral'),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showProductPicker(BuildContext context) {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Appliance',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: StreamBuilder<UserModel?>(
                  stream: authService.userModelStream(),
                  builder: (context, userSnapshot) {
                    final effectiveUserId =
                        userSnapshot.data?.id ?? authService.currentUser?.uid;

                    return StreamBuilder<List<UserApplianceModel>>(
                      stream:
                          effectiveUserId != null
                              ? firestoreService.getUserProducts(
                                effectiveUserId,
                              )
                              : Stream.value([]),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final products = snapshot.data ?? [];

                        if (products.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withAlpha(25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 48,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text('No appliances registered yet'),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    context.pushNamed('add-product');
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Register Appliance'),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return StaggeredFadeIn(
                              index: index,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: PremiumCard(
                                  glowColor: AppTheme.primary,
                                  onTap: () {
                                    Navigator.pop(context);
                                    context.pushNamed(
                                      'service-request',
                                      pathParameters: {'productId': product.id},
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: CachedNetworkImage(
                                          imageUrl:
                                              product.productImageUrl ?? '',
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          placeholder:
                                              (context, url) => Container(
                                                width: 56,
                                                height: 56,
                                                color: AppTheme.background(
                                                  context,
                                                ),
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              ),
                                          errorWidget:
                                              (_, __, ___) => Container(
                                                width: 56,
                                                height: 56,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).scaffoldBackgroundColor,
                                                child: const Icon(
                                                  Icons.devices,
                                                ),
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.productName,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              'Model: ${product.modelNumber}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.copyWith(
                                                color: AppTheme.textSecondary(
                                                  context,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: AppTheme.textSecondary(context),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmerLoading() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: List.generate(3, (index) => _ShimmerCard())),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withAlpha(30),
                  AppTheme.primaryLight.withAlpha(30),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Appliances Yet',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Register your Vignesh Agencies products to track\nwarranty and request service',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.pushNamed('add-product'),
            icon: const Icon(Icons.add),
            label: const Text('Register Your First Appliance'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumApplianceCard(
    BuildContext context,
    UserApplianceModel product,
  ) {
    return PremiumCard(
      glowColor: _getStatusColor(product),
      onTap: () {
        context.pushNamed(
          'appliance-detail',
          pathParameters: {'applianceId': product.id},
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Product Image with gradient border
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      _getStatusColor(product),
                      _getStatusColor(product).withAlpha(100),
                    ],
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: product.productImageUrl ?? '',
                    width: 74,
                    height: 74,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => Container(
                          width: 74,
                          height: 74,
                          color: AppTheme.background(context),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    errorWidget:
                        (_, __, ___) => Container(
                          width: 74,
                          height: 74,
                          color: AppTheme.background(context),
                          child: Icon(
                            Icons.devices,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Model: ${product.modelNumber}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    _buildStatusBadge(context, product),
                  ],
                ),
              ),

              Icon(Icons.chevron_right, color: AppTheme.textSecondary(context)),
            ],
          ),
          if (product.status == ProductStatus.rejected &&
              product.rejectionReason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.error.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: ${product.rejectionReason}',
                      style: const TextStyle(
                        color: AppTheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(UserApplianceModel product) {
    switch (product.status) {
      case ProductStatus.active:
        return product.isExpiringSoon ? AppTheme.warning : AppTheme.success;
      case ProductStatus.pendingValidation:
        return AppTheme.primary;
      case ProductStatus.expired:
        return Colors.grey;
      case ProductStatus.rejected:
        return AppTheme.error;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusBadge(BuildContext context, UserApplianceModel product) {
    Color backgroundColor;
    Color textColor;
    IconData? icon;
    String text;

    switch (product.status) {
      case ProductStatus.active:
        if (product.isExpiringSoon) {
          backgroundColor = AppTheme.warningLight;
          textColor = AppTheme.warning;
          icon = Icons.warning;
          text = 'Expiring Soon';
        } else {
          backgroundColor = AppTheme.successLight;
          textColor = AppTheme.success;
          text = 'Active Warranty';
        }
        break;
      case ProductStatus.pendingValidation:
        backgroundColor = AppTheme.primary.withAlpha(25);
        textColor = AppTheme.primary;
        icon = Icons.hourglass_empty;
        text = 'Pending Validation';
        break;
      case ProductStatus.expired:
        backgroundColor = AppTheme.neutralLight;
        textColor = AppTheme.neutral;
        icon = Icons.history;
        text = 'Warranty Expired';
        break;
      case ProductStatus.rejected:
        backgroundColor = AppTheme.errorLight;
        textColor = AppTheme.error;
        icon = Icons.cancel;
        text = 'Rejected';
        break;
      default:
        backgroundColor = AppTheme.neutralLight;
        textColor = AppTheme.neutral;
        text = product.status.displayName;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ] else ...[
            PulsingDot(color: textColor, size: 6),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFAB(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FloatingActionButton.large(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.pushNamed('add-product');
        },
        backgroundColor: AppTheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 32, color: Colors.white),
      ),
    );
  }
}

class _PremiumQuickActionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _PremiumQuickActionCard({
    required this.title,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  State<_PremiumQuickActionCard> createState() =>
      _PremiumQuickActionCardState();
}

class _PremiumQuickActionCardState extends State<_PremiumQuickActionCard>
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
              height: 160,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient:
                    widget.isPrimary
                        ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primary,
                            AppTheme.primaryLight,
                            AppTheme.primary.withBlue(220),
                          ],
                        )
                        : null,
                color: widget.isPrimary ? null : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                border:
                    widget.isPrimary
                        ? null
                        : Border.all(color: AppTheme.border(context)),
                boxShadow:
                    widget.isPrimary
                        ? [
                          BoxShadow(
                            color: AppTheme.primary.withAlpha(80),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ]
                        : AppTheme.cardShadow,
              ),
              child: Stack(
                children: [
                  // Decorative circle for primary
                  if (widget.isPrimary)
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(25),
                        ),
                      ),
                    ),
                  // Content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color:
                              widget.isPrimary
                                  ? Colors.white.withAlpha(50)
                                  : AppTheme.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          widget.icon,
                          color:
                              widget.isPrimary
                                  ? Colors.white
                                  : AppTheme.primary,
                          size: 24,
                        ),
                      ),
                      const Spacer(),
                      // Text with proper sizing
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.visible,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color:
                              widget.isPrimary
                                  ? Colors.white
                                  : AppTheme.textPrimary(context),
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          fontSize: 14,
                        ),
                      ),
                    ],
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

class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.shimmerBase,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.shimmerBase,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.shimmerBase,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 20,
                      width: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.shimmerBase,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Feature card for welcome section
class _WelcomeFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _WelcomeFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(40)),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary(context),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
