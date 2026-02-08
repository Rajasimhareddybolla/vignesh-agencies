import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../app/theme.dart';
import '../../models/user_appliance_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/profile_completion_service.dart';
import '../../models/order_model.dart';
import '../../models/catalog_product_model.dart';

class AddProductScreen extends StatefulWidget {
  final OrderModel? sourceOrder;
  final OrderItem? sourceOrderItem;

  const AddProductScreen({super.key, this.sourceOrder, this.sourceOrderItem});

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
  XFile? _warrantyCardImage;
  int? _selectedWarrantyMonths;
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedProductImageUrl; // To store image from catalog

  final _imagePicker = ImagePicker();

  bool _isInternalOrder = false;

  @override
  void initState() {
    super.initState();
    if (widget.sourceOrder != null && widget.sourceOrderItem != null) {
      _isInternalOrder = true;
      _selectedCategory = widget.sourceOrderItem!.category;
      _productNameController.text = widget.sourceOrderItem!.productName;
      _purchaseDate = widget.sourceOrder!.orderedAt;
      _selectedProductImageUrl = widget.sourceOrderItem!.productImage;

      // If we have variation info or sku, we might use it for model number
      if (widget.sourceOrderItem!.sku != null) {
        _modelController.text = widget.sourceOrderItem!.sku!;
      }
    }
  }

  @override
  void dispose() {
    _modelController.dispose();
    _serialController.dispose();
    _productNameController.dispose();
    super.dispose();
  }

  void _showImageSourcePicker() {
    _showImageSourcePickerFor(forWarrantyCard: false);
  }

  void _showWarrantyCardSourcePicker() {
    _showImageSourcePickerFor(forWarrantyCard: true);
  }

  void _showImageSourcePickerFor({required bool forWarrantyCard}) {
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
                  forWarrantyCard
                      ? 'Upload Warranty Card'
                      : 'Upload Bill / Warranty Card',
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
                        _pickImageFor(
                          ImageSource.camera,
                          forWarrantyCard: forWarrantyCard,
                        );
                      },
                    ),
                    _ImageSourceOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImageFor(
                          ImageSource.gallery,
                          forWarrantyCard: forWarrantyCard,
                        );
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

  Future<void> _pickImageFor(
    ImageSource source, {
    required bool forWarrantyCard,
  }) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 40,
      );
      if (image != null) {
        setState(() {
          if (forWarrantyCard) {
            _warrantyCardImage = image;
          } else {
            _billImage = image;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
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
      // Should effectively be caught by the fact that Search is main way now
      setState(
        () => _errorMessage = 'Please search and select a product above',
      );
      return;
    }

    if (_purchaseDate == null) {
      setState(() => _errorMessage = 'Please select purchase date');
      return;
    }

    // Bill image is always required
    if (_billImage == null) {
      setState(() => _errorMessage = 'Please upload a photo of your bill');
      return;
    }

    // Check profile completion before proceeding
    final authService = context.read<AuthService>();
    final isComplete = await ProfileCompletionService.checkAndPromptCompletion(
      context,
      authService,
      action: 'register your appliance',
    );

    if (!isComplete || !mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestoreService = context.read<FirestoreService>();
      final storageService = context.read<StorageService>();

      // Use resolved ID to ensure we add products to the linked account if in bypass mode
      final userId = await authService.getResolvedUserId();
      String? billImageUrl;

      // Upload bill image if selected (manual upload)
      if (_billImage != null) {
        billImageUrl = await storageService.uploadBillImage(
          userId: userId,
          imageFile: _billImage!,
        );
      }

      // Upload warranty card image if selected
      String? warrantyCardUrl;
      if (_warrantyCardImage != null) {
        warrantyCardUrl = await storageService.uploadWarrantyCard(
          userId: userId,
          imageFile: _warrantyCardImage!,
        );
      }

      // Calculate warranty end date
      // Priority: 1. Order item warranty, 2. Selected catalog product warranty, 3. Default 12 months
      int warrantyMonths = 12;
      if (widget.sourceOrderItem != null) {
        warrantyMonths = widget.sourceOrderItem!.warrantyMonths;
      } else if (_selectedWarrantyMonths != null &&
          _selectedWarrantyMonths! > 0) {
        warrantyMonths = _selectedWarrantyMonths!;
      }
      // Ensure we never use 0 or negative warranty
      if (warrantyMonths <= 0) warrantyMonths = 12;

      final warrantyEndDate = DateTime(
        _purchaseDate!.year,
        _purchaseDate!.month + (warrantyMonths > 0 ? warrantyMonths : 12),
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
        warrantyCardUrl: warrantyCardUrl,
        // If it comes from an internal order, we can auto-validate or mark differently.
        // For now, keep as pending but with linked order ID.
        status:
            _isInternalOrder
                ? ProductStatus.active
                : ProductStatus.pendingValidation,
        validatedAt: _isInternalOrder ? DateTime.now() : null,
        validatedBy: _isInternalOrder ? 'System (Order Linked)' : null,
        createdAt: DateTime.now(),
        // Link to internal order
        linkedOrderId: widget.sourceOrder?.id,
        purchaseAmount: widget.sourceOrderItem?.price,
        storeLocation: 'Vignesh Agencies App Store',
        productImageUrl: _selectedProductImageUrl,
      );

      await firestoreService.addProduct(product);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product registered successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to register product: $e';
      });
    }
  }

  void _scanBarcode() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _BarcodeScannerModal(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  setState(() {
                    _modelController.text = code;
                  });
                  Navigator.pop(context); // Close modal
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Scanned: $code'),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
    );
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
              // 1. GLOBAL SEARCH (Top Priority)
              Text(
                'Search Product (Recommended)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<CatalogProductModel>>(
                stream: context.read<FirestoreService>().getCatalogProducts(
                  // No category filter - Global Search
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final products = snapshot.data!;

                  return Autocomplete<CatalogProductModel>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<CatalogProductModel>.empty();
                      }
                      return products.where((CatalogProductModel option) {
                        return option.name.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            ) ||
                            option.brand.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            );
                      });
                    },
                    displayStringForOption: (option) => option.name,
                    onSelected: (CatalogProductModel selection) {
                      setState(() {
                        _selectedCategory =
                            selection.categoryId; // Auto-fill Category
                        _productNameController.text =
                            selection.name; // Auto-fill Name

                        // Auto-fill Model from first variation if available
                        if (selection.variations.isNotEmpty) {
                          _modelController.text =
                              selection.variations.first.sku ?? '';
                        }

                        _selectedProductImageUrl =
                            selection.images.isNotEmpty
                                ? selection.images.first
                                : null; // Auto-fill Image

                        // Capture warranty months from catalog product
                        // Check variation-specific warranty first, then base product warranty
                        if (selection.variations.isNotEmpty &&
                            selection.variations.first.warrantyMonths != null &&
                            selection.variations.first.warrantyMonths! > 0) {
                          _selectedWarrantyMonths =
                              selection.variations.first.warrantyMonths;
                        } else {
                          _selectedWarrantyMonths = selection.warrantyMonths;
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Product details auto-filled!'),
                          backgroundColor: AppTheme.success,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    fieldViewBuilder: (
                      context,
                      controller,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'Search by name or model...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon:
                              controller.text.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => controller.clear(),
                                  )
                                  : null,
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 200,
                            width: MediaQuery.of(context).size.width - 40,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8.0),
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  leading:
                                      option.images.isNotEmpty
                                          ? Image.network(
                                            option.images.first,
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (_, __, ___) =>
                                                    const Icon(Icons.image),
                                          )
                                          : const Icon(Icons.image),
                                  title: Text(option.name),
                                  subtitle: Text(option.categoryId),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 32),

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
                    onPressed: _scanBarcode,
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
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withAlpha(50),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: AppTheme.textSecondary(context),
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
                                    ? AppTheme.textPrimary(context)
                                    : AppTheme.textSecondary(context),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.calendar_month,
                        color: AppTheme.textSecondary(context),
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
              if (_isInternalOrder) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.success),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: AppTheme.success),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Linked to Order #${widget.sourceOrder?.id.substring(0, 8) ?? ""}',
                              style: Theme.of(
                                context,
                              ).textTheme.titleSmall?.copyWith(
                                color: AppTheme.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Please upload a photo of your bill for verification.',
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
                ),
                const SizedBox(height: 16),
              ],
              // Bill upload is ALWAYS required
              GestureDetector(
                onTap: _showImageSourcePicker,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color:
                          _billImage == null
                              ? AppTheme.warning.withAlpha(
                                150,
                              ) // Highlight required
                              : Colors.transparent,
                      width: _billImage == null ? 2 : 1,
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
                                              color: AppTheme.background(
                                                context,
                                              ),
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
                                              color: AppTheme.background(
                                                context,
                                              ),
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
                                  color: AppTheme.warning.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: AppTheme.warning,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Upload Bill Photo (Required)',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to take a photo or upload document',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                ),
              ),

              // Warranty Card Upload (Optional, for manual registration)
              if (!_isInternalOrder) ...[
                const SizedBox(height: 24),
                Text(
                  'Warranty Card (Optional)',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _showWarrantyCardSourcePicker,
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withAlpha(50),
                        style:
                            _warrantyCardImage == null
                                ? BorderStyle.solid
                                : BorderStyle.none,
                      ),
                    ),
                    child:
                        _warrantyCardImage != null
                            ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd,
                                  ),
                                  child:
                                      kIsWeb
                                          ? Image.network(
                                            _warrantyCardImage!.path,
                                            width: double.infinity,
                                            height: 140,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (_, __, ___) => Container(
                                                  color: AppTheme.background(
                                                    context,
                                                  ),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.image,
                                                      size: 48,
                                                    ),
                                                  ),
                                                ),
                                          )
                                          : Image.file(
                                            File(_warrantyCardImage!.path),
                                            width: double.infinity,
                                            height: 140,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (_, __, ___) => Container(
                                                  color: AppTheme.background(
                                                    context,
                                                  ),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.image,
                                                      size: 48,
                                                    ),
                                                  ),
                                                ),
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
                                        setState(
                                          () => _warrantyCardImage = null,
                                        );
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
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.verified_user_outlined,
                                    color: AppTheme.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Upload Warranty Card',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap to upload warranty card image',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                  ),
                ),
              ],

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
} // End of _AddProductScreenState

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

class _BarcodeScannerModal extends StatefulWidget {
  final Function(BarcodeCapture) onDetect;

  const _BarcodeScannerModal({required this.onDetect});

  @override
  State<_BarcodeScannerModal> createState() => _BarcodeScannerModalState();
}

class _BarcodeScannerModalState extends State<_BarcodeScannerModal> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle & Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Scan Barcode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scanner
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: widget.onDetect,
                ),
                // Overlay
                Center(
                  child: Container(
                    width: 280,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.primary, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                // Flash Toggle
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ValueListenableBuilder(
                      valueListenable: controller,
                      builder: (context, state, child) {
                        final isExternalFlashOn =
                            state.torchState == TorchState.on;
                        return IconButton(
                          onPressed: () => controller.toggleTorch(),
                          icon: Icon(
                            isExternalFlashOn
                                ? Icons.flash_on
                                : Icons.flash_off,
                            color: Colors.white,
                            size: 32,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black45,
                            padding: const EdgeInsets.all(12),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
