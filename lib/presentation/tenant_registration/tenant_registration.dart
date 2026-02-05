import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import './widgets/emergency_contact_widget.dart';
import './widgets/occupation_info_widget.dart';
import './widgets/personal_details_widget.dart';
import './widgets/preference_settings_widget.dart';

class TenantRegistration extends StatefulWidget {
  const TenantRegistration({super.key});

  @override
  State<TenantRegistration> createState() => _TenantRegistrationState();
}

class _TenantRegistrationState extends State<TenantRegistration>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  int _currentStep = 0;
  bool _isLoading = false;

  // Form data storage
  final Map<String, dynamic> _formData = {
    'personalDetails': <String, dynamic>{},
    'occupationInfo': <String, dynamic>{},
    'preferences': <String, dynamic>{},
    'emergencyContact': <String, dynamic>{},
  };

  // ⭐ NEW: Track validation state for each step
  final Map<int, bool> _stepValidation = {
    0: false, // Personal Details
    1: false, // Occupation Info
    2: false, // Preferences
    3: false, // Emergency Contact
  };

  final List<String> _stepTitles = [
    'Personal Details',
    'Occupation Info',
    'Preferences',
    'Emergency Contact',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ⭐ NEW: Validate current step before proceeding
  bool _validateCurrentStep() {
    final currentData = _formData[_getCurrentStepKey()];

    switch (_currentStep) {
      case 0: // Personal Details
        return _validatePersonalDetails(currentData);
      case 1: // Occupation Info
        return _validateOccupationInfo(currentData);
      case 2: // Preferences
        return _validatePreferences(currentData);
      case 3: // Emergency Contact
        return _validateEmergencyContact(currentData);
      default:
        return false;
    }
  }

  // ⭐ NEW: Get current step's data key
  String _getCurrentStepKey() {
    switch (_currentStep) {
      case 0:
        return 'personalDetails';
      case 1:
        return 'occupationInfo';
      case 2:
        return 'preferences';
      case 3:
        return 'emergencyContact';
      default:
        return '';
    }
  }

  // ⭐ NEW: Validation methods for each step
  bool _validatePersonalDetails(dynamic data) {
    if (data == null || data is! Map<String, dynamic>) {
      print('❌ Personal details validation failed: data is null or not a Map');
      return false;
    }

    print('🔍 Validating personal details: $data');

    // Check if at least some data exists
    if (data.isEmpty) {
      print('❌ Personal details validation failed: data is empty');
      return false;
    }

    // Basic validation - at least 3 fields should be filled
    final nonEmptyFields = data.values.where((v) =>
    v != null && v.toString().trim().isNotEmpty
    ).length;

    if (nonEmptyFields < 3) {
      print('❌ Personal details validation failed: only $nonEmptyFields fields filled');
      return false;
    }

    print('✅ Personal details validation passed');
    return true;
  }

  bool _validateOccupationInfo(dynamic data) {
    if (data == null || data is! Map<String, dynamic>) {
      print('❌ Occupation info validation failed: data is null or not a Map');
      return false;
    }

    print('🔍 Validating occupation info: $data');

    // Check if at least some data exists
    if (data.isEmpty) {
      print('❌ Occupation info validation failed: data is empty');
      return false;
    }

    // Basic validation - at least 2 fields should be filled
    final nonEmptyFields = data.values.where((v) =>
    v != null && v.toString().trim().isNotEmpty
    ).length;

    if (nonEmptyFields < 2) {
      print('❌ Occupation info validation failed: only $nonEmptyFields fields filled');
      return false;
    }

    print('✅ Occupation info validation passed');
    return true;
  }

  bool _validatePreferences(dynamic data) {
    if (data == null || data is! Map<String, dynamic>) {
      print('❌ Preferences validation failed: data is null or not a Map');
      return false;
    }

    print('🔍 Validating preferences: $data');

    // Check if at least some data exists
    if (data.isEmpty) {
      print('❌ Preferences validation failed: data is empty');
      return false;
    }

    // Basic validation - at least 2 fields should be filled
    final nonEmptyFields = data.values.where((v) =>
    v != null && v.toString().trim().isNotEmpty
    ).length;

    if (nonEmptyFields < 2) {
      print('❌ Preferences validation failed: only $nonEmptyFields fields filled');
      return false;
    }

    print('✅ Preferences validation passed');
    return true;
  }

  bool _validateEmergencyContact(dynamic data) {
    if (data == null || data is! Map<String, dynamic>) {
      print('❌ Emergency contact validation failed: data is null or not a Map');
      return false;
    }

    print('🔍 Validating emergency contact: $data');

    // Check if at least some data exists
    if (data.isEmpty) {
      print('❌ Emergency contact validation failed: data is empty');
      return false;
    }

    // Basic validation - at least 2 fields should be filled
    final nonEmptyFields = data.values.where((v) =>
    v != null && v.toString().trim().isNotEmpty
    ).length;

    if (nonEmptyFields < 2) {
      print('❌ Emergency contact validation failed: only $nonEmptyFields fields filled');
      return false;
    }

    print('✅ Emergency contact validation passed');
    return true;
  }

  // ⭐ UPDATED: Next step with validation
  void _nextStep() {
    // Validate current step
    if (!_validateCurrentStep()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all required fields correctly'),
          backgroundColor: AppTheme.warningLight,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Update validation state
    setState(() {
      _stepValidation[_currentStep] = true;
    });

    if (_currentStep < _stepTitles.length - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _updateFormData(String section, Map<String, dynamic> data) {
    setState(() {
      final currentData = _formData[section] as Map<String, dynamic>? ?? <String, dynamic>{};
      _formData[section] = Map<String, dynamic>.from({
        ...currentData,
        ...data,
      });
    });
    print('📝 Updated $section: ${_formData[section]}');
  }

  // ⭐ UPDATED: Submit with final validation
  Future<void> _submitRegistration() async {
    // Final validation check
    if (!_validateCurrentStep()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all required fields correctly'),
          backgroundColor: AppTheme.warningLight,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('🚀 Starting registration process...');
      print('📋 Form Data: $_formData');

      final authService = AuthService();

      final personalDetails = _formData['personalDetails'] as Map<String, dynamic>? ?? {};
      final email = personalDetails['email']?.toString() ?? '';
      final password = personalDetails['password']?.toString() ?? '';

      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password are required');
      }

      print('📧 Email: $email');
      print('🔐 Password: ${password.isNotEmpty ? "****" : "empty"}');

      final result = await authService.registerUser(
        userType: 'tenant',
        email: email,
        password: password,
        personalDetails: Map<String, dynamic>.from(_formData['personalDetails'] as Map? ?? {}),
        occupationInfo: Map<String, dynamic>.from(_formData['occupationInfo'] as Map? ?? {}),
        preferences: Map<String, dynamic>.from(_formData['preferences'] as Map? ?? {}),
        documents: <String, dynamic>{},
        emergencyContact: Map<String, dynamic>.from(_formData['emergencyContact'] as Map? ?? {}),
      );

      print('📊 Registration result: $result');

      if (result['success'] == true) {
        print('✅ Registration successful!');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registration successful! Welcome to RentOk!'),
              backgroundColor: AppTheme.successLight,
              duration: const Duration(seconds: 3),
            ),
          );

          await Future.delayed(const Duration(milliseconds: 500));

          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home-dashboard');
          }
        }
      } else {
        print('❌ Registration failed: ${result['message']}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Registration failed. Please try again.'),
              backgroundColor: AppTheme.warningLight,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌ Registration error: $e');
      print('❌ Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString()}'),
            backgroundColor: AppTheme.warningLight,
            duration: const Duration(seconds: 4),
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
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.lightTheme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
          onPressed: _previousStep,
          icon: CustomIconWidget(
            iconName: 'arrow_back',
            color: AppTheme.lightTheme.primaryColor,
            size: 24,
          ),
        )
            : IconButton(
          onPressed: () => Navigator.pop(context),
          icon: CustomIconWidget(
            iconName: 'close',
            color: AppTheme.lightTheme.primaryColor,
            size: 24,
          ),
        ),
        title: Text(
          'Create Account',
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            color: AppTheme.lightTheme.primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/login-screen'),
            child: Text(
              'Login',
              style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                color: AppTheme.lightTheme.primaryColor,
              ),
            ),
          ),
          SizedBox(width: 2.w),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Progress indicator
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Step ${_currentStep + 1} of ${_stepTitles.length}',
                          style:
                          AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryLight,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _stepTitles[_currentStep],
                          style: AppTheme.lightTheme.textTheme.labelLarge
                              ?.copyWith(
                            color: AppTheme.lightTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.h),
                    // ⭐ UPDATED: Progress indicator with step validation
                    Row(
                      children: List.generate(_stepTitles.length, (index) {
                        final isCompleted = _stepValidation[index] == true;
                        final isCurrent = index == _currentStep;

                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: EdgeInsets.only(right: index < _stepTitles.length - 1 ? 2.w : 0),
                            decoration: BoxDecoration(
                              color: isCompleted || isCurrent
                                  ? AppTheme.lightTheme.primaryColor
                                  : AppTheme.borderLight,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              // Document notice - show on last step
              if (_currentStep == _stepTitles.length - 1)
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.shade700,
                        size: 6.w,
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Document Upload Required',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                                SizedBox(width: 1.w),
                                Text(
                                  '*',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 1.h),
                            Text(
                              'After successful registration, you will need to upload your documents (ID proof, Address proof, etc.) from the Profile section to complete your account verification.',
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: Colors.orange.shade700,
                                height: 1.4,
                              ),
                            ),
                            SizedBox(height: 1.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 3.w,
                                vertical: 1.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.description,
                                    size: 4.w,
                                    color: Colors.orange.shade800,
                                  ),
                                  SizedBox(width: 2.w),
                                  Text(
                                    'Go to Profile → Upload Documents',
                                    style: TextStyle(
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Form content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    PersonalDetailsWidget(
                      onDataChanged: (data) =>
                          _updateFormData('personalDetails', data),
                      initialData: Map<String, dynamic>.from(_formData['personalDetails'] as Map? ?? {}),
                    ),
                    OccupationInfoWidget(
                      onDataChanged: (data) =>
                          _updateFormData('occupationInfo', data),
                      initialData: Map<String, dynamic>.from(_formData['occupationInfo'] as Map? ?? {}),
                    ),
                    PreferenceSettingsWidget(
                      onDataChanged: (data) =>
                          _updateFormData('preferences', data),
                      initialData: Map<String, dynamic>.from(_formData['preferences'] as Map? ?? {}),
                    ),
                    EmergencyContactWidget(
                      onDataChanged: (data) =>
                          _updateFormData('emergencyContact', data),
                      initialData: Map<String, dynamic>.from(_formData['emergencyContact'] as Map? ?? {}),
                    ),
                  ],
                ),
              ),

              // Bottom navigation
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: AppTheme.lightTheme.scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.borderLight,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previousStep,
                          child: Text('Previous'),
                        ),
                      ),
                    if (_currentStep > 0) SizedBox(width: 4.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : _currentStep == _stepTitles.length - 1
                            ? _submitRegistration
                            : _nextStep,
                        child: _isLoading
                            ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.lightTheme.colorScheme.onPrimary,
                            ),
                          ),
                        )
                            : Text(
                          _currentStep == _stepTitles.length - 1
                              ? 'Create Account'
                              : 'Next',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}