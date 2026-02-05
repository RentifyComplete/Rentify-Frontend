import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class TermsConditionsWidget extends StatefulWidget {
  final bool termsAccepted;
  final Function(bool) onTermsChanged;
  final double totalAmount;
  final bool isLoading;
  final VoidCallback onConfirmBooking;

  const TermsConditionsWidget({
    super.key,
    required this.termsAccepted,
    required this.onTermsChanged,
    required this.totalAmount,
    required this.isLoading,
    required this.onConfirmBooking,
  });

  @override
  State<TermsConditionsWidget> createState() => _TermsConditionsWidgetState();
}

class _TermsConditionsWidgetState extends State<TermsConditionsWidget> {
  final bool _showFullTerms = false;

  final String _termsText = """
RENTAL AGREEMENT TERMS AND CONDITIONS

1. BOOKING AND PAYMENT
• Full payment is required to confirm your booking
• Security deposit is refundable subject to property condition
• Service charges are non-refundable
• Payment must be completed within 24 hours of booking

2. OCCUPANCY TERMS
• Maximum occupancy as specified in booking details
• No subletting or unauthorized guests allowed
• Property must be used for residential purposes only
• Smoking and pets are strictly prohibited unless specified

3. CANCELLATION POLICY
• Cancellation more than 30 days: Full refund minus processing fee
• Cancellation 15-30 days: 50% refund of rent amount
• Cancellation less than 15 days: No refund of rent amount
• Security deposit refundable in all cases

4. PROPERTY MAINTENANCE
• Report any damages or issues immediately
• Tenant responsible for damages beyond normal wear and tear
• Regular maintenance will be scheduled with prior notice
• Emergency repairs may be conducted without notice

5. CHECK-IN/CHECK-OUT
• Check-in time: 12:00 PM onwards
• Check-out time: 11:00 AM
• Late check-out may incur additional charges
• Property inspection will be conducted at check-out

6. HOUSE RULES
• Maintain cleanliness and hygiene
• Respect other tenants and neighbors
• No loud music or parties after 10 PM
• Follow all building and society rules

7. LIABILITY AND INSURANCE
• Tenant responsible for personal belongings
• Property owner not liable for theft or damage to personal items
• Tenant advised to obtain personal insurance
• Report any incidents to property management immediately

8. TERMINATION
• Either party may terminate with 30 days written notice
• Immediate termination for violation of terms
• Security deposit adjustment upon termination
• Final settlement within 7 days of check-out

By proceeding with this booking, you acknowledge that you have read, understood, and agree to be bound by these terms and conditions.
""";

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          height: 80.h,
          padding: EdgeInsets.all(4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Terms & Conditions',
                    style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: CustomIconWidget(
                      iconName: 'close',
                      color: AppTheme.lightTheme.colorScheme.onSurface,
                      size: 24,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    _termsText,
                    style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 2.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Confirm',
            style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 1.h),

          Text(
            'Please review the terms and confirm your booking',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
          ),

          SizedBox(height: 3.h),

          // Booking Summary
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.outline
                    .withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.lightTheme.colorScheme.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'receipt',
                      color: AppTheme.lightTheme.colorScheme.primary,
                      size: 24,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Booking Summary',
                      style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount',
                      style:
                          AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '₹${widget.totalAmount.toStringAsFixed(0)}',
                      style: AppTheme.lightTheme.textTheme.headlineMedium
                          ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.lightTheme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  'Including rent, security deposit, and service charges',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 3.h),

          // Terms and Conditions Section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.outline
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'gavel',
                      color: AppTheme.lightTheme.colorScheme.primary,
                      size: 20,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Terms & Conditions',
                      style:
                          AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 2.h),

                // Terms Preview
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: AppTheme.lightTheme.colorScheme.primary
                        .withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _showFullTerms
                            ? _termsText
                            : "${_termsText.substring(0, 300)}...",
                        style:
                            AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      GestureDetector(
                        onTap: _showTermsDialog,
                        child: Text(
                          'Read Full Terms & Conditions',
                          style:
                              AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.lightTheme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 2.h),

                // Terms Acceptance Checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: widget.termsAccepted,
                      onChanged: (bool? value) {
                        if (value != null) {
                          widget.onTermsChanged(value);
                        }
                      },
                      activeColor: AppTheme.lightTheme.colorScheme.primary,
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            widget.onTermsChanged(!widget.termsAccepted),
                        child: Text(
                          'I have read and agree to the Terms & Conditions, Privacy Policy, and Cancellation Policy',
                          style: AppTheme.lightTheme.textTheme.bodyMedium
                              ?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 3.h),

          // Important Notes
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.tertiary
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.tertiary
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'info',
                      color: AppTheme.lightTheme.colorScheme.tertiary,
                      size: 20,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Important Notes',
                      style:
                          AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.lightTheme.colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  '• Booking confirmation will be sent via email and SMS\n• Document verification may take up to 24 hours\n• Check-in details will be shared after verification\n• Contact support for any assistance: +91-9876543210',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 4.h),

          // Confirm Booking Button
          SizedBox(
            width: double.infinity,
            height: 6.h,
            child: ElevatedButton(
              onPressed: widget.termsAccepted && !widget.isLoading
                  ? widget.onConfirmBooking
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.termsAccepted && !widget.isLoading
                    ? AppTheme.lightTheme.colorScheme.primary
                    : AppTheme.lightTheme.colorScheme.outline,
              ),
              child: widget.isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.lightTheme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          'Processing...',
                          style: AppTheme.lightTheme.textTheme.labelLarge
                              ?.copyWith(
                            color: AppTheme.lightTheme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomIconWidget(
                          iconName: 'check_circle',
                          color: widget.termsAccepted
                              ? AppTheme.lightTheme.colorScheme.onPrimary
                              : AppTheme
                                  .lightTheme.colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          'Confirm Booking',
                          style: AppTheme.lightTheme.textTheme.labelLarge
                              ?.copyWith(
                            color: widget.termsAccepted
                                ? AppTheme.lightTheme.colorScheme.onPrimary
                                : AppTheme
                                    .lightTheme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          SizedBox(height: 2.h),

          // Support Contact
          Center(
            child: TextButton.icon(
              onPressed: () {
                // Handle support contact
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Support: +91-9876543210 | support@rentok.com'),
                  ),
                );
              },
              icon: CustomIconWidget(
                iconName: 'support_agent',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 16,
              ),
              label: Text(
                'Need Help? Contact Support',
                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}