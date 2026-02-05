import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mongo_dart/mongo_dart.dart';
import './session_service.dart';
import './mongodb_service.dart';
import '../../models/user_model.dart';

class UserService {
  final SessionService _sessionService = SessionService();
  final MongoDBService _mongoService = MongoDBService();

  // Get current user from session (no API call needed)
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      print('🔄 Getting user from session...');

      final user = await _sessionService.getCurrentUser();

      if (user == null) {
        throw Exception('No user session found. Please login again.');
      }

      // Convert UserModel to Map
      final userData = {
        '_id': user.id?.toHexString() ?? '',
        'id': user.id?.toHexString() ?? '',
        'name': user.personalDetails['fullName'] ?? user.personalDetails['name'] ?? 'User',
        'email': user.email,
        'phone': user.personalDetails['phone'] ?? '',
        'role': user.userType,
        'personalDetails': user.personalDetails,
      };

      await _cacheUserData(userData);
      print('✅ User data retrieved from session');
      return userData;
    } catch (e) {
      print('❌ Error getting user: $e');

      // Try cached data
      final cachedData = await _getCachedUserData();
      if (cachedData != null) {
        print('📦 Using cached user data');
        return cachedData;
      }

      rethrow;
    }
  }

  // Update user profile
  Future<Map<String, dynamic>> updateUserProfile({
    String? name,
    String? email,
    String? phone,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      print('🔄 Updating user profile...');

      // ⭐ STEP 1: Try to get user from session
      var user = await _sessionService.getCurrentUser();

      // ⭐ STEP 2: If no session, try to rebuild from cache
      if (user == null) {
        print('⚠️ No session found, attempting to recover from cache...');

        final cachedData = await _getCachedUserData();
        if (cachedData == null || cachedData['id'] == null) {
          throw Exception('No user session found. Please login again.');
        }

        print('📦 Rebuilding user from cached data...');

        // Rebuild UserModel from cached data
        final personalDetails = cachedData['personalDetails'] as Map<String, dynamic>? ?? {
          'fullName': cachedData['name'],
          'name': cachedData['name'],
          'phone': cachedData['phone'] ?? '',
        };

        user = UserModel(
          id: ObjectId.fromHexString(cachedData['id']),
          userType: cachedData['role'] ?? 'tenant',
          email: cachedData['email'],
          password: '', // Not needed for updates
          personalDetails: personalDetails,
          createdAt: DateTime.now(),
        );

        // Save recovered session
        final token = await _sessionService.getToken();
        await _sessionService.saveSession(user, token: token);
        print('✅ Session recovered from cache');
      }

      if (user.id == null) {
        throw Exception('Invalid user ID');
      }

      print('📝 Current user: ${user.email}');
      print('📝 User ID: ${user.id?.toHexString()}');

      // Update personal details
      final updatedPersonalDetails = Map<String, dynamic>.from(user.personalDetails);
      if (name != null) {
        updatedPersonalDetails['fullName'] = name;
        updatedPersonalDetails['name'] = name;
      }
      if (phone != null) {
        updatedPersonalDetails['phone'] = phone;
      }
      if (additionalData != null) {
        updatedPersonalDetails.addAll(additionalData);
      }

      // ⭐ UPDATE IN MONGODB
      try {
        final db = await _mongoService.getDatabase();
        final usersCollection = db.collection('users');

        print('📝 Updating in MongoDB with ID: ${user.id?.toHexString()}');

        final result = await usersCollection.updateOne(
          where.id(user.id!),
          modify
              .set('email', email ?? user.email)
              .set('personalDetails', updatedPersonalDetails)
              .set('updatedAt', DateTime.now()),
        );

        print('📝 MongoDB update result: isSuccess=${result.isSuccess}, nModified=${result.nModified}');

        if (!result.isSuccess) {
          throw Exception('Failed to update user in database');
        }

        if (result.nModified == 0) {
          print('⚠️ No documents were modified in MongoDB');
        } else {
          print('✅ User updated in MongoDB');
        }
      } catch (mongoError) {
        print('❌ MongoDB update error: $mongoError');
        throw Exception('Failed to update database: $mongoError');
      }

      // Create updated user
      final updatedUser = user.copyWith(
        email: email ?? user.email,
        personalDetails: updatedPersonalDetails,
        updatedAt: DateTime.now(),
      );

      // Save to session
      await _sessionService.updateSession(updatedUser);

      // Return as Map
      final userData = {
        '_id': updatedUser.id?.toHexString() ?? '',
        'id': updatedUser.id?.toHexString() ?? '',
        'name': updatedPersonalDetails['fullName'] ?? updatedPersonalDetails['name'] ?? 'User',
        'email': updatedUser.email,
        'phone': updatedPersonalDetails['phone'] ?? '',
        'role': updatedUser.userType,
        'personalDetails': updatedPersonalDetails,
      };

      await _cacheUserData(userData);
      print('✅ User profile updated successfully');
      print('📝 Updated name: ${userData['name']}');
      return userData;
    } catch (e, stackTrace) {
      print('❌ Error updating user profile: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _cacheUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_data', json.encode(userData));
      await prefs.setString('user_id', userData['_id'] ?? userData['id'] ?? '');
      await prefs.setString('user_name', userData['name'] ?? '');
      await prefs.setString('user_email', userData['email'] ?? '');

      print('💾 User data cached locally');
    } catch (e) {
      print('⚠️ Error caching user data: $e');
    }
  }

  Future<Map<String, dynamic>?> _getCachedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_user_data');

      if (cachedData != null) {
        return json.decode(cachedData);
      }
      return null;
    } catch (e) {
      print('⚠️ Error getting cached user data: $e');
      return null;
    }
  }

  Future<Map<String, String>> getCachedUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'id': prefs.getString('user_id') ?? '',
      'name': prefs.getString('user_name') ?? 'User',
      'email': prefs.getString('user_email') ?? '',
    };
  }

  Future<bool> isLoggedIn() async {
    return await _sessionService.isLoggedIn();
  }

  Future<void> logout() async {
    await _sessionService.clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_user_data');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    print('👋 User logged out');
  }

  Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _cacheUserData(userData);
  }
}