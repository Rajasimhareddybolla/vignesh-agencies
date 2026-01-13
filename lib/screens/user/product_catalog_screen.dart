import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../widgets/common/premium_widgets.dart';

class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({super.key});

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  final List<Map<String, dynamic>> _catalogProducts = [
    {
      'id': '1',
      'name': 'V-Guard Zen Fan',
      'category': 'Fan',
      'description': 'High-speed ceiling fan with anti-dust coating and energy-efficient motor. Operates silently even at high speeds.',
      'features': ['Anti-Dust', 'High Speed', 'Silent Operation', 'REMOTE Control'],
      'image': 'assets/images/fan.png',
    },
    {
      'id': '2',
      'name': 'V-Guard Water Heater',
      'category': 'Heater',
      'description': 'Advanced water heater with polymer protective coating and high-pressure resistance. Perfect for high-rise buildings.',
      'features': ['5-Star Rating', 'Glass Lined Tank', 'Rust Proof', 'Auto Cut-off'],
      'image': 'assets/images/heater.png',
    },
    {
      'id': '3',
      'name': 'V-Guard Stabilizer',
      'category': 'Stabilizer',
      'description': 'Digital voltage stabilizer for ACs up to 1.5 tons. Protects your appliances from voltage fluctuations and surges.',
      'features': ['Digital Display', 'Time Delay', 'High Voltage Cut-off', 'Wall Mountable'],
      'image': 'assets/images/stabilizer.png',
    },
    {
      'id': '4',
      'name': 'Induction Cooktop',
      'category': 'Appliance',
      'description': 'Efficient induction cooktop with 7 Indian cooking menus and preset timer function.',
      'features': ['Touch Controls', 'Auto-off', 'Power Saver', 'Easy Clean'],
      'image': 'assets/images/induction.png',
    },
     {
      'id': '5',
      'name': 'Inverter Battery',
      'category': 'Inverter',
      'description': 'Long-lasting tubular battery with low maintenance and fast charging capability.',
      'features': ['36 Month Warranty', 'High Backup', 'Tubular Technology', 'Deep Cycle'],
      'image': 'assets/images/inverter.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
         leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Product Catalog'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _catalogProducts.length,
        itemBuilder: (context, index) {
          final product = _catalogProducts[index];
          return StaggeredFadeIn(
            index: index,
            child: _buildProductCard(context, product),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      // Use standard card decoration or custom premium card
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10), // Fixed alpha
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image / Header
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.backgroundLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Stack(
              children: [
                 Center(
                   child: Icon(
                    _getIconForCategory(product['category']), 
                    size: 80, 
                    color: AppTheme.primary.withOpacity(0.3)
                   ),
                 ),
                 // If we had real images, we would use them here:
                 // Image.asset(product['image'], fit: BoxFit.cover) 
                 Positioned(
                   top: 12,
                   right: 12,
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                     decoration: BoxDecoration(
                       color: Colors.black.withOpacity(0.6),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Text(
                       product['category'],
                       style: const TextStyle(
                         color: Colors.white,
                         fontSize: 12,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                   ),
                 )
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'],
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product['description'],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (product['features'] as List<String>).map((feature) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        feature,
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'fan': return Icons.wind_power;
      case 'heater': return Icons.water_drop;
      case 'stabilizer': return Icons.electrical_services;
      case 'inverter': return Icons.battery_charging_full;
      default: return Icons.inventory_2;
    }
  }
}
