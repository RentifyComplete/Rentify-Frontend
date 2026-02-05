import 'package:mongo_dart/mongo_dart.dart';
import './mongodb_service.dart';

class PropertiesService {
  final MongoDBService _mongoService = MongoDBService();

  // Get all properties (admin use)
  Future<List<Map<String, dynamic>>> getAllProperties() async {
    try {
      print('🔄 Fetching all properties from MongoDB...');
      final db = await _mongoService.getDatabase();
      final propertiesCollection = db.collection('properties');

      final properties = await propertiesCollection.find().toList();

      print('✅ Fetched ${properties.length} properties from database');
      return properties;
    } catch (e) {
      print('❌ Error fetching properties: $e');
      rethrow;
    }
  }

  // Get properties by owner ID - NEW METHOD
  Future<List<Map<String, dynamic>>> getPropertiesByOwnerId(String ownerId) async {
    try {
      print('🔄 Fetching properties for owner: $ownerId');
      final db = await _mongoService.getDatabase();
      final propertiesCollection = db.collection('properties');

      // Filter properties by ownerId
      final properties = await propertiesCollection.find(
        where.eq('ownerId', ownerId)
      ).toList();

      print('✅ Fetched ${properties.length} properties for owner: $ownerId');
      return properties;
    } catch (e) {
      print('❌ Error fetching properties by owner: $e');
      rethrow;
    }
  }

  // Get property by ID
  Future<Map<String, dynamic>?> getPropertyById(String propertyId) async {
    try {
      print('🔄 Fetching property: $propertyId');
      final db = await _mongoService.getDatabase();
      final propertiesCollection = db.collection('properties');

      final property = await propertiesCollection.findOne(
        where.id(ObjectId.fromHexString(propertyId)),
      );

      if (property != null) {
        print('✅ Property found: ${property['title']}');
      } else {
        print('⚠️ Property not found');
      }

      return property;
    } catch (e) {
      print('❌ Error fetching property: $e');
      rethrow;
    }
  }
}