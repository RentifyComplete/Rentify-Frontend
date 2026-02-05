import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import '../../../theme/app_theme.dart';

class AddressInputWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onNext;
  final VoidCallback onBack;
  final Map<String, dynamic>? initialData;

  const AddressInputWidget({
    super.key,
    required this.onNext,
    required this.onBack,
    this.initialData,
  });

  @override
  State<AddressInputWidget> createState() => _AddressInputWidgetState();
}

class _AddressInputWidgetState extends State<AddressInputWidget> {
  final _formKey = GlobalKey<FormState>();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _landmarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _addressLine1Controller.text = widget.initialData!['addressLine1'] ?? '';
      _addressLine2Controller.text = widget.initialData!['addressLine2'] ?? '';
      _cityController.text = widget.initialData!['city'] ?? '';
      _stateController.text = widget.initialData!['state'] ?? '';
      _pincodeController.text = widget.initialData!['pincode'] ?? '';
      _landmarkController.text = widget.initialData!['landmark'] ?? '';
    }
  }

  @override
  void dispose() {
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  void _handleNext() {
    if (_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      
      final data = {
        'addressLine1': _addressLine1Controller.text.trim(),
        'addressLine2': _addressLine2Controller.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'landmark': _landmarkController.text.trim(),
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
              'Address Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.lightTheme.primaryColor,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Where can we reach you?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 3.h),

            // Address Line 1
            _buildTextField(
              controller: _addressLine1Controller,
              label: 'Address Line 1',
              hint: 'House/Flat No., Building Name',
              icon: Icons.location_on_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter address line 1';
                }
                return null;
              },
            ),
            SizedBox(height: 2.h),

            // Address Line 2
            _buildTextField(
              controller: _addressLine2Controller,
              label: 'Address Line 2',
              hint: 'Street, Area, Colony',
              icon: Icons.location_city_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter address line 2';
                }
                return null;
              },
            ),
            SizedBox(height: 2.h),

            // Landmark (Optional)
            _buildTextField(
              controller: _landmarkController,
              label: 'Landmark (Optional)',
              hint: 'Near a famous place',
              icon: Icons.place_outlined,
            ),
            SizedBox(height: 2.h),

            // City and State Row
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _cityController,
                    label: 'City',
                    hint: 'Your city',
                    icon: Icons.location_city,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter city';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: _buildTextField(
                    controller: _stateController,
                    label: 'State',
                    hint: 'Your state',
                    icon: Icons.map_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter state';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),

            // Pincode
            _buildTextField(
              controller: _pincodeController,
              label: 'Pincode',
              hint: '123456',
              icon: Icons.pin_outlined,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter pincode';
                }
                if (value.trim().length != 6) {
                  return 'Pincode must be 6 digits';
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
}