import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Privacy Policy")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Privacy Policy",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "Last Updated: November 2025",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            _buildSection(
              "1. Information We Collect",
              "We collect information you provide directly to us, such as when you create an account, make a purchase, or contact us. This may include your name, email address, phone number, and payment information.",
            ),
            _buildSection(
              "2. How We Use Your Information",
              "We use the information we collect to provide, maintain, and improve our services, process transactions, send you service-related announcements, and respond to your inquiries.",
            ),
            _buildSection(
              "3. Data Security",
              "We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.",
            ),
            _buildSection(
              "4. Third-Party Sharing",
              "We do not sell, trade, or rent your personal information to third parties. We may share information with service providers who assist us in operating our website and conducting our business.",
            ),
            _buildSection(
              "5. Cookies",
              "We use cookies and similar tracking technologies to enhance your experience. You can control cookies through your browser settings.",
            ),
            _buildSection(
              "6. Your Rights",
              "You have the right to access, update, or delete your personal information at any time by contacting us directly.",
            ),
            _buildSection(
              "7. Payment Processing",
              "Payments will be received and processed by the owner within 1-5 business days from the transaction date. Please allow additional time for bank processing.",
            ),
            _buildSection(
              "8. Contact Us",
              "If you have any questions about this Privacy Policy, please contact us at privacy@example.com.",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}