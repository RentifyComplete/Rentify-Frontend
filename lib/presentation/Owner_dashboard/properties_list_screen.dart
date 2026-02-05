import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/app_export.dart';
import '../../services/property_service.dart';
import '../../services/auth_service.dart';
import '../add_property/add_property_screen.dart';
import 'edit_property_screen.dart';

class PropertiesListScreen extends StatefulWidget {
  const PropertiesListScreen({super.key});

  @override
  State<PropertiesListScreen> createState() => _PropertiesListScreenState();
}

class _PropertiesListScreenState extends State<PropertiesListScreen> {
  final PropertyService _propertyService = PropertyService();
  final AuthService _authService = AuthService();
  final String baseUrl = 'https://rentify-backend-cdaj.onrender.com';

  List<dynamic> myProperties = [];
  bool _isLoadingProperties = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print('🏠 PropertiesListScreen: initState called');
    Future.microtask(() => _loadPropertiesFromDatabase());
  }

  Future<void> _loadPropertiesFromDatabase() async {
    if (!mounted) return;

    setState(() {
      _isLoadingProperties = true;
      _errorMessage = null;
    });

    try {
      final currentOwnerId = await _authService.getCurrentUserId();

      if (currentOwnerId == null || currentOwnerId.isEmpty) {
        throw Exception('User not logged in');
      }

      print('🔄 Loading properties for owner: $currentOwnerId');

      final List<Map<String, dynamic>> allProperties =
      await _propertyService.getAllProperties();

      print('📦 Total properties in database: ${allProperties.length}');

      final List<Map<String, dynamic>> myPropertiesList = allProperties.where((property) {
        final propertyOwnerId = property['ownerId']?.toString() ?? '';
        final matches = propertyOwnerId == currentOwnerId;

        if (!matches) {
          print('⚠️ Skipping property: ${property['title']} (Owner: $propertyOwnerId != $currentOwnerId)');
        } else {
          print('✅ Including property: ${property['title']} (Owner: $propertyOwnerId)');
        }

        return matches;
      }).toList();

      print('📊 Filtered to ${myPropertiesList.length} properties for owner $currentOwnerId');

      if (!mounted) return;

      setState(() {
        myProperties.clear();
        myProperties.addAll(myPropertiesList);
        _isLoadingProperties = false;
      });

      print('✅ Loaded ${myPropertiesList.length} properties for current owner');

      if (myPropertiesList.isEmpty) {
        print('ℹ️ No properties found for this owner');
      }
    } catch (e, stackTrace) {
      print('❌ Error loading properties: $e');
      print('Stack trace: $stackTrace');

      if (!mounted) return;

      setState(() {
        _isLoadingProperties = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _addNewProperty() async {
    print('➕ Navigating to Add Property Screen...');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPropertyScreen(),
      ),
    );

    if (result != null && mounted) {
      print('✅ Property added successfully, reloading list...');
      await _loadPropertiesFromDatabase();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Property added successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _editProperty(dynamic property) async {
    print('✏️ Navigating to Edit Property Screen...');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPropertyScreen(property: property),
      ),
    );

    if (result == true && mounted) {
      print('✅ Property edited successfully, reloading list...');
      await _loadPropertiesFromDatabase();
    }
  }

  void _showPropertyDetails(dynamic property) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(property['title'] ?? 'Property Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Location', property['location']),
              _buildDetailRow('Price', property['price']),
              _buildDetailRow('Type', property['type']),
              _buildDetailRow('Address', property['address']),
              _buildDetailRow('City', property['city']),
              _buildDetailRow('State', property['state']),
              _buildDetailRow('ZIP Code', property['zipCode']),
              _buildDetailRow('Description', property['description']),
              if (property['amenities'] != null && (property['amenities'] as List).isNotEmpty) ...[
                SizedBox(height: 1.h),
                Text(
                  'Amenities: ${(property['amenities'] as List).join(", ")}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              SizedBox(height: 1.h),
              Text(
                'Verified: ${property['isVerified'] == true ? 'Yes' : 'No'}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Text(
        '$label: ${value ?? 'N/A'}',
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  // ⭐ UPDATED: CASCADE DELETE - Deletes property + all tenant bookings
  Future<void> _deleteProperty(String propertyId, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 6.w),
            SizedBox(width: 2.w),
            const Text('Delete Property'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this property?',
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 1.h),
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 5.w),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      'All tenant bookings for this property will also be removed.',
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.primaryLight),
                SizedBox(height: 2.h),
                Text('Deleting property...', style: TextStyle(fontSize: 11.sp)),
              ],
            ),
          ),
        ),
      );

      try {
        print('🗑️ ==================== DELETE PROPERTY ====================');
        print('Property ID: $propertyId');

        // Step 1: Delete all bookings for this property
        print('📋 Step 1: Deleting all bookings for property...');
        final bookingResponse = await http.delete(
          Uri.parse('$baseUrl/api/bookings/property/$propertyId'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 30));

        int deletedBookingsCount = 0;
        if (bookingResponse.statusCode == 200) {
          final bookingData = json.decode(bookingResponse.body);
          deletedBookingsCount = bookingData['deletedCount'] ?? 0;
          print('✅ Bookings deleted: $deletedBookingsCount');
        } else {
          print('⚠️ Warning: Failed to delete bookings: ${bookingResponse.statusCode}');
          // Continue with property deletion even if bookings fail
        }

        // Step 2: Delete the property
        print('🏠 Step 2: Deleting property...');
        final result = await _propertyService.deleteProperty(propertyId);

        // Close loading dialog
        if (mounted) Navigator.pop(context);

        if (result['success'] == true) {
          setState(() {
            myProperties.removeAt(index);
          });

          print('✅ Property deleted successfully');
          print('🗑️ ==================== DELETE SUCCESS ====================\n');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        deletedBookingsCount > 0
                            ? 'Property and $deletedBookingsCount booking(s) deleted'
                            : 'Property deleted successfully',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          print('❌ Failed to delete property: ${result['message']}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${result['message']}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } catch (e) {
        print('❌ Error deleting property: $e');

        // Close loading dialog
        if (mounted) {
          try {
            Navigator.pop(context);
          } catch (_) {}
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🏠 PropertiesListScreen: build called');
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppTheme.primaryLight),
        onPressed: () {
          print('🏠 Back button pressed');
          Navigator.pop(context);
        },
      ),
      title: Text(
        'My Properties',
        style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh, color: AppTheme.primaryLight),
          onPressed: _isLoadingProperties ? null : _loadPropertiesFromDatabase,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildBody() {
    // Show error state
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 15.w,
                color: Colors.red,
              ),
              SizedBox(height: 2.h),
              Text(
                'Error Loading Properties',
                style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTheme.lightTheme.textTheme.bodyMedium,
              ),
              SizedBox(height: 3.h),
              ElevatedButton.icon(
                onPressed: _loadPropertiesFromDatabase,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show loading state
    if (_isLoadingProperties) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryLight),
            SizedBox(height: 2.h),
            Text(
              'Loading properties...',
              style: AppTheme.lightTheme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    // Show empty state
    if (myProperties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_outlined,
              size: 20.w,
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: 2.h),
            Text(
              'No Properties Yet',
              style: AppTheme.lightTheme.textTheme.titleLarge,
            ),
            SizedBox(height: 1.h),
            Text(
              'Add your first property to get started',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 3.h),
            ElevatedButton.icon(
              onPressed: _addNewProperty,
              icon: const Icon(Icons.add),
              label: const Text('Add Property'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentLight,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
              ),
            ),
          ],
        ),
      );
    }

    // Show properties list
    return RefreshIndicator(
      onRefresh: _loadPropertiesFromDatabase,
      color: AppTheme.primaryLight,
      child: ListView.builder(
        padding: EdgeInsets.all(3.w),
        itemCount: myProperties.length,
        itemBuilder: (context, index) {
          final property = myProperties[index];
          return _buildPropertyCard(property, index);
        },
      ),
    );
  }

  Widget _buildPropertyCard(dynamic property, int index) {
    final propertyId = property['_id'] ?? property['id'] ?? '';

    return Card(
      margin: EdgeInsets.only(bottom: 2.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPropertyImage(property),
          Padding(
            padding: EdgeInsets.all(3.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPropertyHeader(property),
                SizedBox(height: 1.h),
                _buildPropertyLocation(property),
                SizedBox(height: 1.h),
                _buildPropertyInfo(property),
                SizedBox(height: 2.h),
                _buildActionButtons(property, propertyId, index),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyImage(dynamic property) {
    List<dynamic> images = property['images'] ?? [];
    String? imageUrl;

    if (images.isNotEmpty) {
      imageUrl = images[0]?.toString();
    }

    print('🖼️ Property: ${property['title']}');
    print('🖼️ Images array: $images');
    print('🖼️ First image URL: $imageUrl');

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
      child: Container(
        width: double.infinity,
        height: 25.h,
        color: Colors.grey.shade300,
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                color: Colors.blue,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error loading image from URL: $imageUrl');
            print('❌ Error: $error');
            return _buildPlaceholderImage();
          },
        )
            : _buildPlaceholderImage(),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey.shade300,
      child: Icon(
        Icons.home,
        size: 15.w,
        color: Colors.grey.shade600,
      ),
    );
  }

  Widget _buildPropertyHeader(dynamic property) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            property['title'] ?? 'Unnamed Property',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (property['isVerified'] == true) _buildVerifiedBadge(),
      ],
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified,
            size: 3.w,
            color: Colors.green,
          ),
          SizedBox(width: 0.5.w),
          Text(
            'Verified',
            style: TextStyle(
              color: Colors.green,
              fontSize: 9.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyLocation(dynamic property) {
    return Row(
      children: [
        Icon(
          Icons.location_on,
          size: 4.w,
          color: AppTheme.primaryLight,
        ),
        SizedBox(width: 1.w),
        Expanded(
          child: Text(
            property['location'] ?? 'Location not specified',
            style: AppTheme.lightTheme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyInfo(dynamic property) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildInfoColumn('Monthly Rent', property['price'] ?? '₹0', isPrimary: true),
        _buildInfoColumn('Type', property['type'] ?? 'N/A'),
        _buildInfoColumn(
          property['type'] == 'Flat' ? 'BHK' : 'Beds',
          property['type'] == 'Flat' ? (property['bhk'] ?? 'N/A') : '${property['beds'] ?? 0}',
        ),
      ],
    );
  }

  Widget _buildInfoColumn(String label, String value, {bool isPrimary = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
            color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 0.5.h),
        Text(
          value,
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isPrimary ? AppTheme.primaryLight : null,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(dynamic property, String propertyId, int index) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showPropertyDetails(property),
            icon: const Icon(Icons.info_outline, size: 18),
            label: const Text('Details'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(vertical: 1.2.h),
            ),
          ),
        ),
        SizedBox(width: 2.w),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _editProperty(property),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(vertical: 1.2.h),
            ),
          ),
        ),
        SizedBox(width: 2.w),
        IconButton(
          onPressed: () => _deleteProperty(propertyId, index),
          icon: const Icon(Icons.delete_outline),
          color: Colors.red,
          iconSize: 6.w,
          tooltip: 'Delete',
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    if (_errorMessage != null) return const SizedBox.shrink();

    return FloatingActionButton.extended(
      onPressed: _addNewProperty,
      icon: const Icon(Icons.add),
      label: const Text('Add Property'),
      backgroundColor: AppTheme.accentLight,
      foregroundColor: Colors.white,
    );
  }
}