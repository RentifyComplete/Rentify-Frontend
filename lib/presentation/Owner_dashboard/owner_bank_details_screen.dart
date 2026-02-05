// owner_bank_details_screen.dart - COMPLETE FINAL VERSION
// Shows saved bank details with IFSC code and allows editing

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/app_export.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';

class OwnerBankDetailsScreen extends StatefulWidget {
  const OwnerBankDetailsScreen({super.key});

  @override
  State<OwnerBankDetailsScreen> createState() => _OwnerBankDetailsScreenState();
}

class _OwnerBankDetailsScreenState extends State<OwnerBankDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final String baseUrl = 'https://rentify-backend-cdaj.onrender.com';

  // Controllers
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _confirmAccountController = TextEditingController();
  final TextEditingController _ifscController = TextEditingController();
  final TextEditingController _accountHolderNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _isCheckingExisting = true;
  bool _obscureAccount = true;
  bool _obscureConfirm = true;
  bool _hasExistingDetails = false;
  bool _isEditMode = false;
  String? _errorMessage;

  Map<String, dynamic>? _existingBankDetails;

  @override
  void initState() {
    super.initState();
    _loadBankDetails();
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _confirmAccountController.dispose();
    _ifscController.dispose();
    _accountHolderNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadBankDetails() async {
    setState(() {
      _isCheckingExisting = true;
      _errorMessage = null;
    });

    try {
      final currentUserId = await _authService.getCurrentUserId();

      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('User not logged in');
      }

      print('🏦 ==================== LOADING BANK DETAILS ====================');
      print('Owner ID: $currentUserId');

      final response = await http.get(
        Uri.parse('$baseUrl/api/payments/bank-details/$currentUserId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _existingBankDetails = data['data'];
            _hasExistingDetails = true;
            _isEditMode = false;
          });
          print('✅ Loaded IFSC Code: ${_existingBankDetails!['ifscCode']}');
          print('✅ Existing bank details loaded');
        } else {
          setState(() {
            _hasExistingDetails = false;
            _isEditMode = true;
          });
          _loadUserDataForNewEntry();
          print('ℹ️ No existing bank details found');
        }
      } else if (response.statusCode == 404) {
        setState(() {
          _hasExistingDetails = false;
          _isEditMode = true;
        });
        _loadUserDataForNewEntry();
        print('ℹ️ No bank details - ready to add new');
      } else {
        throw Exception('Failed to load bank details');
      }

      print('🏦 ==================== END LOADING ====================\n');
    } catch (e) {
      print('❌ Error loading bank details: $e');
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _hasExistingDetails = false;
        _isEditMode = true;
      });
      _loadUserDataForNewEntry();
    } finally {
      setState(() {
        _isCheckingExisting = false;
      });
    }
  }

  Future<void> _loadUserDataForNewEntry() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      print('📱 Loading user data for new entry');
      print('User Phone: "${userProvider.userPhone}"');

      if (userProvider.userPhone.isNotEmpty) {
        _phoneController.text = userProvider.userPhone;
        print('✅ Pre-filled phone: "${_phoneController.text}"');
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
    }
  }

  void _enterEditMode() {
    setState(() {
      _isEditMode = true;

      if (_existingBankDetails != null) {
        _accountHolderNameController.text = _existingBankDetails!['accountHolderName'] ?? '';
        _ifscController.text = _existingBankDetails!['ifscCode'] ?? '';
        
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        if (userProvider.userPhone.isNotEmpty) {
          _phoneController.text = userProvider.userPhone;
        }
        
        print('✅ Pre-filled IFSC for editing: ${_ifscController.text}');
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditMode = false;
      _accountNumberController.clear();
      _confirmAccountController.clear();
      _accountHolderNameController.clear();
      _ifscController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _submitBankDetails() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill all required fields correctly', Colors.red);
      return;
    }

    if (_accountNumberController.text != _confirmAccountController.text) {
      _showSnackBar('Account numbers do not match', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = await _authService.getCurrentUserId();

      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('User not logged in');
      }

      final email = userProvider.userEmail;
      if (email.isEmpty) {
        throw Exception('Email is required. Please update your profile.');
      }

      final phoneFromController = _phoneController.text.trim();
      String cleanPhone = phoneFromController
          .replaceAll('+91', '')
          .replaceAll(' ', '')
          .trim();

      if (cleanPhone.isEmpty || cleanPhone.length != 10) {
        throw Exception('Please enter a valid 10-digit phone number');
      }

      final ifscCode = _ifscController.text.trim().toUpperCase();

      print('🏦 ==================== SUBMITTING BANK DETAILS ====================');
      print('Owner ID: $currentUserId');
      print('Owner Email: $email');
      print('Owner Phone: "$cleanPhone"');
      print('✅ IFSC Code: "$ifscCode"');

      final requestBody = {
        'ownerId': currentUserId,
        'email': email,
        'phone': cleanPhone,
        'accountHolderName': _accountHolderNameController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'ifscCode': ifscCode,
        'bankName': '',
        'branchName': '',
      };

      print('📤 Request Body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/payments/bank-details'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          print('✅ SUCCESS! Bank details saved');
          
          if (data['data'] != null) {
            print('✅ Saved IFSC Code: ${data['data']['ifscCode']}');
          }

          await _loadBankDetails();

          if (mounted) {
            _showSuccessDialog(_hasExistingDetails ? 'Updated' : 'Saved');
          }
        } else {
          throw Exception(data['message'] ?? 'Failed to save bank details');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ ERROR: $e');
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });

      if (mounted) {
        _showSnackBar(_errorMessage ?? 'Unknown error occurred', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog(String action) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 15.w,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                'Bank Details $action!',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                'Your bank account has been ${action.toLowerCase()} successfully.',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 3.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    padding: EdgeInsets.symmetric(vertical: 1.8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
  }

  String? _validateIFSC(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter IFSC code';
    }

    final ifsc = value.trim().toUpperCase();
    final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');

    if (!ifscRegex.hasMatch(ifsc)) {
      return 'Invalid IFSC code format (e.g., SBIN0001234)';
    }

    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter phone number';
    }

    final phone = value.trim().replaceAll('+91', '').replaceAll(' ', '');

    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      return 'Invalid phone number';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.primaryLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _hasExistingDetails && !_isEditMode ? 'Bank Details' :
          _hasExistingDetails ? 'Edit Bank Details' : 'Add Bank Details',
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_hasExistingDetails && !_isEditMode)
            IconButton(
              icon: Icon(Icons.edit, color: AppTheme.primaryLight),
              onPressed: _enterEditMode,
              tooltip: 'Edit',
            ),
        ],
      ),
      body: _isCheckingExisting
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : _hasExistingDetails && !_isEditMode
          ? _buildViewMode()
          : _buildEditMode(),
    );
  }

  Widget _buildViewMode() {
    if (_existingBankDetails == null) return SizedBox();

    final accountNumber = _existingBankDetails!['accountNumber'] ?? '';
    final ifscCode = _existingBankDetails!['ifscCode'] ?? 'N/A';
    final hasAutoTransfer = _existingBankDetails!['autoTransferEnabled'] == true;

    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 8.w),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bank Account Linked',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        hasAutoTransfer
                            ? 'Auto-transfer enabled for tenant payments'
                            : 'Account details saved successfully',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 3.h),

          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  'Account Holder Name',
                  _existingBankDetails!['accountHolderName'] ?? 'N/A',
                  Icons.person,
                ),
                Divider(height: 3.h),
                _buildDetailRow(
                  'Account Number',
                  accountNumber,
                  Icons.account_balance,
                ),
                Divider(height: 3.h),
                _buildDetailRow(
                  'IFSC Code',
                  ifscCode,
                  Icons.code,
                  isHighlighted: true,
                ),
                if (_existingBankDetails!['bankName'] != null &&
                    _existingBankDetails!['bankName'].toString().isNotEmpty) ...[
                  Divider(height: 3.h),
                  _buildDetailRow(
                    'Bank Name',
                    _existingBankDetails!['bankName'],
                    Icons.account_balance_outlined,
                  ),
                ],
                if (_existingBankDetails!['verifiedAt'] != null) ...[
                  Divider(height: 3.h),
                  _buildDetailRow(
                    'Verified On',
                    _formatDate(_existingBankDetails!['verifiedAt']),
                    Icons.verified,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 3.h),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _enterEditMode,
              icon: Icon(Icons.edit, size: 5.w),
              label: Text(
                'Edit Bank Details',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryLight,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 2.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {bool isHighlighted = false}) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(2.w),
          decoration: BoxDecoration(
            color: isHighlighted 
                ? Colors.blue.shade50 
                : AppTheme.primaryLight.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon, 
            color: isHighlighted ? Colors.blue.shade700 : AppTheme.primaryLight, 
            size: 5.w
          ),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.sp,
                  color: Colors.grey.shade600,
                  fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              SizedBox(height: 0.5.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: isHighlighted ? 12.sp : 11.sp,
                  fontWeight: FontWeight.w600,
                  color: isHighlighted ? Colors.blue.shade900 : Colors.grey.shade900,
                  letterSpacing: isHighlighted ? 1.2 : 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildEditMode() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: EdgeInsets.all(3.w),
                margin: EdgeInsets.only(bottom: 2.h),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 5.w),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 9.sp, color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_hasExistingDetails) ...[
              Container(
                padding: EdgeInsets.all(3.w),
                margin: EdgeInsets.only(bottom: 2.h),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 5.w),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        'Enter your account number again to update details',
                        style: TextStyle(fontSize: 9.sp, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Text('Account Holder Name *',
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            SizedBox(height: 1.h),
            TextFormField(
              controller: _accountHolderNameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Enter name as per bank account',
                prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryLight),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Please enter account holder name';
                if (value.trim().length < 3) return 'Name must be at least 3 characters';
                return null;
              },
            ),
            SizedBox(height: 2.h),

            Text('Phone Number *',
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            SizedBox(height: 1.h),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                hintText: 'Enter 10-digit mobile number',
                prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.primaryLight),
                prefixText: '+91 ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
                ),
              ),
              validator: _validatePhone,
            ),
            SizedBox(height: 2.h),

            Text('Account Number *',
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            SizedBox(height: 1.h),
            TextFormField(
              controller: _accountNumberController,
              keyboardType: TextInputType.number,
              obscureText: _obscureAccount,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(18),
              ],
              decoration: InputDecoration(
                hintText: 'Enter account number',
                prefixIcon: Icon(Icons.account_balance, color: AppTheme.primaryLight),
                suffixIcon: IconButton(
                  icon: Icon(_obscureAccount ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureAccount = !_obscureAccount),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Please enter account number';
                if (value.trim().length < 9) return 'Account number too short';
                return null;
              },
            ),
            SizedBox(height: 2.h),

            Text('Confirm Account Number *',
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            SizedBox(height: 1.h),
            TextFormField(
              controller: _confirmAccountController,
              keyboardType: TextInputType.number,
              obscureText: _obscureConfirm,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(18),
              ],
              decoration: InputDecoration(
                hintText: 'Re-enter account number',
                prefixIcon: Icon(Icons.account_balance_outlined, color: AppTheme.primaryLight),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Please confirm account number';
                if (value != _accountNumberController.text) return 'Account numbers do not match';
                return null;
              },
            ),
            SizedBox(height: 2.h),

            Text('IFSC Code *',
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            SizedBox(height: 0.5.h),
            Text(
              'Find your IFSC code on your bank passbook or cheque',
              style: TextStyle(
                fontSize: 9.sp,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 1.h),
            TextFormField(
              controller: _ifscController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: InputDecoration(
                hintText: 'e.g., SBIN0001234',
                prefixIcon: Icon(Icons.code, color: AppTheme.primaryLight),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
                ),
              ),
              validator: _validateIFSC,
            ),
            SizedBox(height: 4.h),

            Row(
              children: [
                if (_hasExistingDetails) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _cancelEdit,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 2.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: AppTheme.primaryLight),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryLight,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 3.w),
                ],
                Expanded(
                  flex: _hasExistingDetails ? 1 : 1,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitBankDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryLight,
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? SizedBox(
                      height: 2.5.h,
                      width: 2.5.h,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                        : Text(
                      _hasExistingDetails ? 'Update Details' : 'Save Bank Details',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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
}