import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme.dart';
import '../../models/user_appliance_model.dart';
import '../../models/service_request_model.dart';
import '../../services/firestore_service.dart';

class ApplianceDetailScreen extends StatelessWidget {
  final String applianceId;

  const ApplianceDetailScreen({super.key, required this.applianceId});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      body: FutureBuilder<UserApplianceModel?>(
        future: firestoreService.getProduct(applianceId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return _buildErrorState(context);
          }

          final appliance = snapshot.data!;
          return _ApplianceDetailContent(appliance: appliance);
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.error.withAlpha(150),
            ),
            const SizedBox(height: 16),
            Text(
              'Appliance not found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'The appliance may have been removed',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplianceDetailContent extends StatelessWidget {
  final UserApplianceModel appliance;

  const _ApplianceDetailContent({required this.appliance});

  Color _getStatusColor() {
    switch (appliance.status) {
      case ProductStatus.active:
        return AppTheme.success;
      case ProductStatus.pendingValidation:
        return AppTheme.warning;
      case ProductStatus.rejected:
        return AppTheme.error;
      case ProductStatus.expired:
        return AppTheme.neutral;
      case ProductStatus.expiringSoon:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final isWarrantyActive = appliance.warrantyEndDate.isAfter(DateTime.now());
    final daysRemaining =
        appliance.warrantyEndDate.difference(DateTime.now()).inDays;

    return CustomScrollView(
      slivers: [
        // Custom App Bar with gradient
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            onPressed: () => context.pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [statusColor, statusColor.withAlpha(180)],
                ),
              ),
              child: Stack(
                children: [
                  // Decorative circles
                  Positioned(
                    right: -40,
                    top: -40,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withAlpha(20),
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
                        color: Colors.white.withAlpha(15),
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.of(context).padding.top + 60,
                      20,
                      20,
                    ),
                    child: Row(
                      children: [
                        // Product image
                        Container(
                          width: 90,
                          height: 90,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(30),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.asset(
                              UserApplianceModel.getProductImage(
                                appliance.category,
                              ),
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => Container(
                                    color: AppTheme.background(context),
                                    child: Icon(
                                      Icons.devices,
                                      size: 40,
                                      color: statusColor,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                appliance.productName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                appliance.category,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(200),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(40),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  appliance.status.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Content
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Rejection Card
              if (appliance.status == ProductStatus.rejected &&
                  appliance.rejectionReason != null &&
                  appliance.rejectionReason!.isNotEmpty)
                _buildRejectionInfoCard(context),

              // Warranty Status Card
              _buildWarrantyCard(
                context,
                isWarrantyActive,
                daysRemaining,
                statusColor,
              ),
              const SizedBox(height: 20),

              // Appliance Details Card
              _buildDetailsCard(context),
              const SizedBox(height: 20),

              // Purchase Info Card
              _buildPurchaseInfoCard(context),
              const SizedBox(height: 20),

              // Service History Section
              _buildServiceHistorySection(context),
              const SizedBox(height: 24),

              // Action Buttons
              _buildActionButtons(context),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildWarrantyCard(
    BuildContext context,
    bool isActive,
    int daysRemaining,
    Color statusColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(30),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isActive ? Icons.verified_user : Icons.gpp_bad,
              color: statusColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? 'Warranty Active' : 'Warranty Expired',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isActive
                      ? '$daysRemaining days remaining'
                      : 'Expired ${-daysRemaining} days ago',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Expires',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary(context),
                ),
              ),
              Text(
                DateFormat('dd MMM yyyy').format(appliance.warrantyEndDate),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight.withAlpha(100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Appliance Details',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow(context, 'Model Number', appliance.modelNumber),
          if (appliance.serialNumber != null &&
              appliance.serialNumber!.isNotEmpty)
            _buildDetailRow(context, 'Serial Number', appliance.serialNumber!),
          _buildDetailRow(context, 'Category', appliance.category),
          _buildDetailRow(
            context,
            'Registered On',
            DateFormat('dd MMM yyyy').format(appliance.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary(context),
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight.withAlpha(100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Purchase Information',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            context,
            'Purchase Date',
            DateFormat('dd MMM yyyy').format(appliance.purchaseDate),
          ),
          if (appliance.purchaseAmount != null && appliance.purchaseAmount! > 0)
            _buildDetailRow(
              context,
              'Purchase Amount',
              '₹${NumberFormat('#,##0').format(appliance.purchaseAmount)}',
            ),
          if (appliance.storeLocation != null &&
              appliance.storeLocation!.isNotEmpty)
            _buildDetailRow(
              context,
              'Store Location',
              appliance.storeLocation!,
            ),

          // Bill Image Preview
          if (appliance.billImageUrl != null &&
              appliance.billImageUrl!.isNotEmpty) ...[
            const Divider(height: 24),
            GestureDetector(
              onTap: () => _showBillImage(context),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: CachedNetworkImage(
                        imageUrl: appliance.billImageUrl!,
                        fit: BoxFit.cover,
                        placeholder:
                            (_, __) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        errorWidget: (_, __, ___) => const Icon(Icons.receipt),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Purchase Bill',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Tap to view full image',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.primary),
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
          ],
        ],
      ),
    );
  }

  void _showBillImage(BuildContext context) {
    if (appliance.billImageUrl == null) return;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: appliance.billImageUrl!,
                    fit: BoxFit.contain,
                    placeholder:
                        (_, __) => Container(
                          height: 200,
                          color: Colors.white,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.textPrimary(context),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildServiceHistorySection(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Service History',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<ServiceRequestModel>>(
          stream: firestoreService.getProductServiceRequests(appliance.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final requests = snapshot.data ?? [];

            if (requests.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.background(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.borderLight.withAlpha(100),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: AppTheme.success.withAlpha(150),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No service requests yet',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your appliance is running smoothly!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children:
                  requests.map((request) {
                    return _ServiceHistoryCard(request: request);
                  }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRejectionInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppTheme.error.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.error.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.report_problem, color: AppTheme.error),
              const SizedBox(width: 12),
              Text(
                'Warranty Rejected',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Reason for rejection:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            appliance.rejectionReason!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    // Allow service requests for all products except rejected ones
    final canRequestService = appliance.status != ProductStatus.rejected;

    return Column(
      children: [
        // Primary Action - Request Service
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                canRequestService
                    ? () {
                      HapticFeedback.lightImpact();
                      context.pushNamed(
                        'service-request',
                        pathParameters: {'productId': appliance.id},
                      );
                    }
                    : null,
            icon: const Icon(Icons.build),
            label: const Text('Request Service'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              disabledBackgroundColor: AppTheme.borderLight,
            ),
          ),
        ),
        if (!canRequestService) ...[
          const SizedBox(height: 8),
          Text(
            'Warranty registration was rejected - cannot request service',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _ServiceHistoryCard extends StatelessWidget {
  final ServiceRequestModel request;

  const _ServiceHistoryCard({required this.request});

  Color _getStatusColor() {
    switch (request.status) {
      case ServiceRequestStatus.pending:
        return AppTheme.warning;
      case ServiceRequestStatus.assigned:
        return AppTheme.info;
      case ServiceRequestStatus.inProgress:
        return AppTheme.primary;
      case ServiceRequestStatus.resolved:
        return AppTheme.success;
      case ServiceRequestStatus.completed:
        return AppTheme.success;
      case ServiceRequestStatus.cancelled:
        return AppTheme.error;
      case ServiceRequestStatus.escalated:
        return AppTheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return InkWell(
      onTap: () {
        // Navigate to service request detail screen
        context.pushNamed(
          'user-service-request-detail',
          pathParameters: {'requestId': request.id},
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight.withAlpha(100)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.issueType,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy').format(request.createdAt),
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                          // Show rating if completed and has rating
                          if (request.status ==
                                  ServiceRequestStatus.completed &&
                              request.rating != null) ...[
                            const SizedBox(width: 12),
                            Row(
                              children: List.generate(5, (index) {
                                return Icon(
                                  index < request.rating!
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: AppTheme.warning,
                                  size: 14,
                                );
                              }),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.status.displayName,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppTheme.borderDark),
              ],
            ),
            // Show "Request Again" button for completed or cancelled requests
            if (request.status == ServiceRequestStatus.completed ||
                request.status == ServiceRequestStatus.cancelled) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Navigate to new service request with same product
                    context.pushNamed(
                      'service-request',
                      pathParameters: {'productId': request.productId},
                    );
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Request Service Again'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
