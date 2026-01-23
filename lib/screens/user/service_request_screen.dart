import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'dart:io';
import '../../app/theme.dart';
import '../../models/user_appliance_model.dart';
import '../../models/service_request_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';

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
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
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
            bitRate: 128000,
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
      final user = await authService.getUserModel();
      final requestId = DateTime.now().millisecondsSinceEpoch.toString();

      // Upload evidence images
      List<String> imageUrls = [];
      if (_evidenceImages.isNotEmpty) {
        imageUrls = await storageService.uploadMultipleImages(
          userId: userId,
          requestId: requestId,
          imageFiles: _evidenceImages,
        );
      }

      // Upload audio recording
      String? audioUrl;
      if (_audioPath != null) {
        audioUrl = await storageService.uploadAudioRecording(
          userId: userId,
          requestId: requestId,
          filePath: _audioPath!,
        );
      }

      // Create service request
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

      await firestoreService.createServiceRequest(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Service request submitted to Vignesh Agencies successfully!',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to submit request: $e';
      });
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
                                                  : AppTheme.textSecondaryLight,
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
                                                  : AppTheme.textSecondaryLight,
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
          color: isActive ? AppTheme.error.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isActive ? AppTheme.error : AppTheme.borderLight,
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
                color: isActive ? AppTheme.error : AppTheme.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
