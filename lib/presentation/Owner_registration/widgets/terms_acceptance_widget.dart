import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import '../../../theme/app_theme.dart';

class TermsAcceptanceWidget extends StatefulWidget {
  final Function(bool) onSubmit;
  final VoidCallback onBack;
  final bool isLoading;

  const TermsAcceptanceWidget({
    super.key,
    required this.onSubmit,
    required this.onBack,
    this.isLoading = false,
  });

  @override
  State<TermsAcceptanceWidget> createState() => _TermsAcceptanceWidgetState();
}

class _TermsAcceptanceWidgetState extends State<TermsAcceptanceWidget> {
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _dataProcessingAccepted = false;

  void _handleSubmit() {
    if (!_termsAccepted || !_privacyAccepted || !_dataProcessingAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please accept all terms and conditions'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    widget.onSubmit(true);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(6.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Terms & Conditions',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.lightTheme.primaryColor,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Please review and accept to continue',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 3.h),

          // Terms Content Card
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTermsSection(
                  icon: Icons.gavel_outlined,
                  title: 'Terms of Service',
                  content:
                      'As a property owner, you agree to list only genuine properties with accurate information. You are responsible for maintaining property standards, handling tenant queries professionally, and complying with all local rental laws and regulations.',
                ),
                Divider(height: 3.h),
                _buildTermsSection(
                  icon: Icons.verified_user_outlined,
                  title: 'Property Standards',
                  content:
                      'All properties must meet minimum safety and habitability standards. You must disclose any known issues or defects. Regular maintenance and timely repairs are your responsibility.',
                ),
                Divider(height: 3.h),
                _buildTermsSection(
                  icon: Icons.payment_outlined,
                  title: 'Payment Terms',
                  content:
                      'Platform fees apply as per our pricing structure. Rental payments will be processed through our secure payment gateway. You agree to our refund and cancellation policies.',
                ),
                Divider(height: 3.h),
                _buildTermsSection(
                  icon: Icons.balance_outlined,
                  title: 'Legal Compliance',
                  content:
                      'You must comply with all applicable laws including fair housing laws, building codes, and tax regulations. You are responsible for obtaining necessary permits and licenses.',
                ),
              ],
            ),
          ),

          SizedBox(height: 3.h),

          // Acceptance Checkboxes
          _buildCheckboxTile(
            value: _termsAccepted,
            onChanged: (value) {
              setState(() {
                _termsAccepted = value!;
              });
              HapticFeedback.selectionClick();
            },
            title: 'I accept the Terms and Conditions',
            subtitle: 'Tap to view full terms',
            onTap: () => _showFullTermsDialog('Terms and Conditions', _getFullTerms()),
          ),

          SizedBox(height: 1.h),

          _buildCheckboxTile(
            value: _privacyAccepted,
            onChanged: (value) {
              setState(() {
                _privacyAccepted = value!;
              });
              HapticFeedback.selectionClick();
            },
            title: 'I accept the Privacy Policy',
            subtitle: 'Tap to view privacy policy',
            onTap: () =>
                _showFullTermsDialog('Privacy Policy', _getPrivacyPolicy()),
          ),

          SizedBox(height: 1.h),

          _buildCheckboxTile(
            value: _dataProcessingAccepted,
            onChanged: (value) {
              setState(() {
                _dataProcessingAccepted = value!;
              });
              HapticFeedback.selectionClick();
            },
            title: 'I consent to data processing',
            subtitle: 'Your data will be processed securely',
            onTap: () =>
                _showFullTermsDialog('Data Processing', _getDataProcessing()),
          ),

          SizedBox(height: 4.h),

          // Important Notice
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_outlined,
                    color: Colors.orange[700], size: 24),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    'By registering, you confirm that all information provided is accurate and you have the legal right to rent the properties listed.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 4.h),

          // Navigation Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.isLoading ? null : widget.onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.lightTheme.primaryColor,
                    side: BorderSide(
                      color: AppTheme.lightTheme.primaryColor,
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_back, size: 20),
                      SizedBox(width: 2.w),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.lightTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor:
                        AppTheme.lightTheme.primaryColor.withOpacity(0.6),
                  ),
                  child: widget.isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 20),
                            SizedBox(width: 2.w),
                            Text(
                              'Submit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.lightTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppTheme.lightTheme.primaryColor,
            size: 20,
          ),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 0.5.h),
              Text(
                content,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxTile({
    required bool value,
    required Function(bool?) onChanged,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: value ? AppTheme.lightTheme.primaryColor : Colors.grey[300]!,
          width: value ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: value
            ? AppTheme.lightTheme.primaryColor.withOpacity(0.05)
            : Colors.white,
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        subtitle: GestureDetector(
          onTap: onTap,
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.lightTheme.primaryColor,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppTheme.lightTheme.primaryColor,
      ),
    );
  }

  void _showFullTermsDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  String _getFullTerms() {
    return '''
TERMS AND CONDITIONS

1. ACCEPTANCE OF TERMS
By registering as a property owner on our platform, you agree to be bound by these Terms and Conditions.

2. PROPERTY LISTING
- All property information must be accurate and up-to-date
- You must have legal ownership or authorization to rent the property
- Properties must meet all safety and habitability standards
- You are responsible for maintaining property condition

3. FEES AND PAYMENTS
- Platform service fees apply as per our pricing structure
- Payment processing through secure gateway
- Refunds subject to our refund policy

4. RESPONSIBILITIES
- Respond to tenant inquiries within 24 hours
- Maintain property standards
- Comply with all local laws and regulations
- Handle disputes professionally

5. TERMINATION
We reserve the right to terminate accounts that violate these terms.

For complete terms, please visit our website.
''';
  }

  String _getPrivacyPolicy() {
    return '''
PRIVACY POLICY

1. INFORMATION COLLECTION
We collect personal information including name, email, phone number, and bank details necessary for providing our services.

2. DATA USAGE
Your information is used for:
- Account management
- Payment processing
- Communication
- Service improvement

3. DATA SECURITY
We implement industry-standard security measures to protect your data.

4. DATA SHARING
We do not sell your personal information. Data may be shared with:
- Payment processors
- Legal authorities when required

5. YOUR RIGHTS
You have the right to access, modify, or delete your personal data.

For complete privacy policy, please visit our website.
''';
  }

  String _getDataProcessing() {
    return '''
DATA PROCESSING CONSENT

By accepting, you consent to:

1. Processing of your personal and business information
2. Storage of documents uploaded to our platform
3. Communication via email, SMS, and push notifications
4. Analytics and service improvement activities
5. Sharing data with verified tenants during booking process

Your data will be:
- Encrypted and stored securely
- Processed only for legitimate business purposes
- Retained as per legal requirements
- Protected against unauthorized access

You can withdraw consent at any time by contacting support.
''';
  }
}