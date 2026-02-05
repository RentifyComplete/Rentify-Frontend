// lib/services/property_service.dart

import 'package:mongo_dart/mongo_dart.dart';
import 'mongodb_service.dart';

class PropertyService {
  final MongoDBService _mongoService = MongoDBService();
  static const String _collectionName = 'properties';

  // Connection with retry logic
  Future<bool> _ensureConnection({int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        if (_mongoService.isConnected) {
          return true;
        }

        print('🔄 Attempt ${i + 1}/$maxRetries: Connecting to MongoDB...');
        await _mongoService.connect();

        if (_mongoService.isConnected) {
          print('✅ Connected successfully');
          return true;
        }

        // Wait before retry
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2));
        }
      } catch (e) {
        print('❌ Connection attempt ${i + 1} failed: $e');
        if (i == maxRetries - 1) {
          return false;
        }
        await Future.delayed(Duration(seconds: 2));
      }
    }
    return false;
  }

  // ✅ Get all properties (for owner dashboard)
  Future<List<Map<String, dynamic>>> getAllProperties() async {
    print('\n🔄 ==================== GET ALL PROPERTIES START ====================');
    try {
      // Try to connect with retry
      final connected = await _ensureConnection();
      if (!connected) {
        print('❌ Failed to connect to database after retries');
        print('💡 Returning empty list');
        return [];
      }

      print('🔍 Fetching properties from collection: $_collectionName');
      final collection = _mongoService.database!.collection(_collectionName);

      final totalCount = await collection.count();
      print('📊 Total properties in database: $totalCount');

      if (totalCount == 0) {
        print('⚠️ No properties found in database');
        return [];
      }

      final properties = await collection.find().toList();
      print('✅ Fetched ${properties.length} properties');

      // Convert ObjectIds to strings
      final convertedProperties = properties.map((property) {
        if (property['_id'] is ObjectId) {
          property['_id'] = (property['_id'] as ObjectId).toHexString();
        }
        return property;
      }).toList();

      if (convertedProperties.isNotEmpty) {
        print('📋 Properties Summary:');
        for (int i = 0; i < convertedProperties.length && i < 5; i++) {
          final prop = convertedProperties[i];
          print('   ${i + 1}. ${prop['title']} - ${prop['price']}');
        }
        if (convertedProperties.length > 5) {
          print('   ... and ${convertedProperties.length - 5} more');
        }
      }

      print('🔄 ==================== GET ALL PROPERTIES END (SUCCESS) ====================\n');
      return convertedProperties;

    } catch (e, stackTrace) {
      print('❌ ==================== ERROR IN GET ALL PROPERTIES ====================');
      print('❌ Error: $e');
      print('❌ Stack trace: $stackTrace');
      print('❌ ==================== ERROR END ====================\n');

      // Return empty list instead of throwing
      return [];
    }
  }

  // ✅ NEW METHOD: Get properties by owner ID
  Future<List<Map<String, dynamic>>> getPropertiesByOwnerId(String ownerId) async {
    print('\n🔄 ==================== GET PROPERTIES BY OWNER ID START ====================');
    print('👤 Owner ID: $ownerId');
    
    try {
      final connected = await _ensureConnection();
      if (!connected) {
        print('❌ Failed to connect to database');
        return [];
      }

      final collection = _mongoService.database!.collection(_collectionName);

      // Query properties by ownerId field
      final properties = await collection
          .find(where.eq('ownerId', ownerId))
          .toList();

      print('✅ Fetched ${properties.length} properties for owner: $ownerId');

      // Convert ObjectIds to strings
      final convertedProperties = properties.map((property) {
        if (property['_id'] is ObjectId) {
          property['_id'] = (property['_id'] as ObjectId).toHexString();
        }
        return property;
      }).toList();

      if (convertedProperties.isNotEmpty) {
        print('📋 Owner Properties Summary:');
        for (int i = 0; i < convertedProperties.length && i < 5; i++) {
          final prop = convertedProperties[i];
          print('   ${i + 1}. ${prop['title']} - ${prop['price']}');
        }
        if (convertedProperties.length > 5) {
          print('   ... and ${convertedProperties.length - 5} more');
        }
      } else {
        print('⚠️ No properties found for owner: $ownerId');
      }

      print('🔄 ==================== GET PROPERTIES BY OWNER ID END ====================\n');
      return convertedProperties;

    } catch (e, stackTrace) {
      print('❌ Error in getPropertiesByOwnerId: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // ✅ Get all active properties (for tenant dashboard and featured properties)
  Future<List<Map<String, dynamic>>> getAllActiveProperties() async {
    print('\n🔄 ==================== GET ACTIVE PROPERTIES START ====================');
    try {
      final connected = await _ensureConnection();
      if (!connected) {
        print('❌ Failed to connect to database');
        return [];
      }

      final collection = _mongoService.database!.collection(_collectionName);

      final totalCount = await collection.count();
      print('📊 Total properties: $totalCount');

      if (totalCount == 0) {
        print('⚠️ Database is empty');
        return [];
      }

      final activeCount = await collection.count(where.eq('isActive', true));
      print('📊 Active properties: $activeCount');

      final properties = await collection
          .find(where.eq('isActive', true))
          .toList();

      print('✅ Fetched ${properties.length} active properties');

      final convertedProperties = properties.map((property) {
        if (property['_id'] is ObjectId) {
          property['_id'] = (property['_id'] as ObjectId).toHexString();
        }
        return property;
      }).toList();

      if (convertedProperties.isNotEmpty) {
        print('📋 Active Properties Summary:');
        for (int i = 0; i < convertedProperties.length && i < 3; i++) {
          final prop = convertedProperties[i];
          print('   ${i + 1}. ${prop['title']} - ${prop['city']}, ${prop['state']}');
        }
      }

      print('🔄 ==================== GET ACTIVE PROPERTIES END ====================\n');
      return convertedProperties;

    } catch (e, stackTrace) {
      print('❌ Error in getAllActiveProperties: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // ✅ Add new property
  Future<Map<String, dynamic>> addProperty(Map<String, dynamic> propertyData) async {
    try {
      print('➕ ==================== ADD PROPERTY START ====================');
      print('➕ Property: ${propertyData['title']}');

      final connected = await _ensureConnection();
      if (!connected) {
        return {
          'success': false,
          'message': 'Could not connect to database',
          'data': null,
        };
      }

      final collection = _mongoService.database!.collection(_collectionName);

      // Add metadata
      propertyData['createdAt'] = DateTime.now().toIso8601String();
      propertyData['updatedAt'] = DateTime.now().toIso8601String();
      propertyData['isActive'] = true;
      propertyData['isVerified'] = propertyData['isVerified'] ?? false;

      // Generate unique ObjectId
      final objectId = ObjectId();
      propertyData['_id'] = objectId;

      print('➕ Inserting property with ID: ${objectId.toHexString()}');
      final result = await collection.insertOne(propertyData);

      if (result.isSuccess) {
        print('✅ Property added successfully');
        print('➕ ==================== ADD PROPERTY END ====================\n');
        return {
          'success': true,
          'message': 'Property added successfully',
          'data': {...propertyData, '_id': objectId.toHexString()},
        };
      } else {
        throw Exception('Insert operation failed');
      }
    } catch (e, stackTrace) {
      print('❌ Error adding property: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Failed to add property: $e',
        'data': null,
      };
    }
  }

  // ✅ Get single property by ID
  Future<Map<String, dynamic>?> getPropertyById(String id) async {
    try {
      print('🔍 Fetching property by ID: $id');

      final connected = await _ensureConnection();
      if (!connected) {
        print('❌ Database connection failed');
        return null;
      }

      final collection = _mongoService.database!.collection(_collectionName);
      final property = await collection.findOne(
          where.eq('_id', ObjectId.fromHexString(id))
      );

      if (property != null) {
        if (property['_id'] is ObjectId) {
          property['_id'] = (property['_id'] as ObjectId).toHexString();
        }
        print('✅ Property found: ${property['title']}');
      } else {
        print('⚠️ Property not found with ID: $id');
      }

      return property;
    } catch (e) {
      print('❌ Error fetching property by ID: $e');
      return null;
    }
  }

  // ✅ Update property - CORRECTED VERSION
  Future<Map<String, dynamic>> updateProperty(
      String propertyId,
      Map<String, dynamic> updates,
      ) async {
    try {
      print('🔄 ==================== UPDATE PROPERTY START ====================');
      print('🔄 Property ID: $propertyId');
      print('📦 Updates: $updates');

      final connected = await _ensureConnection();
      if (!connected) {
        return {
          'success': false,
          'message': 'Could not connect to database',
        };
      }

      final collection = _mongoService.database!.collection(_collectionName);

      // Parse the ObjectId
      ObjectId objectId;
      try {
        objectId = ObjectId.fromHexString(propertyId);
      } catch (e) {
        print('❌ Invalid ObjectId format: $propertyId');
        return {
          'success': false,
          'message': 'Invalid property ID format',
        };
      }

      // Add updated timestamp
      updates['updatedAt'] = DateTime.now().toIso8601String();

      // Create modifier using mongo_dart's modify builder
      final modifier = modify;
      updates.forEach((key, value) {
        modifier.set(key, value);
      });

      print('🔄 Executing update operation...');
      final result = await collection.updateOne(
        where.id(objectId),
        modifier,
      );

      print('📊 Update result - Modified: ${result.nModified}, Matched: ${result.nMatched}');

      if (result.nModified > 0 || result.nMatched > 0) {
        print('✅ Property updated successfully');
        print('🔄 ==================== UPDATE PROPERTY END (SUCCESS) ====================\n');
        return {
          'success': true,
          'message': 'Property updated successfully',
          'data': {'_id': propertyId, ...updates},
        };
      } else {
        print('⚠️ Property not found or no changes made');
        print('🔄 ==================== UPDATE PROPERTY END (NO CHANGES) ====================\n');
        return {
          'success': false,
          'message': 'Property not found or no changes were needed',
        };
      }
    } catch (e, stackTrace) {
      print('❌ ==================== ERROR IN UPDATE PROPERTY ====================');
      print('❌ Error: $e');
      print('❌ Stack trace: $stackTrace');
      print('❌ ==================== ERROR END ====================\n');
      return {
        'success': false,
        'message': 'Error updating property: $e',
      };
    }
  }

  // ✅ Delete property
  Future<Map<String, dynamic>> deleteProperty(String propertyId) async {
    try {
      print('🗑️ Attempting to delete property: $propertyId');

      if (propertyId.isEmpty) {
        return {'success': false, 'message': 'Property ID cannot be empty'};
      }

      final connected = await _ensureConnection();
      if (!connected) {
        return {
          'success': false,
          'message': 'Could not connect to database',
        };
      }

      final collection = _mongoService.database!.collection(_collectionName);

      ObjectId objectId;
      try {
        objectId = ObjectId.fromHexString(propertyId);
      } catch (e) {
        return {
          'success': false,
          'message': 'Invalid property ID format',
        };
      }

      final result = await collection.deleteOne(where.id(objectId));

      if (result.nRemoved > 0) {
        print('✅ Property deleted successfully');
        return {'success': true, 'message': 'Property deleted successfully'};
      } else {
        print('⚠️ No property found with ID: $propertyId');
        return {'success': false, 'message': 'Property not found'};
      }
    } catch (e) {
      print('❌ Error deleting property: $e');
      return {'success': false, 'message': 'Error deleting property: $e'};
    }
  }

  // ✅ Search properties
  Future<List<Map<String, dynamic>>> searchProperties(String query) async {
    try {
      print('🔍 Searching properties with query: "$query"');

      final connected = await _ensureConnection();
      if (!connected) {
        return [];
      }

      final collection = _mongoService.database!.collection(_collectionName);

      final properties = await collection
          .find(where.eq('isActive', true))
          .toList();

      final filteredProperties = properties.where((property) {
        final title = property['title']?.toString().toLowerCase() ?? '';
        final location = property['location']?.toString().toLowerCase() ?? '';
        final city = property['city']?.toString().toLowerCase() ?? '';
        final state = property['state']?.toString().toLowerCase() ?? '';
        final type = property['type']?.toString().toLowerCase() ?? '';
        final searchQuery = query.toLowerCase();

        return title.contains(searchQuery) ||
            location.contains(searchQuery) ||
            city.contains(searchQuery) ||
            state.contains(searchQuery) ||
            type.contains(searchQuery);
      }).toList();

      print('✅ Found ${filteredProperties.length} matching properties');

      return filteredProperties.map((property) {
        if (property['_id'] is ObjectId) {
          property['_id'] = (property['_id'] as ObjectId).toHexString();
        }
        return property;
      }).toList();
    } catch (e) {
      print('❌ Error searching properties: $e');
      return [];
    }
  }

  // ✅ Get database statistics
  Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      final connected = await _ensureConnection();
      if (!connected) {
        return {
          'total': 0,
          'active': 0,
          'verified': 0,
          'inactive': 0,
          'error': 'Not connected',
        };
      }

      final collection = _mongoService.database!.collection(_collectionName);

      final totalCount = await collection.count();
      final activeCount = await collection.count(where.eq('isActive', true));
      final verifiedCount = await collection.count(where.eq('isVerified', true));

      return {
        'total': totalCount,
        'active': activeCount,
        'verified': verifiedCount,
        'inactive': totalCount - activeCount,
      };
    } catch (e) {
      print('❌ Error getting database stats: $e');
      return {
        'total': 0,
        'active': 0,
        'verified': 0,
        'inactive': 0,
        'error': e.toString(),
      };
    }
  }

  // ✅ Close connection
  Future<void> close() async {
    try {
      await _mongoService.close();
      print('✅ MongoDB connection closed');
    } catch (e) {
      print('❌ Error closing connection: $e');
    }
  }
}