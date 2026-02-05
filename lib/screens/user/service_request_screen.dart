import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../models/user_appliance_model.dart';
import '../../models/service_request_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/profile_completion_service.dart';

class ServiceRequestScreen extends StatefulWidget {
  final String productId;

  const ServiceRequestScreen({super.key, required this.productId});

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String? _selectedIssueType;
  List<XFile> _evidenceImages = [];
  String? _audioPath;
  bool _isRecording = false;
  bool _isLoading = false;
  UserApplianceModel? _product;
  String? _errorMessage;

  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    final firestoreService = context.read<FirestoreService>();
    final product = await firestoreService.getProduct(widget.productId);
    setState(() => _product = product);
  }

  Future<void> _pickImage() async {
    if (_evidenceImages.length >= 3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Maximum 3 images allowed')));
      return;
    }

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 45, // Optimized for faster uploads
      );
      if (image != null) {
        setState(() => _evidenceImages.add(image));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to capture image: $e')));
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop recording
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
    } else {
      // Start recording
      if (await _audioRecorder.hasPermission()) {
        final dir = Directory.systemTemp;
        final path =
            '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 64000,
            sampleRate: 44100,
          ),
          path: path,
        );

        setState(() => _isRecording = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedIssueType == null) {
      setState(() => _errorMessage = 'Please select an issue type');
      return;
    }

    // Validate product exists
    if (_product == null) {
      setState(() => _errorMessage = 'Product not found. Please try again.');
      return;
    }

    // Check profile completion before proceeding
    final authService = context.read<AuthService>();
    final isComplete = await ProfileCompletionService.checkAndPromptCompletion(
      context,
      authService,
      action: 'submit your service request',
    );

    if (!isComplete || !mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = context.read<AuthService>();
      final firestoreService = context.read<FirestoreService>();
      final storageService = context.read<StorageService>();

      // Use resolved ID to ensure we create requests for the linked account
      final userId = await authService.getResolvedUserId();

      // 🔒 SECURITY: Validate product ownership
      if (_product!.userId != userId) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'You can only raise service requests for your own products.';
        });
        return;
      }

      final user = await authService.getUserModel();
      final requestId = DateTime.now().millisecondsSinceEpoch.toString();

      // Upload evidence images - continue even if upload fails
      List<String> imageUrls = [];
      bool imageUploadFailed = false;
      print('DEBUG: Starting submission - requestId: $requestId');
      print('DEBUG: Evidence images count: ${_evidenceImages.length}');
      print('DEBUG: Audio path: $_audioPath');

      if (_evidenceImages.isNotEmpty) {
        try {
          imageUrls = await storageService.uploadMultipleImages(
            userId: userId,
            requestId: requestId,
            imageFiles: _evidenceImages,
          );
          print('DEBUG: Uploaded image URLs: $imageUrls');
        } catch (e) {
          print('DEBUG: Image upload failed: $e');
          imageUploadFailed = true;
          // Continue without images - don't fail the whole request
        }
      }

      // Upload audio recording - continue even if upload fails
      String? audioUrl;
      bool audioUploadFailed = false;
      if (_audioPath != null) {
        try {
          print('DEBUG: Uploading audio from path: $_audioPath');
          audioUrl = await storageService.uploadAudioRecording(
            userId: userId,
            requestId: requestId,
            filePath: _audioPath!,
          );
          print('DEBUG: Uploaded audio URL: $audioUrl');
        } catch (e) {
          print('DEBUG: Audio upload failed: $e');
          audioUploadFailed = true;
          // Continue without audio - don't fail the whole request
        }
      }

      // Create service request (even if media uploads failed)
      print('DEBUG: Creating ServiceRequestModel with:');
      print('DEBUG:   evidenceImages: $imageUrls');
      print('DEBUG:   audioRecordingUrl: $audioUrl');

      try {
        final request = ServiceRequestModel(
          id: '',
          userId: userId,
          productId: widget.productId,
          ticketNumber: ServiceRequestModel.generateTicketNumber(),
          issueType: _selectedIssueType!,
          description: _descriptionController.text.trim(),
          evidenceImages: imageUrls,
          audioRecordingUrl: audioUrl,
          status: ServiceRequestStatus.pending,
          priority: ServicePriority.normal,
          createdAt: DateTime.now(),
          customerName: user?.displayName,
          customerPhone: user?.phone,
          productName: _product?.productName,
          productModel: _product?.modelNumber,
        );

        print('DEBUG: Request toFirestore: ${request.toFirestore()}');

        final docId = await firestoreService.createServiceRequest(request);
        print('DEBUG: Created service request with docId: $docId');

        if (mounted) {
          // Show appropriate message based on upload status
          String message = 'Service request submitted successfully!';
          Color bgColor = AppTheme.success;

          if (imageUploadFailed || audioUploadFailed) {
            final failures = <String>[];
            if (imageUploadFailed) failures.add('images');
            if (audioUploadFailed) failures.add('audio');
            message =
                'Request submitted, but ${failures.join(' and ')} could not be uploaded. Please check Firebase Storage configuration.';
            bgColor = Colors.orange;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: bgColor,
              duration: Duration(
                seconds: imageUploadFailed || audioUploadFailed ? 5 : 3,
              ),
            ),
          );
          context.pop();
        }
      } catch (e) {
        print('DEBUG: Failed to create service request: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to submit request: $e';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating request: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Request Service'),
      ),
      body:
          _product == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Selected Appliance Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          border: Border.all(
                            color: AppTheme.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                UserApplianceModel.getProductImage(
                                  _product!.category,
                                ),
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SELECTED APPLIANCE',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall?.copyWith(
                                      color: AppTheme.primary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _product!.productName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color:
                                              _product!.isUnderWarranty
                                                  ? AppTheme.success
                                                  : AppTheme.textSecondary(
                                                    context,
                                                  ),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _product!.isUnderWarranty
                                            ? 'Under Warranty'
                                            : 'Warranty Expired',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall?.copyWith(
                                          color:
                                              _product!.isUnderWarranty
                                                  ? AppTheme.success
                                                  : AppTheme.textSecondary(
                                                    context,
                                                  ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Warranty Details (Always Show)
                      const SizedBox(height: 24),
                      _buildWarrantyDetails(context),

                      const SizedBox(height: 24),

                      // Issue Type Dropdown
                      Text(
                        'What seems to be the issue?',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedIssueType,
                        decoration: const InputDecoration(
                          hintText: 'Select an issue type',
                          prefixIcon: Icon(Icons.report_problem_outlined),
                        ),
                        items:
                            ServiceRequestModel.issueTypes.map((issue) {
                              return DropdownMenuItem(
                                value: issue,
                                child: Text(issue),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedIssueType = value);
                        },
                      ),

                      const SizedBox(height: 24),

                      // Description
                      Text(
                        'Tell us more about the problem',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText:
                              'Type your problem here... (e.g. The inverter is beeping continuously)',
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please describe the issue';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Evidence Section
                      Text(
                        'Add Evidence (Optional)',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      // Soft nudge for adding evidence
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.infoLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.info.withAlpha(50),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: AppTheme.info,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Adding photos or audio helps our technicians understand the issue better and speeds up resolution.',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.infoDark,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Take Photo Button
                          Expanded(
                            child: _EvidenceButton(
                              icon: Icons.camera_alt,
                              label: 'Take Photo',
                              badge:
                                  _evidenceImages.isNotEmpty
                                      ? _evidenceImages.length.toString()
                                      : null,
                              onTap: _pickImage,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Record Audio Button
                          Expanded(
                            child: _EvidenceButton(
                              icon: _isRecording ? Icons.stop : Icons.mic,
                              label:
                                  _isRecording
                                      ? 'Stop Recording'
                                      : (_audioPath != null
                                          ? 'Re-record'
                                          : 'Record Audio'),
                              isActive: _isRecording,
                              badge:
                                  _audioPath != null && !_isRecording
                                      ? '✓'
                                      : null,
                              onTap: _toggleRecording,
                            ),
                          ),
                        ],
                      ),

                      // Image Previews
                      if (_evidenceImages.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _evidenceImages.length,
                            itemBuilder: (context, index) {
                              return Container(
                                width: 80,
                                margin: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(_evidenceImages[index].path),
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _evidenceImages.removeAt(index);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Audio Recording Indicator
                      if (_audioPath != null && !_isRecording) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.successLight,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.audiotrack,
                                color: AppTheme.success,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text('Audio recording attached'),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _audioPath = null);
                                },
                                child: const Icon(Icons.close, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.errorLight,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppTheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppTheme.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitRequest,
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : const Text('Submit Complaint'),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildWarrantyDetails(BuildContext context) {
    final isWarrantyActive = _product!.isUnderWarranty;
    final bgColor =
        isWarrantyActive
            ? AppTheme.successLight.withOpacity(0.3)
            : AppTheme.warningLight.withOpacity(0.3);
    final borderColor =
        isWarrantyActive
            ? AppTheme.success.withOpacity(0.3)
            : AppTheme.warning.withOpacity(0.3);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusMd - 1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isWarrantyActive
                      ? Icons.verified_user
                      : Icons.warning_amber_rounded,
                  color:
                      isWarrantyActive
                          ? AppTheme.success
                          : AppTheme.warningDark,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isWarrantyActive ? 'Warranty Active' : 'Warranty Expired',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color:
                        isWarrantyActive
                            ? AppTheme.successDark
                            : AppTheme.warningDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (isWarrantyActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      '${_product!.daysUntilExpiry} days left',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Warranty Details
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Purchase Date',
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat(
                              'MMM d, yyyy',
                            ).format(_product!.purchaseDate),
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Warranty Ends On',
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat(
                              'MMM d, yyyy',
                            ).format(_product!.warrantyEndDate),
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  isWarrantyActive
                                      ? AppTheme.textPrimary(context)
                                      : AppTheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (_product!.serialNumber != null) ...[
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Serial Number',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _product!.serialNumber!,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ],

                // Warranty Card Image (Bill)
                if (_product!.billImageUrl != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 16,
                        color: AppTheme.textSecondary(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Digital Warranty Card / Bill',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder:
                            (context) => Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: EdgeInsets.zero,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  InteractiveViewer(
                                    minScale: 0.5,
                                    maxScale: 4.0,
                                    child: CachedNetworkImage(
                                      imageUrl: _product!.billImageUrl!,
                                      fit: BoxFit.contain,
                                      placeholder:
                                          (context, url) => const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                          ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 40,
                                    right: 20,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      );
                    },
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withAlpha(50),
                        ),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(
                            _product!.billImageUrl!,
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.0),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            child: const Icon(
                              Icons.zoom_in,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // If no bill image is available
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: AppTheme.textSecondary(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'No digital warranty card available',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
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

class _EvidenceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final bool isActive;
  final VoidCallback onTap;

  const _EvidenceButton({
    required this.icon,
    required this.label,
    this.badge,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color:
              isActive
                  ? AppTheme.error.withOpacity(0.1)
                  : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color:
                isActive
                    ? AppTheme.error
                    : Theme.of(context).dividerColor.withAlpha(50),
          ),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color:
                        isActive
                            ? AppTheme.error.withOpacity(0.1)
                            : AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isActive ? AppTheme.error : AppTheme.primary,
                    size: 24,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.success,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color:
                    isActive ? AppTheme.error : AppTheme.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
