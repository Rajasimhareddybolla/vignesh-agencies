import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../models/service_request_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class RequestsListScreen extends StatefulWidget {
  const RequestsListScreen({super.key});

  @override
  State<RequestsListScreen> createState() => _RequestsListScreenState();
}

class _RequestsListScreenState extends State<RequestsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                'My Requests',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            
            // Tab Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondaryLight,
                indicatorColor: AppTheme.primary,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Active'),
                  Tab(text: 'Completed'),
                ],
              ),
            ),
            
            // Tab Content
            Expanded(
              child: StreamBuilder<List<ServiceRequestModel>>(
                stream: authService.currentUser != null
                    ? firestoreService.getUserServiceRequests(authService.currentUser!.uid)
                    : Stream.value([]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allRequests = snapshot.data ?? [];
                  final activeRequests = allRequests.where((r) =>
                      r.status == ServiceRequestStatus.pending ||
                      r.status == ServiceRequestStatus.assigned ||
                      r.status == ServiceRequestStatus.inProgress).toList();
                  final completedRequests = allRequests.where((r) =>
                      r.status == ServiceRequestStatus.resolved ||
                      r.status == ServiceRequestStatus.cancelled).toList();

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _RequestsList(requests: allRequests),
                      _RequestsList(requests: activeRequests),
                      _RequestsList(requests: completedRequests),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestsList extends StatelessWidget {
  final List<ServiceRequestModel> requests;

  const _RequestsList({required this.requests});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: AppTheme.textSecondaryLight.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No requests found',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        return _RequestCard(request: requests[index]);
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ServiceRequestModel request;

  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundLight,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusMd),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      request.ticketNumber,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${DateFormat('MMM dd, yyyy').format(request.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                _StatusBadge(status: request.status),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Info
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.home_repair_service,
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
                            request.productName ?? 'Product',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            request.issueType,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Description
                Text(
                  request.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryLight,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                // Technician Info (if assigned)
                if (request.technicianName != null) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.engineering,
                        size: 16,
                        color: AppTheme.textSecondaryLight,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Technician: ${request.technicianName}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ServiceRequestStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case ServiceRequestStatus.pending:
        backgroundColor = AppTheme.warningLight;
        textColor = AppTheme.warning;
        break;
      case ServiceRequestStatus.assigned:
        backgroundColor = AppTheme.primary.withOpacity(0.1);
        textColor = AppTheme.primary;
        break;
      case ServiceRequestStatus.inProgress:
        backgroundColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        break;
      case ServiceRequestStatus.resolved:
        backgroundColor = AppTheme.successLight;
        textColor = AppTheme.success;
        break;
      case ServiceRequestStatus.escalated:
        backgroundColor = AppTheme.errorLight;
        textColor = AppTheme.error;
        break;
      case ServiceRequestStatus.cancelled:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade600;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        status.displayName,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
