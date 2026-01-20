import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../models/service_request_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/premium_widgets.dart';

class RequestsListScreen extends StatefulWidget {
  const RequestsListScreen({super.key});

  @override
  State<RequestsListScreen> createState() => _RequestsListScreenState();
}

class _RequestsListScreenState extends State<RequestsListScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _headerController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headerController.dispose();
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
          setState(() {});
          await Future.delayed(const Duration(seconds: 1));
        },
        color: AppTheme.primary,
        child: NestedScrollView(
          physics: const BouncingScrollPhysics(),
          headerSliverBuilder:
              (context, innerBoxIsScrolled) => [
                // Premium Header
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _headerController,
                    child: _buildHeader(context),
                  ),
                ),
                // Tab Bar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: AppTheme.textSecondaryLight,
                      indicatorColor: AppTheme.primary,
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      tabs: const [
                        Tab(text: 'All'),
                        Tab(text: 'Active'),
                        Tab(text: 'Completed'),
                      ],
                    ),
                  ),
                ),
              ],
          body: StreamBuilder<UserModel?>(
            stream: authService.userModelStream(),
            builder: (context, userSnapshot) {
              final effectiveUserId =
                  userSnapshot.data?.id ?? authService.currentUser?.uid;

              return StreamBuilder<List<ServiceRequestModel>>(
                stream:
                    effectiveUserId != null
                        ? firestoreService.getUserServiceRequests(
                          effectiveUserId,
                        )
                        : Stream.value([]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allRequests = snapshot.data ?? [];
                  final activeRequests =
                      allRequests
                          .where(
                            (r) =>
                                r.status == ServiceRequestStatus.pending ||
                                r.status == ServiceRequestStatus.assigned ||
                                r.status == ServiceRequestStatus.inProgress,
                          )
                          .toList();
                  final completedRequests =
                      allRequests
                          .where(
                            (r) =>
                                r.status == ServiceRequestStatus.resolved ||
                                r.status == ServiceRequestStatus.cancelled,
                          )
                          .toList();

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _RequestsList(requests: allRequests),
                      _RequestsList(requests: activeRequests),
                      _RequestsList(requests: completedRequests),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
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
            padding: const EdgeInsets.all(10),
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
              Icons.receipt_long,
              color: AppTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Requests',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Track your service requests',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}

class _RequestsList extends StatelessWidget {
  final List<ServiceRequestModel> requests;

  const _RequestsList({required this.requests});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
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
              const SizedBox(height: 24),
              Text(
                'No requests found',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Your service requests will appear here',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        return StaggeredFadeIn(
          index: index,
          child: _PremiumRequestCard(request: requests[index]),
        );
      },
    );
  }
}

class _PremiumRequestCard extends StatelessWidget {
  final ServiceRequestModel request;

  const _PremiumRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      glowColor: _getStatusColor(request.status),
      onTap: () {
        HapticFeedback.selectionClick();
        // Navigate to request detail screen
        context.push('/admin/request/${request.id}');
      },
      child: Column(
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      request.ticketNumber,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('MMM dd').format(request.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              _PremiumStatusBadge(status: request.status),
            ],
          ),
          const SizedBox(height: 14),

          // Product Info
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getStatusColor(request.status).withAlpha(30),
                      _getStatusColor(request.status).withAlpha(15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.home_repair_service,
                  color: _getStatusColor(request.status),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.productName ?? 'Product',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.issueType,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondaryLight,
              ),
            ],
          ),

          // Technician Info
              if (request.technicianName != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.success.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.engineering,
                          size: 14,
                          color: AppTheme.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Assigned: ${request.technicianName}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (request.status == ServiceRequestStatus.resolved) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _showCompletionDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Confirm & Rate Service'),
                  ),
                ),
              ],
            ],
          ),
        );
      }

  void _showCompletionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Completion'),
        content: const Text(
          'Are you satisfied with the service provided? This will close the request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<FirestoreService>().updateServiceRequestStatus(
                requestId: request.id,
                status: ServiceRequestStatus.completed,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you for your feedback!'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.success,
            ),
            child: const Text('Yes, Complete'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ServiceRequestStatus status) {
    switch (status) {
      case ServiceRequestStatus.pending:
        return AppTheme.warning;
      case ServiceRequestStatus.assigned:
        return AppTheme.primary;
      case ServiceRequestStatus.inProgress:
        return AppTheme.infoDark;
      case ServiceRequestStatus.resolved:
      case ServiceRequestStatus.completed:
        return AppTheme.success;
      case ServiceRequestStatus.escalated:
        return AppTheme.error;
      case ServiceRequestStatus.cancelled:
        return AppTheme.neutral;
    }
  }
}

class _PremiumStatusBadge extends StatelessWidget {
  final ServiceRequestStatus status;

  const _PremiumStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    IconData? icon;

    switch (status) {
      case ServiceRequestStatus.pending:
        backgroundColor = AppTheme.warningLight;
        textColor = AppTheme.warning;
        icon = Icons.schedule;
        break;
      case ServiceRequestStatus.assigned:
        backgroundColor = AppTheme.primary.withAlpha(25);
        textColor = AppTheme.primary;
        icon = Icons.person;
        break;
      case ServiceRequestStatus.inProgress:
        backgroundColor = AppTheme.infoLight;
        textColor = AppTheme.infoDark;
        icon = Icons.build;
        break;
      case ServiceRequestStatus.resolved:
        backgroundColor = AppTheme.successLight;
        textColor = AppTheme.success;
        icon = Icons.check_circle;
        break;
      case ServiceRequestStatus.completed:
        backgroundColor = AppTheme.success;
        textColor = Colors.white;
        icon = Icons.verified;
        break;
      case ServiceRequestStatus.escalated:
        backgroundColor = AppTheme.errorLight;
        textColor = AppTheme.error;
        icon = Icons.warning;
        break;
      case ServiceRequestStatus.cancelled:
        backgroundColor = AppTheme.neutralLight;
        textColor = AppTheme.neutral;
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
