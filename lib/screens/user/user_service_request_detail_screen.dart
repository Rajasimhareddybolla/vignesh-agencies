import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme.dart';
import '../../models/service_request_model.dart';
import '../../services/firestore_service.dart';

/// Client-facing service request detail screen.
/// This screen shows request details in read-only mode and only allows
/// clients to mark a request as completed when the status is 'resolved'.
class UserServiceRequestDetailScreen extends StatefulWidget {
  final String requestId;

  const UserServiceRequestDetailScreen({super.key, required this.requestId});

  @override
  State<UserServiceRequestDetailScreen> createState() =>
      _UserServiceRequestDetailScreenState();
}

class _UserServiceRequestDetailScreenState
    extends State<UserServiceRequestDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Request Details'),
      ),
      body: StreamBuilder<ServiceRequestModel?>(
        stream: firestoreService.getServiceRequestStream(widget.requestId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final request = snapshot.data;
          if (request == null) {
            return const Center(child: Text('Request not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ticket Number & Status Header
                _buildStatusHeader(context, request),

                const SizedBox(height: 20),

                // Issue Details Section
                _SectionCard(
                  title: 'Issue Details',
                  icon: Icons.report_problem_outlined,
                  children: [
                    _DetailRow(label: 'Issue Type', value: request.issueType),
                    _DetailRow(
                      label: 'Reported On',
                      value: DateFormat(
                        'MMM d, yyyy • h:mm a',
                      ).format(request.createdAt),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Product Details Section
                _SectionCard(
                  title: 'Product Details',
                  icon: Icons.inventory_2_outlined,
                  children: [
                    _DetailRow(
                      label: 'Product',
                      value: request.productName ?? 'N/A',
                    ),
                    _DetailRow(
                      label: 'Model',
                      value: request.productModel ?? 'N/A',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Audio Recording Section
                if (request.audioRecordingUrl != null &&
                    request.audioRecordingUrl!.isNotEmpty)
                  _SectionCard(
                    title: 'Audio Description',
                    icon: Icons.mic,
                    children: [
                      _AudioPlayerWidget(audioUrl: request.audioRecordingUrl!),
                    ],
                  )
                else
                  _SectionCard(
                    title: 'Audio Description',
                    icon: Icons.mic_off,
                    children: [
                      Text(
                        'No audio recording attached.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary(context),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Evidence Images Section
                if (request.evidenceImages.isNotEmpty)
                  _SectionCard(
                    title: 'Evidence Images',
                    icon: Icons.photo_library_outlined,
                    children: [
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: request.evidenceImages.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap:
                                    () => _showFullScreenImage(
                                      context,
                                      request.evidenceImages[index],
                                    ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: request.evidenceImages[index],
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    placeholder:
                                        (context, url) => Container(
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                    errorWidget:
                                        (context, url, error) => Container(
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.error),
                                        ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  )
                else
                  _SectionCard(
                    title: 'Evidence Images',
                    icon: Icons.image_not_supported_outlined,
                    children: [
                      Text(
                        'No evidence images available.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary(context),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Service Timeline (Phase 3)
                _buildServiceTimeline(context, request),

                const SizedBox(height: 16),

                // Technician Contact Card (Phase 3) - only show when assigned
                if (request.technicianName != null &&
                    request.status != ServiceRequestStatus.pending)
                  _buildTechnicianCard(context, request),

                if (request.technicianName != null &&
                    request.status != ServiceRequestStatus.pending)
                  const SizedBox(height: 16),

                // Assignment Information (Read-Only)
                _SectionCard(
                  title: 'Service Assignment',
                  icon: Icons.assignment_ind_outlined,
                  children: [_buildAssignmentInfo(context, request)],
                ),

                const SizedBox(height: 16),

                // Resolution Notes (if any)
                if (request.resolutionNotes != null &&
                    request.resolutionNotes!.isNotEmpty)
                  _SectionCard(
                    title: 'Resolution Notes',
                    icon: Icons.notes_outlined,
                    children: [
                      Text(
                        request.resolutionNotes!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),

                // Feedback Section (Phase 3) - show for completed requests
                if (request.status == ServiceRequestStatus.completed)
                  _buildFeedbackSection(context, request),

                const SizedBox(height: 24),

                // Action Button - Only show "Mark as Completed" when status is resolved
                _buildActionSection(context, request),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  // Phase 3: Service Timeline Widget
  Widget _buildServiceTimeline(
    BuildContext context,
    ServiceRequestModel request,
  ) {
    final steps = <_ServiceTimelineStep>[
      _ServiceTimelineStep(
        title: 'Request Submitted',
        subtitle: DateFormat('MMM d, yyyy • h:mm a').format(request.createdAt),
        isCompleted: true,
        icon: Icons.receipt_long_outlined,
      ),
      _ServiceTimelineStep(
        title: 'Technician Assigned',
        subtitle:
            request.assignedAt != null
                ? DateFormat('MMM d, yyyy • h:mm a').format(request.assignedAt!)
                : 'Awaiting assignment',
        isCompleted:
            request.status.index >= ServiceRequestStatus.assigned.index,
        isCurrent: request.status == ServiceRequestStatus.assigned,
        icon: Icons.assignment_ind_outlined,
      ),
      _ServiceTimelineStep(
        title: 'Service In Progress',
        subtitle:
            request.serviceStartedAt != null
                ? DateFormat(
                  'MMM d, yyyy • h:mm a',
                ).format(request.serviceStartedAt!)
                : request.status == ServiceRequestStatus.inProgress
                ? 'Technician is working on it'
                : 'Pending',
        isCompleted:
            request.status.index >= ServiceRequestStatus.inProgress.index,
        isCurrent: request.status == ServiceRequestStatus.inProgress,
        icon: Icons.engineering_outlined,
      ),
      _ServiceTimelineStep(
        title: 'Service Resolved',
        subtitle:
            request.resolvedAt != null
                ? DateFormat('MMM d, yyyy • h:mm a').format(request.resolvedAt!)
                : 'Pending resolution',
        isCompleted:
            request.status.index >= ServiceRequestStatus.resolved.index,
        isCurrent: request.status == ServiceRequestStatus.resolved,
        icon: Icons.check_circle_outline,
      ),
      _ServiceTimelineStep(
        title: 'Completed',
        subtitle:
            request.completedAt != null
                ? DateFormat(
                  'MMM d, yyyy • h:mm a',
                ).format(request.completedAt!)
                : 'Awaiting your confirmation',
        isCompleted: request.status == ServiceRequestStatus.completed,
        isCurrent: request.status == ServiceRequestStatus.completed,
        icon: Icons.verified_outlined,
        isLast: true,
      ),
    ];

    // For cancelled/escalated, show different timeline
    if (request.status == ServiceRequestStatus.cancelled ||
        request.status == ServiceRequestStatus.escalated) {
      return _buildSpecialStatusCard(context, request);
    }

    return _SectionCard(
      title: 'Service Timeline',
      icon: Icons.timeline,
      children: [
        if (request.estimatedCompletionDate != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.info.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.info.withAlpha(50)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: AppTheme.info, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Estimated completion: ${DateFormat('MMM d, yyyy').format(request.estimatedCompletionDate!)}',
                    style: TextStyle(
                      color: AppTheme.infoDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ...steps.map((step) => _buildTimelineStep(context, step)),
      ],
    );
  }

  Widget _buildTimelineStep(BuildContext context, _ServiceTimelineStep step) {
    final isActive = step.isCompleted || step.isCurrent;
    final activeColor = step.isCompleted ? AppTheme.success : AppTheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? activeColor : Colors.transparent,
                border: Border.all(
                  color: isActive ? activeColor : AppTheme.borderLight,
                  width: 2,
                ),
              ),
              child: Icon(
                step.isCompleted ? Icons.check : step.icon,
                size: 14,
                color:
                    isActive ? Colors.white : AppTheme.textSecondary(context),
              ),
            ),
            if (!step.isLast)
              Container(
                width: 2,
                height: 32,
                color:
                    step.isCompleted ? AppTheme.success : AppTheme.borderLight,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: step.isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.w500,
                        color:
                            isActive
                                ? AppTheme.textPrimary(context)
                                : AppTheme.textSecondary(context),
                      ),
                    ),
                    if (step.isCurrent && !step.isCompleted) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Current',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  step.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialStatusCard(
    BuildContext context,
    ServiceRequestModel request,
  ) {
    final isEscalated = request.status == ServiceRequestStatus.escalated;
    final color = isEscalated ? AppTheme.error : AppTheme.neutral;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isEscalated ? Icons.priority_high : Icons.cancel_outlined,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEscalated ? 'Request Escalated' : 'Request Cancelled',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEscalated
                          ? 'This request has been escalated to senior support for priority handling.'
                          : 'This service request has been cancelled.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary(context),
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

  // Phase 3: Technician Contact Card
  Widget _buildTechnicianCard(
    BuildContext context,
    ServiceRequestModel request,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary.withAlpha(15),
            AppTheme.primaryLight.withAlpha(10),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.primary.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.support_agent,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Your Technician',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person,
                  color: AppTheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.technicianName ?? 'Technician',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (request.assignedProvider != null)
                      Text(
                        request.assignedProvider!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    if (request.technicianArrivalTime != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 12,
                            color: AppTheme.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ETA: ${DateFormat('h:mm a').format(request.technicianArrivalTime!)}',
                            style: const TextStyle(
                              color: AppTheme.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (request.technicianPhone != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchPhone(request.technicianPhone!),
                    icon: const Icon(Icons.phone_outlined, size: 18),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchSms(request.technicianPhone!),
                    icon: const Icon(Icons.message_outlined, size: 18),
                    label: const Text('Message'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Phase 3: Feedback Section
  Widget _buildFeedbackSection(
    BuildContext context,
    ServiceRequestModel request,
  ) {
    // If already submitted feedback
    if (request.rating != null) {
      return Column(
        children: [
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Your Feedback',
            icon: Icons.star,
            children: [
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < request.rating! ? Icons.star : Icons.star_border,
                    color: AppTheme.warning,
                    size: 28,
                  );
                }),
              ),
              if (request.feedbackComment != null &&
                  request.feedbackComment!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '"${request.feedbackComment}"',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Submitted on ${DateFormat('MMM d, yyyy').format(request.feedbackSubmittedAt ?? DateTime.now())}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary(context),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Show feedback prompt
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.warning.withAlpha(15),
                AppTheme.warning.withAlpha(5),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.warning.withAlpha(30)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.rate_review,
                      color: AppTheme.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rate Your Experience',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Help us improve by sharing your feedback',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showFeedbackDialog(context, request),
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Submit Feedback'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warning,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showFeedbackDialog(BuildContext context, ServiceRequestModel request) {
    int selectedRating = 0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.star,
                          color: AppTheme.warning,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Rate Service'),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'How was your service experience?',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  selectedRating = index + 1;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Icon(
                                  index < selectedRating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: AppTheme.warning,
                                  size: 40,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getRatingText(selectedRating),
                          style: TextStyle(
                            color: AppTheme.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: commentController,
                          decoration: InputDecoration(
                            hintText: 'Share your experience (optional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed:
                          selectedRating == 0
                              ? null
                              : () async {
                                Navigator.pop(dialogContext);
                                try {
                                  await context
                                      .read<FirestoreService>()
                                      .submitServiceFeedback(
                                        requestId: request.id,
                                        rating: selectedRating,
                                        comment:
                                            commentController.text
                                                    .trim()
                                                    .isEmpty
                                                ? null
                                                : commentController.text.trim(),
                                      );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Thank you for your feedback!',
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
                                          'Failed to submit feedback: $e',
                                        ),
                                        backgroundColor: AppTheme.error,
                                      ),
                                    );
                                  }
                                }
                              },
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            selectedRating == 0
                                ? AppTheme.warning.withAlpha(100)
                                : AppTheme.warning,
                      ),
                      child: const Text('Submit'),
                    ),
                  ],
                ),
          ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent!';
      default:
        return 'Tap to rate';
    }
  }

  void _launchPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (!await launchUrl(uri)) {
        throw 'Could not launch $uri';
      }
    } catch (e) {
      debugPrint('Error launching phone: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open dialer')));
      }
    }
  }

  void _launchSms(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('sms:$cleanPhone');
    try {
      if (!await launchUrl(uri)) {
        throw 'Could not launch $uri';
      }
    } catch (e) {
      debugPrint('Error launching SMS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open messaging app')),
        );
      }
    }
  }

  Widget _buildStatusHeader(BuildContext context, ServiceRequestModel request) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getStatusColor(request.status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: _getStatusColor(request.status).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getStatusColor(request.status),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getStatusIcon(request.status), color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.ticketNumber,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  request.status.displayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _getStatusColor(request.status),
                  ),
                ),
              ],
            ),
          ),
          if (request.priority == ServicePriority.urgent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.urgent,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'URGENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAssignmentInfo(
    BuildContext context,
    ServiceRequestModel request,
  ) {
    if (request.status == ServiceRequestStatus.pending) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.hourglass_empty,
              color: AppTheme.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your request is being reviewed. A technician will be assigned soon.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary(context),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (request.assignedProvider != null)
          _DetailRow(
            label: 'Service Provider',
            value: request.assignedProvider!,
          ),
        if (request.technicianName != null)
          _DetailRow(label: 'Technician', value: request.technicianName!),
        if (request.assignedAt != null)
          _DetailRow(
            label: 'Assigned On',
            value: DateFormat(
              'MMM d, yyyy • h:mm a',
            ).format(request.assignedAt!),
          ),
        if (request.resolvedAt != null)
          _DetailRow(
            label: 'Resolved On',
            value: DateFormat(
              'MMM d, yyyy • h:mm a',
            ).format(request.resolvedAt!),
          ),
        if (request.assignedProvider == null &&
            request.technicianName == null &&
            request.status != ServiceRequestStatus.pending)
          Text(
            'Assignment details will be updated shortly.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary(context),
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildActionSection(
    BuildContext context,
    ServiceRequestModel request,
  ) {
    // Only show the "Mark as Completed" button when status is resolved
    if (request.status == ServiceRequestStatus.resolved) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.success.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppTheme.success),
                const SizedBox(width: 8),
                Text(
                  'Service Completed',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'The technician has marked this service as resolved. Please confirm if the issue has been fixed.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showCompletionDialog(context, request),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.verified),
                label: const Text(
                  'Mark as Completed',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // For completed status - show confirmation message
    if (request.status == ServiceRequestStatus.completed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.success.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.success,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service Completed',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.success,
                    ),
                  ),
                  Text(
                    'Thank you for confirming. This request is now closed.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // For other statuses - show current progress info
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getStatusColor(request.status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: _getStatusColor(request.status).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getStatusColor(request.status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getStatusIcon(request.status),
              color: _getStatusColor(request.status),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusMessage(request.status),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  _getStatusDescription(request.status),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog(
    BuildContext context,
    ServiceRequestModel request,
  ) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Confirm Completion'),
            content: const Text(
              'Are you satisfied with the service provided? This will close the request.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await context
                      .read<FirestoreService>()
                      .updateServiceRequestStatus(
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

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder:
                        (context, url) =>
                            const Center(child: CircularProgressIndicator()),
                    errorWidget:
                        (context, url, error) => const Icon(
                          Icons.error,
                          color: Colors.white,
                          size: 50,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
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

  IconData _getStatusIcon(ServiceRequestStatus status) {
    switch (status) {
      case ServiceRequestStatus.pending:
        return Icons.hourglass_empty;
      case ServiceRequestStatus.assigned:
        return Icons.assignment_ind;
      case ServiceRequestStatus.inProgress:
        return Icons.engineering;
      case ServiceRequestStatus.resolved:
        return Icons.check_circle;
      case ServiceRequestStatus.completed:
        return Icons.verified;
      case ServiceRequestStatus.escalated:
        return Icons.priority_high;
      case ServiceRequestStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _getStatusMessage(ServiceRequestStatus status) {
    switch (status) {
      case ServiceRequestStatus.pending:
        return 'Request Pending';
      case ServiceRequestStatus.assigned:
        return 'Technician Assigned';
      case ServiceRequestStatus.inProgress:
        return 'Service In Progress';
      case ServiceRequestStatus.escalated:
        return 'Request Escalated';
      case ServiceRequestStatus.cancelled:
        return 'Request Cancelled';
      default:
        return status.displayName;
    }
  }

  String _getStatusDescription(ServiceRequestStatus status) {
    switch (status) {
      case ServiceRequestStatus.pending:
        return 'Your request is being reviewed by our team.';
      case ServiceRequestStatus.assigned:
        return 'A technician has been assigned and will contact you soon.';
      case ServiceRequestStatus.inProgress:
        return 'The technician is currently working on your request.';
      case ServiceRequestStatus.escalated:
        return 'Your request has been escalated to senior support.';
      case ServiceRequestStatus.cancelled:
        return 'This request has been cancelled.';
      default:
        return '';
    }
  }
}

// Audio Player Widget
class _AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;

  const _AudioPlayerWidget({required this.audioUrl});

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  final _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() => _duration = newDuration);
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() => _position = newPosition);
      }
    });

    try {
      await _audioPlayer.setSourceUrl(widget.audioUrl);
      setState(() => _isInit = true);
    } catch (e) {
      debugPrint("Error loading audio: $e");
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed:
                  _isInit
                      ? () async {
                        if (_isPlaying) {
                          await _audioPlayer.pause();
                        } else {
                          await _audioPlayer.play(UrlSource(widget.audioUrl));
                        }
                      }
                      : null,
              icon: Icon(
                _isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                size: 40,
                color: AppTheme.primary,
              ),
            ),
            Expanded(
              child: Slider(
                min: 0,
                max: _duration.inSeconds.toDouble(),
                value: _position.inSeconds.toDouble().clamp(
                  0,
                  _duration.inSeconds.toDouble(),
                ),
                onChanged: (value) async {
                  final position = Duration(seconds: value.toInt());
                  await _audioPlayer.seek(position);
                },
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                _formatDuration(_duration),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Section Card Widget
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

// Detail Row Widget
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary(context),
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// Phase 3: Timeline Step Helper Class
class _ServiceTimelineStep {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isCurrent;
  final IconData icon;
  final bool isLast;

  const _ServiceTimelineStep({
    required this.title,
    required this.subtitle,
    this.isCompleted = false,
    this.isCurrent = false,
    this.icon = Icons.circle,
    this.isLast = false,
  });
}
