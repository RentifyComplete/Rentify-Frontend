  // lib/services/mongodb_service.dart

  import 'package:mongo_dart/mongo_dart.dart';

  class MongoDBService {
    static MongoDBService? _instance;
    static Db? _db;

    factory MongoDBService() {
      _instance ??= MongoDBService._internal();
      return _instance!;
    }

    MongoDBService._internal();

    static const String _connectionString =
        'mongodb+srv://rentify085_db_user:L6l69tRpwkBT1bMn@rentify.db6wrq3.mongodb.net/rentify_db?retryWrites=true&w=majority';

    Future<void> connect() async {
      if (_db != null && _db!.isConnected) {
        print('✅ Already connected to MongoDB');
        print('📊 Database name: ${_db!.databaseName}');
        return;
      }

      try {
        print('🔄 ==================== MONGODB CONNECTION START ====================');
        print('🔄 Attempting to connect to MongoDB...');
        print('🔗 Host: rentify.db6wrq3.mongodb.net');
        print('🔗 Database: rentify_db');

        _db = await Db.create(_connectionString);
        await _db!.open();

        print('✅ Connected to MongoDB successfully!');
        print('📊 Database name: ${_db!.databaseName}');
        print('🔍 Checking collections...');

        // List all collections
        final collections = await _db!.getCollectionNames();
        print('📁 Available collections: $collections');

        // Check if 'users' collection exists
        if (collections.contains('users')) {
          print('✅ Users collection exists');
          final usersCollection = _db!.collection('users');
          final count = await usersCollection.count();
          print('📊 Total users: $count');
        } else {
          print('⚠️ Users collection does not exist yet');
          print('💡 It will be created when first user registers');
        }

        // Check if 'properties' collection exists
        if (collections.contains('properties')) {
          print('✅ Properties collection exists');
          final propertiesCollection = _db!.collection('properties');
          final count = await propertiesCollection.count();
          print('📊 Total documents in properties collection: $count');

          if (count > 0) {
            final activeCount = await propertiesCollection.count(where.eq('isActive', true));
            print('✅ Active properties: $activeCount');

            // Get a sample document
            final sample = await propertiesCollection.findOne();
            if (sample != null) {
              print('📋 Sample document fields: ${sample.keys.toList()}');
            }
          } else {
            print('⚠️ WARNING: Properties collection is EMPTY!');
            print('💡 TIP: Use the debug screen to add test properties');
          }
        } else {
          print('⚠️ WARNING: Properties collection does NOT exist!');
          print('💡 It will be created when you add your first property');
        }

        print('🔄 ==================== MONGODB CONNECTION END ====================\n');

      } catch (e, stackTrace) {
        print('❌ ==================== MONGODB CONNECTION ERROR ====================');
        print('❌ Error connecting to MongoDB: $e');
        print('❌ Stack trace:');
        print(stackTrace);
        print('❌ ==================== ERROR END ====================\n');
        print('');
        print('💡 TROUBLESHOOTING TIPS:');
        print('   1. Check your internet connection');
        print('   2. Verify MongoDB Atlas IP whitelist (0.0.0.0/0 for development)');
        print('   3. Confirm your connection string is correct');
        print('   4. Check if your MongoDB cluster is running');
        print('');
        rethrow;
      }
    }

    Db? get database {
      if (_db == null || !_db!.isConnected) {
        throw Exception('Database not connected. Call connect() first.');
      }
      return _db;
    }

    // ADD THIS METHOD - This is what was missing!
    Future<Db> getDatabase() async {
      if (_db == null || !_db!.isConnected) {
        await connect();
      }
      return _db!;
    }

    Future<void> close() async {
      if (_db != null && _db!.isConnected) {
        await _db!.close();
        print('🔌 MongoDB connection closed');
      }
    }

    bool get isConnected => _db != null && _db!.isConnected;

    // Get detailed database status for debugging
    Future<Map<String, dynamic>> getDatabaseStatus() async {
      try {
        print('🔍 Getting database status...');

        if (!isConnected) {
          print('🔄 Not connected, attempting to connect...');
          await connect();
        }

        final collections = await _db!.getCollectionNames();
        print('📁 Collections found: $collections');

        Map<String, dynamic> status = {
          'connected': true,
          'databaseName': _db!.databaseName,
          'collections': collections,
          'propertiesCount': 0,
          'activePropertiesCount': 0,
          'usersCount': 0,
        };

        // Get users collection info
        if (collections.contains('users')) {
          final usersCollection = _db!.collection('users');
          final userCount = await usersCollection.count();
          status['usersCount'] = userCount;
          print('📊 Users: $userCount');
        }

        // Get properties collection info
        if (collections.contains('properties')) {
          final propertiesCollection = _db!.collection('properties');
          final totalCount = await propertiesCollection.count();
          final activeCount = await propertiesCollection.count(where.eq('isActive', true));

          status['propertiesCount'] = totalCount;
          status['activePropertiesCount'] = activeCount;

          print('📊 Properties: $totalCount total, $activeCount active');
        } else {
          print('⚠️ Properties collection does not exist');
        }

        print('✅ Database status retrieved successfully');
        return status;

      } catch (e) {
        print('❌ Error getting database status: $e');
        return {
          'connected': false,
          'error': e.toString(),
          'databaseName': null,
          'collections': [],
          'propertiesCount': 0,
          'activePropertiesCount': 0,
          'usersCount': 0,
        };
      }
    }

    // Test database connection
    Future<bool> testConnection() async {
      try {
        print('🧪 Testing database connection...');
        await connect();

        // Try a simple operation
        final collections = await _db!.getCollectionNames();
        print('✅ Connection test successful. Found ${collections.length} collections');
        return true;
      } catch (e) {
        print('❌ Connection test failed: $e');
        return false;
      }
    }

    // Get collection statistics
    Future<Map<String, dynamic>> getCollectionStats(String collectionName) async {
      try {
        if (!isConnected) {
          await connect();
        }

        final collection = _db!.collection(collectionName);
        final count = await collection.count();

        return {
          'name': collectionName,
          'documentCount': count,
          'exists': true,
        };
      } catch (e) {
        print('❌ Error getting collection stats: $e');
        return {
          'name': collectionName,
          'documentCount': 0,
          'exists': false,
          'error': e.toString(),
        };
      }
    }
  }