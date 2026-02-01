import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/auth/admin_login_screen.dart';
import '../screens/user/notifications_screen.dart';
import '../screens/user/cart_screen.dart';
import '../screens/user/product_catalog_screen.dart';
import '../screens/user/saved_addresses_screen.dart';
import '../screens/user/all_referrals_screen.dart';
import '../screens/common/help_center_screen.dart';
import '../screens/common/contact_support_screen.dart';
import '../screens/common/legal_screens.dart';
import '../screens/user/home_screen.dart';
import '../screens/user/add_product_screen.dart';
import '../screens/user/service_request_screen.dart';
import '../screens/user/referral_screen.dart';
import '../screens/user/requests_list_screen.dart';
import '../screens/user/user_service_request_detail_screen.dart';
import '../screens/user/orders_screen.dart';
import '../screens/user/profile_screen.dart';
import '../screens/user/edit_profile_screen.dart';
import '../screens/user/all_appliances_screen.dart';
import '../screens/user/product_detail_screen.dart';
import '../screens/admin/command_center_screen.dart';
import '../screens/admin/service_requests_screen.dart';
import '../screens/admin/service_request_detail_screen.dart';
import '../screens/admin/warranty_validation_screen.dart';
import '../screens/admin/payout_manager_screen.dart';
import '../screens/admin/reports_screen.dart';
import '../screens/admin/send_notification_screen.dart';
import '../screens/admin/admin_settings_screen.dart';
import '../screens/admin/products/product_list_screen.dart';
import '../screens/admin/products/add_edit_product_screen.dart';
import '../screens/admin/products/admin_orders_screen.dart';
import '../screens/admin/marketing_manager_screen.dart';
import '../screens/admin/add_banner_screen.dart';
import '../screens/admin/agents_management_screen.dart';
import '../models/catalog_product_model.dart';
import '../services/auth_service.dart';
import '../screens/user/checkout_screen.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();
  static final _adminShellNavigatorKey = GlobalKey<NavigatorState>();

  static final AuthService _authService = AuthService();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      final isLoggedIn = _authService.isLoggedIn;
      final isLoginRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/otp' ||
          state.matchedLocation == '/admin-login';

      if (!isLoggedIn && !isLoginRoute) {
        return '/login';
      }

      if (isLoggedIn && isLoginRoute) {
        final isAdmin = await _authService.isCurrentUserAdmin();
        return isAdmin ? '/admin' : '/home';
      }

      return null;
    },
    routes: [
      // Auth Routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        name: 'otp',
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          final verificationId = state.uri.queryParameters['vid'] ?? '';
          return OTPScreen(phoneNumber: phone, verificationId: verificationId);
        },
      ),
      GoRoute(
        path: '/admin-login',
        name: 'admin-login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/product-catalog',
        name: 'product-catalog',
        builder: (context, state) => const ProductCatalogScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/saved-addresses',
        builder: (context, state) => const SavedAddressesScreen(),
      ),
      GoRoute(
        path: '/all-referrals',
        builder: (context, state) => const AllReferralsScreen(),
      ),
      GoRoute(
        path: '/help-center',
        builder: (context, state) => const HelpCenterScreen(),
      ),
      GoRoute(
        path: '/contact-support',
        builder: (context, state) => const ContactSupportScreen(),
      ),
      GoRoute(path: '/terms', builder: (context, state) => const TermsScreen()),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),

      // User Shell Route with Bottom Navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return UserShellScreen(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            pageBuilder:
                (context, state) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/requests',
            name: 'requests',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: RequestsListScreen()),
          ),
          GoRoute(
            path: '/orders',
            name: 'orders',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: OrdersScreen()),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),

      // User Routes (outside shell)
      GoRoute(
        path: '/add-product',
        name: 'add-product',
        builder: (context, state) => const AddProductScreen(),
      ),
      GoRoute(
        path: '/service-request/:productId',
        name: 'service-request',
        builder: (context, state) {
          final productId = state.pathParameters['productId'] ?? '';
          return ServiceRequestScreen(productId: productId);
        },
      ),
      GoRoute(
        path: '/referral',
        name: 'referral',
        builder: (context, state) => const ReferralScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        name: 'edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/all-appliances',
        name: 'all-appliances',
        builder: (context, state) => const AllAppliancesScreen(),
      ),
      GoRoute(
        path: '/product-detail/:productId',
        name: 'product-detail',
        builder: (context, state) {
          final productId = state.pathParameters['productId'] ?? '';
          final product = state.extra as CatalogProductModel?;
          return ProductDetailScreen(productId: productId, product: product);
        },
      ),
      GoRoute(
        path: '/user/request/:requestId',
        name: 'user-request-detail',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId'] ?? '';
          return UserServiceRequestDetailScreen(requestId: requestId);
        },
      ),

      // Admin Shell Route with Side Navigation
      ShellRoute(
        navigatorKey: _adminShellNavigatorKey,
        builder: (context, state, child) {
          return AdminShellScreen(child: child);
        },
        routes: [
          GoRoute(
            path: '/admin',
            name: 'admin-home',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: CommandCenterScreen()),
          ),
          GoRoute(
            path: '/admin/requests',
            name: 'admin-requests',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: AdminServiceRequestsScreen()),
          ),
          GoRoute(
            path: '/admin/warranty',
            name: 'admin-warranty',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: WarrantyValidationScreen()),
          ),
          GoRoute(
            path: '/admin/payouts',
            name: 'admin-payouts',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: PayoutManagerScreen()),
          ),
          GoRoute(
            path: '/admin/reports',
            name: 'admin-reports',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: ReportsScreen()),
          ),
          GoRoute(
            path: '/admin/notifications',
            name: 'admin-notifications',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: SendNotificationScreen()),
          ),
          GoRoute(
            path: '/admin/settings',
            name: 'admin-settings',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: AdminSettingsScreen()),
          ),
          GoRoute(
            path: '/admin/products',
            name: 'admin-products',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: AdminProductListScreen()),
          ),
          GoRoute(
            path: '/admin/orders',
            name: 'admin-orders',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: AdminOrdersScreen()),
          ),
          GoRoute(
            path: '/admin/marketing',
            name: 'admin-marketing',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: MarketingManagerScreen()),
          ),
          GoRoute(
            path: '/admin/marketing/add',
            name: 'admin-add-marketing',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: AddBannerScreen()),
          ),
          GoRoute(
            path: '/admin/agents',
            name: 'admin-agents',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: AgentsManagementScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/admin/request/:requestId',
        name: 'admin-request-detail',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId'] ?? '';
          return ServiceRequestDetailScreen(requestId: requestId);
        },
      ),
      GoRoute(
        path: '/admin/products/add',
        name: 'admin-add-product',
        builder: (context, state) => const AddEditProductScreen(),
      ),
      GoRoute(
        path: '/admin/products/edit',
        name: 'admin-edit-product',
        builder: (context, state) {
          final product = state.extra as CatalogProductModel?;
          return AddEditProductScreen(product: product);
        },
      ),
    ],
    errorBuilder:
        (context, state) => Scaffold(
          body: Center(child: Text('Page not found: ${state.uri.path}')),
        ),
  );
}

// User Shell Screen with Bottom Navigation
class UserShellScreen extends StatelessWidget {
  final Widget child;

  const UserShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _calculateSelectedIndex(context),
          onDestinationSelected: (index) => _onItemTapped(index, context),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Requests',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'My Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/requests')) return 1;
    if (location.startsWith('/orders')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.goNamed('home');
        break;
      case 1:
        context.goNamed('requests');
        break;
      case 2:
        context.goNamed('orders');
        break;
      case 3:
        context.goNamed('profile');
        break;
    }
  }
}

// Admin Shell Screen with Side Navigation
class AdminShellScreen extends StatelessWidget {
  final Widget child;

  const AdminShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 800;

    if (isWideScreen) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.of(context).size.width >= 1200,
              selectedIndex: _calculateSelectedIndex(context),
              onDestinationSelected: (index) => _onItemTapped(index, context),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (MediaQuery.of(context).size.width >= 1200)
                      Text(
                        'Vignesh Agencies Admin',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.build_outlined),
                  selectedIcon: Icon(Icons.build),
                  label: Text('Requests'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.verified_outlined),
                  selectedIcon: Icon(Icons.verified),
                  label: Text('Warranty'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.payments_outlined),
                  selectedIcon: Icon(Icons.payments),
                  label: Text('Payouts'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics),
                  label: Text('Reports'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    // Mobile layout with bottom navigation
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (index) => _onItemTapped(index, context),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.verified_outlined),
            selectedIcon: Icon(Icons.verified),
            label: 'Warranty',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Payouts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/admin') return 0;
    if (location.startsWith('/admin/requests')) return 1;
    if (location.startsWith('/admin/warranty')) return 2;
    if (location.startsWith('/admin/payouts')) return 3;
    if (location.startsWith('/admin/reports')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.goNamed('admin-home');
        break;
      case 1:
        context.goNamed('admin-requests');
        break;
      case 2:
        context.goNamed('admin-warranty');
        break;
      case 3:
        context.goNamed('admin-payouts');
        break;
      case 4:
        context.goNamed('admin-settings');
        break;
    }
  }
}
