import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import '../../../theme/app_theme.dart';

class BankDetailsWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onNext;
  final VoidCallback onBack;
  final Map<String, dynamic>? initialData;

  const BankDetailsWidget({
    super.key,
    required this.onNext,
    required this.onBack,
    this.initialData,
  });

  @override
  State<BankDetailsWidget> createState() => _BankDetailsWidgetState();
}

class _BankDetailsWidgetState extends State<BankDetailsWidget> {
  final _formKey = GlobalKey<FormState>();
  final _accountHolderNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _confirmAccountNumberController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _branchNameController = TextEditingController();

  String _accountType = 'Savings';
  final List<String> _accountTypes = ['Savings', 'Current'];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _accountHolderNameController.text =
          widget.initialData!['accountHolderName'] ?? '';
      _accountNumberController.text = widget.initialData!['accountNumber'] ?? '';
      _confirmAccountNumberController.text =
          widget.initialData!['confirmAccountNumber'] ?? '';
      _ifscCodeController.text = widget.initialData!['ifscCode'] ?? '';
      _bankNameController.text = widget.initialData!['bankName'] ?? '';
      _branchNameController.text = widget.initialData!['branchName'] ?? '';
      _accountType = widget.initialData!['accountType'] ?? 'Savings';
    }
  }

  @override
  void dispose() {
    _accountHolderNameController.dispose();
    _accountNumberController.dispose();
    _confirmAccountNumberController.dispose();
    _ifscCodeController.dispose();
    _bankNameController.dispose();
    _branchNameController.dispose();
    super.dispose();
  }

  void _handleNext() {
    if (_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();

      final data = {
        'accountHolderName': _accountHolderNameController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'confirmAccountNumber': _confirmAccountNumberController.text.trim(),
        'ifscCode': _ifscCodeController.text.trim().toUpperCase(),
        'bankName': _bankNameController.text.trim(),
        'branchName': _branchNameController.text.trim(),
        'accountType': _accountType,
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
              'Bank Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.lightTheme.primaryColor,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'For receiving rental payments',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 3.h),

            // Account Holder Name
            _buildTextField(
              controller: _accountHolderNameController,
              label: 'Account Holder Name',
              hint: 'As per bank records',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter account holder name';
                }
                return null;
              },
            ),
            SizedBox(height: 2.h),

            // Account Type
            _buildDropdownField(
              label: 'Account Type',
              value: _accountType,
              items: _accountTypes,
              icon: Icons.account_balance_outlined,
              onChanged: (value) {
                setState(() {
                  _accountType = value!;
                });
              },
            ),
            SizedBox(height: 2.h),

            // Account Number
            _buildTextField(
              controller: _accountNumberController,
              label: 'Account Number',
              hint: 'Enter your account number',
              icon: Icons.numbers_outlined,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter account number';
                }
                if (value.trim().length < 9 || value.trim().length > 18) {
                  return 'Invalid account number';
                }
                return null;
              },
            ),
            SizedBox(height: 2.h),

            // Confirm Account Number
            _buildTextField(
              controller: _confirmAccountNumberController,
              label: 'Confirm Account Number',
              hint: 'Re-enter your account number',
              icon: Icons.numbers_outlined,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please confirm account number';
                }
                if (value.trim() != _accountNumberController.text.trim()) {
                  return 'Account numbers do not match';
                }
                return null;
              },
            ),
            SizedBox(height: 2.h),

            // IFSC Code
            _buildTextField(
              controller: _ifscCodeController,
              label: 'IFSC Code',
              hint: 'e.g., SBIN0001234',
              icon: Icons.code_outlined,
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter IFSC code';
                }
                if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$')
                    .hasMatch(value.toUpperCase())) {
                  return 'Please enter a valid IFSC code';
                }
                return null;
              },
            ),
            SizedBox(height: 2.h),

            // Bank Name
            _buildTextField(
              controller: _bankNameController,
              label: 'Bank Name',
              hint: 'e.g., State Bank of India',
              icon: Icons.account_balance_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter bank name';
                }
                return null;
              },
            ),
            SizedBox(height: 2.h),

            // Branch Name
            _buildTextField(
              controller: _branchNameController,
              label: 'Branch Name',
              hint: 'e.g., Connaught Place',
              icon: Icons.location_on_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter branch name';
                }
                return null;
              },
            ),

            SizedBox(height: 3.h),

            // Security Note
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.green[700], size: 24),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Text(
                      'Your bank details are encrypted and secure. They will only be used for payment processing.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[900],
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