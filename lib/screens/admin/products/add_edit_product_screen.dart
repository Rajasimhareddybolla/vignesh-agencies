import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../../../app/theme.dart';
import '../../../models/catalog_product_model.dart';
import '../../../models/user_appliance_model.dart'; // For Categories
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';
import '../../../widgets/common/premium_widgets.dart';

class AddEditProductScreen extends StatefulWidget {
  final CatalogProductModel? product; // Null for Add, Non-null for Edit

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _basePriceController = TextEditingController();
  final _offerPriceController = TextEditingController();
  final _warrantyController = TextEditingController();
  final _stockQuantityController = TextEditingController();
  final _lowStockThresholdController = TextEditingController();
  final _estimatedDeliveryDaysController = TextEditingController();

  // State
  String? _selectedCategory;
  List<String> _images = []; // URLs
  List<XFile> _newImages = []; // Local files
  bool _isActive = true;
  bool _trackInventory = true;
  List<ProductVariation> _variations = [];
  Map<String, String> _specifications = {};
  List<String> _highlights = [];
  bool _isLoading = false;

  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _initEditMode();
    } else {
      _brandController.text = 'V-Guard'; // Default
      _stockQuantityController.text = '0';
      _lowStockThresholdController.text = '5';
      _estimatedDeliveryDaysController.text = '3';
    }
  }

  void _initEditMode() {
    final p = widget.product!;
    _nameController.text = p.name;
    _descriptionController.text = p.description;
    _brandController.text = p.brand;
    _basePriceController.text = p.basePrice.toString();
    _offerPriceController.text = p.offerPrice?.toString() ?? '';
    _warrantyController.text = p.warrantyMonths.toString();
    _stockQuantityController.text = p.stockQuantity.toString();
    _lowStockThresholdController.text = p.lowStockThreshold.toString();
    _estimatedDeliveryDaysController.text = p.estimatedDeliveryDays.toString();
    _selectedCategory = p.categoryId;
    _images = List.from(p.images);
    _isActive = p.isActive;
    _trackInventory = p.trackInventory;
    _variations = List.from(p.variations);
    _specifications = Map.from(p.specifications);
    _highlights = List.from(p.highlights);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _basePriceController.dispose();
    _offerPriceController.dispose();
    _warrantyController.dispose();
    _stockQuantityController.dispose();
    _lowStockThresholdController.dispose();
    _estimatedDeliveryDaysController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final img = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (img != null) {
        setState(() => _newImages.add(img));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }
    if (_images.isEmpty && _newImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestoreService = context.read<FirestoreService>();
      final storageService =
          context
              .read<StorageService>(); // Assume this exists for general uploads

      // Upload new images
      // NOTE: We need a generic upload method in StorageService.
      // Assuming 'uploadProductImage' exists or we can use a generic one.
      // For now, I'll assume we can upload.

      List<String> finalImageUrls = List.from(_images);

      for (var file in _newImages) {
        final url = await storageService.uploadProductImage(imageFile: file);
        if (url != null) {
          finalImageUrls.add(url);
        }
      }

      final product = CatalogProductModel(
        id: widget.product?.id ?? '', // Empty for new, populated for edit
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        categoryId: _selectedCategory!,
        images: finalImageUrls,
        brand: _brandController.text.trim(),
        isActive: _isActive,
        basePrice: double.parse(_basePriceController.text),
        offerPrice: double.tryParse(_offerPriceController.text),
        warrantyMonths: int.tryParse(_warrantyController.text) ?? 12,
        stockQuantity: int.tryParse(_stockQuantityController.text) ?? 0,
        lowStockThreshold: int.tryParse(_lowStockThresholdController.text) ?? 5,
        trackInventory: _trackInventory,
        estimatedDeliveryDays: int.tryParse(_estimatedDeliveryDaysController.text) ?? 3,
        variations: _variations,
        specifications: _specifications,
        highlights: _highlights,
        createdAt: widget.product?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.product == null) {
        await firestoreService.addCatalogProduct(product);
      } else {
        await firestoreService.updateCatalogProduct(product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product saved successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving product: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // UI Builders...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add Product' : 'Edit Product'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _saveProduct),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Basic Details'),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Product Name',
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items:
                            UserApplianceModel.categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),

                      const SizedBox(height: 24),
                      _buildSectionHeader('Pricing & Warranty'),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _basePriceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Base Price (₹)',
                              ),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _offerPriceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Offer Price (Optional)',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _warrantyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Warranty (Months)',
                        ),
                      ),

                      const SizedBox(height: 24),
                      _buildSectionHeader('Stock Management'),
                      SwitchListTile(
                        title: const Text('Track Inventory'),
                        subtitle: const Text(
                          'Enable to manage stock quantity',
                        ),
                        value: _trackInventory,
                        onChanged: (v) => setState(() => _trackInventory = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_trackInventory) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _stockQuantityController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Stock Quantity',
                                  suffixIcon: _buildStockStatusIcon(),
                                ),
                                validator: (v) {
                                  if (!_trackInventory) return null;
                                  if (v == null || v.isEmpty) return 'Required';
                                  final qty = int.tryParse(v);
                                  if (qty == null || qty < 0) return 'Invalid';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lowStockThresholdController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Low Stock Alert',
                                  hintText: 'e.g., 5',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _estimatedDeliveryDaysController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Estimated Delivery Days',
                            hintText: 'e.g., 3',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildStockStatusBanner(),
                      ],

                      const SizedBox(height: 24),
                      _buildSectionHeader('Images'),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.add_a_photo,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                            ..._images.map(
                              (url) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  memCacheWidth: 200,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  placeholder:
                                      (context, url) => Container(
                                        color:
                                            Theme.of(
                                              context,
                                            ).scaffoldBackgroundColor,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                  errorWidget:
                                      (context, url, error) =>
                                          const Icon(Icons.error),
                                ),
                              ),
                            ),
                            ..._newImages.map(
                              (file) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Image.file(
                                  File(file.path),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      _buildSectionHeader('Specifications (Key-Value)'),
                      // Simplified Specs Editor
                      ..._specifications.entries.map(
                        (e) => ListTile(
                          title: Text(e.key),
                          subtitle: Text(e.value),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, size: 16),
                            onPressed:
                                () => setState(
                                  () => _specifications.remove(e.key),
                                ),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showAddSpecDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Specification'),
                      ),

                      const SizedBox(height: 24),
                      _buildSectionHeader('Variations'),
                      // Placeholder for variations logic
                      ..._variations.map(
                        (v) => ListTile(
                          title: Text(v.attributes.toString()),
                          subtitle: Text('₹${v.price}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, size: 16),
                            onPressed:
                                () => setState(() => _variations.remove(v)),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showAddVariationDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Variation'),
                      ),

                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showAddSpecDialog() {
    String key = '';
    String value = '';
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Specification'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Name (e.g. Power)',
                  ),
                  onChanged: (v) => key = v,
                ),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Value (e.g. 500W)',
                  ),
                  onChanged: (v) => value = v,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (key.isNotEmpty && value.isNotEmpty) {
                    setState(() => _specifications[key] = value);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  void _showAddVariationDialog() {
    // Simplified variation adder for now
    String attrKey = 'Color'; // Default
    String attrValue = '';
    String price = _basePriceController.text;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Variation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Attribute (e.g. Color)',
                  ),
                  onChanged: (v) => attrKey = v,
                ),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Value (e.g. Red)',
                  ),
                  onChanged: (v) => attrValue = v,
                ),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Price override',
                  ),
                  onChanged: (v) => price = v,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (attrKey.isNotEmpty && attrValue.isNotEmpty) {
                    setState(() {
                      _variations.add(
                        ProductVariation(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          attributes: {attrKey: attrValue},
                          price: double.tryParse(price) ?? 0,
                        ),
                      );
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  Widget? _buildStockStatusIcon() {
    final qty = int.tryParse(_stockQuantityController.text) ?? 0;
    final threshold = int.tryParse(_lowStockThresholdController.text) ?? 5;
    
    if (qty <= 0) {
      return const Icon(Icons.error, color: AppTheme.error);
    } else if (qty <= threshold) {
      return const Icon(Icons.warning_amber, color: AppTheme.warning);
    } else {
      return const Icon(Icons.check_circle, color: AppTheme.success);
    }
  }

  Widget _buildStockStatusBanner() {
    final qty = int.tryParse(_stockQuantityController.text) ?? 0;
    final threshold = int.tryParse(_lowStockThresholdController.text) ?? 5;
    
    IconData icon;
    Color color;
    String message;
    
    if (qty <= 0) {
      icon = Icons.error_outline;
      color = AppTheme.error;
      message = 'Product is out of stock and cannot be purchased';
    } else if (qty <= threshold) {
      icon = Icons.warning_amber;
      color = AppTheme.warning;
      message = 'Low stock - only $qty units remaining';
    } else {
      icon = Icons.inventory_2;
      color = AppTheme.success;
      message = '$qty units in stock';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
