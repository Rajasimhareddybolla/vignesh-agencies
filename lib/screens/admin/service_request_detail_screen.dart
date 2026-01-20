import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme.dart';
import '../../models/service_request_model.dart';
import '../../services/firestore_service.dart';

class ServiceRequestDetailScreen extends StatefulWidget {
  final String requestId;

  const ServiceRequestDetailScreen({super.key, required this.requestId});

  @override
  State<ServiceRequestDetailScreen> createState() =>
      _ServiceRequestDetailScreenState();
}

class _ServiceRequestDetailScreenState
    extends State<ServiceRequestDetailScreen> {
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
    final firestoreService = context.read<FirestoreService>();
    final request = await firestoreService.getServiceRequest(widget.requestId);
    setState(() {
      _request = request;
      _isLoading = false;
      _selectedProvider = request?.assignedProvider;
      _technicianController.text = request?.technicianName ?? '';
    });
  }

  Future<void> _updateStatus(ServiceRequestStatus newStatus) async {
    final firestoreService = context.read<FirestoreService>();

    await firestoreService.updateServiceRequestStatus(
      requestId: widget.requestId,
      status: newStatus,
      assignedProvider: _selectedProvider,
      technicianName:
          _technicianController.text.isNotEmpty
              ? _technicianController.text
              : null,
      resolutionNotes:
          _notesController.text.isNotEmpty ? _notesController.text : null,
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
              itemBuilder:
                  (context) =>
                      ServiceRequestStatus.values
                          .where((s) => s != _request!.status)
                          .map(
                            (status) => PopupMenuItem(
                              value: status,
                              child: Text('Mark as ${status.displayName}'),
                            ),
                          )
                          .toList(),
            ),
        ],
      ),
      body:
          _isLoading
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
                        color: _getStatusColor(
                          _request!.status,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: _getStatusColor(
                            _request!.status,
                          ).withOpacity(0.3),
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
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondaryLight,
                                  ),
                                ),
                                Text(
                                  _request!.status.displayName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _getStatusColor(_request!.status),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_request!.priority == ServicePriority.urgent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.urgent,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusFull,
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.warning,
                                    color: Colors.white,
                                    size: 16,
                                  ),
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
                        _DetailRow(
                          label: 'Name',
                          value: _request!.customerName ?? 'N/A',
                        ),
                        _DetailRow(
                          label: 'Phone',
                          value: _request!.customerPhone ?? 'N/A',
                        ),
                        _DetailRow(
                          label: 'Address',
                          value: _request!.customerAddress ?? 'N/A',
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Product Details
                    _SectionCard(
                      title: 'Product Details',
                      icon: Icons.inventory_2,
                      children: [
                        _DetailRow(
                          label: 'Product',
                          value: _request!.productName ?? 'N/A',
                        ),
                        _DetailRow(
                          label: 'Model',
                          value: _request!.productModel ?? 'N/A',
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Issue Details
                    _SectionCard(
                      title: 'Issue Details',
                      icon: Icons.report_problem,
                      children: [
                        _DetailRow(
                          label: 'Issue Type',
                          value: _request!.issueType,
                        ),
                        _DetailRow(
                          label: 'Reported On',
                          value: DateFormat(
                            'MMM d, yyyy • h:mm a',
                          ).format(_request!.createdAt),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Description',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondaryLight),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _request!.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),

                    // Evidence Images
                    if (_request!.evidenceImages.isNotEmpty) ...[
                      const SizedBox(height: 16),
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
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: _request!.evidenceImages[index],
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],

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
                      items:
                          ServiceRequestModel.serviceProviders.map((provider) {
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
                        if (_request!.status ==
                            ServiceRequestStatus.pending) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  () => _updateStatus(
                                    ServiceRequestStatus.assigned,
                                  ),
                              icon: const Icon(Icons.assignment_ind),
                              label: const Text('Assign'),
                            ),
                          ),
                        ] else if (_request!.status ==
                            ServiceRequestStatus.assigned) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  () => _updateStatus(
                                    ServiceRequestStatus.inProgress,
                                  ),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start'),
                            ),
                          ),
                        ] else if (_request!.status ==
                            ServiceRequestStatus.inProgress) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  () => _updateStatus(
                                    ServiceRequestStatus.resolved,
                                  ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.success,
                              ),
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Resolve'),
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
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
