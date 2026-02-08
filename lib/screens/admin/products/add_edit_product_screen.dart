import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../../../app/theme.dart';
import '../../../models/catalog_product_model.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';

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
  final _rewardCoinsController = TextEditingController();

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
      _rewardCoinsController.text = '0';
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
    _rewardCoinsController.text = p.rewardCoins.toString();
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
    _rewardCoinsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final img = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 60,
      );
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
        estimatedDeliveryDays:
            int.tryParse(_estimatedDeliveryDaysController.text) ?? 3,
        rewardCoins: int.tryParse(_rewardCoinsController.text) ?? 0,
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

  Future<void> _confirmArchive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Archive Product'),
            content: const Text(
              'Are you sure you want to archive this product? It will no longer be visible to customers.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Archive',
                  style: TextStyle(color: AppTheme.error),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      setState(() => _isActive = false);
      // _saveProduct will handle the update
      await _saveProduct();
    }
  }

  Future<void> _confirmUnarchive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Unarchive Product'),
            content: const Text(
              'Are you sure you want to unarchive this product? It will be visible to customers again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Unarchive',
                  style: TextStyle(color: AppTheme.success),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      setState(() => _isActive = true);
      await _saveProduct();
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    final shouldAdd = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New Category'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g. Smart Fan',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add'),
              ),
            ],
          ),
    );

    if (shouldAdd == true && controller.text.trim().isNotEmpty) {
      final newCategory = controller.text.trim();
      try {
        await context.read<FirestoreService>().addCategory(newCategory);
        setState(() {
          _selectedCategory = newCategory;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Category "$newCategory" added')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error adding category: $e')));
        }
      }
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: StreamBuilder<List<String>>(
                              stream:
                                  context
                                      .read<FirestoreService>()
                                      .getCategories(),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return Text('Error: ${snapshot.error}');
                                }

                                final categories = snapshot.data ?? [];
                                final uniqueCategories =
                                    categories.toSet().toList();

                                // Ensure selected category is in the list (for edits)
                                if (_selectedCategory != null &&
                                    !uniqueCategories.contains(
                                      _selectedCategory,
                                    ) &&
                                    _selectedCategory!.isNotEmpty) {
                                  uniqueCategories.add(_selectedCategory!);
                                }

                                return DropdownButtonFormField<String>(
                                  value: _selectedCategory,
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                  ),
                                  items:
                                      uniqueCategories.map((c) {
                                        return DropdownMenuItem(
                                          value: c,
                                          child: Text(c),
                                        );
                                      }).toList(),
                                  onChanged:
                                      (v) =>
                                          setState(() => _selectedCategory = v),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _showAddCategoryDialog,
                            icon: const Icon(Icons.add_circle_outline),
                            color: AppTheme.primary,
                            tooltip: 'Add New Category',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _rewardCoinsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Reward Coins on Purchase',
                          hintText: 'Coins credited when user buys this product',
                          prefixIcon: Icon(Icons.monetization_on, color: Colors.amber),
                        ),
                      ),

                      const SizedBox(height: 24),
                      _buildSectionHeader('Stock Management'),
                      SwitchListTile(
                        title: const Text('Track Inventory'),
                        subtitle: const Text('Enable to manage stock quantity'),
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
                      _buildSectionHeader('Variations'),
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
                      if (widget.product != null) ...[
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child:
                              _isActive
                                  ? OutlinedButton.icon(
                                    onPressed: _confirmArchive,
                                    icon: const Icon(
                                      Icons.archive,
                                      color: AppTheme.error,
                                    ),
                                    label: const Text(
                                      'Archive Product',
                                      style: TextStyle(color: AppTheme.error),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: AppTheme.error,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                  )
                                  : OutlinedButton.icon(
                                    onPressed: _confirmUnarchive,
                                    icon: const Icon(
                                      Icons.unarchive,
                                      color: AppTheme.success,
                                    ),
                                    label: const Text(
                                      'Unarchive Product',
                                      style: TextStyle(color: AppTheme.success),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: AppTheme.success,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                        ),
                      ],
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
            child: Text(message, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
