import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../core/app_export.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import './widgets/login_header_widget.dart';
import '../../models/user_model.dart';
import '../Owner_registration/property_owner_registration.dart';
import 'package:rentokpg/presentation/login_screen/forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  String _selectedUserType = 'tenant';

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final AuthService _authService = AuthService();
  final SessionService _sessionService = SessionService();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = true;
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('\n🚀 LoginScreen initialized');
    _checkExistingSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('📱 App resumed on login screen');
    }
  }

  /// ✅ OPTIMIZED: Enhanced session check with timeout protection
  Future<void> _checkExistingSession() async {
    print('\n🔍 === CHECKING EXISTING SESSION ===');
    
    try {
      // Add timeout to prevent infinite loading
      await Future.any([
        _performSessionCheck(),
        Future.delayed(const Duration(seconds: 5), () {
          print('⏱️ Session check timeout (5s)');
          throw TimeoutException('Session check took too long');
        }),
      ]);
    } on TimeoutException catch (e) {
      print('⚠️ Session check timed out: $e');
      // Continue to login screen
    } catch (e, stackTrace) {
      print('❌ Error checking session: $e');
      print('Stack trace: $stackTrace');
      // Continue to login screen on error
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingSession = false;
        });
        print('✅ Session check complete\n');
      }
    }
  }

  /// Perform the actual session check
  Future<void> _performSessionCheck() async {
    // Add small delay to ensure SharedPreferences is ready
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Debug: Print current session data
    await _sessionService.debugPrintSessionData();
    
    // Check if session should be restored
    final shouldRestore = await _sessionService.shouldRestoreSessionOnAppRestart();
    print('Should restore session: $shouldRestore');

    if (shouldRestore) {
      print('✅ Attempting to restore session...');
      
      final user = await _sessionService.getCurrentUser();
      final token = await _sessionService.getToken();

      if (user != null && token != null) {
        print('✅ User and token found');
        print('   Email: ${user.email}');
        print('   Type: ${user.userType}');
        
        if (!mounted) {
          print('⚠️ Widget not mounted, aborting');
          return;
        }

        // Load user data to provider
        final userProvider = Provider.of<UserProvider>(context, listen: false);

        final userData = {
          '_id': user.id?.toHexString() ?? '',
          'id': user.id?.toHexString() ?? '',
          'email': user.email,
          'name': user.personalDetails['fullName'] ??
              user.personalDetails['name'] ??
              'User',
          'phone': user.personalDetails['phone'] ?? '',
          'role': user.userType,
          'userType': user.userType,
          'authToken': token,
          'personalDetails': user.personalDetails,
        };

        userProvider.setUserData(userData);
        print('✅ User data loaded to provider');

        // Update last active timestamp
        await _sessionService.updateLastActive();

        // Navigate to appropriate dashboard
        final userType = user.userType == 'owner' ? 'owner' : 'tenant';
        final route = userType == 'owner' ? '/owner-dashboard' : '/home-dashboard';

        print('📍 Navigating to: $route');

        // Small delay for smooth transition
        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          Navigator.pushReplacementNamed(context, route);
          print('✅ Auto-login successful!');
        }
        return;
      } else {
        print('⚠️ User or token is null');
        print('   User: ${user != null}');
        print('   Token: ${token != null}');
      }
    } else {
      print('ℹ️ Session should not be restored');
      // Clear session if Remember Me is disabled
      await _sessionService.clearSessionIfNotRemembered();
    }
  }

  /// ✅ OPTIMIZED: Enhanced login with better validation and error handling
  Future<void> _handleLogin() async {
    print('\n🔐 === HANDLING LOGIN ===');
    HapticFeedback.lightImpact();

    // Validation
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      _showErrorSnackBar('Please enter your email');
      return;
    }

    if (password.isEmpty) {
      _showErrorSnackBar('Please enter your password');
      return;
    }

    // Email validation
    if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email)) {
      _showErrorSnackBar('Please enter a valid email');
      return;
    }

    // Password length check
    if (password.length < 6) {
      _showErrorSnackBar('Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('📧 Email: $email');
      print('🔒 Remember Me: $_rememberMe');
      print('👤 User Type: $_selectedUserType');

      // Add timeout to login request
      final loginResult = await Future.any([
        _authService.login(email, password),
        Future.delayed(const Duration(seconds: 30), () {
          print('⏱️ Login request timeout (30s)');
          throw TimeoutException('Login request took too long');
        }),
      ]);

      if (loginResult != null) {
        final user = loginResult['user'] as UserModel;
        final token = loginResult['token'] as String;

        print('✅ Login successful from API');
        print('   User: ${user.email}');
        print('   Type: ${user.userType}');

        // Check if user type matches selected type
        if (user.userType != _selectedUserType) {
          final selectedType = _selectedUserType == 'tenant' ? 'Tenant' : 'Owner';
          final actualType = user.userType == 'tenant' ? 'Tenant' : 'Owner';
          
          _showErrorSnackBar(
            'Invalid login. You selected $selectedType but this account is registered as $actualType.');
          
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // ✅ Save session with Remember Me preference
        print('💾 Saving session...');
        final sessionSaved = await _sessionService.saveSession(
          user,
          token: token,
          rememberMe: _rememberMe,
        );

        if (!sessionSaved) {
          print('⚠️ Warning: Session may not have saved completely');
          // Show warning but continue
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Warning: Session may not persist across restarts'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }

        // Debug: Verify session was saved
        await _sessionService.debugPrintSessionData();

        if (!mounted) return;

        // Load to provider
        final userProvider = Provider.of<UserProvider>(context, listen: false);

        final userData = {
          '_id': user.id?.toHexString() ?? '',
          'id': user.id?.toHexString() ?? '',
          'name': user.personalDetails['fullName'] ??
              user.personalDetails['name'] ??
              'User',
          'email': user.email,
          'phone': user.personalDetails['phone'] ?? '',
          'role': user.userType,
          'userType': user.userType,
          'authToken': token,
          'personalDetails': user.personalDetails,
        };

        userProvider.setUserData(userData);
        print('✅ User data loaded to provider');

        if (!mounted) return;

        // Navigate to appropriate dashboard
        final route = user.userType == 'owner' ? '/owner-dashboard' : '/home-dashboard';
        print('📍 Navigating to: $route');
        
        Navigator.pushReplacementNamed(context, route);

        // Show welcome message
        final userName = userData['name'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome back, $userName!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        print('✅ Login complete!\n');
      } else {
        print('❌ Login failed: No result from API');
        _showErrorSnackBar('Login failed. Please try again.');
      }
    } on TimeoutException catch (e) {
      print('⏱️ Login timeout: $e');
      if (!mounted) return;
      _showErrorSnackBar('Login timed out. Please check your connection and try again.');
    } catch (e, stackTrace) {
      print('❌ Login error: $e');
      print('Stack trace: $stackTrace');
      
      if (!mounted) return;
      
      // Clean up error message
      String errorMessage = e.toString();
      errorMessage = errorMessage.replaceAll('Exception: ', '');
      errorMessage = errorMessage.replaceAll('Error: ', '');
      
      // Show user-friendly error messages
      if (errorMessage.toLowerCase().contains('network')) {
        _showErrorSnackBar('Network error. Please check your internet connection.');
      } else if (errorMessage.toLowerCase().contains('invalid') || 
                 errorMessage.toLowerCase().contains('incorrect')) {
        _showErrorSnackBar('Invalid email or password. Please try again.');
      } else {
        _showErrorSnackBar(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _handleForgotPassword() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ForgotPasswordScreen(),
      ),
    );
  }

  void _handleSignUp() {
    HapticFeedback.lightImpact();

    if (_selectedUserType == 'tenant') {
      Navigator.pushNamed(context, '/tenant-registration');
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PropertyOwnerRegistration(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return Scaffold(
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppTheme.lightTheme.colorScheme.primary,
              ),
              SizedBox(height: 2.h),
              Text(
                'Checking session...',
                style: AppTheme.lightTheme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 4.h),
              LoginHeaderWidget(),
              SizedBox(height: 6.h),
              _buildUserTypeToggle(),
              SizedBox(height: 4.h),
              _buildFormFields(),
              SizedBox(height: 1.h),
              _buildRememberMeToggle(),
              SizedBox(height: 2.h),
              _buildLoginButton(),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: AppTheme.lightTheme.colorScheme.outline
                          .withOpacity(0.3),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Text(
                      'OR',
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: AppTheme.lightTheme.colorScheme.outline
                          .withOpacity(0.3),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              _buildSignUpSection(),
              SizedBox(height: 4.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserTypeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Login as',
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.lightTheme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 2.h),
        Row(
          children: [
            Expanded(
              child: _buildUserTypeCard(
                title: 'Tenant',
                icon: Icons.home_outlined,
                userType: 'tenant',
                isSelected: _selectedUserType == 'tenant',
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: _buildUserTypeCard(
                title: 'Owner',
                icon: Icons.business_outlined,
                userType: 'owner',
                isSelected: _selectedUserType == 'owner',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserTypeCard({
    required String title,
    required IconData icon,
    required String userType,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        if (_isLoading) return; // Prevent changing during login
        setState(() {
          _selectedUserType = userType;
        });
        HapticFeedback.selectionClick();
        print('🔄 User type changed to: $userType');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.lightTheme.colorScheme.primary.withOpacity(0.1)
              : AppTheme.lightTheme.colorScheme.surface,
          border: Border.all(
            color: isSelected
                ? AppTheme.lightTheme.colorScheme.primary
                : AppTheme.lightTheme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? AppTheme.lightTheme.colorScheme.primary
                  : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppTheme.lightTheme.colorScheme.primary
                    : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'Enter your email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: 2.h),
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Enter your password',
          icon: Icons.lock_outline,
          isPassword: true,
          isPasswordVisible: _isPasswordVisible,
          onTogglePassword: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
        SizedBox(height: 1.h),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isLoading ? null : _handleForgotPassword,
            child: Text(
              'Forgot Password?',
              style: TextStyle(
                color: _isLoading 
                    ? AppTheme.lightTheme.colorScheme.primary.withOpacity(0.5)
                    : AppTheme.lightTheme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRememberMeToggle() {
    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: _rememberMe,
            onChanged: _isLoading
                ? null
                : (value) {
                    setState(() {
                      _rememberMe = value ?? true;
                    });
                    HapticFeedback.selectionClick();
                    print('🔄 Remember Me changed to: $_rememberMe');
                  },
            activeColor: AppTheme.lightTheme.colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        SizedBox(width: 2.w),
        Expanded(
          child: GestureDetector(
            onTap: _isLoading
                ? null
                : () {
                    setState(() {
                      _rememberMe = !_rememberMe;
                    });
                    HapticFeedback.selectionClick();
                    print('🔄 Remember Me changed to: $_rememberMe');
                  },
            child: Text(
              'Remember me',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: _isLoading
                    ? AppTheme.lightTheme.colorScheme.onSurface.withOpacity(0.5)
                    : AppTheme.lightTheme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.lightTheme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 1.h),
        TextField(
          controller: controller,
          obscureText: isPassword && !isPasswordVisible,
          keyboardType: keyboardType,
          enabled: !_isLoading,
          textInputAction: isPassword ? TextInputAction.done : TextInputAction.next,
          onSubmitted: (_) {
            if (isPassword) {
              _handleLogin();
            }
          },
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: onTogglePassword,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.lightTheme.colorScheme.outline
                    .withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.lightTheme.colorScheme.outline
                    .withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.lightTheme.colorScheme.primary,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.lightTheme.colorScheme.outline
                    .withOpacity(0.2),
              ),
            ),
            filled: true,
            fillColor: _isLoading 
                ? AppTheme.lightTheme.colorScheme.surface.withOpacity(0.5)
                : AppTheme.lightTheme.colorScheme.surface,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.lightTheme.colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: AppTheme.lightTheme.colorScheme.primary
              .withOpacity(0.6),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Login',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildSignUpSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: AppTheme.lightTheme.textTheme.bodyMedium,
            ),
            GestureDetector(
              onTap: _isLoading ? null : _handleSignUp,
              child: Text(
                'Sign Up',
                style: TextStyle(
                  color: _isLoading
                      ? AppTheme.lightTheme.colorScheme.primary.withOpacity(0.5)
                      : AppTheme.lightTheme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 1.h),
        Text(
          'as ${_selectedUserType == 'tenant' ? 'Tenant' : 'Property Owner'}',
          style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
            color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  
  @override
  String toString() => message;
}