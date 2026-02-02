import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
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
            return const Center(
              child: Text('Request not found'),
            );
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
                      value: DateFormat('MMM d, yyyy • h:mm a')
                          .format(request.createdAt),
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
                        label: 'Product', value: request.productName ?? 'N/A'),
                    _DetailRow(
                        label: 'Model', value: request.productModel ?? 'N/A'),
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
                                onTap: () => _showFullScreenImage(
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
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
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

                // Assignment Information (Read-Only)
                _SectionCard(
                  title: 'Service Assignment',
                  icon: Icons.assignment_ind_outlined,
                  children: [
                    _buildAssignmentInfo(context, request),
                  ],
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
            child: Icon(
              _getStatusIcon(request.status),
              color: Colors.white,
            ),
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
      BuildContext context, ServiceRequestModel request) {
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
          _DetailRow(
            label: 'Technician',
            value: request.technicianName!,
          ),
        if (request.assignedAt != null)
          _DetailRow(
            label: 'Assigned On',
            value:
                DateFormat('MMM d, yyyy • h:mm a').format(request.assignedAt!),
          ),
        if (request.resolvedAt != null)
          _DetailRow(
            label: 'Resolved On',
            value:
                DateFormat('MMM d, yyyy • h:mm a').format(request.resolvedAt!),
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
      BuildContext context, ServiceRequestModel request) {
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
                const Icon(
                  Icons.check_circle_outline,
                  color: AppTheme.success,
                ),
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
              child: const Icon(
                Icons.verified,
                color: Colors.white,
              ),
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
        border:
            Border.all(color: _getStatusColor(request.status).withOpacity(0.3)),
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
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
      BuildContext context, ServiceRequestModel request) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => const Icon(
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
              onPressed: _isInit
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
                value: _position.inSeconds
                    .toDouble()
                    .clamp(0, _duration.inSeconds.toDouble()),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderLight),
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
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
