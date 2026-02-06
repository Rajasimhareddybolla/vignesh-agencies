import 'package:cloud_firestore/cloud_firestore.dart';

/// Shipping fee calculator using pincode-based slab model.
///
/// Default logic (can be overridden via Firestore `settings/shipping_config`):
/// - Orders above freeShippingThreshold → FREE
/// - Same city (first 3 digits match shop pincode) → localFee
/// - Same state (first 2 digits match) → stateFee
/// - Other → nationalFee
class ShippingService {
  static final ShippingService _instance = ShippingService._();
  factory ShippingService() => _instance;
  ShippingService._();

  // Default config (used as fallback)
  static const _defaultConfig = ShippingConfig(
    shopPincode: '600001', // Shop base pincode (Chennai)
    freeShippingThreshold: 2000.0,
    localFee: 49.0, // Same city
    stateFee: 99.0, // Same state
    nationalFee: 149.0, // Other states
    localEstimatedDays: '2-3',
    stateEstimatedDays: '3-5',
    nationalEstimatedDays: '5-7',
  );

  ShippingConfig? _cachedConfig;
  DateTime? _lastFetch;

  /// Fetches shipping config from Firestore (with 5-minute cache)
  Future<ShippingConfig> getConfig() async {
    // Return cached if fresh
    if (_cachedConfig != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inMinutes < 5) {
      return _cachedConfig!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('shipping_config')
          .get();

      if (doc.exists && doc.data() != null) {
        _cachedConfig = ShippingConfig.fromMap(doc.data()!);
      } else {
        _cachedConfig = _defaultConfig;
      }
    } catch (e) {
      _cachedConfig = _defaultConfig;
    }

    _lastFetch = DateTime.now();
    return _cachedConfig!;
  }

  /// Calculate shipping info for a given pincode and cart total.
  /// Returns a [ShippingInfo] with fee, estimated days, and free threshold.
  Future<ShippingInfo> calculateShipping({
    required String pincode,
    required double cartTotal,
    int itemCount = 1,
  }) async {
    final config = await getConfig();

    // Free shipping above threshold
    if (cartTotal >= config.freeShippingThreshold) {
      return ShippingInfo(
        fee: 0.0,
        estimatedDays: _getEstimatedDays(pincode, config),
        freeShippingThreshold: config.freeShippingThreshold,
        isFreeShipping: true,
        reason: 'Free delivery on orders above ₹${config.freeShippingThreshold.toStringAsFixed(0)}',
      );
    }

    // Pincode must be 6 digits
    if (pincode.length != 6) {
      return ShippingInfo(
        fee: config.nationalFee,
        estimatedDays: config.nationalEstimatedDays,
        freeShippingThreshold: config.freeShippingThreshold,
        isFreeShipping: false,
      );
    }

    final shopPin = config.shopPincode;

    // Same city — first 3 digits match
    if (pincode.substring(0, 3) == shopPin.substring(0, 3)) {
      return ShippingInfo(
        fee: config.localFee,
        estimatedDays: config.localEstimatedDays,
        freeShippingThreshold: config.freeShippingThreshold,
        isFreeShipping: false,
        reason: 'Add ₹${(config.freeShippingThreshold - cartTotal).toStringAsFixed(0)} more for free delivery',
      );
    }

    // Same state — first 2 digits match
    if (pincode.substring(0, 2) == shopPin.substring(0, 2)) {
      return ShippingInfo(
        fee: config.stateFee,
        estimatedDays: config.stateEstimatedDays,
        freeShippingThreshold: config.freeShippingThreshold,
        isFreeShipping: false,
        reason: 'Add ₹${(config.freeShippingThreshold - cartTotal).toStringAsFixed(0)} more for free delivery',
      );
    }

    // National
    return ShippingInfo(
      fee: config.nationalFee,
      estimatedDays: config.nationalEstimatedDays,
      freeShippingThreshold: config.freeShippingThreshold,
      isFreeShipping: false,
      reason: 'Add ₹${(config.freeShippingThreshold - cartTotal).toStringAsFixed(0)} more for free delivery',
    );
  }

  String _getEstimatedDays(String pincode, ShippingConfig config) {
    if (pincode.length != 6) return config.nationalEstimatedDays;
    final shopPin = config.shopPincode;
    if (pincode.substring(0, 3) == shopPin.substring(0, 3)) {
      return config.localEstimatedDays;
    }
    if (pincode.substring(0, 2) == shopPin.substring(0, 2)) {
      return config.stateEstimatedDays;
    }
    return config.nationalEstimatedDays;
  }
}

class ShippingConfig {
  final String shopPincode;
  final double freeShippingThreshold;
  final double localFee;
  final double stateFee;
  final double nationalFee;
  final String localEstimatedDays;
  final String stateEstimatedDays;
  final String nationalEstimatedDays;

  const ShippingConfig({
    required this.shopPincode,
    required this.freeShippingThreshold,
    required this.localFee,
    required this.stateFee,
    required this.nationalFee,
    required this.localEstimatedDays,
    required this.stateEstimatedDays,
    required this.nationalEstimatedDays,
  });

  factory ShippingConfig.fromMap(Map<String, dynamic> map) {
    return ShippingConfig(
      shopPincode: map['shopPincode'] ?? '600001',
      freeShippingThreshold: (map['freeShippingThreshold'] ?? 2000).toDouble(),
      localFee: (map['localFee'] ?? 49).toDouble(),
      stateFee: (map['stateFee'] ?? 99).toDouble(),
      nationalFee: (map['nationalFee'] ?? 149).toDouble(),
      localEstimatedDays: map['localEstimatedDays'] ?? '2-3',
      stateEstimatedDays: map['stateEstimatedDays'] ?? '3-5',
      nationalEstimatedDays: map['nationalEstimatedDays'] ?? '5-7',
    );
  }
}

class ShippingInfo {
  final double fee;
  final String estimatedDays;
  final double freeShippingThreshold;
  final bool isFreeShipping;
  final String? reason;

  const ShippingInfo({
    required this.fee,
    required this.estimatedDays,
    required this.freeShippingThreshold,
    required this.isFreeShipping,
    this.reason,
  });
}
