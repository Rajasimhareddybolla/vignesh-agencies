import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../app/theme.dart';
import '../../models/user_appliance_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _modelController = TextEditingController();
  final _serialController = TextEditingController();
  final _productNameController = TextEditingController();

  String? _selectedCategory;
  DateTime? _purchaseDate;
  XFile? _billImage;
  bool _isLoading = false;
  String? _errorMessage;

  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _modelController.dispose();
    _serialController.dispose();
    _productNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() => _billImage = image);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Upload Bill / Warranty Card',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ImageSourceOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                    _ImageSourceOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _purchaseDate = picked);
    }
  }

  Future<void> _registerProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      setState(() => _errorMessage = 'Please select a product category');
      return;
    }

    if (_purchaseDate == null) {
      setState(() => _errorMessage = 'Please select purchase date');
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

      // Use resolved ID to ensure we add products to the linked account if in bypass mode
      final userId = await authService.getResolvedUserId();
      String? billImageUrl;

      // Upload bill image if selected
      if (_billImage != null) {
        billImageUrl = await storageService.uploadBillImage(
          userId: userId,
          imageFile: _billImage!,
        );
      }

      // Calculate warranty end date (1 year from purchase by default)
      final warrantyEndDate = DateTime(
        _purchaseDate!.year + 1,
        _purchaseDate!.month,
        _purchaseDate!.day,
      );

      // Create product model
      final product = UserApplianceModel(
        id: '',
        userId: userId,
        category: _selectedCategory!,
        productName:
            _productNameController.text.isNotEmpty
                ? _productNameController.text.trim()
                : _selectedCategory!,
        modelNumber: _modelController.text.trim(),
        serialNumber:
            _serialController.text.trim().isNotEmpty
                ? _serialController.text.trim()
                : null,
        purchaseDate: _purchaseDate!,
        warrantyEndDate: warrantyEndDate,
        billImageUrl: billImageUrl,
        status: ProductStatus.pendingValidation,
        createdAt: DateTime.now(),
      );

      await firestoreService.addProduct(product);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vignesh Agencies product registered successfully! Awaiting verification.',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to register product with Vignesh Agencies: $e';
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
        title: const Text('Register Product'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Category Dropdown
              Text(
                'Product Category',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  hintText: 'Select Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items:
                    UserApplianceModel.categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getCategoryIcon(category),
                              size: 20,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Flexible(child: Text(category)),
                          ],
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                },
              ),

              const SizedBox(height: 24),

              // Product Name (Optional)
              Text(
                'Product Name (Optional)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _productNameController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Victo 15L Heater',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),

              const SizedBox(height: 24),

              // Model / Serial Number
              Text(
                'Model / Serial Number',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _modelController,
                decoration: InputDecoration(
                  hintText: 'e.g., VG-WH-15',
                  prefixIcon: const Icon(Icons.qr_code),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () {
                      // TODO: Implement barcode scanner
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Barcode scanner coming soon!'),
                        ),
                      );
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter model number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Date of Purchase
              Text(
                'Date of Purchase',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: AppTheme.textSecondaryLight,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _purchaseDate != null
                              ? DateFormat('dd/MM/yyyy').format(_purchaseDate!)
                              : 'mm/dd/yyyy',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(
                            color:
                                _purchaseDate != null
                                    ? AppTheme.textPrimaryLight
                                    : AppTheme.textSecondaryLight,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.calendar_month,
                        color: AppTheme.textSecondaryLight,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Bill / Warranty Card Upload
              Text(
                'Bill / Warranty Card',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showImageSourcePicker,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.borderLight,
                      style:
                          _billImage == null
                              ? BorderStyle.solid
                              : BorderStyle.none,
                    ),
                  ),
                  child:
                      _billImage != null
                          ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd,
                                ),
                                child:
                                    kIsWeb
                                        ? Image.network(
                                          _billImage!.path,
                                          width: double.infinity,
                                          height: 180,
                                          fit: BoxFit.cover,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Container(
                                              color: AppTheme.backgroundLight,
                                              child: const Center(
                                                child: Icon(
                                                  Icons.image,
                                                  size: 48,
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                        : Image.file(
                                          File(_billImage!.path),
                                          width: double.infinity,
                                          height: 180,
                                          fit: BoxFit.cover,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Container(
                                              color: AppTheme.backgroundLight,
                                              child: const Center(
                                                child: Icon(
                                                  Icons.image,
                                                  size: 48,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() => _billImage = null);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          )
                          : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: AppTheme.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Upload Photo',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to take a photo or upload document',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
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

              // Register Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registerProduct,
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
                          : const Text('Register Product'),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'water heater':
        return Icons.water_drop;
      case 'stabilizer':
        return Icons.electrical_services;
      case 'inverter':
        return Icons.battery_charging_full;
      case 'fan':
        return Icons.wind_power;
      case 'air cooler':
        return Icons.ac_unit;
      case 'kitchen appliances':
        return Icons.kitchen;
      case 'solar products':
        return Icons.solar_power;
      case 'wiring & cables':
        return Icons.cable;
      case 'switchgear':
        return Icons.toggle_on;
      default:
        return Icons.devices_other;
    }
  }
}

class _ImageSourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}
