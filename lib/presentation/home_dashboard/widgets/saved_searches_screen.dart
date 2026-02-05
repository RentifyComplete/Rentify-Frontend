// lib/presentation/home_dashboard/widgets/saved_searches_screen.dart

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class SavedSearchesScreen extends StatelessWidget {
  const SavedSearchesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Searches'),
        backgroundColor: AppTheme.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_outline,
              size: 80,
              color: AppTheme.textSecondaryLight,
            ),
            const SizedBox(height: 20),
            const Text(
              'No Saved Searches',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your saved property searches will appear here',
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