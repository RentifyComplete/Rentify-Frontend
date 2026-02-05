import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_export.dart';

class HostInfoWidget extends StatelessWidget {
  final Map<String, dynamic> hostData;
  final VoidCallback onMessageTap;

  const HostInfoWidget({
    super.key,
    required this.hostData,
    required this.onMessageTap,
  });

  void _showContactOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildContactBottomSheet(context),
    );
  }

  Widget _buildContactBottomSheet(BuildContext context) {
    final phoneNumber = hostData["phoneNumber"] as String? ?? "";
    final hostName = hostData["name"] as String? ?? "Host";

    // ⭐ FIX: Check for empty, null, or string "null"
    if (phoneNumber.isEmpty || phoneNumber == 'null' || phoneNumber == 'NULL') {
      return Container(
        padding: EdgeInsets.all(5.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12.w,
              height: 0.6.h,
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            SizedBox(height: 3.h),
            Icon(Icons.phone_disabled, size: 32, color: Colors.orange.shade400),
            SizedBox(height: 2.h),
            Text(
              'Phone number not available',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.lightTheme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'The property owner hasn\'t added their phone number yet. Please try contacting through the booking system.',
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 3.h),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(5.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12.w,
            height: 0.6.h,
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Contact $hostName',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTheme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 4.h),
          // Call Option
          _buildContactOption(
            context,
            icon: 'phone',
            title: 'Call',
            subtitle: phoneNumber,
            onTap: () => _makePhoneCall(phoneNumber, context),
          ),
          SizedBox(height: 2.h),
          // WhatsApp Option
          _buildContactOption(
            context,
            icon: 'whatsapp',
            title: 'Message on WhatsApp',
            subtitle: 'Chat directly with $hostName',
            onTap: () => _openWhatsApp(phoneNumber, context),
          ),
          SizedBox(height: 3.h),
        ],
      ),
    );
  }

  Widget _buildContactOption(
    BuildContext context, {
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.5.w),
                decoration: BoxDecoration(
                  color: AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: CustomIconWidget(
                  iconName: icon,
                  color: AppTheme.lightTheme.colorScheme.primary,
                  size: 24,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.lightTheme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      subtitle,
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber, BuildContext context) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
        Navigator.pop(context);
      } else {
        _showErrorSnackBar(context, 'Could not launch phone call');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Error making call: $e');
    }
  }

  Future<void> _openWhatsApp(String phoneNumber, BuildContext context) async {
    // Remove any non-digit characters from phone number
    final cleanedPhoneNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
    
    // Ensure phone number starts with country code (e.g., 91 for India)
    String whatsappNumber = cleanedPhoneNumber;
    if (!cleanedPhoneNumber.startsWith('+')) {
      if (!cleanedPhoneNumber.startsWith('91')) {
        whatsappNumber = '91$cleanedPhoneNumber'; // Add India country code if not present
      }
      whatsappNumber = '+$whatsappNumber';
    }

    final String message = 'Hi, I am interested in your property.';
    final Uri whatsappUri = Uri.parse(
      'https://wa.me/$whatsappNumber?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        Navigator.pop(context);
      } else {
        _showErrorSnackBar(context, 'WhatsApp is not installed');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Error opening WhatsApp: $e');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hosted by',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTheme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 3.h),
          Row(
            children: [
              Container(
                width: 15.w,
                height: 15.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.lightTheme.colorScheme.primary
                        .withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: CustomImageWidget(
                    imageUrl: hostData["image"] as String,
                    width: 15.w,
                    height: 15.w,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hostData["name"] as String,
                      style:
                          AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.lightTheme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'star',
                          color: Colors.amber,
                          size: 16,
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          '${hostData["rating"]} • ${hostData["properties"]} properties',
                          style:
                              AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                            color: AppTheme
                                .lightTheme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      hostData["responseTime"] as String,
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showContactOptions(context),
                icon: CustomIconWidget(
                  iconName: 'message',
                  color: AppTheme.lightTheme.colorScheme.primary,
                  size: 18,
                ),
                label: Text('Message'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}