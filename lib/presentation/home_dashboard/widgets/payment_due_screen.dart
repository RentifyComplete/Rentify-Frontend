// lib/presentation/home_dashboard/widgets/payment_due_screen.dart

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class PaymentDueScreen extends StatelessWidget {
  const PaymentDueScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Due'),
        backgroundColor: AppTheme.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.payment_outlined,
              size: 80,
              color: AppTheme.textSecondaryLight,
            ),
            const SizedBox(height: 20),
            const Text(
              'No Payments Due',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'All your payments are up to date',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}