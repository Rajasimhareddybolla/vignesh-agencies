import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme.dart';
import '../../services/auth_service.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: context.read<AuthService>().isCurrentUserAdmin(),
      builder: (context, snapshot) {
        final isAdmin = snapshot.data ?? false;

        return Scaffold(
          appBar: AppBar(title: const Text('About Us')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withAlpha(40),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: Image.asset(
                      'assets/images/va.jpeg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppTheme.primaryLight,
                          child: const Icon(
                            Icons.store_mall_directory,
                            size: 60,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                Text(
                  'Vignesh Agencies',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isAdmin ? 'Admin Portal' : 'Your Trusted Electronics Partner',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Content Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border(context)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isAdmin) ...[
                        _buildSectionTitle(context, 'System Overview'),
                        const SizedBox(height: 12),
                        const Text(
                          'This application serves as the central command hub for Vignesh Agencies operations. It enables efficient management of service requests, warranty validations, technician assignments, and inventory control.',
                          style: TextStyle(height: 1.6),
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle(context, 'Key Features'),
                        const SizedBox(height: 12),
                        _buildFeatureItem(Icons.verified, 'Warranty Validation System'),
                        _buildFeatureItem(Icons.build, 'Service Request Tracking'),
                        _buildFeatureItem(Icons.people, 'Agent & Technician Management'),
                        _buildFeatureItem(Icons.inventory, 'Product Catalog Management'),
                      ] else ...[
                        _buildSectionTitle(context, 'Our Story'),
                        const SizedBox(height: 12),
                        const Text(
                          'Vignesh Agencies has been a cornerstone in the electronics distribution market, committed to delivering high-quality appliances and exceptional after-sales service. We specialize in household electronics ranging from energy-efficient fans to durable water heaters.',
                          style: TextStyle(height: 1.6),
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle(context, 'Our Commitment'),
                        const SizedBox(height: 12),
                        const Text(
                          'We believe in building lasting relationships with our customers through transparency, prompt service, and genuine products. Our "Service Hub" app is designed to make your ownership experience seamless and hassle-free.',
                           style: TextStyle(height: 1.6),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Contact Info
                _buildSectionTitle(context, 'Contact Us'),
                const SizedBox(height: 16),
                _buildContactRow(context, Icons.location_on, '123, Main Street, District Center, Area Code 560001'),
                const SizedBox(height: 12),
                GestureDetector(
                    onTap: () => _launchUrl('mailto:support@vigneshagencies.in'),
                    child: _buildContactRow(context, Icons.email, 'support@vigneshagencies.in')
                ),
                const SizedBox(height: 12),
                GestureDetector(
                    onTap: () => _launchUrl('tel:+919876543210'),
                    child: _buildContactRow(context, Icons.phone, '+91 98765 43210')
                ),

                const SizedBox(height: 48),

                // Developer Credits Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.code, color: AppTheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        'About the Developers',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Designed & Developed by Raja & Vatsal',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Freelance developers committed to building high-quality\nsoftware solutions for modern businesses.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary(context),
                              height: 1.5,
                            ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _showDeveloperContactOptions(context),
                        icon: const Icon(Icons.contact_support_outlined, size: 18),
                        label: const Text('Contact Developers'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                Text(
                  'Version 1.0.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary(context).withAlpha(100),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '© ${DateTime.now().year} Vignesh Agencies. All rights reserved.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary(context).withAlpha(100),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppTheme.primary,
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildContactRow(BuildContext context, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary(context)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $urlString');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  void _showDeveloperContactOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Developers',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Get in touch with Raja & Vatsal for your own app development needs.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary(context),
                  ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.primaryLight,
                child: Icon(Icons.phone, color: Colors.white),
              ),
              title: const Text('Call Us'),
              subtitle: const Text('+91 9014297131'),
              onTap: () {
                Navigator.pop(context);
                _launchUrl('tel:+919014297131');
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.primaryLight,
                child: Icon(Icons.email, color: Colors.white),
              ),
              title: const Text('Email Us'),
              subtitle: const Text('rajasimhabolla@gmail.com'),
              onTap: () {
                Navigator.pop(context);
                _launchUrl('mailto:rajasimhabolla@gmail.com?subject=Inquiry from Vignesh Agencies App');
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
