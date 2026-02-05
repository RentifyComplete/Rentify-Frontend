import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class EmergencyContactWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onDataChanged;
  final Map<String, dynamic> initialData;

  const EmergencyContactWidget({
    super.key,
    required this.onDataChanged,
    required this.initialData,
  });

  @override
  State<EmergencyContactWidget> createState() => _EmergencyContactWidgetState();
}

class _EmergencyContactWidgetState extends State<EmergencyContactWidget> {
  final TextEditingController _primaryNameController = TextEditingController();
  final TextEditingController _primaryPhoneController = TextEditingController();
  final TextEditingController _primaryEmailController = TextEditingController();
  final TextEditingController _secondaryNameController =
      TextEditingController();
  final TextEditingController _secondaryPhoneController =
      TextEditingController();
  final TextEditingController _secondaryEmailController =
      TextEditingController();

  String? _primaryRelationship;
  String? _secondaryRelationship;
  bool _allowContactSharing = true;
  bool _emergencyNotifications = true;

  final List<String> _relationshipOptions = [
    'Parent',
    'Sibling',
    'Spouse',
    'Friend',
    'Relative',
    'Colleague',
    'Guardian',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    final primaryContact = widget.initialData['primaryContact'] ?? {};
    final secondaryContact = widget.initialData['secondaryContact'] ?? {};

    _primaryNameController.text = primaryContact['name'] ?? '';
    _primaryPhoneController.text = primaryContact['phone'] ?? '';
    _primaryEmailController.text = primaryContact['email'] ?? '';
    _primaryRelationship = primaryContact['relationship'];

    _secondaryNameController.text = secondaryContact['name'] ?? '';
    _secondaryPhoneController.text = secondaryContact['phone'] ?? '';
    _secondaryEmailController.text = secondaryContact['email'] ?? '';
    _secondaryRelationship = secondaryContact['relationship'];

    _allowContactSharing = widget.initialData['allowContactSharing'] ?? true;
    _emergencyNotifications =
        widget.initialData['emergencyNotifications'] ?? true;
  }

  void _updateData() {
    final data = {
      'primaryContact': {
        'name': _primaryNameController.text,
        'phone': _primaryPhoneController.text,
        'email': _primaryEmailController.text,
        'relationship': _primaryRelationship,
      },
      'secondaryContact': {
        'name': _secondaryNameController.text,
        'phone': _secondaryPhoneController.text,
        'email': _secondaryEmailController.text,
        'relationship': _secondaryRelationship,
      },
      'allowContactSharing': _allowContactSharing,
      'emergencyNotifications': _emergencyNotifications,
    };
    widget.onDataChanged(data);
  }

  @override
  void dispose() {
    _primaryNameController.dispose();
    _primaryPhoneController.dispose();
    _primaryEmailController.dispose();
    _secondaryNameController.dispose();
    _secondaryPhoneController.dispose();
    _secondaryEmailController.dispose();
    super.dispose();
  }

  Widget _buildContactSection({
    required String title,
    required String subtitle,
    required TextEditingController nameController,
    required TextEditingController phoneController,
    required TextEditingController emailController,
    required String? selectedRelationship,
    required Function(String?) onRelationshipChanged,
    required bool isRequired,
  }) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isRequired) ...[
                SizedBox(width: 2.w),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    color: AppTheme.warningLight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Required',
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.warningLight,
                      fontSize: 10.sp,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 0.5.h),
          Text(
            subtitle,
            style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryLight,
            ),
          ),
          SizedBox(height: 2.h),

          // Name Field
          TextFormField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              hintText: 'Enter contact person\'s name',
              prefixIcon: Padding(
                padding: EdgeInsets.all(3.w),
                child: CustomIconWidget(
                  iconName: 'person',
                  color: AppTheme.textSecondaryLight,
                  size: 5.w,
                ),
              ),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (isRequired && (value == null || value.isEmpty)) {
                return 'Name is required';
              }
              return null;
            },
            onChanged: (_) => _updateData(),
          ),
          SizedBox(height: 2.h),

          // Phone and Relationship Row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'Enter phone number',
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(3.w),
                      child: CustomIconWidget(
                        iconName: 'phone',
                        color: AppTheme.textSecondaryLight,
                        size: 5.w,
                      ),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (value) {
                    if (isRequired && (value == null || value.isEmpty)) {
                      return 'Phone is required';
                    }
                    if (value != null &&
                        value.isNotEmpty &&
                        value.length != 10) {
                      return 'Invalid phone number';
                    }
                    return null;
                  },
                  onChanged: (_) => _updateData(),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: selectedRelationship,
                  decoration: InputDecoration(
                    labelText: 'Relationship',
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(3.w),
                      child: CustomIconWidget(
                        iconName: 'family_restroom',
                        color: AppTheme.textSecondaryLight,
                        size: 5.w,
                      ),
                    ),
                  ),
                  items: _relationshipOptions.map((String relationship) {
                    return DropdownMenuItem<String>(
                      value: relationship,
                      child: Text(relationship),
                    );
                  }).toList(),
                  onChanged: onRelationshipChanged,
                  validator: (value) {
                    if (isRequired && (value == null || value.isEmpty)) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),

          // Email Field
          TextFormField(
            controller: emailController,
            decoration: InputDecoration(
              labelText: 'Email Address (Optional)',
              hintText: 'Enter email address',
              prefixIcon: Padding(
                padding: EdgeInsets.all(3.w),
                child: CustomIconWidget(
                  iconName: 'email',
                  color: AppTheme.textSecondaryLight,
                  size: 5.w,
                ),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}\$')
                    .hasMatch(value)) {
                  return 'Enter a valid email address';
                }
              }
              return null;
            },
            onChanged: (_) => _updateData(),
          ),
        ],
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
            'Emergency Contacts',
            style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.lightTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Provide emergency contact details for safety and verification purposes',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryLight,
            ),
          ),
          SizedBox(height: 3.h),

          // Primary Contact
          _buildContactSection(
            title: 'Primary Emergency Contact',
            subtitle: 'Main person to contact in case of emergency',
            nameController: _primaryNameController,
            phoneController: _primaryPhoneController,
            emailController: _primaryEmailController,
            selectedRelationship: _primaryRelationship,
            onRelationshipChanged: (value) {
              setState(() {
                _primaryRelationship = value;
              });
              _updateData();
            },
            isRequired: true,
          ),
          SizedBox(height: 3.h),

          // Secondary Contact
          _buildContactSection(
            title: 'Secondary Emergency Contact',
            subtitle: 'Alternative person to contact if primary is unavailable',
            nameController: _secondaryNameController,
            phoneController: _secondaryPhoneController,
            emailController: _secondaryEmailController,
            selectedRelationship: _secondaryRelationship,
            onRelationshipChanged: (value) {
              setState(() {
                _secondaryRelationship = value;
              });
              _updateData();
            },
            isRequired: false,
          ),
          SizedBox(height: 3.h),

          // Privacy Settings
          Text(
            'Privacy Settings',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),

          SwitchListTile(
            title: Text('Allow contact sharing'),
            subtitle: Text(
                'Property owners can contact your emergency contacts for verification'),
            value: _allowContactSharing,
            onChanged: (value) {
              setState(() {
                _allowContactSharing = value;
              });
              _updateData();
            },
            contentPadding: EdgeInsets.zero,
          ),

          SwitchListTile(
            title: Text('Emergency notifications'),
            subtitle: Text(
                'Send notifications to emergency contacts about your bookings'),
            value: _emergencyNotifications,
            onChanged: (value) {
              setState(() {
                _emergencyNotifications = value;
              });
              _updateData();
            },
            contentPadding: EdgeInsets.zero,
          ),
          SizedBox(height: 3.h),

          // Safety Information
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppTheme.successLight.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.successLight.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'shield',
                      color: AppTheme.successLight,
                      size: 5.w,
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      'Your Safety Matters',
                      style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.successLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  'Emergency contacts help ensure your safety and provide property owners with additional verification. This information is kept confidential and only used when necessary.',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.successLight,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),

          // Final Step Info
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppTheme.accentLight.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.accentLight.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'celebration',
                      color: AppTheme.accentLight,
                      size: 5.w,
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      'Almost Done!',
                      style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.accentLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  'You\'re just one step away from creating your account. Click "Create Account" to complete your registration and start finding your perfect accommodation.',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.accentLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
