// lib/screens/debug_screen.dart

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../services/mongodb_service.dart';
import '../services/property_service.dart';

class DatabaseDebugScreen extends StatefulWidget {
  const DatabaseDebugScreen({super.key});

  @override
  State<DatabaseDebugScreen> createState() => _DatabaseDebugScreenState();
}

class _DatabaseDebugScreenState extends State<DatabaseDebugScreen> {
  final MongoDBService _mongoService = MongoDBService();
  final PropertyService _propertyService = PropertyService();
  
  Map<String, dynamic>? _dbStatus;
  List<Map<String, dynamic>>? _properties;
  Map<String, dynamic>? _stats;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkDatabase();
  }

  Future<void> _checkDatabase() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('🔍 Debug Screen: Checking database...');
      
      // Get database status
      final status = await _mongoService.getDatabaseStatus();
      print('✅ Database status: $status');
      
      // Get properties
      final properties = await _propertyService.getAllActiveProperties();
      print('✅ Fetched ${properties.length} properties');
      
      // Get stats
      final stats = await _propertyService.getDatabaseStats();
      print('✅ Database stats: $stats');
      
      setState(() {
        _dbStatus = status;
        _properties = properties;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('❌ Error in debug screen: $e');
      print(stackTrace);
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addTestProperty() async {
    try {
      print('➕ Adding test property...');
      
      final testProperty = {
        'title': 'Test Property ${DateTime.now().millisecond}',
        'price': '15000',
        'city': 'Bangalore',
        'state': 'Karnataka',
        'type': 'Flat',
        'bhk': 2,
        'beds': 2,
        'amenities': ['WiFi', 'Parking', 'Gym', 'Security'],
        'images': [
          'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800',
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800',
        ],
        'location': 'Koramangala, Bangalore',
        'isActive': true,
        'isVerified': true,
        'rating': 4.5,
        'description': 'Beautiful 2BHK apartment in prime location',
      };

      final result = await _propertyService.addProperty(testProperty);
      
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Test property added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _checkDatabase(); // Refresh
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteAllProperties() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Properties?'),
        content: const Text('This will delete all properties from the database. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final allProperties = await _propertyService.getAllProperties();
      int deleted = 0;
      
      for (final property in allProperties) {
        final result = await _propertyService.deleteProperty(property['_id']);
        if (result['success']) deleted++;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Deleted $deleted properties'),
          backgroundColor: Colors.green,
        ),
      );
      
      _checkDatabase();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkDatabase,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    Card(
                      color: Colors.red[100],
                      child: Padding(
                        padding: EdgeInsets.all(4.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.error, color: Colors.red[700]),
                                SizedBox(width: 2.w),
                                const Text(
                                  '❌ Error',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 1.h),
                            Text(_error!),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 2.h),
                  ],
                  
                  // Connection Status
                  _buildSection(
                    'Connection Status',
                    _dbStatus != null && _dbStatus!['connected'] == true
                        ? Colors.green
                        : Colors.red,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          'Status',
                          _dbStatus?['connected'] == true ? '✅ Connected' : '❌ Not Connected',
                          _dbStatus?['connected'] == true ? Colors.green : Colors.red,
                        ),
                        _buildInfoRow('Database', _dbStatus?['databaseName'] ?? 'N/A'),
                        _buildInfoRow(
                          'Collections',
                          _dbStatus?['collections']?.join(', ') ?? 'N/A',
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 2.h),
                  
                  // Statistics
                  if (_stats != null) ...[
                    _buildSection(
                      'Database Statistics',
                      Colors.blue,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Total Properties', _stats!['total'].toString()),
                          _buildInfoRow(
                            'Active Properties',
                            _stats!['active'].toString(),
                            Colors.green,
                          ),
                          _buildInfoRow('Inactive Properties', _stats!['inactive'].toString()),
                          _buildInfoRow(
                            'Verified Properties',
                            _stats!['verified'].toString(),
                            Colors.blue,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 2.h),
                  ],
                  
                  // Properties List
                  _buildSection(
                    'Active Properties (${_properties?.length ?? 0})',
                    Colors.orange,
                    _properties == null || _properties!.isEmpty
                        ? Column(
                            children: [
                              SizedBox(height: 2.h),
                              Icon(
                                Icons.inbox_outlined,
                                size: 15.w,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 1.h),
                              const Text(
                                'No active properties found',
                                style: TextStyle(color: Colors.grey),
                              ),
                              SizedBox(height: 1.h),
                              const Text(
                                'Add a test property to get started',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: _properties!.asMap().entries.map((entry) {
                              final index = entry.key;
                              final prop = entry.value;
                              return Card(
                                margin: EdgeInsets.only(bottom: 2.h),
                                elevation: 2,
                                child: ExpansionTile(
                                  leading: CircleAvatar(
                                    child: Text('${index + 1}'),
                                  ),
                                  title: Text(
                                    prop['title'] ?? 'No title',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    '${prop['city']}, ${prop['state']} • ${prop['price']}',
                                  ),
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.all(3.w),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildPropertyDetail('ID', prop['_id']),
                                          _buildPropertyDetail('Type', prop['type']),
                                          _buildPropertyDetail('Price', prop['price']),
                                          _buildPropertyDetail('Location', '${prop['city']}, ${prop['state']}'),
                                          _buildPropertyDetail('Active', prop['isActive'].toString()),
                                          _buildPropertyDetail('Verified', prop['isVerified'].toString()),
                                          if (prop['bhk'] != null)
                                            _buildPropertyDetail('BHK', prop['bhk'].toString()),
                                          if (prop['beds'] != null)
                                            _buildPropertyDetail('Beds', prop['beds'].toString()),
                                          if (prop['amenities'] != null && prop['amenities'] is List)
                                            _buildPropertyDetail(
                                              'Amenities',
                                              (prop['amenities'] as List).join(', '),
                                            ),
                                          if (prop['images'] != null)
                                            _buildPropertyDetail(
                                              'Images',
                                              prop['images'] is List
                                                  ? '${(prop['images'] as List).length} images'
                                                  : '1 image',
                                            ),
                                          SizedBox(height: 1.h),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              TextButton.icon(
                                                onPressed: () async {
                                                  final confirmed = await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: const Text('Delete Property?'),
                                                      content: Text('Delete "${prop['title']}"?'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context, false),
                                                          child: const Text('Cancel'),
                                                        ),
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context, true),
                                                          style: TextButton.styleFrom(
                                                            foregroundColor: Colors.red,
                                                          ),
                                                          child: const Text('Delete'),
                                                        ),
                                                      ],
                                                    ),
                                                  );

                                                  if (confirmed == true) {
                                                    final result = await _propertyService.deleteProperty(prop['_id']);
                                                    if (result['success']) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text('✅ Property deleted'),
                                                          backgroundColor: Colors.green,
                                                        ),
                                                      );
                                                      _checkDatabase();
                                                    }
                                                  }
                                                },
                                                icon: const Icon(Icons.delete, size: 18),
                                                label: const Text('Delete'),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  
                  SizedBox(height: 2.h),
                  
                  // Action Buttons
                  _buildSection(
                    'Actions',
                    Colors.purple,
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _addTestProperty,
                            icon: const Icon(Icons.add_home),
                            label: const Text('Add Test Property'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.all(3.w),
                            ),
                          ),
                        ),
                        SizedBox(height: 1.h),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _addTestProperty,
                            icon: const Icon(Icons.add_circle),
                            label: const Text('Add Another Test Property'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.all(3.w),
                            ),
                          ),
                        ),
                        SizedBox(height: 1.h),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _deleteAllProperties,
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('Delete All Properties'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: EdgeInsets.all(3.w),
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 2.h),
                  
                  // Instructions
                  _buildSection(
                    'Instructions',
                    Colors.teal,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInstruction(
                          '1.',
                          'Check if MongoDB is connected (should show ✅)',
                        ),
                        _buildInstruction(
                          '2.',
                          'Check database statistics - you should have Active Properties > 0',
                        ),
                        _buildInstruction(
                          '3.',
                          'If no properties exist, click "Add Test Property"',
                        ),
                        _buildInstruction(
                          '4.',
                          'Go back to Home Dashboard and pull down to refresh',
                        ),
                        _buildInstruction(
                          '5.',
                          'Properties should now appear in "Featured Properties"',
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 2.h),
                  
                  // Troubleshooting
                  _buildSection(
                    'Troubleshooting',
                    Colors.deepOrange,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTroubleshootItem(
                          '❌ Not Connected',
                          'Check your internet connection and MongoDB Atlas IP whitelist',
                        ),
                        _buildTroubleshootItem(
                          '⚠️ No Active Properties',
                          'Add test properties or check if existing properties have isActive = true',
                        ),
                        _buildTroubleshootItem(
                          '❌ Properties not showing',
                          'Check console logs and ensure images URLs are valid',
                        ),
                        _buildTroubleshootItem(
                          '🔄 Still not working',
                          'Check the console output (logs) for detailed error messages',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, Color color, Widget child) {
    return Card(
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: color, size: 20),
                SizedBox(width: 2.w),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(4.w),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 35.w,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyDetail(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 0.5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 25.w,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstruction(String number, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootItem(String issue, String solution) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.5.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            issue,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            solution,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}