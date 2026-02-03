import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme.dart';
import '../../models/service_request_model.dart';
import '../../models/user_appliance_model.dart';
import '../../models/agent_model.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class ServiceRequestDetailScreen extends StatefulWidget {
  final String requestId;

  const ServiceRequestDetailScreen({super.key, required this.requestId});

  @override
  State<ServiceRequestDetailScreen> createState() =>
      _ServiceRequestDetailScreenState();
}

class _ServiceRequestDetailScreenState
    extends State<ServiceRequestDetailScreen> {
  String? _selectedProvider;
  AgentModel? _selectedAgent;
  final _technicianController = TextEditingController();
  final _technicianPhoneController = TextEditingController();
  final _technicianAddressController = TextEditingController();
  final _notesController = TextEditingController();

  // Admin Voice Note
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  String? _adminVoiceNotePath;
  String? _adminVoiceNoteUrl; // URL from Firestore/Storage if already saved

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _technicianController.dispose();
    _technicianPhoneController.dispose();
    _technicianAddressController.dispose();
    _notesController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _initializeControllers(ServiceRequestModel request) {
    if (!_isInitialized) {
      _selectedProvider = request.assignedProvider;
      _technicianController.text = request.technicianName ?? '';
      _technicianPhoneController.text = request.technicianPhone ?? '';
      _technicianAddressController.text = request.technicianAddress ?? '';
      _adminVoiceNoteUrl = request.adminVoiceNoteUrl;
      _isInitialized = true;
    }
  }

  void _populateFromAgent(AgentModel agent) {
    setState(() {
      _selectedAgent = agent;
      _technicianController.text = agent.name;
      _technicianPhoneController.text = agent.phone;
      _technicianAddressController.text = agent.address;
    });
  }

  Future<void> _updateStatus(ServiceRequestStatus newStatus) async {
    final firestoreService = context.read<FirestoreService>();
    final storageService = context.read<StorageService>();

    // Upload admin voice note if new one recorded
    if (_adminVoiceNotePath != null && _adminVoiceNoteUrl == null) {
      try {
        _adminVoiceNoteUrl = await storageService.uploadAdminVoiceNote(
          requestId: widget.requestId,
          filePath: _adminVoiceNotePath!,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload voice note: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }

    await firestoreService.updateServiceRequestStatus(
      requestId: widget.requestId,
      status: newStatus,
      assignedProvider: _selectedProvider,
      technicianName:
          _technicianController.text.isNotEmpty
              ? _technicianController.text
              : null,
      technicianPhone:
          _technicianPhoneController.text.isNotEmpty
              ? _technicianPhoneController.text
              : null,
      technicianAddress:
          _technicianAddressController.text.isNotEmpty
              ? _technicianAddressController.text
              : null,
      resolutionNotes:
          _notesController.text.isNotEmpty ? _notesController.text : null,
      adminVoiceNoteUrl: _adminVoiceNoteUrl,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status updated to ${newStatus.displayName}'),
        backgroundColor: AppTheme.success,
      ),
    );

    // If assigning, trigger WhatsApp and update agent
    if (newStatus == ServiceRequestStatus.assigned) {
      // Update agent's last assigned  timestamp
      if (_selectedAgent != null) {
        await firestoreService.updateAgentLastAssigned(_selectedAgent!.id);
      }
      // Ask user if they want to share via WhatsApp
      _showShareDialog();
    }
  }

  // Voice Recording Methods
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path =
            '${directory.path}/admin_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _adminVoiceNotePath = null; // Reset previous
          _adminVoiceNoteUrl = null; // Reset previous URL if re-recording
        });
      }
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _adminVoiceNotePath = path;
      });
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  void _deleteAdminRecording() {
    setState(() {
      _adminVoiceNotePath = null;
      _adminVoiceNoteUrl = null;
    });
  }

  void _showShareDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Share Assignment Details'),
            content: const Text(
              'Do you want to share the request details with the technician via WhatsApp?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('No'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleShareAction();
                },
                child: const Text('Share via WhatsApp'),
              ),
            ],
          ),
    );
  }

  Future<void> _handleShareAction() async {
    // await _generateAndSharePdf(); // This method is not provided in the snippet, assuming it exists elsewhere or will be added.
    // After sharing PDF, we can also prompt to open chat if needed,
    // but usually user will just share PDF to WhatsApp contact.
    // We can also offer "Open WhatsApp Chat" as a separate button in the status SnackBar or UI.
    // Let's call the message sender too for the text part.
    await _sendWhatsAppMessage();
  }

  Future<void> _sendWhatsAppMessage() async {
    final firestoreService = context.read<FirestoreService>();
    final request = await firestoreService.getServiceRequest(widget.requestId);
    if (request == null) return;

    final phone = _technicianPhoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot send WhatsApp: No technician phone number'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Fetch Product for Warranty Details
    UserApplianceModel? product;
    try {
      product = await firestoreService.getProduct(request.productId);
    } catch (e) {
      print('Error fetching product: $e');
    }

    final StringBuffer msg = StringBuffer();
    msg.writeln('*New Service Request Assigned*');
    msg.writeln('--------------------------------');
    msg.writeln('*Ticket ID:* ${request.ticketNumber}');
    msg.writeln('*Issue Type:* ${request.issueType}');
    msg.writeln(
      '*Priority:* ${request.priority == ServicePriority.urgent ? "URGENT 🚨" : "Normal"}',
    );
    msg.writeln('');

    msg.writeln('*Product Details:*');
    msg.writeln('Product: ${request.productName ?? "N/A"}');
    msg.writeln('Model: ${request.productModel ?? "N/A"}');

    if (product != null) {
      msg.writeln('Warranty Status: ${product.status.displayName}');
      msg.writeln(
        'Warranty Ends: ${DateFormat('dd MMM yyyy').format(product.warrantyEndDate)}',
      );
    } else {
      msg.writeln('Warranty Info: N/A');
    }
    msg.writeln('');

    msg.writeln('*Customer Details:*');
    msg.writeln('Name: ${request.customerName ?? "N/A"}');
    msg.writeln('Phone: ${request.customerPhone ?? "N/A"}');
    msg.writeln('Address: ${request.customerAddress ?? "N/A"}');
    msg.writeln('');

    msg.writeln('*Issue Description:*');
    msg.writeln(request.description);
    msg.writeln('');

    if (request.audioRecordingUrl != null) {
      msg.writeln('*Audio Note:*');
      msg.writeln(request.audioRecordingUrl);
      msg.writeln('');
    }

    if (request.evidenceImages.isNotEmpty) {
      msg.writeln('*Images:*');
      for (var img in request.evidenceImages) {
        msg.writeln(img);
      }
      msg.writeln('');
    }

    if (request.adminVoiceNoteUrl != null || _adminVoiceNoteUrl != null) {
      msg.writeln('*Admin Instruction (Voice Note):*');
      msg.writeln(request.adminVoiceNoteUrl ?? _adminVoiceNoteUrl);
      msg.writeln('');
    }

    final String message = msg.toString();

    // Try WhatsApp with app scheme first, then fallback to web
    final List<String> urls = [
      'whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}',
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    ];

    bool launched = false;
    for (final url in urls) {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          launched = true;
          break;
        }
      } catch (e) {
        print('Error launching $url: $e');
      }
    }

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open WhatsApp. Please ensure WhatsApp is installed.',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _generateAndSharePdf() async {
    final firestoreService = context.read<FirestoreService>();
    final request = await firestoreService.getServiceRequest(widget.requestId);
    if (request == null) return;

    // Fetch product if available
    UserApplianceModel? product;
    if (request.productId.isNotEmpty) {
      try {
        product = await firestoreService.getProduct(request.productId);
      } catch (e) {
        print('Error fetching product for PDF: $e');
      }
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Service Request Details',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  pw.Text(
                    request.ticketNumber,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Status and Priority
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Status: ${request.status.displayName}'),
                pw.Text(
                  'Priority: ${request.priority.displayName.toUpperCase()}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color:
                        request.priority == ServicePriority.urgent
                            ? PdfColors.red
                            : PdfColors.black,
                  ),
                ),
              ],
            ),
            pw.Divider(),

            // Customer Info
            pw.Header(level: 1, text: 'Customer Details'),
            pw.Text('Name: ${request.customerName ?? "N/A"}'),
            pw.Text('Phone: ${request.customerPhone ?? "N/A"}'),
            pw.Text('Address: ${request.customerAddress ?? "N/A"}'),
            pw.SizedBox(height: 10),

            // Product Info
            pw.Header(level: 1, text: 'Product Details'),
            pw.Text('Product: ${request.productName ?? "N/A"}'),
            pw.Text('Model: ${request.productModel ?? "N/A"}'),
            if (product != null) ...[
              pw.Text(
                'Warranty Status: ${product.isUnderWarranty ? "Active" : "Expired"}',
              ),
              pw.Text(
                'Warranty Ends: ${DateFormat("dd MMM yyyy").format(product.warrantyEndDate)}',
              ),
            ],
            pw.SizedBox(height: 10),

            // Issue Info
            pw.Header(level: 1, text: 'Issue Description'),
            pw.Text('Type: ${request.issueType}'),
            pw.Text(
              'Reported: ${DateFormat("dd MMM yyyy, h:mm a").format(request.createdAt)}',
            ),
            pw.Paragraph(text: request.description),

            // Admin Instructions
            if (_adminVoiceNoteUrl != null ||
                (request.adminVoiceNoteUrl != null &&
                    request.adminVoiceNoteUrl!.isNotEmpty)) ...[
              pw.SizedBox(height: 10),
              pw.Header(level: 1, text: 'Admin Instructions'),
              pw.Text(
                'Voice Note Attached to Job Card. Please check WhatsApp for link.',
              ),
            ],

            // Footer
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.Text(
              'Vignesh Agencies Service Team',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10),
            ),
          ];
        },
      ),
    );

    // Save and Share
    final bytes = await doc.save();
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/service_request_${request.ticketNumber}.pdf',
    );
    await file.writeAsBytes(bytes);

    // Share using Share Plus
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Service Request ${request.ticketNumber} Details');
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return StreamBuilder<ServiceRequestModel?>(
      stream: firestoreService.getServiceRequestStream(widget.requestId),
      builder: (context, snapshot) {
        final request = snapshot.data;

        // Initialize controllers when data is first loaded
        if (request != null) {
          _initializeControllers(request);
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: Text(request?.ticketNumber ?? 'Loading...'),
            actions: [
              if (request != null)
                PopupMenuButton<ServiceRequestStatus>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: _updateStatus,
                  itemBuilder:
                      (context) =>
                          ServiceRequestStatus.values
                              .where((s) => s != request.status)
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
              snapshot.connectionState == ConnectionState.waiting &&
                      request == null
                  ? const Center(child: CircularProgressIndicator())
                  : request == null
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
                              request.status,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                            border: Border.all(
                              color: _getStatusColor(
                                request.status,
                              ).withOpacity(0.3),
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
                                      'Status',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.textSecondary(context),
                                      ),
                                    ),
                                    Text(
                                      request.status.displayName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: _getStatusColor(request.status),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (request.priority == ServicePriority.urgent)
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
                              value: request.customerName ?? 'N/A',
                            ),
                            _DetailRow(
                              label: 'Phone',
                              value: request.customerPhone ?? 'N/A',
                            ),
                            _DetailRow(
                              label: 'Address',
                              value: request.customerAddress ?? 'N/A',
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
                              value: request.productName ?? 'N/A',
                            ),
                            _DetailRow(
                              label: 'Model',
                              value: request.productModel ?? 'N/A',
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Warranty Details
                        FutureBuilder<UserApplianceModel?>(
                          future: firestoreService.getProduct(
                            request.productId,
                          ),
                          builder: (context, productSnapshot) {
                            final product = productSnapshot.data;

                            if (productSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return _SectionCard(
                                title: 'Warranty Details',
                                icon: Icons.shield,
                                children: const [
                                  Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                ],
                              );
                            }

                            if (product == null) {
                              return _SectionCard(
                                title: 'Warranty Details',
                                icon: Icons.shield,
                                children: [
                                  Text(
                                    'Unable to load warranty information.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textSecondary(context),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              );
                            }

                            final isWarrantyActive = product.isUnderWarranty;

                            return _SectionCard(
                              title: 'Warranty Details',
                              icon:
                                  isWarrantyActive
                                      ? Icons.verified_user
                                      : Icons.warning_amber_rounded,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        isWarrantyActive
                                            ? AppTheme.success.withOpacity(0.1)
                                            : AppTheme.warning.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          isWarrantyActive
                                              ? AppTheme.success.withOpacity(
                                                0.3,
                                              )
                                              : AppTheme.warning.withOpacity(
                                                0.3,
                                              ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isWarrantyActive
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color:
                                            isWarrantyActive
                                                ? AppTheme.success
                                                : AppTheme.warning,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isWarrantyActive
                                            ? 'Warranty Active'
                                            : 'Warranty Expired',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall?.copyWith(
                                          color:
                                              isWarrantyActive
                                                  ? AppTheme.successDark
                                                  : AppTheme.warningDark,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (isWarrantyActive) ...[
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.success,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            '${product.daysUntilExpiry} days left',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _DetailRow(
                                  label: 'Purchase Date',
                                  value: DateFormat(
                                    'MMM d, yyyy',
                                  ).format(product.purchaseDate),
                                ),
                                _DetailRow(
                                  label: 'Warranty Expires',
                                  value: DateFormat(
                                    'MMM d, yyyy',
                                  ).format(product.warrantyEndDate),
                                ),
                                if (product.serialNumber != null)
                                  _DetailRow(
                                    label: 'Serial Number',
                                    value: product.serialNumber!,
                                  ),
                                if (product.billImageUrl != null) ...[
                                  const SizedBox(height: 8),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Digital Warranty Card / Bill',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textSecondary(context),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap:
                                        () => _showFullScreenImage(
                                          context,
                                          product.billImageUrl!,
                                        ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: product.billImageUrl!,
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        placeholder:
                                            (context, url) => Container(
                                              color: Colors.grey[200],
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(),
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
                                ],
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // Issue Details
                        _SectionCard(
                          title: 'Issue Details',
                          icon: Icons.report_problem,
                          children: [
                            _DetailRow(
                              label: 'Issue Type',
                              value: request.issueType,
                            ),
                            _DetailRow(
                              label: 'Reported On',
                              value: DateFormat(
                                'MMM d, yyyy • h:mm a',
                              ).format(request.createdAt),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Description',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
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

                        // Audio Recording
                        const SizedBox(height: 16),
                        if (request.audioRecordingUrl != null &&
                            request.audioRecordingUrl!.isNotEmpty)
                          _SectionCard(
                            title: 'Audio Description',
                            icon: Icons.mic,
                            children: [
                              _AudioPlayerWidget(
                                audioUrl: request.audioRecordingUrl!,
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
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary(context),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),

                        // Evidence Images
                        const SizedBox(height: 16),
                        if (request.evidenceImages.isNotEmpty)
                          _SectionCard(
                            title: 'Evidence Images',
                            icon: Icons.photo_library,
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: CachedNetworkImage(
                                            imageUrl:
                                                request.evidenceImages[index],
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                            placeholder:
                                                (context, url) => Container(
                                                  color: Colors.grey[200],
                                                  child: const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    Container(
                                                      color: Colors.grey[200],
                                                      child: const Icon(
                                                        Icons.error,
                                                      ),
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
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary(context),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 24),

                        // Assignment Section with Agent Selector
                        _SectionCard(
                          title: 'Assignment',
                          icon: Icons.assignment,
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedProvider,
                              decoration: const InputDecoration(
                                labelText: 'Service Provider',
                                prefixIcon: Icon(Icons.business),
                              ),
                              items:
                                  ServiceRequestModel.serviceProviders.map((
                                    provider,
                                  ) {
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
                            // Agent Selector
                            StreamBuilder<List<AgentModel>>(
                              stream:
                                  context
                                      .read<FirestoreService>()
                                      .getActiveAgents(),
                              builder: (context, snapshot) {
                                final agents = snapshot.data ?? [];

                                if (agents.isEmpty) {
                                  return Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warning.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: AppTheme.warning.withOpacity(
                                              0.3,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.info_outline,
                                              color: AppTheme.warning,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'No saved agents. Add agent details manually or create agents in Agent Management.',
                                                style: TextStyle(
                                                  color: AppTheme.warning,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                  );
                                }

                                return Column(
                                  children: [
                                    DropdownButtonFormField<String>(
                                      value: _selectedAgent?.id,
                                      decoration: InputDecoration(
                                        labelText: 'Select Saved Agent',
                                        prefixIcon: const Icon(
                                          Icons.person_search,
                                        ),
                                        suffix: TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _selectedAgent = null;
                                              _technicianController.clear();
                                              _technicianPhoneController
                                                  .clear();
                                              _technicianAddressController
                                                  .clear();
                                            });
                                          },
                                          child: const Text('Clear'),
                                        ),
                                      ),
                                      items:
                                          agents.map((agent) {
                                            return DropdownMenuItem(
                                              value: agent.id,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    agent.name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  Text(
                                                    agent.phone,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AppTheme.textSecondary(
                                                            context,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                      onChanged: (agentId) {
                                        if (agentId != null) {
                                          final agent = agents.firstWhere(
                                            (a) => a.id == agentId,
                                          );
                                          _populateFromAgent(agent);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                );
                              },
                            ),
                            TextFormField(
                              controller: _technicianController,
                              decoration: const InputDecoration(
                                labelText: 'Agent Name',
                                prefixIcon: Icon(Icons.person),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _technicianPhoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Agent Phone Number',
                                prefixIcon: Icon(Icons.phone),
                                hintText: 'e.g. 919876543210',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _technicianAddressController,
                              decoration: const InputDecoration(
                                labelText: 'Agent Address',
                                prefixIcon: Icon(Icons.location_on),
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),

                            // Admin Voice Note Recorder
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.border(context),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Voice Note for Technician',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textSecondary(context),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_isRecording)
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.mic,
                                          color: Colors.red,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Recording...',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          icon: const Icon(Icons.stop_circle),
                                          color: Colors.red,
                                          onPressed: _stopRecording,
                                        ),
                                      ],
                                    )
                                  else if (_adminVoiceNotePath != null ||
                                      (_adminVoiceNoteUrl != null &&
                                          _adminVoiceNoteUrl!.isNotEmpty))
                                    Column(
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.mic_none),
                                            const SizedBox(width: 8),
                                            Text(
                                              _adminVoiceNotePath != null
                                                  ? 'New Recording Ready'
                                                  : 'Voice Note Attached',
                                            ),
                                            const Spacer(),
                                            if (_adminVoiceNotePath != null)
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                onPressed:
                                                    _deleteAdminRecording,
                                              ),
                                          ],
                                        ),
                                        if (_adminVoiceNotePath != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8.0,
                                            ),
                                            child: Text(
                                              'Will be sent with assignment',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.success,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        if (_adminVoiceNoteUrl != null &&
                                            _adminVoiceNotePath == null)
                                          _AudioPlayerWidget(
                                            audioUrl: _adminVoiceNoteUrl!,
                                          ),
                                      ],
                                    )
                                  else
                                    InkWell(
                                      onTap: _startRecording,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: AppTheme.primary.withOpacity(
                                              0.3,
                                            ),
                                            style: BorderStyle.solid,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.mic,
                                              color: AppTheme.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Tap to Record Instructions',
                                              style: TextStyle(
                                                color: AppTheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
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
                            if (request.status ==
                                ServiceRequestStatus.pending) ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      () => _updateStatus(
                                        ServiceRequestStatus.assigned,
                                      ),
                                  icon: const Icon(Icons.assignment_ind),
                                  label: const Text('Assign & Notify Agent'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ] else if (request.status ==
                                ServiceRequestStatus.assigned) ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      () => _updateStatus(
                                        ServiceRequestStatus.inProgress,
                                      ),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Start Work'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _sendWhatsAppMessage,
                                  icon: const Icon(Icons.share),
                                  label: const Text('Resend WhatsApp'),
                                ),
                              ),
                            ] else if (request.status ==
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
                            ] else if (request.status ==
                                ServiceRequestStatus.resolved) ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      null, // Waiting for user confirmation
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.success
                                        .withOpacity(0.5),
                                  ),
                                  icon: const Icon(Icons.hourglass_bottom),
                                  label: const Text(
                                    'Waiting for User Confirmation',
                                  ),
                                ),
                              ),
                            ] else if (request.status ==
                                ServiceRequestStatus.completed) ...[
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.success.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.verified,
                                        color: AppTheme.success,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Completed by Customer',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall?.copyWith(
                                          color: AppTheme.success,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
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
      },
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

  Future<void> _generateAndSharePdf() async {
    final firestoreService = context.read<FirestoreService>();
    final request = await firestoreService.getServiceRequest(widget.requestId);
    if (request == null) return;

    // Fetch product if available
    UserApplianceModel? product;
    if (request.productId.isNotEmpty) {
      try {
        product = await firestoreService.getProduct(request.productId);
      } catch (e) {
        print('Error fetching product for PDF: $e');
      }
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Service Request Details',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  pw.Text(
                    request.ticketNumber,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Status and Priority
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Status: ${request.status.displayName}'),
                pw.Text(
                  'Priority: ${request.priority.displayName.toUpperCase()}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color:
                        request.priority == ServicePriority.urgent
                            ? PdfColors.red
                            : PdfColors.black,
                  ),
                ),
              ],
            ),
            pw.Divider(),

            // Customer Info
            pw.Header(level: 1, text: 'Customer Details'),
            pw.Text('Name: ${request.customerName ?? "N/A"}'),
            pw.Text('Phone: ${request.customerPhone ?? "N/A"}'),
            pw.Text('Address: ${request.customerAddress ?? "N/A"}'),
            pw.SizedBox(height: 10),

            // Product Info
            pw.Header(level: 1, text: 'Product Details'),
            pw.Text('Product: ${request.productName ?? "N/A"}'),
            pw.Text('Model: ${request.productModel ?? "N/A"}'),
            if (product != null) ...[
              pw.Text(
                'Warranty Status: ${product.isUnderWarranty ? "Active" : "Expired"}',
              ),
              pw.Text(
                'Warranty Ends: ${DateFormat("dd MMM yyyy").format(product.warrantyEndDate)}',
              ),
            ],
            pw.SizedBox(height: 10),

            // Issue Info
            pw.Header(level: 1, text: 'Issue Description'),
            pw.Text('Type: ${request.issueType}'),
            pw.Text(
              'Reported: ${DateFormat("dd MMM yyyy, h:mm a").format(request.createdAt)}',
            ),
            pw.Paragraph(text: request.description),

            // Admin Instructions
            if (_adminVoiceNoteUrl != null ||
                (request.adminVoiceNoteUrl != null &&
                    request.adminVoiceNoteUrl!.isNotEmpty)) ...[
              pw.SizedBox(height: 10),
              pw.Header(level: 1, text: 'Admin Instructions'),
              pw.Text(
                'Voice Note Attached to Job Card. Please check WhatsApp for link.',
              ),
            ],

            // Footer
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.Text(
              'Vignesh Agencies Service Team',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10),
            ),
          ];
        },
      ),
    );

    // Save and Share
    final bytes = await doc.save();
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/service_request_${request.ticketNumber}.pdf',
    );
    await file.writeAsBytes(bytes);

    // Share using Share Plus
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Service Request ${request.ticketNumber} Details');
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

    // Then set the source
    try {
      await _audioPlayer.setSourceUrl(widget.audioUrl);
      if (mounted) {
        setState(() => _isInit = true);
      }
    } catch (e) {
      print('Error initializing audio: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (!_isInit) return;

    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
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
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: _isInit ? _togglePlayPause : null,
              color: AppTheme.primary,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Slider(
                    value: _position.inSeconds.toDouble(),
                    max: _duration.inSeconds.toDouble(),
                    onChanged:
                        _isInit
                            ? (value) async {
                              final position = Duration(seconds: value.toInt());
                              await _audioPlayer.seek(position);
                            }
                            : null,
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
              ),
            ),
          ],
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
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusMd - 1),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary(context),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
