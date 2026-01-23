import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../app/theme.dart';
import '../../models/service_request_model.dart';
import '../../services/firestore_service.dart';

class ServiceRequestDetailScreen extends StatefulWidget {
  final String requestId;

  const ServiceRequestDetailScreen({super.key, required this.requestId});

  @override
  State<ServiceRequestDetailScreen> createState() => _ServiceRequestDetailScreenState();
}

class _ServiceRequestDetailScreenState extends State<ServiceRequestDetailScreen> {
  ServiceRequestModel? _request;
  bool _isLoading = true;
  String? _selectedProvider;
  final _technicianController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  @override
  void dispose() {
    _technicianController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadRequest() async {
    try {
      final firestoreService = context.read<FirestoreService>();
      print('DEBUG ADMIN: Loading request with ID: ${widget.requestId}');
      final request = await firestoreService.getServiceRequest(widget.requestId);
      
      print('DEBUG ADMIN: Request loaded:');
      print('DEBUG ADMIN:   evidenceImages: ${request?.evidenceImages}');
      print('DEBUG ADMIN:   evidenceImages length: ${request?.evidenceImages.length}');
      print('DEBUG ADMIN:   audioRecordingUrl: ${request?.audioRecordingUrl}');
      
      if (mounted) {
        setState(() {
          _request = request;
          _isLoading = false;
          _selectedProvider = request?.assignedProvider;
          _technicianController.text = request?.technicianName ?? '';
        });
      }
    } catch (e) {
      print('Error loading request: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading details: $e')),
        );
      }
    }
  }

  Future<void> _updateStatus(ServiceRequestStatus newStatus) async {
    final firestoreService = context.read<FirestoreService>();
    
    await firestoreService.updateServiceRequestStatus(
      requestId: widget.requestId,
      status: newStatus,
      assignedProvider: _selectedProvider,
      technicianName: _technicianController.text.isNotEmpty 
          ? _technicianController.text 
          : null,
      resolutionNotes: _notesController.text.isNotEmpty 
          ? _notesController.text 
          : null,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status updated to ${newStatus.displayName}'),
        backgroundColor: AppTheme.success,
      ),
    );
    
    _loadRequest();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(_request?.ticketNumber ?? 'Loading...'),
        actions: [
          if (_request != null)
            PopupMenuButton<ServiceRequestStatus>(
              icon: const Icon(Icons.more_vert),
              onSelected: _updateStatus,
              itemBuilder: (context) => ServiceRequestStatus.values
                  .where((s) => s != _request!.status)
                  .map((status) => PopupMenuItem(
                        value: status,
                        child: Text('Mark as ${status.displayName}'),
                      ))
                  .toList(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _request == null
              ? const Center(child: Text('Request not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _getStatusColor(_request!.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                            color: _getStatusColor(_request!.status).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _getStatusColor(_request!.status),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getStatusIcon(_request!.status),
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Status',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textSecondaryLight,
                                    ),
                                  ),
                                  Text(
                                    _request!.status.displayName,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: _getStatusColor(_request!.status),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_request!.priority == ServicePriority.urgent)
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
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Customer Details
                      _SectionCard(
                        title: 'Customer Details',
                        icon: Icons.person,
                        children: [
                          _DetailRow(label: 'Name', value: _request!.customerName ?? 'N/A'),
                          _DetailRow(label: 'Phone', value: _request!.customerPhone ?? 'N/A'),
                          _DetailRow(label: 'Address', value: _request!.customerAddress ?? 'N/A'),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Product Details
                      _SectionCard(
                        title: 'Product Details',
                        icon: Icons.inventory_2,
                        children: [
                          _DetailRow(label: 'Product', value: _request!.productName ?? 'N/A'),
                          _DetailRow(label: 'Model', value: _request!.productModel ?? 'N/A'),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Issue Details
                      _SectionCard(
                        title: 'Issue Details',
                        icon: Icons.report_problem,
                        children: [
                          _DetailRow(label: 'Issue Type', value: _request!.issueType),
                          _DetailRow(
                            label: 'Reported On',
                            value: DateFormat('MMM d, yyyy • h:mm a').format(_request!.createdAt),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Description',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _request!.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      
                      // Audio Recording
                      const SizedBox(height: 16),
                      if (_request!.audioRecordingUrl != null && _request!.audioRecordingUrl!.isNotEmpty)
                        _SectionCard(
                          title: 'Audio Description',
                          icon: Icons.mic,
                          children: [
                            _AudioPlayerWidget(
                              audioUrl: _request!.audioRecordingUrl!,
                            ),
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
                                color: AppTheme.textSecondaryLight,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),

                      // Evidence Images
                      const SizedBox(height: 16),
                      if (_request!.evidenceImages.isNotEmpty)
                        _SectionCard(
                          title: 'Evidence Images',
                          icon: Icons.photo_library,
                          children: [
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _request!.evidenceImages.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      onTap: () => _showFullScreenImage(
                                        context, 
                                        _request!.evidenceImages[index],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: _request!.evidenceImages[index],
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: Colors.grey[200],
                                            child: const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Container(
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
                          icon: Icons.image_not_supported,
                          children: [
                            Text(
                              'No evidence images available.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondaryLight,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      
                      const SizedBox(height: 24),
                      
                      // Assignment Section
                      Text(
                        'Assignment',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      DropdownButtonFormField<String>(
                        value: _selectedProvider,
                        decoration: const InputDecoration(
                          labelText: 'Service Provider',
                          prefixIcon: Icon(Icons.business),
                        ),
                        items: ServiceRequestModel.serviceProviders.map((provider) {
                          return DropdownMenuItem(
                            value: provider,
                            child: Text(provider),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedProvider = value);
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _technicianController,
                        decoration: const InputDecoration(
                          labelText: 'Technician Name',
                          prefixIcon: Icon(Icons.engineering),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Resolution Notes',
                          alignLabelWithHint: true,
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(bottom: 48),
                            child: Icon(Icons.notes),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Action Buttons
                      Row(
                        children: [
                          if (_request!.status == ServiceRequestStatus.pending) ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _updateStatus(ServiceRequestStatus.assigned),
                                icon: const Icon(Icons.assignment_ind),
                                label: const Text('Assign'),
                              ),
                            ),
                          ] else if (_request!.status == ServiceRequestStatus.assigned) ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _updateStatus(ServiceRequestStatus.inProgress),
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Start'),
                              ),
                            ),
                          ] else if (_request!.status == ServiceRequestStatus.inProgress) ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _updateStatus(ServiceRequestStatus.resolved),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                ),
                                icon: const Icon(Icons.check_circle),
                                label: const Text('Resolve'),
                              ),
                            ),
                          ] else if (_request!.status ==
                              ServiceRequestStatus.resolved) ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: null, // Waiting for user confirmation
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      AppTheme.success.withOpacity(0.5),
                                ),
                                icon: const Icon(Icons.hourglass_bottom),
                                label: const Text(
                                  'Waiting for User Confirmation',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      
                      const SizedBox(height: 32),
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
}

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
    // Setup listeners first
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

    // Try to set source to get duration metadata
    try {
      await _audioPlayer.setSourceUrl(widget.audioUrl);
      setState(() => _isInit = true);
    } catch (e) {
      print("Error loading audio: $e");
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
                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
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
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryLight,
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
