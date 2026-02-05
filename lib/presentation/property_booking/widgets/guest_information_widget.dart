import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class GuestInformationWidget extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final Function(Map<String, dynamic>) onDataChanged;
  final VoidCallback onNext;

  const GuestInformationWidget({
    super.key,
    required this.bookingData,
    required this.onDataChanged,
    required this.onNext,
  });

  @override
  State<GuestInformationWidget> createState() => _GuestInformationWidgetState();
}

class _GuestInformationWidgetState extends State<GuestInformationWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _requestsController = TextEditingController();

  int _occupants = 1;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.bookingData["guestName"] ?? "";
    _emailController.text = widget.bookingData["guestEmail"] ?? "";
    _phoneController.text = widget.bookingData["guestPhone"] ?? "";
    _requestsController.text = widget.bookingData["specialRequests"] ?? "";
    _occupants = widget.bookingData["occupants"] ?? 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _requestsController.dispose();
    super.dispose();
  }

  void _updateData() {
    widget.onDataChanged({
      "guestName": _nameController.text,
      "guestEmail": _emailController.text,
      "guestPhone": _phoneController.text,
      "specialRequests": _requestsController.text,
      "occupants": _occupants,
    });
  }

  void _handleNext() {
    if (_formKey.currentState?.validate() ?? false) {
      _updateData();
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Guest Information',
              style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 1.h),

            Text(
              'Please provide details for the primary guest',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
            ),

            SizedBox(height: 3.h),

            // Guest Name
            _buildInputField(
              controller: _nameController,
              label: 'Full Name',
              hint: 'Enter your full name',
              icon: 'person',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your full name';
                }
                if (value.length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),

            SizedBox(height: 2.h),

            // Email
            _buildInputField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'Enter your email address',
              icon: 'email',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email address';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),

            SizedBox(height: 2.h),

            // Phone Number
            _buildInputField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: 'Enter your phone number',
              icon: 'phone',
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                if (!RegExp(r'^[0-9]{10}$')
                    .hasMatch(value.replaceAll(RegExp(r'[^\d]'), ''))) {
                  return 'Please enter a valid 10-digit phone number';
                }
                return null;
              },
            ),

            SizedBox(height: 3.h),

            // Number of Occupants
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.lightTheme.colorScheme.outline
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'group',
                        color: AppTheme.lightTheme.colorScheme.primary,
                        size: 20,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        'Number of Occupants',
                        style:
                            AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total occupants: $_occupants',
                        style: AppTheme.lightTheme.textTheme.bodyMedium,
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _occupants > 1
                                ? () {
                                    setState(() {
                                      _occupants--;
                                    });
                                  }
                                : null,
                            icon: CustomIconWidget(
                              iconName: 'remove_circle_outline',
                              color: _occupants > 1
                                  ? AppTheme.lightTheme.colorScheme.primary
                                  : AppTheme.lightTheme.colorScheme.outline,
                              size: 24,
                            ),
                          ),
                          Container(
                            width: 12.w,
                            height: 5.h,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppTheme.lightTheme.colorScheme.outline,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '$_occupants',
                                style: AppTheme.lightTheme.textTheme.titleMedium
                                    ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _occupants < 6
                                ? () {
                                    setState(() {
                                      _occupants++;
                                    });
                                  }
                                : null,
                            icon: CustomIconWidget(
                              iconName: 'add_circle_outline',
                              color: _occupants < 6
                                  ? AppTheme.lightTheme.colorScheme.primary
                                  : AppTheme.lightTheme.colorScheme.outline,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 3.h),

            // Special Requests
            _buildInputField(
              controller: _requestsController,
              label: 'Special Requests (Optional)',
              hint: 'Any special requirements or requests...',
              icon: 'note_add',
              maxLines: 4,
              isRequired: false,
            ),

            SizedBox(height: 4.h),

            // Continue Button
            SizedBox(
              width: double.infinity,
              height: 6.h,
              child: ElevatedButton(
                onPressed: _handleNext,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    CustomIconWidget(
                      iconName: 'arrow_forward',
                      color: AppTheme.lightTheme.colorScheme.onPrimary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool isRequired = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CustomIconWidget(
              iconName: icon,
              color: AppTheme.lightTheme.colorScheme.primary,
              size: 20,
            ),
            SizedBox(width: 2.w),
            Text(
              label,
              style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isRequired) ...[
              SizedBox(width: 1.w),
              Text(
                '*',
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          onChanged: (_) => _updateData(),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: icon,
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
