import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import 'tenant_documents_viewer_screen.dart';
import 'tenant_card_widget.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();

  // Data lists
  List<Map<String, dynamic>> myProperties = [];
  List<Map<String, dynamic>> allBookings = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentOwnerId = await _authService.getCurrentUserId();

      if (currentOwnerId == null || currentOwnerId.isEmpty) {
        throw Exception('User not logged in');
      }

      print('🔄 Loading data for owner: $currentOwnerId');

      await Future.wait([
        _loadProperties(currentOwnerId),
        _loadBookings(currentOwnerId),
      ]);

      setState(() {
        _isLoading = false;
      });

      print('✅ Data loaded: ${myProperties.length} properties, ${allBookings.length} bookings');
    } catch (e) {
      print('❌ Error loading data: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProperties(String ownerId) async {
    try {
      print('🔄 Loading properties for owner: $ownerId');
      
      var url = _authService.getPropertiesByOwnerUrl(ownerId);
      print('📡 Properties URL: $url');

      var response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      print('📥 Properties Response Status: ${response.statusCode}');

      if (response.statusCode == 404) {
        print('⚠️ Owner endpoint not found, trying to fetch all properties...');
        url = _authService.getAllPropertiesUrl();
        print('📡 All Properties URL: $url');
        
        response = await http.get(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 30));
        
        print('📥 All Properties Response Status: ${response.statusCode}');
      }

      print('📥 Properties Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📊 Decoded data keys: ${data.keys}');

        if (data['success'] == true) {
          var propertiesData = data['data'] ?? data['properties'];
          print('📊 Properties data type: ${propertiesData.runtimeType}');

          if (propertiesData != null && propertiesData is List) {
            final filteredProperties = propertiesData.where((prop) {
              final propOwnerId = prop['ownerId']?.toString() ?? '';
              print('   Checking property: ${prop['title']} - Owner: $propOwnerId vs $ownerId');
              return propOwnerId == ownerId;
            }).toList();

            print('📊 Total properties: ${propertiesData.length}');
            print('📊 Filtered properties for owner $ownerId: ${filteredProperties.length}');

            setState(() {
              myProperties = List<Map<String, dynamic>>.from(filteredProperties);
            });
            print('✅ Loaded ${myProperties.length} properties');
            
            for (var prop in myProperties) {
              print('   ✓ Property: ${prop['title']} (ID: ${prop['_id']}, Owner: ${prop['ownerId']})');
            }
          } else {
            print('⚠️ Properties data is not a list or is null');
            setState(() {
              myProperties = [];
            });
          }
        } else {
          print('⚠️ API returned success: false');
          print('   Message: ${data['message']}');
          setState(() {
            myProperties = [];
          });
        }
      } else {
        print('❌ Failed to load properties: ${response.statusCode}');
        setState(() {
          myProperties = [];
        });
      }
    } catch (e, stackTrace) {
      print('❌ Error loading properties: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        myProperties = [];
      });
    }
  }

 // Add this to your _loadBookings method in PeopleScreen
// Replace the existing _loadBookings method with this debug version

Future<void> _loadBookings(String ownerId) async {
  try {
    print('🔄 Loading bookings for owner: $ownerId');
    
    var url = _authService.getBookingsByOwnerUrl(ownerId);
    print('📡 Bookings URL: $url');

    var response = await http.get(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 30));

    print('📥 Bookings Response Status: ${response.statusCode}');
    print('📥 Bookings Response Body: ${response.body}');

    if (response.statusCode == 404) {
      print('⚠️ Owner endpoint returned 404, trying to fetch all bookings...');
      url = _authService.getAllBookingsUrl();
      print('📡 All Bookings URL: $url');
      
      response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));
      
      print('📥 All Bookings Response Status: ${response.statusCode}');
      print('📥 All Bookings Response Body: ${response.body}');
    }

    if (response.statusCode != 200) {
      print('❌ Failed to load bookings: ${response.statusCode}');
      setState(() {
        allBookings = [];
      });
      return;
    }

    final data = json.decode(response.body);
    print('📊 Decoded data type: ${data.runtimeType}');
    print('📊 Response structure: ${data.keys}');

    var bookingsData;
    
    if (data is List) {
      bookingsData = data;
      print('📊 Response is a direct array with ${data.length} items');
    } else if (data is Map) {
      if (data.containsKey('success')) {
        print('📊 Success flag: ${data['success']}');
        if (data['success'] == true) {
          bookingsData = data['bookings'] ?? data['data'];
        } else {
          print('⚠️ API returned success: false');
          print('   Message: ${data['message']}');
        }
      } else {
        bookingsData = data['bookings'] ?? data['data'];
      }
    }

    print('📊 Bookings data type: ${bookingsData?.runtimeType}');

    if (bookingsData != null && bookingsData is List) {
      print('📊 Raw bookings count: ${bookingsData.length}');
      
      // ⭐ DEBUG: Check documents in each booking
      for (int i = 0; i < bookingsData.length; i++) {
        var booking = bookingsData[i];
        print('');
        print('📋 Booking #$i DETAILED DEBUG:');
        print('   _id: ${booking['_id']}');
        print('   tenantName: ${booking['tenantName']}');
        print('   tenantEmail: ${booking['tenantEmail']}');
        print('   ownerId: "${booking['ownerId']}"');
        print('   propertyId: ${booking['propertyId']}');
        print('   status: ${booking['status']}');
        
        // ⭐ CHECK ALL POSSIBLE DOCUMENT FIELDS
        print('   📄 DOCUMENT FIELDS CHECK:');
        print('      Has "documents": ${booking.containsKey('documents')}');
        print('      Has "tenantDocuments": ${booking.containsKey('tenantDocuments')}');
        
        if (booking.containsKey('documents')) {
          print('      documents value: ${booking['documents']}');
          print('      documents type: ${booking['documents'].runtimeType}');
        }
        
        if (booking.containsKey('tenantDocuments')) {
          print('      tenantDocuments value: ${booking['tenantDocuments']}');
          print('      tenantDocuments type: ${booking['tenantDocuments'].runtimeType}');
        }
        
        // ⭐ PRINT ALL BOOKING KEYS
        print('   📋 All booking keys:');
        booking.keys.forEach((key) {
          print('      - $key');
        });
      }
      
      final filteredBookings = bookingsData.where((booking) {
        final bookingOwnerId = booking['ownerId']?.toString() ?? '';
        final ownerIdString = ownerId.toString();
        return bookingOwnerId == ownerIdString;
      }).toList();

      print('');
      print('📊 Total bookings in response: ${bookingsData.length}');
      print('📊 Filtered bookings for owner $ownerId: ${filteredBookings.length}');

      setState(() {
        allBookings = List<Map<String, dynamic>>.from(filteredBookings);
      });
      print('✅ Final allBookings count: ${allBookings.length}');
    } else {
      print('⚠️ Bookings data is not a list or is null');
      setState(() {
        allBookings = [];
      });
    }
  } catch (e, stackTrace) {
    print('❌ Error loading bookings: $e');
    print('Stack trace: $stackTrace');
    setState(() {
      allBookings = [];
    });
  }
}

  Future<void> _editTenantRent(Map<String, dynamic> tenant) async {
    final bookingId = tenant['bookingId']?.toString();
    final currentRent = (tenant['monthlyRent'] as num?)?.toDouble() ?? 0;
    
    print('🔧 Edit Rent - Booking ID: $bookingId');
    print('🔧 Edit Rent - Current Rent: $currentRent');
    print('🔧 Edit Rent - Tenant: ${tenant['name']}');
    
    if (bookingId == null || bookingId.isEmpty) {
      print('❌ Invalid booking ID');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid booking ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final TextEditingController rentController = TextEditingController(
      text: currentRent.toStringAsFixed(0),
    );

    final newRent = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: AppTheme.primaryLight),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                'Edit Monthly Rent',
                style: TextStyle(fontSize: 14.sp),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tenant: ${tenant['name']}',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('Property: ${tenant['propertyTitle']}'),
            SizedBox(height: 2.h),
            Text(
              'Current Rent: ₹$currentRent/month',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 10.sp,
              ),
            ),
            SizedBox(height: 2.h),
            TextField(
              controller: rentController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'New Monthly Rent',
                prefixText: '₹',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
                ),
                hintText: 'Enter new rent amount',
              ),
              autofocus: true,
            ),
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 5.w),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      'This will update the monthly rent for this tenant',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 9.sp,
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
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final rentText = rentController.text.trim();
              if (rentText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter a rent amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              final parsedRent = double.tryParse(rentText);
              if (parsedRent == null || parsedRent <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter a valid rent amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              Navigator.pop(context, parsedRent);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
              foregroundColor: Colors.white,
            ),
            child: Text('Update Rent'),
          ),
        ],
      ),
    );

    if (newRent == null || newRent == currentRent) {
      print('⚠️ Rent update cancelled or unchanged');
      print('   New Rent: $newRent, Current Rent: $currentRent');
      return;
    }

    print('✅ Proceeding with rent update');
    print('   Old Rent: ₹$currentRent');
    print('   New Rent: ₹$newRent');
    print('   Booking ID: $bookingId');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.primaryLight),
                SizedBox(height: 2.h),
                Text('Updating rent...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final url = _authService.getUpdateBookingUrl(bookingId);
      print('📝 Updating booking rent');
      print('   URL: $url');
      print('   Booking ID: $bookingId');
      print('   New Rent: ₹$newRent');

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'monthlyRent': newRent,
        }),
      ).timeout(const Duration(seconds: 30));

      print('📥 Update Response Status: ${response.statusCode}');
      print('📥 Update Response Body: ${response.body}');

      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        print('✅ Response decoded successfully');
        print('   Success flag: ${data['success']}');
        
        if (data['success'] == false) {
          print('❌ Backend returned success: false');
          print('   Message: ${data['message']}');
          throw Exception(data['message'] ?? 'Failed to update rent');
        }
        
        print('✅ Rent updated successfully, reloading data...');
        await _loadData();
        print('✅ Data reloaded');
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text('Rent updated successfully: ₹${newRent.toStringAsFixed(0)}/month'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        print('❌ Server returned error status: ${response.statusCode}');
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      print('❌ Error updating rent: $e');
      print('❌ Stack trace: $stackTrace');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update rent: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _deleteTenant(Map<String, dynamic> tenant) async {
    final bookingId = tenant['bookingId']?.toString();
    
    if (bookingId == null || bookingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid booking ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                'Confirm Delete',
                style: TextStyle(fontSize: 14.sp),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to remove this tenant?'),
            SizedBox(height: 2.h),
            Text(
              'Tenant: ${tenant['name']}',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('Property: ${tenant['propertyTitle']}'),
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 5.w),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      'This action cannot be undone',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 9.sp,
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
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.primaryLight),
                SizedBox(height: 2.h),
                Text('Removing tenant...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final url = _authService.getDeleteBookingUrl(bookingId);
      print('🗑️ Deleting booking: $url');

      final response = await http.delete(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      print('📥 Delete Response Status: ${response.statusCode}');
      print('📥 Delete Response Body: ${response.body}');

      Navigator.pop(context);

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.body.isNotEmpty) {
          final data = json.decode(response.body);
          
          if (data['success'] == false) {
            throw Exception(data['message'] ?? 'Failed to delete tenant');
          }
        }
        
        await _loadData();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 2.w),
                Expanded(child: Text('Tenant removed successfully')),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      Navigator.pop(context);
      print('❌ Error deleting tenant: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove tenant: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Map<String, dynamic> _getPropertyStats(Map<String, dynamic> property) {
    final propertyId = property['_id']?.toString() ?? '';
    final propertyBookings = allBookings.where((b) =>
        b['propertyId']?.toString() == propertyId &&
        b['status'] != 'cancelled'
    ).toList();

    int totalBeds = 0;
    if (property['type'] == 'PG') {
      totalBeds = property['beds'] ?? 0;
    } else if (property['type'] == 'Flat') {
      final bhk = property['bhk']?.toString() ?? '1';
      final match = RegExp(r'(\d+)').firstMatch(bhk);
      if (match != null) {
        totalBeds = int.parse(match.group(1)!);
      }
    }

    final filledBeds = propertyBookings.length;
    final vacantBeds = totalBeds - filledBeds;

    final activeTenants = propertyBookings.where((b) => b['status'] == 'active').length;
    final leads = propertyBookings.where((b) => b['status'] == 'pending').length;
    final underNotice = propertyBookings.where((b) => b['underNotice'] == true).length;
    final totalTenants = propertyBookings.length;

    double totalDues = 0;
    for (var booking in propertyBookings) {
      totalDues += (booking['pendingDues'] ?? 0).toDouble();
    }

    return {
      'totalBeds': totalBeds,
      'filledBeds': filledBeds,
      'vacantBeds': vacantBeds,
      'activeTenants': activeTenants,
      'totalTenants': totalTenants,
      'leads': leads,
      'underNotice': underNotice,
      'totalDues': totalDues,
      'bookings': propertyBookings,
    };
  }

  List<Map<String, dynamic>> _getAllTenants() {
    final tenants = <Map<String, dynamic>>[];
    final seenBookingIds = <String>{};

    print('🔍 Processing ${allBookings.length} bookings');

    for (var booking in allBookings) {
      print('📋 Processing booking: ${booking['_id']}');
      print('   Status: ${booking['status']}');
      print('   Tenant: ${booking['tenantName']}');
      print('   Email: ${booking['tenantEmail']}');

      final bookingId = booking['_id']?.toString() ?? '';

      if (bookingId.isEmpty) {
        print('⚠️ Skipping booking - missing booking ID');
        continue;
      }

      if (booking['status'] == 'cancelled') {
        print('⚠️ Skipping cancelled booking');
        continue;
      }

      if (seenBookingIds.contains(bookingId)) {
        print('⚠️ Skipping duplicate booking');
        continue;
      }
      seenBookingIds.add(bookingId);

      final email = booking['tenantEmail']?.toString() ?? '';
      final name = booking['tenantName']?.toString() ?? 'Tenant';

      final property = myProperties.firstWhere(
            (p) => p['_id']?.toString() == booking['propertyId']?.toString(),
        orElse: () => {},
      );

      final tenant = {
        'name': name,
        'email': email,
        'phone': booking['tenantPhone']?.toString() ?? '',
        'monthlyRent': booking['monthlyRent'] ?? 0,
        'securityDeposit': booking['securityDeposit'] ?? 0,
        'moveInDate': booking['moveInDate']?.toString() ?? '',
        'leaseDuration': booking['leaseDuration'] ?? 12,
        'status': booking['status']?.toString() ?? 'active',
        'propertyTitle': property.isNotEmpty ? (property['title'] ?? 'Unknown Property') : 'Unknown Property',
        'propertyId': booking['propertyId']?.toString() ?? '',
        'bookingId': bookingId,
        'pendingDues': booking['pendingDues'] ?? 0,
        'underNotice': booking['underNotice'] ?? false,
        'documents': booking['tenantDocuments'] ?? booking['documents'] ?? {},
        'roomNumber': booking['roomNumber'],
        'occupancyType': booking['occupancyType'],
      };

      tenants.add(tenant);
      print('✅ Added tenant: ${tenant['name']} (${tenant['email']})');
    }

    print('✅ Total tenants processed: ${tenants.length}');

    // Sort tenants by room number
    tenants.sort((a, b) {
      final roomA = a['roomNumber'];
      final roomB = b['roomNumber'];

      // Handle null values - put them at the end
      if (roomA == null && roomB == null) return 0;
      if (roomA == null) return 1;
      if (roomB == null) return -1;

      // Try to parse as numbers for proper numeric sorting
      final numA = int.tryParse(roomA.toString());
      final numB = int.tryParse(roomB.toString());

      if (numA != null && numB != null) {
        return numA.compareTo(numB); // Numeric comparison
      }

      // Fall back to string comparison if not numbers
      return roomA.toString().compareTo(roomB.toString());
    });

    if (_searchQuery.isNotEmpty) {
      final filtered = tenants.where((t) {
        final name = (t['name'] as String).toLowerCase();
        final email = (t['email'] as String).toLowerCase();
        final property = (t['propertyTitle'] as String).toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || email.contains(query) || property.contains(query);
      }).toList();
      print('🔍 Filtered to ${filtered.length} tenants matching "$_searchQuery"');
      return filtered;
    }

    return tenants;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(110),
        child: AppBar(
          backgroundColor: AppTheme.primaryLight,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'People Management',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: _isLoading ? null : _loadData,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(48),
            child: Container(
              color: AppTheme.primaryLight,
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.6),
                labelStyle: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Properties Dashboard'),
                  Tab(text: 'Tenants'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : _errorMessage != null
          ? _buildErrorState()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildTenantTab(),
              ],
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 15.w, color: Colors.red),
            SizedBox(height: 2.h),
            Text(
              'Error Loading Data',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 1.h),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            SizedBox(height: 3.h),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
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

  Widget _buildDashboardTab() {
    if (myProperties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_outlined, size: 15.w, color: Colors.grey),
            SizedBox(height: 2.h),
            Text(
              'No Properties Yet',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 1.h),
            Text(
              'Add properties to see tenant management',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primaryLight,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: myProperties.map((property) {
            final stats = _getPropertyStats(property);
            return Padding(
              padding: EdgeInsets.only(bottom: 3.h),
              child: _buildPropertyCard(property, stats),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> property, Map<String, dynamic> stats) {
    final totalBeds = stats['totalBeds'] as int;
    final filledBeds = stats['filledBeds'] as int;
    final vacantBeds = stats['vacantBeds'] as int;
    final activeTenants = stats['activeTenants'] as int;
    final totalTenants = stats['totalTenants'] as int;
    final leads = stats['leads'] as int;
    final underNotice = stats['underNotice'] as int;
    final totalDues = stats['totalDues'] as double;

    String roomsInfo = '';
    if (property['type'] == 'PG') {
      roomsInfo = '${property['rooms'] ?? 1} Rooms / $totalBeds Beds';
    } else {
      roomsInfo = '${property['bhk'] ?? '1 BHK'} / $totalBeds Beds';
    }

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.apartment, color: AppTheme.primaryLight, size: 8.w),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property['title'] ?? 'Unnamed Property',
                      style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      roomsInfo,
                      style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),

          if (totalBeds > 0) ...[
            Row(
              children: [
                if (filledBeds > 0)
                  Expanded(
                    flex: filledBeds,
                    child: Container(
                      height: 3.h,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(4),
                          right: vacantBeds == 0 ? Radius.circular(4) : Radius.zero,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Filled: $filledBeds',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (vacantBeds > 0)
                  Expanded(
                    flex: vacantBeds,
                    child: Container(
                      height: 3.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.horizontal(
                          left: filledBeds == 0 ? Radius.circular(4) : Radius.zero,
                          right: Radius.circular(4),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Vacant: $vacantBeds',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 2.h),
          ],

          _buildStatRow(Icons.people, 'Total Tenants', totalTenants.toString()),
          _buildStatRow(Icons.people_alt, 'Active Tenants', activeTenants.toString()),
          _buildStatRow(Icons.campaign, 'Leads', leads.toString()),
          _buildStatRow(Icons.notifications_active, 'Under Notice', underNotice.toString()),

          if (totalDues > 0) ...[
            SizedBox(height: 1.h),
            Divider(),
            SizedBox(height: 1.h),
            Text(
              'Dues of ₹${totalDues.toStringAsFixed(0)} is pending for $activeTenants tenants',
              style: TextStyle(
                color: Colors.red,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.8.h),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryLight, size: 5.w),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              label,
              style: AppTheme.lightTheme.textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantTab() {
    final tenants = _getAllTenants();
    final tenantsWithDues = tenants.where((t) => (t['pendingDues'] as num).toDouble() > 0).length;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(4.w),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by name, email, or property',
              prefixIcon: Icon(Icons.search, color: AppTheme.primaryLight),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
              ),
            ),
          ),
        ),

        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Row(
            children: [
              Expanded(
                child: _buildTenantStatCard(
                  tenants.length.toString(),
                  'Total\nTenants',
                  AppTheme.primaryLight,
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: _buildTenantStatCard(
                  tenants.where((t) => t['status'] == 'active').length.toString(),
                  'Active\nTenants',
                  Colors.green,
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: _buildTenantStatCard(
                  tenants.where((t) => t['underNotice'] == true).length.toString(),
                  'Under\nNotice',
                  Colors.orange,
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: _buildTenantStatCard(
                  tenantsWithDues.toString(),
                  'With\nDues',
                  Colors.red,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 2.h),

        Expanded(
          child: tenants.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 15.w, color: Colors.grey),
                      SizedBox(height: 2.h),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No tenants found'
                            : 'No Tenants Yet',
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Try different search terms'
                            : 'Tenants will appear here after booking',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.primaryLight,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    itemCount: tenants.length,
                    itemBuilder: (context, index) {
                      final tenant = tenants[index];
                      return _buildTenantCard(tenant);
                    },
                  ),
                ),
        ),
      ],
    );
  }
  
  Widget _buildTenantStatCard(String value, String label, Color color) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8.sp,
              color: Colors.grey.shade700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantCard(Map<String, dynamic> tenant) {
    return TenantCardWidget(
      tenant: tenant,
      onEditRent: () => _editTenantRent(tenant),
      onDelete: () => _deleteTenant(tenant),
      onCall: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call: ${tenant['phone']}')),
        );
      },
      onEmail: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email: ${tenant['email']}')),
        );
      },
    );
  }
}

