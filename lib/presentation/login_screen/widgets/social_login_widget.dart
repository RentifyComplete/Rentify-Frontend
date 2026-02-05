import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class SocialLoginWidget extends StatelessWidget {
  final Function(String) onSocialLogin;

  const SocialLoginWidget({
    super.key,
    required this.onSocialLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Divider with text
        Row(
          children: [
            Expanded(
              child: Divider(
                color: AppTheme.lightTheme.colorScheme.outline,
                thickness: 1,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Text(
                'Or continue with',
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: AppTheme.lightTheme.colorScheme.outline,
                thickness: 1,
              ),
            ),
          ],
        ),

        SizedBox(height: 3.h),

        // Social login buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSocialButton(
              'Google',
              'g_logo',
              () => onSocialLogin('Google'),
            ),
            _buildSocialButton(
              'Apple',
              'apple',
              () => onSocialLogin('Apple'),
            ),
            _buildSocialButton(
              'Facebook',
              'facebook',
              () => onSocialLogin('Facebook'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton(String name, String iconName, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 25.w,
        height: 6.h,
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.lightTheme.colorScheme.outline,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.lightTheme.colorScheme.shadow,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomIconWidget(
                iconName: _getIconName(name),
                color: _getIconColor(name),
                size: 6.w,
              ),
              SizedBox(height: 0.5.h),
              Text(
                name,
                style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getIconName(String provider) {
    switch (provider) {
      case 'Google':
        return 'g_translate';
      case 'Apple':
        return 'apple';
      case 'Facebook':
        return 'facebook';
      default:
        return 'login';
    }
  }

  Color _getIconColor(String provider) {
    switch (provider) {
      case 'Google':
        return Color(0xFF4285F4);
      case 'Apple':
        return Color(0xFF000000);
      case 'Facebook':
        return Color(0xFF1877F2);
      default:
        return AppTheme.lightTheme.colorScheme.onSurface;
    }
  }
}
