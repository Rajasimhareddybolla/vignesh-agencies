import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../services/auth_service.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: context.read<AuthService>().isCurrentUserAdmin(),
      builder: (context, snapshot) {
        final isAdmin = snapshot.data ?? false;

        return Scaffold(
          appBar: AppBar(title: const Text('Help Center')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Search hint
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withAlpha(30)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tap on any question to see the answer',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (isAdmin) ...[
                // ADMIN FAQs
                _buildSectionHeader(context, 'Dashboard & Analytics', Icons.dashboard_outlined),
                const _FAQItem(
                    question: 'How do I track daily sales and requests?',
                    answer: 'Use the Command Center dashboard. It gives you a real-time overview of Pending Requests, Registrations, Total Users, and Payouts.'
                ),
                const _FAQItem(
                    question: 'How often are the stats updated?',
                    answer: 'The dashboard stats are updated in real-time as new requests or registrations come in.'
                ),

                const SizedBox(height: 16),
                _buildSectionHeader(context, 'Service Management', Icons.build_circle_outlined),
                const _FAQItem(
                    question: 'How do I assign a technician?',
                    answer: 'Open a "Pending" request from the Service Requests list. In the "Assignment" section, select a Saved Agent or enter their details manually, then tap "Assign & Notify Agent".'
                ),
                const _FAQItem(
                    question: 'Can I send voice instructions to technicians?',
                    answer: 'Yes. In the assignment section, use the microphone button to record a voice note. This will be sent to the technician.'
                ),
                 const _FAQItem(
                    question: 'How do I close a request?',
                    answer: 'Once the work is done, mark the request as "Resolved". The user will then confirm completion.'
                ),

                const SizedBox(height: 16),
                _buildSectionHeader(context, 'Product & Warranty', Icons.verified_user_outlined),
                const _FAQItem(
                    question: 'How do I validate warranty registrations?',
                    answer: 'Go to the "Warranty" tab. Review the uploaded bill and serial number. You can Approve or Reject the registration.'
                ),
                const _FAQItem(
                    question: 'How do add new products to the catalog?',
                    answer: 'Go to "Products" section and tap the + button. Enter product details, price, and specs.'
                ),
              ] else ...[
                // USER FAQs
                _buildSectionHeader(context, 'About Vignesh Agencies', Icons.storefront_outlined),
                 const _FAQItem(
                  question: 'Who is Vignesh Agencies?',
                  answer: 'Vignesh Agencies is your trusted partner for high-quality electronic appliances and reliable service. We provide a wide range of products including fans, water heaters, and stabilizers.',
                ),
                const _FAQItem(
                  question: 'Where are you located?',
                  answer: 'We operate primarily in the district area. Please contact support for our exact store locations.',
                ),

                const SizedBox(height: 16),
                _buildSectionHeader(context, 'Products & Warranty', Icons.inventory_2_outlined),
                const _FAQItem(
                  question: 'How do I register my product for warranty?',
                  answer: 'Go to the Home screen and tap "Register Appliance". Upload your purchase bill from Vignesh Agencies and enter the details. Once approved, your warranty is active.',
                ),
                const _FAQItem(
                  question: 'What is the warranty period?',
                  answer: 'Warranty coverage depends on the product (e.g., 2 years for Water Heaters, 3 years for Stabilizers). Check your product purchase receipt or manual.',
                ),

                const SizedBox(height: 16),
                _buildSectionHeader(context, 'Service & Support', Icons.build_outlined),
                const _FAQItem(
                  question: 'How do I request a repair?',
                  answer: 'Go to "My Appliances", select the item, and tap "Request Service". Our team will assign a technician to visit you.',
                ),
                 const _FAQItem(
                  question: 'Is service chargeable?',
                  answer: 'Service is free for manufacturing defects within the warranty period. Out-of-warranty services or physical damage repairs are chargeable.',
                ),

                const SizedBox(height: 16),
                _buildSectionHeader(context, 'Ordering', Icons.shopping_cart_outlined),
                const _FAQItem(
                  question: 'Can I buy products directly from the app?',
                  answer: 'Yes! Browse our catalog in the "Shop" section and place orders. We currently support Cash on Delivery.',
                ),
              ],

              const SizedBox(height: 32),

              // Contact Support Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withAlpha(50),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.headset_mic, color: Colors.white, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Still need help?',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Our support team at Vignesh Agencies is ready to assist you',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withAlpha(200),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _makePhoneCall(context, '+919876543210'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          icon: const Icon(Icons.phone, size: 18),
                          label: const Text('Call Us'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => _openWhatsApp(context, '+919876543210'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF25D366),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          icon: const Icon(Icons.chat, size: 18),
                          label: const Text('WhatsApp'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String urlScheme) async {
    final Uri url = Uri.parse(urlScheme);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $urlScheme');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch: $e')),
        );
      }
    }
  }

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    await launchUrl(uri);
  }

  Future<void> _openWhatsApp(BuildContext context, String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$cleanNumber');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }
  }
}

class _FAQItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FAQItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.border(context)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          question,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Text(
            answer,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
