import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
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

          // Account & Profile Section
          _buildSectionHeader(context, 'Account & Profile', Icons.person_outline),
          const _FAQItem(
            question: 'How do I update my profile?',
            answer: 'Go to Profile tab → Edit Profile. You can update your name, phone number, and profile picture.',
          ),
          const _FAQItem(
            question: 'How do I change my phone number?',
            answer: 'Currently, the phone number is linked to your account. Contact support to change it.',
          ),

          const SizedBox(height: 16),

          // Products & Warranty Section
          _buildSectionHeader(context, 'Products & Warranty', Icons.inventory_2_outlined),
          const _FAQItem(
            question: 'How do I register a product?',
            answer: 'Go to the Home screen and tap on "Register Appliance" or the + button. Fill in the product details, upload your purchase bill, and submit for warranty approval.',
          ),
          const _FAQItem(
            question: 'What documents do I need for registration?',
            answer: 'You need your purchase bill/invoice showing the product details, purchase date, and dealer information. A clear photo of the bill is required.',
          ),
          const _FAQItem(
            question: 'What is the warranty period?',
            answer: 'Warranty period varies by product type:\n• Water Heaters: 2 years\n• Stabilizers: 3 years\n• Fans: 2 years\n• Other appliances: 1-2 years\nCheck your product manual for specific details.',
          ),
          const _FAQItem(
            question: 'What does "Warranty Pending" mean?',
            answer: 'Your product registration is being verified by our team. This usually takes 1-2 business days. You\'ll be notified once approved.',
          ),
          const _FAQItem(
            question: 'My warranty was rejected. What should I do?',
            answer: 'Check the rejection reason in your appliance details. Common reasons include unclear bill photo or missing information. You can re-submit with correct documents.',
          ),

          const SizedBox(height: 16),

          // Service Requests Section
          _buildSectionHeader(context, 'Service Requests', Icons.build_outlined),
          const _FAQItem(
            question: 'How do I request service?',
            answer: 'Select a product from "My Appliances" and tap "Request Service". Choose the issue type, describe the problem, and optionally add photos or voice recording. Our team will contact you within 24-48 hours.',
          ),
          const _FAQItem(
            question: 'How do I track my service request?',
            answer: 'Go to the "Requests" tab in the bottom navigation. You\'ll see all your requests with current status: Pending, Assigned, In Progress, or Completed.',
          ),
          const _FAQItem(
            question: 'Can I cancel a service request?',
            answer: 'Contact our support team to cancel a pending request. Once a technician is assigned, cancellation may not be possible.',
          ),
          const _FAQItem(
            question: 'Is service free under warranty?',
            answer: 'Yes, service is free for manufacturing defects within the warranty period. Physical damage or misuse may incur charges.',
          ),

          const SizedBox(height: 16),

          // Orders & Payments Section
          _buildSectionHeader(context, 'Orders & Payments', Icons.shopping_bag_outlined),
          const _FAQItem(
            question: 'What payment methods are accepted?',
            answer: 'Currently, we accept Cash on Delivery (COD). Online payment options will be available soon.',
          ),
          const _FAQItem(
            question: 'How long does delivery take?',
            answer: 'Standard delivery takes 3-5 business days depending on your location. You\'ll receive updates via notifications.',
          ),
          const _FAQItem(
            question: 'Can I return a product?',
            answer: 'Products can be returned within 7 days of delivery if unused and in original packaging. Contact support to initiate a return.',
          ),

          const SizedBox(height: 16),

          // Referrals Section
          _buildSectionHeader(context, 'Referrals & Rewards', Icons.card_giftcard_outlined),
          const _FAQItem(
            question: 'How do referrals work?',
            answer: 'Share your unique referral code with friends. When they register their first appliance using your code, you earn ₹100 in rewards!',
          ),
          const _FAQItem(
            question: 'Where do I find my referral code?',
            answer: 'Go to Profile → "Redeem Referral Code" or check the Referrals section. Your code is also shown on the Home screen.',
          ),
          const _FAQItem(
            question: 'How do I use my rewards?',
            answer: 'Rewards are automatically applied to your account and can be used for future purchases or service charges.',
          ),

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
                  'Our support team is ready to assist you',
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
                      onPressed: () => _makePhoneCall('+919876543210'),
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
                      onPressed: () => _openWhatsApp('+919876543210'),
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

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    final uri = Uri.parse('https://wa.me/${phoneNumber.replaceAll('+', '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
