import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart'; // Add this import
import 'widgets/personal_info_widget.dart';
import 'widgets/business_details_widget.dart';
import 'widgets/address_input_widget.dart';
import 'widgets/document_upload_widget.dart';
import 'widgets/bank_details_widget.dart';
import 'widgets/terms_acceptance_widget.dart';

class PropertyOwnerRegistration extends StatefulWidget {
  const PropertyOwnerRegistration({super.key});

  @override
  State<PropertyOwnerRegistration> createState() =>
      _PropertyOwnerRegistrationState();
}

class _PropertyOwnerRegistrationState extends State<PropertyOwnerRegistration> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Add AuthService
  final AuthService _authService = AuthService();

  // Form data storage
  final Map<String, dynamic> _formData = {
    'personalInfo': {},
    'businessDetails': {},
    'address': {},
    'documents': {},
    'bankDetails': {},
    'termsAccepted': false,
  };

  final List<String> _stepTitles = [
    'Personal Info',
    'Business Details',
    'Address',
    'Documents',
    'Bank Details',
    'Terms & Conditions',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 5) {
      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      HapticFeedback.selectionClick();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      HapticFeedback.selectionClick();
    }
  }

  void _updateFormData(String section, dynamic data) {
    setState(() {
      // Convert Map<dynamic, dynamic> to Map<String, dynamic>
      if (data is Map) {
        _formData[section] = Map<String, dynamic>.from(data);
      } else {
        _formData[section] = data;
      }
    });
  }

  Future<void> _submitRegistration() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Debug: Print all form data
      print('📋 Complete Form Data:');
      print('Personal Info: ${_formData['personalInfo']}');
      print('Business Details: ${_formData['businessDetails']}');
      print('Address: ${_formData['address']}');
      print('Documents: ${_formData['documents']}');
      print('Bank Details: ${_formData['bankDetails']}');
      print('Terms: ${_formData['termsAccepted']}');

      // Validate that all required data is present
      if (_formData['personalInfo'] == null || 
          (_formData['personalInfo'] as Map).isEmpty) {
        throw Exception('Personal information is required. Please go back and fill the first step.');
      }

      // Convert to proper type with type safety
      final personalInfo = Map<String, dynamic>.from(_formData['personalInfo'] as Map);

      // Check for email and password with detailed error
      if (personalInfo['email'] == null || personalInfo['email'].toString().trim().isEmpty) {
        throw Exception('Email is required. Please check the Personal Info step.');
      }

      if (personalInfo['password'] == null || personalInfo['password'].toString().trim().isEmpty) {
        throw Exception('Password is required. Please check the Personal Info step.');
      }

      if (personalInfo['fullName'] == null || personalInfo['fullName'].toString().trim().isEmpty) {
        throw Exception('Full name is required. Please check the Personal Info step.');
      }

      // Prepare registration data with proper type conversion
      final registrationData = {
        'userType': 'owner',
        'email': personalInfo['email'].toString().trim(),
        'password': personalInfo['password'].toString(),
        'personalDetails': {
          'fullName': personalInfo['fullName'] ?? '',
          'phone': personalInfo['phone'] ?? '',
          'dateOfBirth': personalInfo['dateOfBirth'] ?? '',
        },
        'businessDetails': _formData['businessDetails'] != null 
            ? Map<String, dynamic>.from(_formData['businessDetails'] as Map)
            : {},
        'address': _formData['address'] != null
            ? Map<String, dynamic>.from(_formData['address'] as Map)
            : {},
        'documents': _formData['documents'] != null
            ? Map<String, dynamic>.from(_formData['documents'] as Map)
            : {},
        'bankDetails': _formData['bankDetails'] != null
            ? Map<String, dynamic>.from(_formData['bankDetails'] as Map)
            : {},
        'termsAccepted': (_formData['termsAccepted'] != null && _formData['termsAccepted'] is Map)
            ? (Map<String, dynamic>.from(_formData['termsAccepted'] as Map)['accepted'] ?? false)
            : false,
      };

      print('✅ Submitting registration for: ${registrationData['email']}');

      // Call the registration API
      final result = await _authService.registerOwner(registrationData);

      print('📬 Registration Result: $result');

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registration successful! Please login to continue.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Navigate back to login screen
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login-screen',
            (route) => false,
          );
        } else {
          throw Exception(result['message'] ?? 'Registration failed');
        }
      }
    } catch (e, stackTrace) {
      print('❌ Registration Error: $e');
      print('Stack Trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Owner Registration'),
        backgroundColor: AppTheme.lightTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Progress Indicator
          _buildProgressIndicator(),

          // Step Content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: NeverScrollableScrollPhysics(),
              children: [
                PersonalInfoWidget(
                  onNext: (data) {
                    _updateFormData('personalInfo', data);
                    _nextStep();
                  },
                  initialData: _formData['personalInfo'] != null 
                      ? Map<String, dynamic>.from(_formData['personalInfo'] as Map)
                      : null,
                ),
                BusinessDetailsWidget(
                  onNext: (data) {
                    _updateFormData('businessDetails', data);
                    _nextStep();
                  },
                  onBack: _previousStep,
                  initialData: _formData['businessDetails'] != null
                      ? Map<String, dynamic>.from(_formData['businessDetails'] as Map)
                      : null,
                ),
                AddressInputWidget(
                  onNext: (data) {
                    _updateFormData('address', data);
                    _nextStep();
                  },
                  onBack: _previousStep,
                  initialData: _formData['address'] != null
                      ? Map<String, dynamic>.from(_formData['address'] as Map)
                      : null,
                ),
                DocumentUploadWidget(
                  onNext: (data) {
                    _updateFormData('documents', data);
                    _nextStep();
                  },
                  onBack: _previousStep,
                  initialData: _formData['documents'] != null
                      ? Map<String, dynamic>.from(_formData['documents'] as Map)
                      : null,
                ),
                BankDetailsWidget(
                  onNext: (data) {
                    _updateFormData('bankDetails', data);
                    _nextStep();
                  },
                  onBack: _previousStep,
                  initialData: _formData['bankDetails'] != null
                      ? Map<String, dynamic>.from(_formData['bankDetails'] as Map)
                      : null,
                ),
                TermsAcceptanceWidget(
                  onSubmit: (accepted) {
                    _updateFormData('termsAccepted', {'accepted': accepted});
                    _submitRegistration();
                  },
                  onBack: _previousStep,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Step indicators
          Row(
            children: List.generate(_stepTitles.length, (index) {
              final isCompleted = index < _currentStep;
              final isCurrent = index == _currentStep;

              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCompleted || isCurrent
                                  ? AppTheme.lightTheme.primaryColor
                                  : Colors.grey[300],
                            ),
                            child: Center(
                              child: isCompleted
                                  ? Icon(Icons.check,
                                      color: Colors.white, size: 18)
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: isCurrent
                                            ? Colors.white
                                            : Colors.grey[600],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            _stepTitles[index],
                            style: TextStyle(
                              fontSize: 10,
                              color: isCurrent
                                  ? AppTheme.lightTheme.primaryColor
                                  : Colors.grey[600],
                              fontWeight:
                                  isCurrent ? FontWeight.w600 : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    if (index < _stepTitles.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: EdgeInsets.only(bottom: 3.h),
                          color: isCompleted
                              ? AppTheme.lightTheme.primaryColor
                              : Colors.grey[300],
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}