import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_export.dart';
import './privacy_policy_screen.dart';
import './terms_conditions_screen.dart';

class LoginFooterWidget extends StatelessWidget {
  const LoginFooterWidget({super.key});

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 3.h, horizontal: 4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: AppTheme.lightTheme.colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Company Info Section
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.home_rounded,
                color: AppTheme.primaryLight,
                size: 6.w,
              ),
              SizedBox(width: 2.w),
              Text(
                'Rentify',
                style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryLight,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 1.5.h),
          
          // Tagline
          Text(
            'Your trusted property rental platform',
            style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryLight,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: 2.h),
          
          // Helpline Section
          Container(
            padding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 4.w),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryLight.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.support_agent,
                      color: AppTheme.primaryLight,
                      size: 5.w,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Need Help?',
                      style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryLight,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                
                // Phone Number
                InkWell(
                  onTap: () => _launchURL('tel:+919306935505'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.phone,
                        color: AppTheme.primaryLight,
                        size: 4.w,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        '+91 93069 35505',
                        style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 0.8.h),
                
                // Email
                InkWell(
                  onTap: () => _launchURL('mailto:Yaksh@rentify24.com'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.email,
                        color: AppTheme.primaryLight,
                        size: 4.w,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        'Yaksh@rentify24.com',
                        style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 2.h),
          
          // Divider
          Divider(
            color: AppTheme.lightTheme.colorScheme.outline.withOpacity(0.2),
            thickness: 1,
          ),
          
          SizedBox(height: 2.h),
          
          // Footer Links
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 1.w,
            runSpacing: 1.h,
            children: [
              _buildFooterLink(
                context,
                'Privacy Policy',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacyPolicyScreen(),
                    ),
                  );
                },
              ),
              _buildDot(),
              _buildFooterLink(
                context,
                'Terms & Conditions',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TermsConditionsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          
          SizedBox(height: 2.h),
          
          // Copyright & Version
          Column(
            children: [
              Text(
                '© 2024 Rentify. All rights reserved.',
                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryLight.withOpacity(0.7),
                  fontSize: 9.sp,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 0.5.h),
              Text(
                'Version 1.0.0',
                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryLight.withOpacity(0.5),
                  fontSize: 8.sp,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          
          SizedBox(height: 1.h),
          
          // Made with love message
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Made with',
                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryLight.withOpacity(0.6),
                  fontSize: 9.sp,
                ),
              ),
              SizedBox(width: 1.w),
              Icon(
                Icons.favorite,
                color: Colors.red,
                size: 3.w,
              ),
              SizedBox(width: 1.w),
              Text(
                'in India',
                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryLight.withOpacity(0.6),
                  fontSize: 9.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: AppTheme.primaryLight.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 5.w,
          color: AppTheme.primaryLight,
        ),
      ),
    );
  }

  Widget _buildFooterLink(
    BuildContext context,
    String text,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
        child: Text(
          text,
          style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
            color: AppTheme.primaryLight,
            fontWeight: FontWeight.w500,
            fontSize: 9.5.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildDot() {
    return Text(
      '•',
      style: TextStyle(
        color: AppTheme.textSecondaryLight.withOpacity(0.5),
        fontSize: 9.sp,
      ),
    );
  }
}