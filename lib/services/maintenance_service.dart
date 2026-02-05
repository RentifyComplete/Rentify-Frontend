// lib/services/maintenance_service.dart

import 'package:mongo_dart/mongo_dart.dart';
import 'mongodb_service.dart';

class MaintenanceService {
  final MongoDBService _mongoDBService = MongoDBService();

  // Create a new maintenance request
  Future<Map<String, dynamic>?> createMaintenanceRequest({
    required String propertyId,
    required String tenantId,
    required String tenantName,
    required String tenantEmail,
    required String tenantPhone,
    required String category,
    required String title,
    required String description,
    required String priority,
    List<String>? imageUrls,
    String? notes,
  }) async {
    try {
      final db = await _mongoDBService.getDatabase();
      final collection = db.collection('maintenance_requests');

      // ⭐ CRITICAL: Store propertyId as STRING for consistent querying
      final maintenanceRequest = {
        '_id': ObjectId(),
        'propertyId': propertyId, // Store as string
        'tenantId': tenantId,
        'tenantName': tenantName,
        'tenantEmail': tenantEmail,
        'tenantPhone': tenantPhone,
        'category': category,
        'title': title,
        'description': description,
        'priority': priority,
        'status': 'Pending', // Pending, In Progress, Completed, Cancelled
        'imageUrls': imageUrls ?? [],
        'notes': notes ?? '',
        'createdAt': DateTime.now().toUtc(),
        'updatedAt': DateTime.now().toUtc(),
        'assignedTo': null,
        'completedAt': null,
        'estimatedCost': null,
        'actualCost': null,
      };

      print('🔧 Creating maintenance request...');
      print('   Property ID: $propertyId (${propertyId.runtimeType})');
      print('   Tenant ID: $tenantId');
      print('   Category: $category');
      print('   Title: $title');

      final result = await collection.insertOne(maintenanceRequest);

      if (result.isSuccess) {
        print('✅ Maintenance request created successfully');
        print('📋 Request ID: ${maintenanceRequest['_id']}');
        print('📋 Stored Property ID: ${maintenanceRequest['propertyId']}');
        return maintenanceRequest;
      } else {
        print('❌ Failed to create maintenance request');
        return null;
      }
    } catch (e) {
      print('❌ Error creating maintenance request: $e');
      return null;
    }
  }

  // Get all maintenance requests for a specific tenant
  Future<List<Map<String, dynamic>>> getMaintenanceRequestsByTenant(String tenantId) async {
    try {
      final db = await _mongoDBService.getDatabase();
      final collection = db.collection('maintenance_requests');

      final requests = await collection
          .find(where.eq('tenantId', tenantId))
          .toList();

      print('📋 Found ${requests.length} maintenance requests for tenant: $tenantId');
      return requests;
    } catch (e) {
      print('❌ Error fetching maintenance requests: $e');
      return [];
    }
  }

  // ⭐ FIXED: Get all maintenance requests for a specific property
  Future<List<Map<String, dynamic>>> getMaintenanceRequestsByProperty(String propertyId) async {
    try {
      final db = await _mongoDBService.getDatabase();
      final collection = db.collection('maintenance_requests');

      print('🔍 Searching maintenance requests for property: $propertyId (${propertyId.runtimeType})');

      // Try multiple query formats to handle different storage formats
      var requests = await collection
          .find(where.eq('propertyId', propertyId))
          .toList();

      // If no results, try with ObjectId
      if (requests.isEmpty && ObjectId.isValidHexId(propertyId)) {
        print('🔍 Trying with ObjectId format...');
        requests = await collection
            .find(where.eq('propertyId', ObjectId.fromHexString(propertyId)))
            .toList();
      }

      // If still no results, check all maintenance requests and their propertyId formats
      if (requests.isEmpty) {
        print('🔍 Checking all maintenance requests in database...');
        final allRequests = await collection.find().toList();
        print('📋 Total maintenance requests in DB: ${allRequests.length}');

        if (allRequests.isNotEmpty) {
          print('📋 Sample propertyIds in database:');
          for (var req in allRequests.take(3)) {
            print('   - ${req['propertyId']} (${req['propertyId'].runtimeType})');
          }
        }

        // Manual filter as fallback
        requests = allRequests.where((req) {
          final reqPropertyId = req['propertyId'].toString();
          return reqPropertyId == propertyId || reqPropertyId.contains(propertyId);
        }).toList();
      }

      print('📋 Found ${requests.length} maintenance requests for property: $propertyId');
      return requests;
    } catch (e) {
      print('❌ Error fetching maintenance requests: $e');
      return [];
    }
  }

  // Get maintenance request by ID
  Future<Map<String, dynamic>?> getMaintenanceRequestById(String requestId) async {
    try {
      final db = await _mongoDBService.getDatabase();
      final collection = db.collection('maintenance_requests');

      final request = await collection.findOne(where.eq('_id', ObjectId.fromHexString(requestId)));

      if (request != null) {
        print('✅ Maintenance request found: $requestId');
      } else {
        print('⚠️ Maintenance request not found: $requestId');
      }

      return request;
    } catch (e) {
      print('❌ Error fetching maintenance request: $e');
      return null;
    }
  }

  // ⭐ FIXED: Update maintenance request status (works for both owner and tenant)
  Future<bool> updateMaintenanceRequestStatus(String requestId, String status) async {
    try {
      final db = await _mongoDBService.getDatabase();
      final collection = db.collection('maintenance_requests');

      print('🔄 Updating request $requestId to status: $status');

      // Build the update document
      Map<String, dynamic> updateData = {
        'status': status,
        'updatedAt': DateTime.now().toUtc(),
      };

      // Add completedAt timestamp if status is Completed
      if (status == 'Completed') {
        updateData['completedAt'] = DateTime.now().toUtc();
        print('✅ Adding completedAt timestamp');
      }

      // Perform the update
      final result = await collection.updateOne(
        where.eq('_id', ObjectId.fromHexString(requestId)),
        modify.set('status', status)
            .set('updatedAt', DateTime.now().toUtc())
            .set('completedAt', status == 'Completed' ? DateTime.now().toUtc() : null),
      );

      if (result.isSuccess && result.nModified > 0) {
        print('✅ Maintenance request status updated to: $status');
        print('📊 Documents modified: ${result.nModified}');
        return true;
      } else if (result.isSuccess && result.nModified == 0) {
        print('⚠️ Request found but no changes made (possibly already in this status)');
        return true; // Still return true as the operation succeeded
      } else {
        print('❌ Failed to update maintenance request status');
        print('📊 Result: ${result.toString()}');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Error updating maintenance request status: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  // Update maintenance request
  Future<bool> updateMaintenanceRequest(String requestId, Map<String, dynamic> updates) async {
    try {
      final db = await _mongoDBService.getDatabase();
      final collection = db.collection('maintenance_requests');

      updates['updatedAt'] = DateTime.now().toUtc();

      final modifier = modify;
      updates.forEach((key, value) {
        modifier.set(key, value);
      });

      final result = await collection.updateOne(
        where.eq('_id', ObjectId.fromHexString(requestId)),
        modifier,
      );

      if (result.isSuccess) {
        print('✅ Maintenance request updated successfully');
        return true;
      } else {
        print('❌ Failed to update maintenance request');
        return false;
      }
    } catch (e) {
      print('❌ Error updating maintenance request: $e');
      return false;
    }
  }

  // Delete maintenance request
  Future<bool> deleteMaintenanceRequest(String requestId) async {
    try {
      final db = await _mongoDBService.getDatabase();
      final collection = db.collection('maintenance_requests');

      final result = await collection.deleteOne(where.eq('_id', ObjectId.fromHexString(requestId)));

      if (result.isSuccess) {
        print('✅ Maintenance request deleted successfully');
        return true;
      } else {
        print('❌ Failed to delete maintenance request');
        return false;
      }
    } catch (e) {
      print('❌ Error deleting maintenance request: $e');
      return false;
    }
  }

  // Get maintenance requests by status
  Future<List<Map<String, dynamic>>> getMaintenanceRequestsByStatus(String status) async {
    try {
      final db = await _mongoDBService.getDatabase();
      final collection = db.collection('maintenance_requests');

      final requests = await collection
          .find(where.eq('status', status))
          .toList();

      print('📋 Found ${requests.length} maintenance requests with status: $status');
      return requests;
    } catch (e) {
      print('❌ Error fetching maintenance requests by status: $e');
      return [];
    }
  }

  // Get all maintenance requests
  Future<List<Map<String, dynamic>>> getAllMaintenanceRequests() async {
    try {
      final db = await _mongoDBService.getDatabase();
      final collection = db.collection('maintenance_requests');

      final requests = await collection
          .find()
          .toList();

      print('📋 Found ${requests.length} total maintenance requests');
      return requests;
    } catch (e) {
      print('❌ Error fetching all maintenance requests: $e');
      return [];
    }
  }

  // Get maintenance requests statistics
  Future<Map<String, int>> getMaintenanceRequestsStats() async {
    try {
      final db = await _mongoDBService.getDatabase();
      final collection = db.collection('maintenance_requests');

      final total = await collection.count();
      final pending = await collection.count(where.eq('status', 'Pending'));
      final inProgress = await collection.count(where.eq('status', 'In Progress'));
      final completed = await collection.count(where.eq('status', 'Completed'));
      final cancelled = await collection.count(where.eq('status', 'Cancelled'));

      return {
        'total': total,
        'pending': pending,
        'inProgress': inProgress,
        'completed': completed,
        'cancelled': cancelled,
      };
    } catch (e) {
      print('❌ Error fetching maintenance requests stats: $e');
      return {
        'total': 0,
        'pending': 0,
        'inProgress': 0,
        'completed': 0,
        'cancelled': 0,
      };
    }
  }

  // Get maintenance requests by priority
  Future<List<Map<String, dynamic>>> getMaintenanceRequestsByPriority(String priority) async {
    try {
      final db = await _mongoDBService.getDatabase();
      final collection = db.collection('maintenance_requests');

      final requests = await collection
          .find(where.eq('priority', priority))
          .toList();

      print('📋 Found ${requests.length} maintenance requests with priority: $priority');
      return requests;
    } catch (e) {
      print('❌ Error fetching maintenance requests by priority: $e');
      return [];
    }
  }

  // Get maintenance requests by category
  Future<List<Map<String, dynamic>>> getMaintenanceRequestsByCategory(String category) async {
    try {
      final db = await _mongoDBService.getDatabase();
      final collection = db.collection('maintenance_requests');

      final requests = await collection
          .find(where.eq('category', category))
          .toList();

      print('📋 Found ${requests.length} maintenance requests with category: $category');
      return requests;
    } catch (e) {
      print('❌ Error fetching maintenance requests by category: $e');
      return [];
    }
  }
}