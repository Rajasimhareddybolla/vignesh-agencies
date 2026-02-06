import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../models/order_model.dart'; // For AddressModel
import '../../services/cart_service.dart';
import '../../services/auth_service.dart';
import '../../services/order_service.dart';
import '../../services/shipping_service.dart';
import '../../widgets/common/profile_completion_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingProfile = true;
  List<Map<String, dynamic>> _savedAddresses = [];
  String? _selectedAddressId;

  // Shipping
  ShippingInfo? _shippingInfo;
  bool _isCalculatingShipping = false;

  @override
  void initState() {
    super.initState();
    _prefillUserData();
  }

  Future<void> _prefillUserData() async {
    final authService = context.read<AuthService>();

    try {
      // Get user model for profile data
      final userModel = await authService.getUserModel();
      final userId = await authService.getResolvedUserId();

      if (userModel != null && mounted) {
        _nameController.text = userModel.displayName;
        _phoneController.text = userModel.phone ?? '';
      }

      // Fetch saved addresses
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

          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
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
      _stateController.text = address['state'] ?? '';
      _pincodeController.text = address['pincode'] ?? '';
    });
    // Recalculate shipping for the selected address pincode
    _calculateShipping(address['pincode'] ?? '');
  }

  Future<void> _calculateShipping(String pincode) async {
    if (pincode.length != 6) {
      setState(() => _shippingInfo = null);
      return;
    }
    setState(() => _isCalculatingShipping = true);
    try {
      final cart = context.read<CartService>();
      final info = await ShippingService().calculateShipping(
        pincode: pincode,
        cartTotal: cart.totalAmount,
        itemCount: cart.itemCount,
      );
      if (mounted) {
        setState(() {
          _shippingInfo = info;
          _isCalculatingShipping = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCalculatingShipping = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  /// Validates cart items for stock availability before checkout
  /// Returns true if cart is valid, false otherwise
  Future<bool> _validateCartStock() async {
    final cart = context.read<CartService>();
    final orderService = context.read<OrderService>();

    setState(() => _isLoading = true);

    try {
      final validationResult = await orderService.validateCart(cart.items);

      if (!mounted) return false;

      final isValid = validationResult['isValid'] as bool? ?? false;
      if (!isValid) {
        final dynamic rawIssues = validationResult['issues'];
        final List<Map<String, dynamic>> issues = [];
        if (rawIssues != null && rawIssues is List) {
          for (final item in rawIssues) {
            if (item is Map) {
              issues.add(Map<String, dynamic>.from(item));
            }
          }
        }

        await _showValidationIssuesDialog(issues, cart);
        return false;
      }

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to validate cart: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shows dialog with cart validation issues
  Future<void> _showValidationIssuesDialog(
    List<Map<String, dynamic>> issues,
    CartService cart,
  ) async {
    final hasStockIssues = issues.any(
      (i) => i['type'] == 'out_of_stock' || i['type'] == 'insufficient_stock',
    );
    final hasPriceChanges = issues.any((i) => i['type'] == 'price_changed');
    final hasUnavailable = issues.any((i) => i['type'] == 'not_available');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  hasUnavailable || hasStockIssues
                      ? Icons.error_outline
                      : Icons.info_outline,
                  color:
                      hasUnavailable || hasStockIssues
                          ? AppTheme.error
                          : AppTheme.warning,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Cart Update Required',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Some items in your cart need attention:',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: issues.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, index) {
                        final issue = issues[index];
                        return _buildIssueItem(issue);
                      },
                    ),
                  ),
                  if (hasPriceChanges &&
                      !hasStockIssues &&
                      !hasUnavailable) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info, size: 16, color: AppTheme.warning),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Price changes will be updated in your cart automatically.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (hasStockIssues || hasUnavailable) ...[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Update Cart'),
                ),
              ] else ...[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Review Cart'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    // Continue with updated prices
                    _showOrderConfirmation(skipValidation: true);
                  },
                  child: const Text('Continue Anyway'),
                ),
              ],
            ],
          ),
    );
  }

  Widget _buildIssueItem(Map<String, dynamic> issue) {
    final type = issue['type'] as String;
    final productName = issue['productName'] as String? ?? 'Unknown Product';

    IconData icon;
    Color color;
    String message;

    switch (type) {
      case 'not_available':
        icon = Icons.block;
        color = AppTheme.error;
        message = 'This product is no longer available';
        break;
      case 'out_of_stock':
        icon = Icons.inventory_2_outlined;
        color = AppTheme.error;
        message = 'Out of stock - please remove from cart';
        break;
      case 'insufficient_stock':
        final available = issue['availableStock'] as int? ?? 0;
        final requested = issue['requestedQuantity'] as int? ?? 0;
        icon = Icons.warning_amber;
        color = AppTheme.warning;
        message = 'Only $available available (you have $requested in cart)';
        break;
      case 'price_changed':
        final oldPrice = issue['oldPrice'] as num? ?? 0;
        final newPrice = issue['newPrice'] as num? ?? 0;
        icon = Icons.price_change;
        color = newPrice > oldPrice ? AppTheme.error : AppTheme.success;
        message =
            'Price ${newPrice > oldPrice ? 'increased' : 'decreased'}: '
            '₹${oldPrice.toStringAsFixed(0)} → ₹${newPrice.toStringAsFixed(0)}';
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
        message = 'Issue with this product';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productName,
                style: const TextStyle(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(message, style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ),
      ],
    );
  }

  void _showOrderConfirmation({bool skipValidation = false}) async {
    if (!_formKey.currentState!.validate()) return;

    // Validate cart stock before proceeding (unless skipped for price-only changes)
    if (!skipValidation) {
      final isCartValid = await _validateCartStock();
      if (!isCartValid || !mounted) return;
    }

    // Check profile completion before proceeding
    final authService = context.read<AuthService>();
    final isComplete = await ProfileCompletionService.checkAndPromptCompletion(
      context,
      authService,
      action: 'place your order',
    );

    if (!isComplete || !mounted) return;

    final cart = context.read<CartService>();

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Confirm Order'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are about to place an order for ${cart.itemCount} item(s).',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Amount:'),
                          Text(
                            '₹${(cart.totalAmount + (_shippingInfo?.fee ?? 0)).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      if ((_shippingInfo?.fee ?? 0) > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '(incl. ₹${_shippingInfo!.fee.toStringAsFixed(0)} shipping)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Delivering to:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_nameController.text}\n${_streetController.text}, ${_cityController.text}\n${_stateController.text} - ${_pincodeController.text}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Payment: Cash on Delivery',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _placeOrder();
                },
                child: const Text('Confirm & Place Order'),
              ),
            ],
          ),
    );
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final cartService = context.read<CartService>();
      final orderService = context.read<OrderService>();
      final authService = context.read<AuthService>();

      // Use resolved user ID to handle linked accounts in bypass mode
      final userId = await authService.getResolvedUserId();

      // getResolvedUserId() throws if not authenticated, but we check anyway
      // ignore: unnecessary_null_comparison
      if (userId == null) throw Exception('User not logged in');

      final address = AddressModel(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        street: _streetController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
      );

      final orderId = await orderService.placeOrder(
        userId: userId,
        cartItems: cartService.items,
        totalAmount: cartService.totalAmount + (_shippingInfo?.fee ?? 0),
        address: address,
        shippingFee: _shippingInfo?.fee ?? 0,
      );

      if (mounted) {
        cartService.clearCart();

        // Calculate estimated delivery
        final estimatedDelivery = DateTime.now().add(const Duration(days: 5));
        final estimatedText = DateFormat(
          'EEEE, MMMM d',
        ).format(estimatedDelivery);

        // Capture parent context for navigation inside dialog
        final parentContext = context;

        // Show success and navigate to orders
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (dialogContext) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success Animation Container
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: AppTheme.success,
                        size: 60,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Order Placed Successfully!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Thank you for your order',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Order Details Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.background(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _OrderConfirmRow(
                            icon: Icons.receipt_outlined,
                            label: 'Order ID',
                            value:
                                '#${orderId.substring(orderId.length - 6).toUpperCase()}',
                          ),
                          const SizedBox(height: 12),
                          _OrderConfirmRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Expected Delivery',
                            value: estimatedText,
                          ),
                          const SizedBox(height: 12),
                          _OrderConfirmRow(
                            icon: Icons.payment_outlined,
                            label: 'Payment Method',
                            value: 'Cash on Delivery',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Next Steps Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.info.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.info.withAlpha(50)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppTheme.info,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You will receive updates about your order status via email/notification.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext); // Close dialog
                            parentContext.go('/shop'); // Go to home/shop
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Continue Shopping'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(dialogContext); // Close dialog
                            parentContext.pushNamed(
                              'order-detail',
                              pathParameters: {'orderId': orderId},
                            ); // Navigate to specific order
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('View Order'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to place order';

        final errorString = e.toString().toLowerCase();
        if (errorString.contains('out of stock') ||
            errorString.contains('insufficient stock')) {
          errorMessage =
              'Some items are out of stock. Please update your cart.';
          // Re-validate cart to show specific issues
          _validateCartStock();
        } else if (errorString.contains('price') ||
            errorString.contains('changed')) {
          errorMessage =
              'Product prices have changed. Please review your cart.';
        } else {
          errorMessage = 'Failed to place order: $e';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.error,
            action: SnackBarAction(
              label: 'View Cart',
              textColor: Colors.white,
              onPressed: () => context.go('/cart'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Checkout'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Saved Addresses Section
              if (_savedAddresses.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitle('Saved Addresses'),
                    TextButton(
                      onPressed: () => context.push('/saved-addresses'),
                      child: const Text('Manage'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _savedAddresses.length,
                    itemBuilder: (context, index) {
                      final address = _savedAddresses[index];
                      final isSelected = _selectedAddressId == address['id'];
                      return GestureDetector(
                        onTap: () => _selectAddress(address),
                        child: Container(
                          width: 200,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? AppTheme.primary.withOpacity(0.1)
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    address['type'] == 'Home'
                                        ? Icons.home
                                        : address['type'] == 'Work'
                                        ? Icons.work
                                        : Icons.location_on,
                                    size: 16,
                                    color:
                                        isSelected
                                            ? AppTheme.primary
                                            : AppTheme.textSecondary(context),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      address['type'] ?? 'Address',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isSelected
                                                ? AppTheme.primary
                                                : null,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: AppTheme.primary,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Text(
                                  '${address['address']}, ${address['city']}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              _buildSectionTitle('Shipping Address'),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(
                  labelText: 'Street Address / Area',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(labelText: 'City'),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _pincodeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Pincode'),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _stateController,
                decoration: const InputDecoration(labelText: 'State'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),

              const SizedBox(height: 32),
              _buildSectionTitle('Payment Method'),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primary),
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.primary.withOpacity(0.05),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.money, color: AppTheme.primary),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cash on Delivery',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Pay when you receive the product',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Radio(
                      value: true,
                      groupValue: true,
                      onChanged: (_) {},
                      activeColor: AppTheme.primary,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              _buildOrderSummary(),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _showOrderConfirmation,
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Place Order'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildOrderSummary() {
    final cart = context.watch<CartService>();
    final shippingFee = _shippingInfo?.fee ?? 0;
    final grandTotal = cart.totalAmount + shippingFee;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Subtotal (${cart.itemCount} items)',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              Text('₹${cart.totalAmount.toStringAsFixed(0)}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Delivery Fee'),
              _isCalculatingShipping
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _shippingInfo == null
                      ? Text(
                          'Enter pincode',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary(context),
                          ),
                        )
                      : _shippingInfo!.isFreeShipping
                          ? const Text(
                              'FREE',
                              style: TextStyle(
                                color: AppTheme.success,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : Text(
                              '₹${_shippingInfo!.fee.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
            ],
          ),
          // Free shipping hint
          if (_shippingInfo != null &&
              !_shippingInfo!.isFreeShipping &&
              _shippingInfo!.reason != null) ...[
            const SizedBox(height: 4),
            Text(
              _shippingInfo!.reason!,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.success,
              ),
            ),
          ],
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                '₹${grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Delivery Estimate
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.infoLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  color: AppTheme.info,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated Delivery',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppTheme.infoDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _shippingInfo != null
                            ? '${_shippingInfo!.estimatedDays} business days'
                            : '3-7 business days',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.infoDark,
                        ),
                      ),
                    ],
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

// Helper widget for order confirmation dialog
class _OrderConfirmRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _OrderConfirmRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary(context),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}
