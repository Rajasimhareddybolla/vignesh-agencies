import 'package:flutter/material.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help Center')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _FAQItem(
            question: 'How do I register a product?',
            answer:
                'Go to the Home screen and tap on the "Add Product" button. Fill in the details and upload your bill.',
          ),
          _FAQItem(
            question: 'How do I request service?',
            answer:
                'Select a product from "My Appliances" and tap "Request Service". Choose the issue type and submit.',
          ),
          _FAQItem(
            question: 'What is the warranty period?',
            answer:
                'Warranty period varies by product. Generally it is 1-2 years. Check your product manual or warranty card.',
          ),
          _FAQItem(
            question: 'How do I track my service request?',
            answer:
                'You can track all your requests in the "Service Requests" tab on the bottom navigation bar.',
          ),
        ],
      ),
    );
  }
}

class _FAQItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FAQItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(answer, style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }
}
