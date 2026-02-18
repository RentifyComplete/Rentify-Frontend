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

// ── Design tokens ──────────────────────────────────────────────────────────
class _C {
  static const navy       = Color(0xFF0D1B2A);
  static const navyMid    = Color(0xFF1A2E46);
  static const blue       = Color(0xFF1B4F8A);
  static const blueBright = Color(0xFF2463AE);
  static const sky        = Color(0xFF4A90D9);
  static const skyLight   = Color(0xFF7DB8F0);
  static const offWhite   = Color(0xFFF4F7FC);
  static const greyLine   = Color(0xFFE8EEF7);
  static const greyText   = Color(0xFF8FA3BE);
  static const white      = Color(0xFFFFFFFF);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with WidgetsBindingObserver {
  String _selectedUserType = 'tenant';

  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final AuthService    _authService    = AuthService();
  final SessionService _sessionService = SessionService();

  bool _isPasswordVisible = false;
  bool _isLoading         = false;
  bool _rememberMe        = true;
  bool _isCheckingSession = true;

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  // ── Session check ─────────────────────────────────────────────────────────
  Future<void> _checkExistingSession() async {
    try {
      await Future.any([
        _performSessionCheck(),
        Future.delayed(const Duration(seconds: 5),
                () => throw TimeoutException('Session check took too long')),
      ]);
    } on TimeoutException {
      // continue to login
    } catch (_) {
      // continue to login
    } finally {
      if (mounted) setState(() => _isCheckingSession = false);
    }
  }

  Future<void> _performSessionCheck() async {
    await Future.delayed(const Duration(milliseconds: 100));
    await _sessionService.debugPrintSessionData();
    final shouldRestore =
    await _sessionService.shouldRestoreSessionOnAppRestart();

    if (shouldRestore) {
      final user  = await _sessionService.getCurrentUser();
      final token = await _sessionService.getToken();

      if (user != null && token != null && mounted) {
        final userProvider =
        Provider.of<UserProvider>(context, listen: false);
        userProvider.setUserData({
          '_id'            : user.id?.toHexString() ?? '',
          'id'             : user.id?.toHexString() ?? '',
          'email'          : user.email,
          'name'           : user.personalDetails['fullName'] ??
              user.personalDetails['name'] ?? 'User',
          'phone'          : user.personalDetails['phone'] ?? '',
          'role'           : user.userType,
          'userType'       : user.userType,
          'authToken'      : token,
          'personalDetails': user.personalDetails,
        });
        await _sessionService.updateLastActive();
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            user.userType == 'owner' ? '/owner-dashboard' : '/home-dashboard',
          );
        }
      }
    } else {
      await _sessionService.clearSessionIfNotRemembered();
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    HapticFeedback.lightImpact();
    final email    = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty)    return _showError('Please enter your email');
    if (password.isEmpty) return _showError('Please enter your password');
    if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email))
      return _showError('Please enter a valid email');
    if (password.length < 6)
      return _showError('Password must be at least 6 characters');

    setState(() => _isLoading = true);

    try {
      final loginResult = await Future.any([
        _authService.login(email, password),
        Future.delayed(const Duration(seconds: 30),
                () => throw TimeoutException('Login request took too long')),
      ]);

      if (loginResult != null) {
        final user  = loginResult['user']  as UserModel;
        final token = loginResult['token'] as String;

        if (user.userType != _selectedUserType) {
          final sel = _selectedUserType == 'tenant' ? 'Tenant' : 'Owner';
          final act = user.userType       == 'tenant' ? 'Tenant' : 'Owner';
          setState(() => _isLoading = false);
          return _showError(
              'You selected $sel but this account is registered as $act.');
        }

        final saved = await _sessionService.saveSession(
            user, token: token, rememberMe: _rememberMe);
        if (!saved && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Warning: Session may not persist'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ));
        }

        if (!mounted) return;
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final userData = {
          '_id'            : user.id?.toHexString() ?? '',
          'id'             : user.id?.toHexString() ?? '',
          'name'           : user.personalDetails['fullName'] ??
              user.personalDetails['name'] ?? 'User',
          'email'          : user.email,
          'phone'          : user.personalDetails['phone'] ?? '',
          'role'           : user.userType,
          'userType'       : user.userType,
          'authToken'      : token,
          'personalDetails': user.personalDetails,
        };
        userProvider.setUserData(userData);

        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          user.userType == 'owner' ? '/owner-dashboard' : '/home-dashboard',
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Welcome back, ${userData['name']}!'),
          backgroundColor: _C.blue,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      } else {
        _showError('Login failed. Please try again.');
      }
    } on TimeoutException {
      if (mounted)
        _showError('Login timed out. Check your connection and try again.');
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString()
          .replaceAll('Exception: ', '')
          .replaceAll('Error: ', '');
      if (msg.toLowerCase().contains('network'))
        msg = 'Network error. Please check your internet connection.';
      else if (msg.toLowerCase().contains('invalid') ||
          msg.toLowerCase().contains('incorrect'))
        msg = 'Invalid email or password. Please try again.';
      _showError(msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'Dismiss',
        textColor: Colors.white,
        onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
      ),
    ));
  }

  void _handleForgotPassword() {
    HapticFeedback.lightImpact();
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ForgotPasswordScreen()));
  }

  void _handleSignUp() {
    HapticFeedback.lightImpact();
    if (_selectedUserType == 'tenant') {
      Navigator.pushNamed(context, '/tenant-registration');
    } else {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const PropertyOwnerRegistration()));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) return _buildSplash();

    // Make status bar transparent with white icons so navy header shows through
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: _C.offWhite,
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Full-bleed header covers status bar
            const LoginHeaderWidget(),

            // Form body — padded safely at the bottom only
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 3.5.h),
                  _buildRoleToggle(),
                  SizedBox(height: 3.h),
                  _buildEmailField(),
                  SizedBox(height: 2.h),
                  _buildPasswordField(),
                  _buildForgotRow(),
                  SizedBox(height: 1.h),
                  _buildRememberRow(),
                  SizedBox(height: 2.5.h),
                  _buildLoginButton(),
                  SizedBox(height: 2.5.h),
                  _buildDivider(),
                  SizedBox(height: 2.5.h),
                  _buildSignUpRow(),
                  SizedBox(height: 4.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Splash ────────────────────────────────────────────────────────────────
  Widget _buildSplash() => Scaffold(
    backgroundColor: _C.navy,
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(_C.skyLight),
            ),
          ),
          SizedBox(height: 2.h),
          const Text(
            'RENTIFY',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
          ),
          SizedBox(height: 0.8.h),
          const Text(
            'Checking session…',
            style: TextStyle(
              color: _C.greyText,
              fontSize: 13,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ),
  );

  // ── Role toggle ───────────────────────────────────────────────────────────
  Widget _buildRoleToggle() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'SIGN IN AS',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
          color: _C.greyText,
        ),
      ),
      SizedBox(height: 1.5.h),
      Row(
        children: [
          Expanded(
              child: _roleCard('tenant', 'Tenant', Icons.home_outlined)),
          SizedBox(width: 3.w),
          Expanded(
              child: _roleCard('owner', 'Owner', Icons.domain_outlined)),
        ],
      ),
    ],
  );

  Widget _roleCard(String type, String label, IconData icon) {
    final active = _selectedUserType == type;
    return GestureDetector(
      onTap: _isLoading
          ? null
          : () {
        setState(() => _selectedUserType = type);
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(vertical: 2.2.h),
        decoration: BoxDecoration(
          color: active ? _C.navy : _C.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? _C.blueBright : _C.greyLine,
            width: active ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: active
                  ? _C.blue.withOpacity(0.25)
                  : Colors.black.withOpacity(0.04),
              blurRadius: active ? 16 : 8,
              offset: Offset(0, active ? 6 : 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: active ? _C.sky.withOpacity(0.15) : _C.greyLine,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22,
                  color: active ? _C.skyLight : _C.greyText),
            ),
            SizedBox(height: 1.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: active ? _C.white : _C.greyText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Text fields ───────────────────────────────────────────────────────────
  Widget _buildEmailField() => _field(
    controller: _emailController,
    label: 'EMAIL ADDRESS',
    hint: 'Enter your email address',
    icon: Icons.mail_outline_rounded,
    keyboardType: TextInputType.emailAddress,
    textInputAction: TextInputAction.next,
  );

  Widget _buildPasswordField() => _field(
    controller: _passwordController,
    label: 'PASSWORD',
    hint: 'Enter your password',
    icon: Icons.lock_outline_rounded,
    obscure: !_isPasswordVisible,
    textInputAction: TextInputAction.done,
    onSubmitted: (_) => _handleLogin(),
    suffixIcon: IconButton(
      icon: Icon(
        _isPasswordVisible
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        size: 20,
        color: _C.greyText,
      ),
      onPressed: () =>
          setState(() => _isPasswordVisible = !_isPasswordVisible),
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
            color: _C.greyText,
          ),
        ),
        SizedBox(height: 1.h),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          enabled: !_isLoading,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _C.navy,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: _C.greyText.withOpacity(0.7),
              fontWeight: FontWeight.w300,
              fontSize: 13,
            ),
            prefixIcon: Icon(icon, size: 20, color: _C.greyText),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: _isLoading ? _C.white.withOpacity(0.6) : _C.white,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
              const BorderSide(color: _C.greyLine, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
              const BorderSide(color: _C.greyLine, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
              const BorderSide(color: _C.blueBright, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: _C.greyLine.withOpacity(0.5), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── Forgot password ───────────────────────────────────────────────────────
  Widget _buildForgotRow() => Align(
    alignment: Alignment.centerRight,
    child: TextButton(
      onPressed: _isLoading ? null : _handleForgotPassword,
      style: TextButton.styleFrom(
        padding:
        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        'Forgot Password?',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color:
          _isLoading ? _C.blue.withOpacity(0.4) : _C.blueBright,
          letterSpacing: 0.2,
        ),
      ),
    ),
  );

  // ── Remember me ───────────────────────────────────────────────────────────
  Widget _buildRememberRow() => GestureDetector(
    onTap: _isLoading
        ? null
        : () {
      setState(() => _rememberMe = !_rememberMe);
      HapticFeedback.selectionClick();
    },
    child: Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: _rememberMe ? _C.navy : _C.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _rememberMe ? _C.blueBright : _C.greyLine,
              width: 1.5,
            ),
            boxShadow: _rememberMe
                ? [
              BoxShadow(
                color: _C.blue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ]
                : [],
          ),
          child: _rememberMe
              ? const Icon(Icons.check_rounded,
              size: 14, color: Colors.white)
              : null,
        ),
        SizedBox(width: 3.w),
        Text(
          'Keep me signed in',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: _isLoading
                ? _C.navy.withOpacity(0.4)
                : _C.navy.withOpacity(0.65),
          ),
        ),
      ],
    ),
  );

  // ── Login button ──────────────────────────────────────────────────────────
  Widget _buildLoginButton() => SizedBox(
    width: double.infinity,
    height: 56,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: _isLoading
            ? null
            : const LinearGradient(
          colors: [_C.blue, _C.blueBright, Color(0xFF2D6DC4)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        color: _isLoading ? _C.blue.withOpacity(0.5) : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isLoading
            ? []
            : [
          BoxShadow(
            color: _C.blue.withOpacity(0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: _C.blue.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          disabledBackgroundColor: Colors.transparent,
        ),
        child: _isLoading
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
            AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SIGN IN',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10),
            Icon(Icons.arrow_forward_rounded,
                size: 18, color: Colors.white),
          ],
        ),
      ),
    ),
  );

  // ── Divider ───────────────────────────────────────────────────────────────
  Widget _buildDivider() => Row(
    children: [
      const Expanded(child: Divider(color: _C.greyLine, thickness: 1)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: const Text(
          'OR',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
            color: _C.greyText,
          ),
        ),
      ),
      const Expanded(child: Divider(color: _C.greyLine, thickness: 1)),
    ],
  );

  // ── Sign up ───────────────────────────────────────────────────────────────
  Widget _buildSignUpRow() => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Don't have an account?",
            style: TextStyle(
              fontSize: 13,
              color: _C.greyText,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _isLoading ? null : _handleSignUp,
            child: Text(
              'Create Account',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _isLoading
                    ? _C.blueBright.withOpacity(0.4)
                    : _C.blueBright,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: 0.8.h),
      Text(
        'as ${_selectedUserType == 'tenant' ? 'Tenant' : 'Property Owner'}',
        style: const TextStyle(
          fontSize: 11,
          color: _C.greyText,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.3,
        ),
      ),
    ],
  );
}

// ── Timeout exception ─────────────────────────────────────────────────────
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}