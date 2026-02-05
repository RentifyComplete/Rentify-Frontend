// lib/services/tenant_service.dart

import 'package:mongo_dart/mongo_dart.dart';
import 'mongodb_service.dart';

class TenantService {
  final MongoDBService _mongoService = MongoDBService();

  /// Get tenant by ID with all details including Cloudinary document URLs
  Future<Map<String, dynamic>?> getTenantById(String tenantId) async {
    try {
      print('🔍 TenantService: Fetching tenant with ID: $tenantId');
      
      final db = await _mongoService.getDatabase();
      final tenantsCollection = db.collection('tenants');

      // Try to parse as ObjectId
      ObjectId? objectId;
      try {
        objectId = ObjectId.fromHexString(tenantId);
      } catch (e) {
        print('⚠️ Invalid ObjectId format: $tenantId, trying as string');
        // If ObjectId parsing fails, try finding by string ID
        final tenantDoc = await tenantsCollection.findOne(where.eq('_id', tenantId));
        if (tenantDoc != null) {
          print('✅ Tenant found using string ID');
          _logDocumentDetails(tenantDoc);
          return tenantDoc;
        }
        return null;
      }

      // Fetch tenant from database using ObjectId
      final tenantDoc = await tenantsCollection.findOne(where.id(objectId));

      if (tenantDoc == null) {
        print('❌ Tenant not found with ID: $tenantId');
        return null;
      }

      print('✅ Tenant found: ${tenantDoc['name']}');
      _logDocumentDetails(tenantDoc);

      return tenantDoc;
    } catch (e) {
      print('❌ Error fetching tenant by ID: $e');
      return null;
    }
  }

  /// Log document details for debugging (shows Cloudinary URLs)
  void _logDocumentDetails(Map<String, dynamic> tenantDoc) {
    if (tenantDoc['documents'] != null) {
      final docs = Map<String, dynamic>.from(tenantDoc['documents']);
      print('📄 Document fields in database (${docs.length} total):');
      
      docs.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty && value.toString() != 'null') {
          final valueStr = value.toString();
          // Check if it's a Cloudinary URL
          final isCloudinaryUrl = valueStr.contains('cloudinary.com') || valueStr.contains('res.cloudinary');
          final displayValue = valueStr.length > 60 ? '${valueStr.substring(0, 60)}...' : valueStr;
          
          if (isCloudinaryUrl) {
            print('   ✓ $key: [Cloudinary] $displayValue');
          } else {
            print('   ✓ $key: $displayValue');
          }
        } else {
          print('   ✗ $key: [empty]');
        }
      });
    } else {
      print('⚠️ No documents field found in tenant data');
    }
  }

  /// Get all tenants for a property
  Future<List<Map<String, dynamic>>> getTenantsByPropertyId(String propertyId) async {
    try {
      print('🔍 Fetching tenants for property: $propertyId');
      
      final db = await _mongoService.getDatabase();
      final tenantsCollection = db.collection('tenants');

      final tenants = await tenantsCollection
          .find(where.eq('propertyId', propertyId))
          .toList();

      print('✅ Found ${tenants.length} tenants for property');
      return tenants;
    } catch (e) {
      print('❌ Error fetching tenants by property: $e');
      return [];
    }
  }

  /// Get all tenants for an owner
  Future<List<Map<String, dynamic>>> getTenantsByOwnerId(String ownerId) async {
    try {
      print('🔍 Fetching tenants for owner: $ownerId');
      
      final db = await _mongoService.getDatabase();
      final tenantsCollection = db.collection('tenants');

      final tenants = await tenantsCollection
          .find(where.eq('ownerId', ownerId))
          .toList();

      print('✅ Found ${tenants.length} tenants for owner');
      return tenants;
    } catch (e) {
      print('❌ Error fetching tenants by owner: $e');
      return [];
    }
  }

  /// Update tenant documents (Cloudinary URLs)
  Future<bool> updateTenantDocuments(
    String tenantId,
    Map<String, dynamic> documents,
  ) async {
    try {
      print('📝 Updating documents for tenant: $tenantId');
      
      final db = await _mongoService.getDatabase();
      final tenantsCollection = db.collection('tenants');

      final objectId = ObjectId.fromHexString(tenantId);

      final result = await tenantsCollection.updateOne(
        where.id(objectId),
        modify.set('documents', documents),
      );

      if (result.isSuccess) {
        print('✅ Tenant documents updated successfully');
        return true;
      } else {
        print('❌ Failed to update tenant documents');
        return false;
      }
    } catch (e) {
      print('❌ Error updating tenant documents: $e');
      return false;
    }
  }

  /// Add or update a specific document for a tenant (Cloudinary URL)
  Future<bool> updateTenantDocument(
    String tenantId,
    String documentKey,
    String documentUrl,
  ) async {
    try {
      print('📝 Updating document "$documentKey" for tenant: $tenantId');
      print('   URL: ${documentUrl.length > 60 ? documentUrl.substring(0, 60) + "..." : documentUrl}');
      
      final db = await _mongoService.getDatabase();
      final tenantsCollection = db.collection('tenants');

      final objectId = ObjectId.fromHexString(tenantId);

      final result = await tenantsCollection.updateOne(
        where.id(objectId),
        modify.set('documents.$documentKey', documentUrl),
      );

      if (result.isSuccess) {
        print('✅ Document "$documentKey" updated successfully');
        return true;
      } else {
        print('❌ Failed to update document "$documentKey"');
        return false;
      }
    } catch (e) {
      print('❌ Error updating tenant document: $e');
      return false;
    }
  }

  /// Delete tenant
  Future<bool> deleteTenant(String tenantId) async {
    try {
      print('🗑️ Deleting tenant: $tenantId');
      
      final db = await _mongoService.getDatabase();
      final tenantsCollection = db.collection('tenants');

      final objectId = ObjectId.fromHexString(tenantId);

      final result = await tenantsCollection.deleteOne(where.id(objectId));

      if (result.isSuccess) {
        print('✅ Tenant deleted successfully');
        return true;
      } else {
        print('❌ Failed to delete tenant');
        return false;
      }
    } catch (e) {
      print('❌ Error deleting tenant: $e');
      return false;
    }
  }

  /// Update tenant rent
  Future<bool> updateTenantRent(String tenantId, double newRent) async {
    try {
      print('💰 Updating rent for tenant: $tenantId to ₹$newRent');
      
      final db = await _mongoService.getDatabase();
      final tenantsCollection = db.collection('tenants');

      final objectId = ObjectId.fromHexString(tenantId);

      final result = await tenantsCollection.updateOne(
        where.id(objectId),
        modify.set('monthlyRent', newRent),
      );

      if (result.isSuccess) {
        print('✅ Rent updated successfully');
        return true;
      } else {
        print('❌ Failed to update rent');
        return false;
      }
    } catch (e) {
      print('❌ Error updating rent: $e');
      return false;
    }
  }

  /// Update pending dues
  Future<bool> updatePendingDues(String tenantId, double dues) async {
    try {
      print('💸 Updating dues for tenant: $tenantId to ₹$dues');
      
      final db = await _mongoService.getDatabase();
      final tenantsCollection = db.collection('tenants');

      final objectId = ObjectId.fromHexString(tenantId);

      final result = await tenantsCollection.updateOne(
        where.id(objectId),
        modify.set('pendingDues', dues),
      );

      if (result.isSuccess) {
        print('✅ Dues updated successfully');
        return true;
      } else {
        print('❌ Failed to update dues');
        return false;
      }
    } catch (e) {
      print('❌ Error updating dues: $e');
      return false;
    }
  }

  /// Update notice status
  Future<bool> updateNoticeStatus(String tenantId, bool underNotice) async {
    try {
      print('🔔 Updating notice status for tenant: $tenantId to $underNotice');
      
      final db = await _mongoService.getDatabase();
      final tenantsCollection = db.collection('tenants');

      final objectId = ObjectId.fromHexString(tenantId);

      final result = await tenantsCollection.updateOne(
        where.id(objectId),
        modify.set('underNotice', underNotice),
      );

      if (result.isSuccess) {
        print('✅ Notice status updated successfully');
        return true;
      } else {
        print('❌ Failed to update notice status');
        return false;
      }
    } catch (e) {
      print('❌ Error updating notice status: $e');
      return false;
    }
  }
}