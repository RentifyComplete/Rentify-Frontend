// lib/routes/app_routes.dart

import 'package:flutter/material.dart';
import '../core/app_export.dart';
import '../presentation/login_screen/login_screen.dart';
import '../presentation/login_screen/forgot_password_screen.dart';
import '../presentation/home_dashboard/home_dashboard.dart';
import '../presentation/owner_dashboard/owner_dashboard.dart';
import '../presentation/property_details/property_details.dart';
import '../presentation/tenant_registration/tenant_registration.dart';
import '../presentation/property_booking/property_booking.dart';
import '../presentation/Owner_registration/property_owner_registration.dart';
import '../presentation/add_property/add_property_screen.dart';
// Import the new screens
import '../presentation/home_dashboard/widgets/saved_searches_screen.dart';
import '../presentation/home_dashboard/widgets/payment_due_screen.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class AppRoutes {
  // Route constants
  static const String initial = '/';
  static const String loginScreen = '/login-screen';
  static const String forgotPassword = '/forgot-password';
  static const String homeDashboard = '/home-dashboard';
  static const String ownerDashboard = '/owner-dashboard';
  static const String propertyDetails = '/property-details';
  static const String tenantRegistration = '/tenant-registration';
  static const String propertyBooking = '/property-booking';
  static const String propertyOwnerRegistration = '/property-owner-registration';
  static const String tenantDashboard = '/tenant-dashboard';
  static const String addProperty = '/add-property';

  // Quick Actions Routes
  static const String savedSearches = '/saved-searches';
  static const String payments = '/payments';
  static const String addTenant = '/add-tenant';
  static const String receivePayment = '/receive-payment';
  static const String addExpense = '/add-expense';
  static const String addDues = '/add-dues';
  static const String sendAnnouncement = '/send-announcement';
  static const String addTeamTenant = '/add-team-tenant';
  static const String addBankAccount = '/add-bank-account';
  static const String agreementSettings = '/agreement-settings';

  // Tenant Dashboard sub-routes (placeholders)
  static const String tenantPayments = '/tenant-payments';
  static const String tenantPayRent = '/tenant-pay-rent';
  static const String tenantPaymentHistory = '/tenant-payment-history';
  static const String tenantMaintenance = '/tenant-maintenance';
  static const String tenantNewMaintenance = '/tenant-new-maintenance';
  static const String tenantDocuments = '/tenant-documents';
  static const String tenantNotices = '/tenant-notices';
  static const String tenantChat = '/tenant-chat';
  static const String tenantHelp = '/tenant-help';
  static const String tenantNotifications = '/tenant-notifications';
  static const String tenantSettings = '/tenant-settings';
  static const String tenantProfileEdit = '/tenant-profile-edit';

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => LoginScreen(),
    loginScreen: (context) => LoginScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(),
    homeDashboard: (context) => const HomeDashboard(),
    ownerDashboard: (context) => OwnerDashboardScreen(),
    propertyDetails: (context) => PropertyDetails(),
    tenantRegistration: (context) => const TenantRegistration(),
    propertyOwnerRegistration: (context) => const PropertyOwnerRegistration(),
    propertyBooking: (context) => PropertyBookingScreen(),
    addProperty: (context) => const AddPropertyScreen(),

    // Quick Actions Routes - Now with actual screens
    savedSearches: (context) => const SavedSearchesScreen(),
    payments: (context) => const PaymentDueScreen(),
    addTenant: (context) => _PlaceholderScreen(title: 'Add Tenant'),
    receivePayment: (context) => _PlaceholderScreen(title: 'Receive Payment'),
    addExpense: (context) => _PlaceholderScreen(title: 'Add Expense'),
    addDues: (context) => _PlaceholderScreen(title: 'Add Dues'),
    sendAnnouncement: (context) => _PlaceholderScreen(title: 'Send Announcement'),
    addTeamTenant: (context) => _PlaceholderScreen(title: 'Add Team Tenant'),
    addBankAccount: (context) => _PlaceholderScreen(title: 'Add Bank Account'),
    agreementSettings: (context) => _PlaceholderScreen(title: 'Agreement Settings'),

    // Placeholder routes for tenant dashboard features
    tenantPayments: (context) => _PlaceholderScreen(title: 'Payments'),
    tenantPayRent: (context) => _PlaceholderScreen(title: 'Pay Rent'),
    tenantPaymentHistory: (context) => _PlaceholderScreen(title: 'Payment History'),
    tenantMaintenance: (context) => _PlaceholderScreen(title: 'Maintenance'),
    tenantNewMaintenance: (context) => _PlaceholderScreen(title: 'New Maintenance Request'),
    tenantDocuments: (context) => _PlaceholderScreen(title: 'Documents'),
    tenantNotices: (context) => _PlaceholderScreen(title: 'Notices'),
    tenantChat: (context) => _PlaceholderScreen(title: 'Chat with Landlord'),
    tenantHelp: (context) => _PlaceholderScreen(title: 'Help & Support'),
    tenantNotifications: (context) => _PlaceholderScreen(title: 'Notifications'),
    tenantSettings: (context) => _PlaceholderScreen(title: 'Settings'),
    tenantProfileEdit: (context) => _PlaceholderScreen(title: 'Edit Profile'),
  };
}

// TEMPORARY Registration Screen (kept for owner registration backup)
class _RegistrationScreen extends StatefulWidget {
  final String title;
  final String userType;

  const _RegistrationScreen({required this.title, required this.userType});

  @override
  State<_RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<_RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ Actually save to MongoDB
      final authService = AuthService();
      
      final result = await authService.registerUser(
        userType: widget.userType,
        email: _emailController.text.trim(),
        password: _passwordController.text,
        personalDetails: {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'password': _passwordController.text,
        },
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registration successful!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate based on user type
          if (widget.userType == 'owner') {
            Navigator.pushReplacementNamed(context, AppRoutes.ownerDashboard);
          } else {
            Navigator.pushReplacementNamed(context, AppRoutes.homeDashboard);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Registration failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
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
        title: Text(widget.title),
        backgroundColor: AppTheme.primaryLight,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Create Your Account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Register as a ${widget.userType}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Full Name
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                
                // Email
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'Enter your email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                
                // Phone
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  hint: 'Enter your phone number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                
                // Password
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Create a password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  isPasswordVisible: _isPasswordVisible,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible 
                          ? Icons.visibility_outlined 
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Register Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegistration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryLight,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Register',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Already have account
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'Login',
                        style: TextStyle(
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isPasswordVisible = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword && !isPasswordVisible,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            suffixIcon: suffixIcon,
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
              borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter $label';
            }
            return null;
          },
        ),
      ],
    );
  }
}

// Placeholder screen for routes not yet implemented
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppTheme.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 80,
              color: AppTheme.textSecondaryLight,
            ),
            const SizedBox(height: 20),
            Text(
              '$title Screen',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Coming Soon!',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryLight,
                foregroundColor: Colors.white,
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}