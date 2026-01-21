import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Text('''
1. Introduction
Welcome to Vignesh Agencies District Service Hub. These Terms and Conditions govern your use of our app.

2. User Accounts
You are responsible for maintaining the confidentiality of your account credentials.

3. Service Requests
Service requests are subject to technician availability. We strive to attend to all requests within 24-48 hours.

4. Warranty
Product warranty claims must be supported by valid proof of purchase.

(This is a placeholder for the full Terms & Conditions)
          ''', style: TextStyle(fontSize: 16, height: 1.5)),
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Text('''
1. Data Collection
We collect personal information such as name, phone number, and address to provide service.

2. Data Usage
Your data is used solely for service delivery, warranty management, and app improvement.

3. Data Sharing
We do not share your personal data with third parties without your consent, except as required by law.

(This is a placeholder for the full Privacy Policy)
          ''', style: TextStyle(fontSize: 16, height: 1.5)),
      ),
    );
  }
}
