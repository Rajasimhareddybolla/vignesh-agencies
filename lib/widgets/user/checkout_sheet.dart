import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app/theme.dart';
import '../../models/catalog_product_model.dart';
import '../../models/order_model.dart'; // For AddressModel and OrderModel
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../common/premium_widgets.dart';

class CheckoutSheet extends StatefulWidget {
  final CatalogProductModel product;
  final ProductVariation? selectedVariation;
  final double price;

  const CheckoutSheet({
    super.key,
    required this.product,
    this.selectedVariation,
    required this.price,
  });

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  // State is hardcoded to 'Tamil Nadu' or simple field for now
  final _stateController = TextEditingController(text: 'Tamil Nadu');

  bool _isLoading = false;
  bool _isLoadingAddresses = true;
  List<Map<String, dynamic>> _savedAddresses = [];
  String? _selectedAddressId;

  @override
  void initState() {
    super.initState();
    _prefillUserData();
  }

  Future<void> _prefillUserData() async {
    final authService = context.read<AuthService>();
    final user = await authService.getUserModel();
    if (user != null && mounted) {
      setState(() {
        _nameController.text = user.displayName;
        _phoneController.text = user.phone ?? '';
      });
    }

    // Fetch saved addresses
    try {
      final userId = await authService.getResolvedUserId();
      final addressesSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('addresses')
              .orderBy('updatedAt', descending: true)
              .get();

      if (mounted) {
        setState(() {
          _savedAddresses =
              addressesSnapshot.docs
                  .map((doc) => {'id': doc.id, ...doc.data()})
                  .toList();

          // Auto-select first address if available
          if (_savedAddresses.isNotEmpty) {
            _selectAddress(_savedAddresses.first);
          }

          _isLoadingAddresses = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAddresses = false);
      }
    }
  }

  void _selectAddress(Map<String, dynamic> address) {
    setState(() {
      _selectedAddressId = address['id'];
      _nameController.text = address['name'] ?? _nameController.text;
      _phoneController.text = address['phone'] ?? _phoneController.text;
      _streetController.text = address['address'] ?? '';
      _cityController.text = address['city'] ?? '';
      _stateController.text = address['state'] ?? 'Tamil Nadu';
      _pincodeController.text = address['pincode'] ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    // Check if address is selected
    if (_selectedAddressId == null || _streetController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestoreService = context.read<FirestoreService>();
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;

      if (userId == null) {
        throw Exception('User not logged in');
      }

      final address = AddressModel(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        street: _streetController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
      );

      // Create Order Item
      final orderItem = OrderItem(
        productId: widget.product.id,
        variationId: widget.selectedVariation?.id,
        productName: widget.product.name,
        productImage:
            widget.product.images.isNotEmpty ? widget.product.images.first : '',
        selectedAttributes: widget.selectedVariation?.attributes ?? {},
        quantity: 1, // Simple quantity for now
        price: widget.price,
        warrantyMonths:
            widget.selectedVariation?.warrantyMonths ??
            widget.product.warrantyMonths,
      );

      final order = OrderModel(
        id: '', // Generated by firestoreService
        userId: userId,
        items: [orderItem],
        totalAmount: widget.price, // + Delivery Fee if any
        address: address,
        orderedAt: DateTime.now(),
        paymentMethod: 'COD',
      );

      final orderId = await firestoreService.placeOrder(order);

      if (mounted) {
        Navigator.pop(context); // Close sheet
        _showSuccessDialog(context, orderId);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error placing order: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(BuildContext context, String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppTheme.success,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Order Placed!',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Order ID: ${orderId.substring(orderId.length - 6).toUpperCase()}',
                ),
                const SizedBox(height: 16),
                Text(
                  'Your order has been placed successfully.\nYou can track it in the Requests tab.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary(context)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  context.pop(); // Close dialog
                  context.go('/home'); // Go home
                },
                child: const Text('Back to Home'),
              ),
              ElevatedButton(
                onPressed: () {
                  context.pop();
                  context.pushNamed(
                    'order-detail',
                    pathParameters: {'orderId': orderId},
                  );
                },
                child: const Text('View Orders'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Checkout',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          Flexible(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Summary
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.background(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          if (widget.product.images.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: widget.product.images.first,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                memCacheWidth: 200,
                              ),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                ),
                                if (widget.selectedVariation != null)
                                  Text(
                                    widget.selectedVariation!.attributes.values
                                        .join(', '),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary(context),
                                    ),
                                  ),
                                Text(
                                  '₹${widget.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Saved Addresses Section
                    if (_isLoadingAddresses)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_savedAddresses.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Delivery Address',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              context.push('/saved-addresses');
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add New'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Vertical list of address cards
                      ...List.generate(_savedAddresses.length, (index) {
                        final address = _savedAddresses[index];
                        final isSelected = _selectedAddressId == address['id'];
                        return GestureDetector(
                          onTap: () => _selectAddress(address),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? AppTheme.primary.withAlpha(20)
                                      : AppTheme.surface(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isSelected
                                        ? AppTheme.primary
                                        : AppTheme.border(context),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Type Icon
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? AppTheme.primary.withAlpha(30)
                                            : AppTheme.background(context),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    address['type'] == 'Home'
                                        ? Icons.home
                                        : address['type'] == 'Work'
                                        ? Icons.work
                                        : Icons.location_on,
                                    size: 20,
                                    color:
                                        isSelected
                                            ? AppTheme.primary
                                            : AppTheme.textSecondary(context),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Address Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            address['type'] ?? 'Address',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  isSelected
                                                      ? AppTheme.primary
                                                      : null,
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primary,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'Selected',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${address['address']}, ${address['city']}, ${address['state']} - ${address['pincode']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary(
                                            context,
                                          ),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                // Radio
                                Radio<String>(
                                  value: address['id'],
                                  groupValue: _selectedAddressId,
                                  onChanged: (value) => _selectAddress(address),
                                  activeColor: AppTheme.primary,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ] else ...[
                      // No saved addresses
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.background(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border(context)),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.location_off,
                              size: 40,
                              color: AppTheme.textSecondary(context),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No saved addresses',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                context.push('/saved-addresses');
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Address'),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    // Payment Method
                    Text(
                      'Payment Method',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primary),
                        borderRadius: BorderRadius.circular(12),
                        color: AppTheme.primary.withAlpha(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.money, color: AppTheme.primary),
                          SizedBox(width: 12),
                          Text(
                            'Cash on Delivery',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                          Spacer(),
                          Icon(Icons.check_circle, color: AppTheme.primary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          ElevatedButton(
            onPressed: _isLoading ? null : _placeOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Confirm Order'),
                        const SizedBox(width: 8),
                        Text(
                          '• ₹${widget.price.toStringAsFixed(0)}',
                          style: TextStyle(color: Colors.white.withAlpha(200)),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}
