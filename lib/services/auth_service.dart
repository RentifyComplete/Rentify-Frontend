// lib/services/auth_service.dart

import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'mongodb_service.dart';
import 'session_service.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

class AuthService {
  final MongoDBService _mongoService = MongoDBService();
  final SessionService _sessionService = SessionService();
  
  static const String baseUrl = 'https://www.rentify24.com/api';
  
  static const String propertiesEndpoint = '/properties';
  static const String bookingsEndpoint = '/bookings';
  static const String authEndpoint = '/auth';

  String getPropertiesByOwnerUrl(String ownerId) => '$baseUrl$propertiesEndpoint/owner/$ownerId';
  String getBookingsByOwnerUrl(String ownerId) => '$baseUrl$bookingsEndpoint/owner/$ownerId';
  String getBookingsByTenantUrl(String email) => '$baseUrl$bookingsEndpoint/tenant/$email';
  String getAllPropertiesUrl() => '$baseUrl$propertiesEndpoint';
  String getAllBookingsUrl() => '$baseUrl$bookingsEndpoint';
  String getUpdateBookingUrl(String bookingId) => '$baseUrl$bookingsEndpoint/$bookingId';
  String getDeleteBookingUrl(String bookingId) => '$baseUrl$bookingsEndpoint/$bookingId';
  String getRecordRentPaymentUrl(String bookingId) => '$baseUrl$bookingsEndpoint/$bookingId/rent';
  String getSendResetOtpUrl() => '$baseUrl$authEndpoint/send-reset-otp';
  String getVerifyOtpUrl() => '$baseUrl$authEndpoint/verify-otp';
  String getResetPasswordUrl() => '$baseUrl$authEndpoint/reset-password';

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  bool _isStrongPassword(String password) {
    return password.length >= 6;
  }

  String _generateSessionToken(UserModel user) {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomBytes = List<int>.generate(32, (i) => random.nextInt(256));
    final tokenData = '${user.id}_${user.email}_$timestamp}_${randomBytes.join()}';
    final bytes = utf8.encode(tokenData);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  String _generateResetToken() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomBytes = List<int>.generate(32, (i) => random.nextInt(256));
    final tokenData = '${timestamp}_${randomBytes.join()}';
    final bytes = utf8.encode(tokenData);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<String?> getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('userId');
    } catch (e) {
      print('❌ Error getting current user ID: $e');
      return null;
    }
  }

  Future<void> _saveUserId(dynamic userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      String userIdString;
      if (userId is ObjectId) {
        userIdString = userId.toHexString();
      } else {
        userIdString = userId.toString();
      }

      await prefs.setString('userId', userIdString);
      print('💾 Saved userId: $userIdString');
    } catch (e) {
      print('❌ Error saving user ID: $e');
      throw e;
    }
  }

  Future<void> _saveUserType(String userType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userType', userType);
      print('💾 Saved userType: $userType');
    } catch (e) {
      print('❌ Error saving user type: $e');
      throw e;
    }
  }

  // ✅ FIXED: Clear ALL cached data including documents
  Future<void> _ensureEmailSaved(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final normalizedEmail = email.toLowerCase().trim();
      
      print('🔐 ========== SAVING USER EMAIL ==========');
      print('📧 Email to save: $normalizedEmail');
      
      // ✅ CRITICAL: Clear ALL old user data
      print('🗑️ Clearing all old user data...');
      final keysToClear = [  // ✅ FIXED: Was 'keysToClr', now 'keysToClear'
        'cached_user_data',
        'userEmail',
        'tenant_documents', // ✅ CRITICAL: Clear old documents
        'user_name',
        'user_id',
      ];
      
      for (final key in keysToClear) {  // ✅ FIXED: Now matches variable name
        await prefs.remove(key);
      }
      print('✅ Cleared all old user data');
      
      // Save new email in all keys
      await prefs.setString('user_email', normalizedEmail);
      await prefs.setString('email', normalizedEmail);
      await prefs.setString('tenantEmail', normalizedEmail);
      await prefs.setString('userEmail', normalizedEmail);
      
      await prefs.commit();
      
      // Verify
      final verify1 = prefs.getString('user_email');
      final verify2 = prefs.getString('email');
      final verify3 = prefs.getString('tenantEmail');
      final verify4 = prefs.getString('userEmail');
      
      print('✅ Verification:');
      print('   user_email: $verify1');
      print('   email: $verify2');
      print('   tenantEmail: $verify3');
      print('   userEmail: $verify4');
      
      if (verify1 != normalizedEmail || verify2 != normalizedEmail || 
          verify3 != normalizedEmail || verify4 != normalizedEmail) {
        print('❌ CRITICAL: Email verification failed!');
        throw Exception('Email verification failed after save');
      }
      
      print('✅ Email saved and verified successfully');
      print('=========================================');
    } catch (e) {
      print('❌ CRITICAL: Failed to save email: $e');
      throw e;
    }
  }

  @Deprecated('Use _ensureEmailSaved for guaranteed saving')
  Future<void> _saveUserEmail(String email) async {
    await _ensureEmailSaved(email);
  }

  Future<String?> getCurrentUserType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('userType');
    } catch (e) {
      print('❌ Error getting user type: $e');
      return null;
    }
  }

  Future<String?> getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      String? email = prefs.getString('user_email');
      if (email != null && email.isNotEmpty) {
        print('📧 Retrieved from user_email: $email');
        return email;
      }
      
      email = prefs.getString('email');
      if (email != null && email.isNotEmpty) {
        print('📧 Retrieved from email: $email');
        return email;
      }
      
      email = prefs.getString('tenantEmail');
      if (email != null && email.isNotEmpty) {
        print('📧 Retrieved from tenantEmail: $email');
        return email;
      }

      email = prefs.getString('userEmail');
      if (email != null && email.isNotEmpty) {
        print('📧 Retrieved from userEmail: $email');
        return email;
      }
      
      print('⚠️ No email found in any location');
      return null;
    } catch (e) {
      print('❌ Error getting user email: $e');
      return null;
    }
  }

  Future<void> logout() async {
    print('🚪 AuthService: Logging out...');
    
    try {
      await _sessionService.clearSession();
      print('✅ SessionService cleared');
      
      final prefs = await SharedPreferences.getInstance();
      
      final keysToRemove = [
        'userId',
        'userType',
        'user_email',
        'email',
        'tenantEmail',
        'userEmail',
        'cached_user_data',
        'user_name',
        'user_id',
        'session_token',
        'tenant_documents',
        'current_user',
        'is_logged_in',
      ];
      
      for (final key in keysToRemove) {
        await prefs.remove(key);
        print('🗑️ Removed: $key');
      }
      
      await prefs.commit();
      
      print('✅ AuthService: Logout complete');
    } catch (e) {
      print('❌ AuthService: Logout error: $e');
      throw Exception('Failed to logout: $e');
    }
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      print('🔐 ========== LOGIN ATTEMPT ==========');
      print('📧 Email: ${email.toLowerCase()}');
      
      final db = await _mongoService.getDatabase();
      final users = db.collection('users');

      final userDoc = await users.findOne(where.eq('email', email.toLowerCase()));
      if (userDoc == null) {
        print('❌ User not found');
        throw Exception("Invalid email or password");
      }

      if (userDoc['password'] != _hashPassword(password)) {
        print('❌ Invalid password');
        throw Exception("Invalid email or password");
      }

      final user = UserModel.fromMap(userDoc);
      final token = _generateSessionToken(user);

      print('✅ User authenticated: ${user.email}');
      print('💾 Saving user session data...');

      try {
        await _saveUserId(user.id!);
        await _saveUserType(user.userType);
        await _ensureEmailSaved(user.email);
        
        print('✅ All session data saved successfully');
      } catch (saveError) {
        print('❌ CRITICAL: Failed to save session data: $saveError');
        throw Exception('Login successful but failed to save session: $saveError');
      }

      print('✅ Login complete');
      print('====================================');

      return {
        'user': user,
        'token': token,
      };
    } catch (e) {
      print('❌ Login error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 ========== LOGIN USER ATTEMPT ==========');
      print('📧 Email: ${email.toLowerCase()}');
      
      final db = await _mongoService.getDatabase();
      final users = db.collection('users');

      final userDoc = await users.findOne(where.eq('email', email.toLowerCase()));
      if (userDoc == null) {
        print('❌ User not found');
        return {'success': false, 'message': 'Invalid email or password'};
      }

      if (userDoc['password'] != _hashPassword(password)) {
        print('❌ Invalid password');
        return {'success': false, 'message': 'Invalid email or password'};
      }

      final user = UserModel.fromMap(userDoc);
      
      print('✅ User authenticated: ${user.email}');
      print('💾 Saving user session data...');

      try {
        await _saveUserId(user.id!);
        await _saveUserType(user.userType);
        await _ensureEmailSaved(user.email);
        
        print('✅ All session data saved successfully');
      } catch (saveError) {
        print('❌ CRITICAL: Failed to save session data: $saveError');
        return {
          'success': false,
          'message': 'Login successful but failed to save session: $saveError'
        };
      }

      print('✅ Login complete');
      print('=========================================');

      return {
        'success': true,
        'message': 'Login successful',
        'user': user,
      };
    } catch (e) {
      print('❌ Login error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> registerOwner(Map<String, dynamic> data) async {
    try {
      final ownerDocuments = {
        'businessDetails': data['businessDetails'] ?? {},
        'address': data['address'] ?? {},
        'bankDetails': data['bankDetails'] ?? {},
        'uploadedDocuments': data['documents'] ?? {},
        'termsAccepted': data['termsAccepted'] ?? false,
        'registeredAt': DateTime.now().toIso8601String(),
        'accountStatus': 'pending_verification',
      };

      return await registerUser(
        userType: "owner",
        email: data['email'],
        password: data['password'],
        personalDetails: data['personalDetails'],
        documents: ownerDocuments,
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<Map<String, dynamic>> registerUser({
    required String userType,
    required String email,
    required String password,
    required Map<String, dynamic> personalDetails,
    Map<String, dynamic>? occupationInfo,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? documents,
    Map<String, dynamic>? emergencyContact,
  }) async {
    try {
      print('📝 ========== USER REGISTRATION ==========');
      print('📧 Email: ${email.toLowerCase()}');
      print('👤 Type: $userType');
      
      final db = await _mongoService.getDatabase();
      final users = db.collection('users');

      final existing = await users.findOne(where.eq('email', email.toLowerCase()));
      if (existing != null) {
        print('⚠️ Email already registered');
        return {'success': false, 'message': 'Email already registered'};
      }

      final newUser = UserModel(
        userType: userType,
        email: email.toLowerCase(),
        password: _hashPassword(password),
        personalDetails: personalDetails,
        occupationInfo: occupationInfo,
        preferences: preferences,
        documents: documents,
        emergencyContact: emergencyContact,
      );

      final result = await users.insertOne(newUser.toMap());

      if (result.isSuccess) {
        print('✅ User created in database');
        print('💾 Saving session data...');
        
        try {
          await _saveUserId(result.id);
          await _saveUserType(userType);
          await _ensureEmailSaved(email);
          
          print('✅ Session data saved successfully');
        } catch (saveError) {
          print('❌ Failed to save session: $saveError');
          return {
            'success': false,
            'message': 'Registration successful but failed to save session: $saveError'
          };
        }

        String idString = (result.id is ObjectId)
            ? result.id.toHexString()
            : result.id.toString();

        print('✅ Registration complete');
        print('=======================================');

        return {
          'success': true,
          'message': 'Registration successful',
          'userId': idString,
        };
      }

      print('❌ Registration failed');
      return {'success': false, 'message': 'Registration failed'};
    } catch (e) {
      print('❌ Registration error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendPasswordResetEmailFull(String email) async {
    try {
      final url = Uri.parse(getSendResetOtpUrl());
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim()}),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      print('📡 Send OTP Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? 'OTP sent successfully',
        };
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'message': errorData['message'] ?? 'Failed to send OTP',
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Server error: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      print('❌ Send OTP error: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> verifyOTP(String email, String otp) async {
    try {
      final url = Uri.parse(getVerifyOtpUrl());
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'otp': otp.trim(),
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      print('📡 Verify OTP Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? 'OTP verified',
        };
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'message': errorData['message'] ?? 'Invalid OTP',
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Server error: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      print('❌ Verify OTP error: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> resetPasswordWithOTP(
    String email,
    String otp,
    String newPassword,
  ) async {
    try {
      if (!_isStrongPassword(newPassword)) {
        return {
          'success': false,
          'message': 'Password must be at least 6 characters',
        };
      }

      final url = Uri.parse(getResetPasswordUrl());
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email.trim(),
          'otp': otp.trim(),
          'newPassword': newPassword.trim(),
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      print('📡 Reset Password Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          print('✅ Password reset successfully');
          return {
            'success': true,
            'message': data['message'] ?? 'Password reset successful',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to reset password',
          };
        }
      } else if (response.statusCode == 400) {
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'message': errorData['message'] ?? 'Invalid request',
          };
        } catch (_) {
          return {'success': false, 'message': 'Invalid request (400)'};
        }
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthorized - OTP may be expired',
        };
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Reset password error: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    final result = await sendPasswordResetEmailFull(email);
    return result['success'] == true;
  }

  Future<Map<String, dynamic>> verifyResetToken(String token) async {
    try {
      final db = await _mongoService.getDatabase();
      final users = db.collection('users');

      final userDoc = await users.findOne(where.eq('resetToken', token));

      if (userDoc == null) {
        return {'success': false, 'message': 'Invalid reset token'};
      }

      final expiry = DateTime.parse(userDoc['resetTokenExpiry']);
      if (DateTime.now().isAfter(expiry)) {
        return {'success': false, 'message': 'Reset token expired'};
      }

      return {'success': true, 'email': userDoc['email']};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resetPasswordWithToken(
      String token, String newPassword) async {
    try {
      final verify = await verifyResetToken(token);
      if (!verify['success']) return verify;

      final email = verify['email'];

      final db = await _mongoService.getDatabase();
      final users = db.collection('users');

      final result = await users.updateOne(
        where.eq('email', email.toLowerCase()),
        modify
            .set('password', _hashPassword(newPassword))
            .unset('resetToken')
            .unset('resetTokenExpiry'),
      );

      if (result.isSuccess) {
        return {'success': true, 'message': 'Password reset successful'};
      }

      return {'success': false, 'message': 'Failed to reset password'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resetPasswordDirect(
    String email,
    String newPassword,
  ) async {
    try {
      if (!_isStrongPassword(newPassword)) {
        return {
          'success': false,
          'message': 'Password must be at least 6 characters',
        };
      }

      final db = await _mongoService.getDatabase();
      final users = db.collection('users');

      final result = await users.updateOne(
        where.eq('email', email.toLowerCase()),
        modify.set('password', _hashPassword(newPassword)),
      );

      if (result.isSuccess) {
        print('✅ Password updated directly');
        return {
          'success': true,
          'message': 'Password reset successful',
        };
      }

      return {'success': false, 'message': 'Failed to update password'};
    } catch (e) {
      print('❌ Direct password update error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<UserModel?> getUserById(String userId) async {
    try {
      final db = await _mongoService.getDatabase();
      final users = db.collection('users');

      final userDoc = await users.findOne(where.id(ObjectId.fromHexString(userId)));

      if (userDoc != null) return UserModel.fromMap(userDoc);
      return null;
    } catch (e) {
      print('❌ Error getting user by ID: $e');
      return null;
    }
  }

  Future<bool> emailExists(String email) async {
    try {
      final db = await _mongoService.getDatabase();
      final users = db.collection('users');

      final user = await users.findOne(where.eq('email', email.toLowerCase()));

      return user != null;
    } catch (e) {
      print('❌ Error checking email existence: $e');
      return false;
    }
  }

  Future<bool> updatePassword(String email, String newPassword) async {
    try {
      final db = await _mongoService.getDatabase();
      final users = db.collection('users');

      final result = await users.updateOne(
        where.eq('email', email.toLowerCase()),
        modify.set('password', _hashPassword(newPassword)),
      );

      return result.isSuccess;
    } catch (e) {
      print('❌ Error updating password: $e');
      return false;
    }
  }
}