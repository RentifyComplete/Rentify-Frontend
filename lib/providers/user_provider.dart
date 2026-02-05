import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../services/user_service.dart';
import '../services/session_service.dart';
import '../models/user_model.dart';

class UserProvider with ChangeNotifier {
  final UserService _userService = UserService();
  final SessionService _sessionService = SessionService();

  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _userData != null;

  // User info getters (NO profile picture from backend)
  String get userName => _userData?['name'] ?? 'User';
  String get userEmail => _userData?['email'] ?? '';
  String get userId => _userData?['_id'] ?? _userData?['id'] ?? '';

  // ⭐ FIXED: Extract phone from nested personalDetails structure
  String get userPhone {
    print('🔍 UserProvider.userPhone called');

    // Try personalDetails first (this is where it's stored in your MongoDB schema)
    if (_userData?['personalDetails'] != null) {
      final personalDetails = _userData!['personalDetails'] as Map<String, dynamic>?;
      if (personalDetails?['phone'] != null && personalDetails!['phone'].toString().isNotEmpty) {
        final phone = personalDetails['phone'].toString();
        print('✅ Found phone in personalDetails: $phone');
        return phone;
      }
    }

    // Fallback to direct phone field (in case schema changes)
    if (_userData?['phone'] != null && _userData!['phone'].toString().isNotEmpty) {
      final phone = _userData!['phone'].toString();
      print('✅ Found phone in direct field: $phone');
      return phone;
    }

    print('⚠️ No phone number found in userData');
    return '';
  }

  // ⭐ NEW - Location getters
  String get userCity => _userData?['city'] ?? 'Gurugram';
  String get userState => _userData?['state'] ?? 'Haryana';

  // Default profile picture (static, not from backend)
  String get userProfilePicture =>
      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop';

  // Get user role (tenant/owner)
  String get userRole => _userData?['role'] ?? 'tenant';
  bool get isPropertyOwner => userRole.toLowerCase() == 'owner' || userRole.toLowerCase() == 'landlord';

  // Load user data
  Future<void> loadUserData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🔄 Loading user data...');

      // Try to get cached data first for instant display
      final cachedInfo = await _userService.getCachedUserInfo();
      if (cachedInfo['name']?.isNotEmpty ?? false) {
        _userData = cachedInfo;
        notifyListeners();
        print('📦 Loaded cached user data');
      }

      // Then fetch fresh data from server
      final data = await _userService.getCurrentUser();
      _userData = data;
      _isLoading = false;
      _errorMessage = null;

      print('✅ User data loaded: ${_userData?['name']} - ${_userData?['city']}, ${_userData?['state']}');
      print('📞 Phone from personalDetails: ${userPhone}'); // Test the getter
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      print('❌ Error loading user data: $e');
      notifyListeners();
    }
  }

  // ⭐ UPDATED - Update user profile with session recovery and location support
  Future<bool> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? city,    // ⭐ NEW
    String? state,   // ⭐ NEW
    Map<String, dynamic>? additionalData,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🔄 Starting profile update...');
      print('📝 New values - Name: $name, Email: $email, Phone: $phone, City: $city, State: $state');

      // ⭐ STEP 1: Check if session exists
      var currentUser = await _sessionService.getCurrentUser();

      if (currentUser == null) {
        print('⚠️ No session found! Attempting to recover from cached data...');

        // ⭐ RECOVERY: Try to rebuild session from current _userData
        if (_userData != null && _userData!['id'] != null) {
          print('🔄 Rebuilding session from provider data...');

          try {
            // Get the auth token (if it exists)
            final token = await _sessionService.getToken();

            // Reconstruct UserModel from provider data
            final personalDetails = _userData!['personalDetails'] as Map<String, dynamic>? ?? {
              'fullName': _userData!['name'],
              'name': _userData!['name'],
              'phone': _userData!['phone'],
              'city': _userData!['city'],      // ⭐ NEW
              'state': _userData!['state'],    // ⭐ NEW
            };

            final recoveredUser = UserModel(
              id: ObjectId.fromHexString(_userData!['id']),
              userType: _userData!['role'] ?? 'tenant',
              email: _userData!['email'],
              password: '', // Password not needed for updates
              personalDetails: personalDetails,
              createdAt: DateTime.now(),
            );

            // Save recovered session
            await _sessionService.saveSession(recoveredUser, token: token);
            print('✅ Session recovered successfully');

            currentUser = recoveredUser;
          } catch (recoveryError) {
            print('❌ Session recovery failed: $recoveryError');
            _errorMessage = 'Session expired. Please log in again.';
            _isLoading = false;
            notifyListeners();
            return false;
          }
        } else {
          print('❌ Cannot recover session - no provider data available');
          _errorMessage = 'No user session found. Please login again.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      print('✅ Session verified: ${currentUser.email}');

      // ⭐ STEP 2: Prepare additional data with location
      final updateData = <String, dynamic>{};
      if (city != null) updateData['city'] = city;
      if (state != null) updateData['state'] = state;
      if (additionalData != null) updateData.addAll(additionalData);

      // ⭐ STEP 3: Update via UserService (which updates both MongoDB and Session)
      final updatedData = await _userService.updateUserProfile(
        name: name,
        email: email,
        phone: phone,
        additionalData: updateData.isNotEmpty ? updateData : null,
      );

      print('✅ Backend and session updated successfully');

      // ⭐ STEP 4: Update provider data
      _userData = updatedData;
      _isLoading = false;
      _errorMessage = null;

      print('✅ Profile update complete!');
      print('📋 Updated data: Name=${_userData!['name']}, Email=${_userData!['email']}, Location=${_userData!['city']}, ${_userData!['state']}');

      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      print('❌ Error updating profile: $e');
      notifyListeners();
      return false;
    }
  }

  // ⭐ NEW - Update only location (useful for weather refresh)
  Future<bool> updateLocation(String city, String state) async {
    return await updateProfile(city: city, state: state);
  }

  // Logout (DEPRECATED - use clearUserData instead)
  Future<void> logout() async {
    await _userService.logout();
    await _sessionService.clearSession();
    _userData = null;
    _errorMessage = null;
    notifyListeners();
    print('👋 User logged out from provider');
  }

  // ⭐ NEW - Clear user data (call on logout)
  /// Clear all user data from provider
  /// This should be called during logout process
  void clearUserData() {
    _userData = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
    print('🗑️ UserProvider: User data cleared');
  }

  // Initialize from cached data (for app startup)
  Future<void> initFromCache() async {
    try {
      final cachedInfo = await _userService.getCachedUserInfo();
      if (cachedInfo['name']?.isNotEmpty ?? false) {
        _userData = cachedInfo;
        notifyListeners();
        print('📦 Initialized from cached data');
        print('📞 Phone available: ${userPhone}');
      }
    } catch (e) {
      print('⚠️ Error initializing from cache: $e');
    }
  }

  // Set user data (call this after login)
  void setUserData(Map<String, dynamic> data) {
    _userData = data;
    _userService.saveUserData(data);
    notifyListeners();
    print('✅ User data set in provider: ${data['name']} - ${data['city']}, ${data['state']}');
    print('📞 Phone number: ${userPhone}');
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Refresh user data
  Future<void> refreshUserData() async {
    await loadUserData();
  }

  // ⭐ NEW - Debug method to inspect user data structure
  void debugUserData() {
    print('\n========== USER PROVIDER DEBUG ==========');
    print('User ID: $userId');
    print('User Email: $userEmail');
    print('User Name: $userName');
    print('User Phone: $userPhone');
    print('User City: $userCity');
    print('User State: $userState');
    print('User Role: $userRole');
    print('Is Property Owner: $isPropertyOwner');
    print('\nRaw userData structure:');
    print('  Keys: ${_userData?.keys.toList()}');
    if (_userData?['personalDetails'] != null) {
      print('  personalDetails keys: ${(_userData!['personalDetails'] as Map).keys.toList()}');
      print('  personalDetails.phone: ${(_userData!['personalDetails'] as Map)['phone']}');
    }
    print('=========================================\n');
  }
}