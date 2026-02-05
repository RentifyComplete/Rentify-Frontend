import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_model.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class SessionService {
  static const String _userKey = 'current_user';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _tokenKey = 'auth_token';
  static const String _rememberMeKey = 'remember_me';
  static const String _lastActiveKey = 'last_active';
  static const String _sessionIdKey = 'session_id';
  static const String _logoutFlagKey = 'just_logged_out'; // NEW: Logout flag
  
  static const Duration _sessionTimeout = Duration(days: 30);

  /// Save user session with proper type conversion
  Future<bool> saveSession(UserModel user, {String? token, bool rememberMe = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

      // Convert user to Map and sanitize for JSON
      Map<String, dynamic> userMap = user.toMap();
      userMap = _sanitizeForJson(userMap);
      
      final userJson = jsonEncode(userMap);

      final userSaved = await prefs.setString(_userKey, userJson);
      final loginSaved = await prefs.setBool(_isLoggedInKey, true);
      final rememberSaved = await prefs.setBool(_rememberMeKey, rememberMe);
      final activeSaved = await prefs.setString(_lastActiveKey, DateTime.now().toIso8601String());
      final sessionSaved = await prefs.setString(_sessionIdKey, sessionId);
      
      // Clear logout flag when saving new session
      await prefs.remove(_logoutFlagKey);

      bool tokenSaved = true;
      if (token != null) {
        tokenSaved = await prefs.setString(_tokenKey, token);
      }

      final allSaved = userSaved && loginSaved && rememberSaved && activeSaved && sessionSaved && tokenSaved;

      if (allSaved) {
        print('✅ Session saved successfully');
        print('   Remember Me: $rememberMe');
        print('   Session ID: $sessionId');
        print('   User: ${user.email}');
      }

      return allSaved;
    } catch (e, stackTrace) {
      print('❌ Error saving session: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// ✅ Convert complex types to JSON-safe types
  Map<String, dynamic> _sanitizeForJson(Map<String, dynamic> map) {
    final sanitized = <String, dynamic>{};
    
    map.forEach((key, value) {
      if (value == null) {
        sanitized[key] = null;
      } else if (value is DateTime) {
        sanitized[key] = value.toIso8601String();
      } else if (value is mongo.ObjectId) {
        sanitized[key] = value.toHexString();
      } else if (value is Map) {
        sanitized[key] = _sanitizeForJson(value as Map<String, dynamic>);
      } else if (value is List) {
        sanitized[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _sanitizeForJson(item);
          } else if (item is DateTime) {
            return item.toIso8601String();
          } else if (item is mongo.ObjectId) {
            return item.toHexString();
          }
          return item;
        }).toList();
      } else {
        sanitized[key] = value;
      }
    });
    
    return sanitized;
  }

  /// ✅ Reconstruct complex types from JSON
  Map<String, dynamic> _reconstructFromJson(Map<String, dynamic> map) {
    final reconstructed = <String, dynamic>{};
    
    // Known DateTime fields in UserModel
    final dateTimeFields = ['createdAt', 'updatedAt', 'lastLogin', 'dateOfBirth', 'verifiedAt'];
    // Known ObjectId fields
    final objectIdFields = ['_id', 'id', 'ownerId', 'propertyId', 'userId'];
    
    map.forEach((key, value) {
      if (value == null) {
        reconstructed[key] = null;
      } else if (dateTimeFields.contains(key) && value is String) {
        // ✅ Reconstruct DateTime from string
        try {
          reconstructed[key] = DateTime.parse(value);
        } catch (e) {
          reconstructed[key] = value; // Keep as string if parsing fails
        }
      } else if (objectIdFields.contains(key) && value is String) {
        // ✅ Reconstruct ObjectId from string
        try {
          reconstructed[key] = mongo.ObjectId.fromHexString(value);
        } catch (e) {
          reconstructed[key] = value; // Keep as string if parsing fails
        }
      } else if (value is Map) {
        // Recursively reconstruct nested maps
        reconstructed[key] = _reconstructFromJson(value as Map<String, dynamic>);
      } else if (value is List) {
        // Reconstruct lists
        reconstructed[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _reconstructFromJson(item);
          }
          return item;
        }).toList();
      } else {
        reconstructed[key] = value;
      }
    });
    
    return reconstructed;
  }

  /// Get current user with proper type reconstruction
  Future<UserModel?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);

      if (userJson == null) {
        print('⚠️ No user data found in storage');
        return null;
      }

      // Parse JSON
      final userMap = jsonDecode(userJson) as Map<String, dynamic>;
      
      // ✅ Reconstruct all complex types
      final reconstructedMap = _reconstructFromJson(userMap);
      
      // Parse and return user
      final user = UserModel.fromMap(reconstructedMap);

      print('✅ User retrieved: ${user.email}');
      return user;
    } catch (e, stackTrace) {
      print('❌ Error getting current user: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (token != null) {
        print('✅ Token retrieved');
      } else {
        print('⚠️ No token found');
      }
      return token;
    } catch (e) {
      print('❌ Error getting token: $e');
      return null;
    }
  }

  Future<String?> getAuthToken() async {
    return await getToken();
  }

  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userKey) != null;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isRememberMeEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_rememberMeKey) ?? true;
    } catch (e) {
      return true;
    }
  }

  /// NEW: Check if user just logged out
  Future<bool> hasJustLoggedOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loggedOut = prefs.getBool(_logoutFlagKey) ?? false;
      
      if (loggedOut) {
        print('🚩 Logout flag detected - preventing auto-login');
        // Clear the flag after reading it
        await prefs.remove(_logoutFlagKey);
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Error checking logout flag: $e');
      return false;
    }
  }

  /// NEW: Set logout flag
  Future<void> setLogoutFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_logoutFlagKey, true);
      print('🚩 Logout flag set');
    } catch (e) {
      print('❌ Error setting logout flag: $e');
    }
  }

  Future<bool> shouldRestoreSessionOnAppRestart() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      print('🔍 Checking session restoration...');

      // NEW: Check if user just logged out
      final justLoggedOut = await hasJustLoggedOut();
      if (justLoggedOut) {
        print('   🚫 User just logged out - skipping session restore');
        return false;
      }

      final rememberMe = prefs.getBool(_rememberMeKey);
      print('   Remember Me: $rememberMe');

      if (rememberMe != true) {
        print('   ❌ Remember Me is disabled');
        return false;
      }

      final userJson = prefs.getString(_userKey);
      final token = prefs.getString(_tokenKey);

      print('   User data exists: ${userJson != null}');
      print('   Token exists: ${token != null}');

      if (userJson == null || token == null) {
        print('   ❌ Missing user data or token');
        return false;
      }

      try {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        if (userMap['email'] == null) {
          print('   ❌ Invalid user data structure');
          return false;
        }
      } catch (e) {
        print('   ❌ Corrupt user data: $e');
        await clearSession();
        return false;
      }

      final lastActiveStr = prefs.getString(_lastActiveKey);
      if (lastActiveStr != null) {
        try {
          final lastActive = DateTime.parse(lastActiveStr);
          final now = DateTime.now();
          final difference = now.difference(lastActive);

          print('   Last active: ${difference.inDays} days ago');

          if (difference > _sessionTimeout) {
            print('   ❌ Session expired (${difference.inDays} days)');
            await clearSession();
            return false;
          }
        } catch (e) {
          print('   ⚠️ Invalid last active date: $e');
        }
      }

      print('   ✅ Session can be restored');
      return true;
    } catch (e) {
      print('❌ Error checking session: $e');
      return false;
    }
  }

  Future<bool> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Set logout flag FIRST before clearing anything
      await setLogoutFlag();
      
      // Then clear all session data
      await prefs.remove(_userKey);
      await prefs.remove(_tokenKey);
      await prefs.remove(_rememberMeKey);
      await prefs.remove(_lastActiveKey);
      await prefs.remove(_sessionIdKey);
      await prefs.setBool(_isLoggedInKey, false);

      print('✅ Session cleared successfully');
      return true;
    } catch (e) {
      print('❌ Error clearing session: $e');
      return false;
    }
  }

  Future<bool> clearSessionIfNotRemembered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool(_rememberMeKey) ?? true;

      print('🔍 Checking if session should be cleared...');
      print('   Remember Me: $rememberMe');

      if (!rememberMe) {
        print('   ℹ️ Remember Me disabled - clearing session');
        await clearSession();
        return true;
      } else {
        print('   ✅ Remember Me enabled - keeping session');
      }

      return false;
    } catch (e) {
      print('❌ Error in clearSessionIfNotRemembered: $e');
      return false;
    }
  }

  Future<void> updateLastActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastActiveKey, DateTime.now().toIso8601String());
      print('✅ Last active updated');
    } catch (e) {
      print('❌ Error updating last active: $e');
    }
  }

  Future<void> debugPrintSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      print('\n========== SESSION DEBUG ==========');
      print('User exists: ${prefs.getString(_userKey) != null}');
      print('Token exists: ${prefs.getString(_tokenKey) != null}');
      print('Remember Me: ${prefs.getBool(_rememberMeKey)}');
      print('Last Active: ${prefs.getString(_lastActiveKey)}');
      print('Session ID: ${prefs.getString(_sessionIdKey)}');
      print('Is Logged In: ${prefs.getBool(_isLoggedInKey)}');
      print('Logout Flag: ${prefs.getBool(_logoutFlagKey)}'); // NEW
      
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        try {
          final userMap = jsonDecode(userJson);
          print('User email: ${userMap['email']}');
          print('User type: ${userMap['userType']}');
        } catch (e) {
          print('⚠️ Could not parse user data: $e');
        }
      }
      
      print('===================================\n');
    } catch (e) {
      print('❌ Error printing debug data: $e');
    }
  }

  Future<bool> getRememberMePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_rememberMeKey) ?? true;
    } catch (e) {
      return true;
    }
  }

  Future<bool> updateSession(UserModel user) async {
    try {
      final token = await getToken();
      final rememberMe = await isRememberMeEnabled();

      print('🔄 Updating session...');
      print('   User: ${user.email}');

      return await saveSession(user, token: token, rememberMe: rememberMe);
    } catch (e) {
      print('❌ Error updating session: $e');
      return false;
    }
  }

  Future<String?> getUserType() async {
    final user = await getCurrentUser();
    return user?.userType;
  }

  Future<String?> getUserId() async {
    final user = await getCurrentUser();
    return user?.id?.toHexString();
  }

  Future<String?> getUserEmail() async {
    final user = await getCurrentUser();
    return user?.email;
  }

  Future<Map<String, dynamic>?> getSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool(_rememberMeKey) ?? true;

      if (!rememberMe) {
        return null;
      }

      final user = await getCurrentUser();
      if (user == null) return null;

      final token = await getToken();

      return {
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
      };
    } catch (e) {
      print('❌ Error getting session: $e');
      return null;
    }
  }

  Future<UserModel?> getUserIfRemembered() async {
    try {
      final shouldRestore = await shouldRestoreSessionOnAppRestart();
      if (!shouldRestore) return null;
      return await getCurrentUser();
    } catch (e) {
      return null;
    }
  }

  Future<bool> isSessionValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastActiveStr = prefs.getString(_lastActiveKey);
      if (lastActiveStr == null) return true;

      final lastActive = DateTime.parse(lastActiveStr);
      final now = DateTime.now();
      return now.difference(lastActive) <= _sessionTimeout;
    } catch (e) {
      return true;
    }
  }

  Future<int> getSessionAge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastActiveStr = prefs.getString(_lastActiveKey);
      if (lastActiveStr == null) return 0;

      final lastActive = DateTime.parse(lastActiveStr);
      return DateTime.now().difference(lastActive).inDays;
    } catch (e) {
      return 0;
    }
  }

  Future<void> refreshSession() async {
    try {
      await updateLastActive();
      print('✅ Session refreshed');
    } catch (e) {
      print('❌ Error refreshing session: $e');
    }
  }
}