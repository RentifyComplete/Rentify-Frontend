import 'package:flutter/material.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Terms & Conditions")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Terms & Conditions",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "Last Updated: November 2025",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            _buildSection(
              "1. Acceptance of Terms",
              "By accessing and using this application, you accept and agree to be bound by the terms and provision of this agreement.",
            ),
            _buildSection(
              "2. User Responsibilities",
              "You are responsible for maintaining the confidentiality of your account information and passwords. You agree to accept responsibility for all activities that occur under your account.",
            ),
            _buildSection(
              "3. Prohibited Activities",
              "You agree not to engage in any activity that disrupts or negatively affects the quality of the service, including harassment, illegal activities, or unauthorized access.",
            ),
            _buildSection(
              "4. Payment Terms",
              "All payments must be made through authorized payment methods. Payment will be received and processed by the owner within 1-5 business days from the transaction date.",
            ),
            _buildSection(
              "5. Refund Policy",
              "Refunds are subject to our refund policy. Please refer to our customer service for specific details regarding your purchase.",
            ),
            _buildSection(
              "6. Limitation of Liability",
              "We shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of or inability to use the service.",
            ),
            _buildSection(
              "7. Intellectual Property",
              "All content, features, and functionality are owned by us, our licensors, or other providers of such material and are protected by copyright and other laws.",
            ),
            _buildSection(
              "8. Modifications to Terms",
              "We reserve the right to modify these terms at any time. Your continued use of the service constitutes your acceptance of any changes.",
            ),
            _buildSection(
              "9. Termination",
              "We may terminate or suspend your account and access to the service immediately, without prior notice or liability, for any reason.",
            ),
            _buildSection(
              "10. Governing Law",
              "These terms are governed by and construed in accordance with the laws of the jurisdiction in which the company is located.",
            ),
            _buildSection(
              "11. Contact Information",
              "For questions or concerns regarding these Terms & Conditions, please contact us at support@example.com.",
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