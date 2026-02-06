import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../models/service_request_model.dart';
import '../../services/firestore_service.dart';

class AdminServiceRequestsScreen extends StatefulWidget {
  const AdminServiceRequestsScreen({super.key});

  @override
  State<AdminServiceRequestsScreen> createState() =>
      _AdminServiceRequestsScreenState();
}

class _AdminServiceRequestsScreenState
    extends State<AdminServiceRequestsScreen> {
  ServiceRequestStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Admin Gradient Header
          _buildHeader(context),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: _filterStatus == null,
                  onTap: () => setState(() => _filterStatus = null),
                ),
                _FilterChip(
                  label: 'Pending',
                  isSelected: _filterStatus == ServiceRequestStatus.pending,
                  onTap:
                      () => setState(
                        () => _filterStatus = ServiceRequestStatus.pending,
                      ),
                ),
                _FilterChip(
                  label: 'Assigned',
                  isSelected: _filterStatus == ServiceRequestStatus.assigned,
                  onTap:
                      () => setState(
                        () => _filterStatus = ServiceRequestStatus.assigned,
                      ),
                ),
                _FilterChip(
                  label: 'In Progress',
                  isSelected: _filterStatus == ServiceRequestStatus.inProgress,
                  onTap:
                      () => setState(
                        () => _filterStatus = ServiceRequestStatus.inProgress,
                      ),
                ),
                _FilterChip(
                  label: 'Resolved',
                  isSelected: _filterStatus == ServiceRequestStatus.resolved,
                  onTap:
                      () => setState(
                        () => _filterStatus = ServiceRequestStatus.resolved,
                      ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Requests List
          Expanded(
            child: StreamBuilder<List<ServiceRequestModel>>(
              stream: firestoreService.getAllServiceRequests(
                filterStatus: _filterStatus,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final requests = snapshot.data ?? [];

                if (requests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: AppTheme.textSecondary(
                            context,
                          ).withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No requests found',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return _RequestRow(
                      request: request,
                      onTap: () {
                        context.pushNamed(
                          'admin-request-detail',
                          pathParameters: {'requestId': request.id},
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
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: AppTheme.adminGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Service Requests',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage and track all service requests',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.borderLight,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color:
                  isSelected ? Colors.white : AppTheme.textSecondary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final ServiceRequestModel request;
  final VoidCallback onTap;

  const _RequestRow({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.borderLight),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            // Priority Indicator
            Container(
              width: 4,
              height: 64,
              decoration: BoxDecoration(
                color:
                    request.priority == ServicePriority.urgent
                        ? AppTheme.urgent
                        : AppTheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      if (request.priority == ServicePriority.urgent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.errorLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'URGENT',
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(
                              color: AppTheme.urgent,
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${request.customerName ?? 'Customer'} • ${request.productName ?? 'Product'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    request.issueType,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  // Media Attachments Indicator
                  if (request.evidenceImages.isNotEmpty ||
                      (request.audioRecordingUrl != null &&
                          request.audioRecordingUrl!.isNotEmpty)) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (request.evidenceImages.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.image,
                                  size: 12,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${request.evidenceImages.length}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (request.audioRecordingUrl != null &&
                            request.audioRecordingUrl!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.mic,
                                  size: 12,
                                  color: AppTheme.success,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Audio',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.success,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Status & Date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusBadge(status: request.status),
                const SizedBox(height: 8),
                Text(
                  DateFormat('MMM d, h:mm a').format(request.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary(context)),
          ],
        ),
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
        backgroundColor = AppTheme.infoLight;
        textColor = AppTheme.infoDark;
        break;
      case ServiceRequestStatus.resolved:
        backgroundColor = AppTheme.successLight;
        textColor = AppTheme.success;
        break;
      case ServiceRequestStatus.completed:
        backgroundColor = AppTheme.success;
        textColor = Colors.white;
        break;
      case ServiceRequestStatus.escalated:
        backgroundColor = AppTheme.errorLight;
        textColor = AppTheme.error;
        break;
      case ServiceRequestStatus.cancelled:
        backgroundColor = AppTheme.neutralLight;
        textColor = AppTheme.neutral;
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
