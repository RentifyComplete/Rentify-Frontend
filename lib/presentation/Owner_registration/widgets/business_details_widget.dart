import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import '../../../theme/app_theme.dart';

class BusinessDetailsWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onNext;
  final VoidCallback onBack;
  final Map<String, dynamic>? initialData;

  const BusinessDetailsWidget({
    super.key,
    required this.onNext,
    required this.onBack,
    this.initialData,
  });

  @override
  State<BusinessDetailsWidget> createState() => _BusinessDetailsWidgetState();
}

class _BusinessDetailsWidgetState extends State<BusinessDetailsWidget> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _gstNumberController = TextEditingController();
  final _panNumberController = TextEditingController();
  final _yearsInBusinessController = TextEditingController();
  final _totalPropertiesController = TextEditingController();

  String _businessType = 'Individual';
  final List<String> _businessTypes = [
    'Individual',
    'Sole Proprietorship',
    'Partnership',
    'Private Limited',
    'Limited Liability Partnership (LLP)',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _companyNameController.text = widget.initialData!['companyName'] ?? '';
      _gstNumberController.text = widget.initialData!['gstNumber'] ?? '';
      _panNumberController.text = widget.initialData!['panNumber'] ?? '';
      _yearsInBusinessController.text = widget.initialData!['yearsInBusiness'] ?? '';
      _totalPropertiesController.text = widget.initialData!['totalProperties'] ?? '';
      _businessType = widget.initialData!['businessType'] ?? 'Individual';
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _gstNumberController.dispose();
    _panNumberController.dispose();
    _yearsInBusinessController.dispose();
    _totalPropertiesController.dispose();
    super.dispose();
  }

  void _handleNext() {
    if (_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      
      final data = {
        'businessType': _businessType,
        'companyName': _companyNameController.text.trim(),
        'gstNumber': _gstNumberController.text.trim().toUpperCase(),
        'panNumber': _panNumberController.text.trim().toUpperCase(),
        'yearsInBusiness': _yearsInBusinessController.text.trim(),
        'totalProperties': _totalPropertiesController.text.trim(),
      };

      widget.onNext(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(6.w),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Business Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.lightTheme.primaryColor,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Tell us about your property business',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 3.h),

            // Business Type Dropdown
            _buildDropdownField(
              label: 'Business Type',
              value: _businessType,
              items: _businessTypes,
              icon: Icons.business_center_outlined,
              onChanged: (value) {
                setState(() {
                  _businessType = value!;
                });
              },
            ),
            SizedBox(height: 2.h),

            // Company/Business Name
            _buildTextField(
              controller: _companyNameController,
              label: 'Company/Business Name',
              hint: 'Enter your company or business name',
              icon: Icons.apartment_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your business name';
                }
                return null;
              },
            ),
            SizedBox(height: 2.h),

            // GST Number (Optional)
            _buildTextField(
              controller: _gstNumberController,
              label: 'GST Number (Optional)',
              hint: '22AAAAA0000A1Z5',
              icon: Icons.receipt_long_outlined,
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}[Z]{1}[A-Z\d]{1}$')
                      .hasMatch(value.toUpperCase())) {
                    return 'Please enter a valid GST number';
                  }
                }
                return null;
              },
            ),
            SizedBox(height: 2.h),

            // PAN Number
            _buildTextField(
              controller: _panNumberController,
              label: 'PAN Number',
              hint: 'ABCDE1234F',
              icon: Icons.credit_card_outlined,
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your PAN number';
                }
                if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$')
                    .hasMatch(value.toUpperCase())) {
                  return 'Please enter a valid PAN number';
                }
                return null;
              },
            ),
            SizedBox(height: 2.h),

            // Years in Business
            _buildTextField(
              controller: _yearsInBusinessController,
              label: 'Years in Property Business',
              hint: 'e.g., 5',
              icon: Icons.trending_up_outlined,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter years of experience';
                }
                final years = int.tryParse(value);
                if (years == null || years < 0) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            SizedBox(height: 2.h),

            // Total Properties
            _buildTextField(
              controller: _totalPropertiesController,
              label: 'Total Properties Owned',
              hint: 'e.g., 10',
              icon: Icons.home_work_outlined,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter number of properties';
                }
                final properties = int.tryParse(value);
                if (properties == null || properties < 1) {
                  return 'Please enter at least 1 property';
                }
                return null;
              },
            ),

            SizedBox(height: 4.h),

            // Navigation Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onBack,
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
                    onPressed: _handleNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.lightTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(icon, color: AppTheme.lightTheme.primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.lightTheme.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 1.h),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppTheme.lightTheme.primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.lightTheme.primaryColor,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}