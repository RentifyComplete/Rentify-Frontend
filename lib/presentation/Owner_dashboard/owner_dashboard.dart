import 'package:flutter/material.dart';
import 'people_screen.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'booking_requests_screen.dart';
import 'payment_due_screen.dart';
import 'maintenance_screen.dart';
import 'analytics_screen.dart';
import 'my_documents.dart';
import '../../core/app_export.dart';
import '../../services/property_service.dart';
import '../../services/auth_service.dart';
import '../../providers/user_provider.dart';
import '../add_property/add_property_screen.dart';
import 'properties_list_screen.dart';
import './widgets/quick_action_card_widget.dart';
import 'owner_bank_details_screen.dart';
import './widgets/login_footer_widget.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen>
    with TickerProviderStateMixin {
  int _currentTabIndex = 0;
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;

  // Backend Integration
  final PropertyService _propertyService = PropertyService();
  final AuthService _authService = AuthService();
  final String baseUrl = 'https://rentify-backend-cdaj.onrender.com';
  List<dynamic> myProperties = [];
  List<Map<String, dynamic>> allBookings = [];
  bool _isLoadingProperties = false;
  String? _errorMessage;

  // Weather data
  Map<String, dynamic>? weatherData;
  bool _isLoadingWeather = true;
  String? userCity;
  String? userState;

  // Mock documents data
  List<Map<String, dynamic>> recentDocuments = [
    {
      'type': 'Aadhar Card',
      'icon': Icons.badge_outlined,
      'color': Colors.blue,
      'status': 'Verified',
    },
    {
      'type': 'PAN Card',
      'icon': Icons.credit_card_outlined,
      'color': Colors.orange,
      'status': 'Verified',
    },
    {
      'type': 'Profile Photo',
      'icon': Icons.photo_camera_outlined,
      'color': Colors.green,
      'status': 'Verified',
    },
  ];

  final List<Map<String, dynamic>> ownerQuickActions = [
    {
      "title": "Bank Details",
      "subtitle": "Add/Edit account",
      "icon": "account_balance",
      "color": Color(0xFF9C27B0),
      "route": "/bank-details",
    },
    {
      "title": "Booking Requests",
      "subtitle": "Check Your Requests",
      "icon": "notifications_active",
      "color": AppTheme.warningLight,
      "route": "/booking-requests",
    },
    {
      "title": "Maintenance",
      "subtitle": "Check Your Requests",
      "icon": "build",
      "color": AppTheme.successLight,
      "route": "/maintenance",
    },
    {
      "title": "Analytics",
      "subtitle": "View insights",
      "icon": "analytics",
      "color": AppTheme.primaryLight,
      "route": "/analytics",
    },
  ];

  @override
  void initState() {
    super.initState();
    print('🎬 OwnerDashboard: initState called');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      await userProvider.loadUserData();

      if (mounted) {
        setState(() {
          userCity = userProvider.userCity;
          userState = userProvider.userState;
        });

        print('📍 Owner location loaded: $userCity, $userState');

        _loadWeatherData();
        _loadPropertiesFromDatabase();
        _loadBookingsFromDatabase();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================================
  // LOGOUT HANDLER METHOD
  // ============================================================================
// Replace the _handleLogout method (lines 139-207) with this:

Future<void> _handleLogout(BuildContext context) async {
  print('🚪 Owner logging out...');
  
  // Show confirmation dialog
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        icon: const Icon(
          Icons.logout,
          color: Colors.red,
          size: 48,
        ),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      );
    },
  );

  if (confirmed != true) {
    print('❌ Logout cancelled');
    return;
  }

  // Show loading indicator
  if (!context.mounted) return;
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => const Center(
      child: CircularProgressIndicator(),
    ),
  );

  try {
    // 1. Logout using auth service (clears session with logout flag)
    await _authService.logout();
    print('✅ Auth service logout complete');

    // 2. Clear user data from provider
    if (!context.mounted) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.clearUserData();
    print('✅ User data cleared from provider');

    // 3. Small delay to ensure everything is cleared
    await Future.delayed(const Duration(milliseconds: 300));

    if (!context.mounted) return;

    // 4. Close loading dialog
    Navigator.of(context, rootNavigator: true).pop();

    // 5. Navigate to login screen and remove all previous routes
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login-screen',
      (route) => false,
    );

    print('✅ Navigated to login screen');
    print('✅ Logout complete!');
  } catch (e, stackTrace) {
    print('❌ Logout error: $e');
    print('Stack trace: $stackTrace');

    if (!context.mounted) return;

    // Close loading dialog
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {}

    if (!context.mounted) return;

    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to logout: ${e.toString()}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
  Widget _buildLogoutMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Menu',
      onSelected: (String value) {
        if (value == 'logout') {
          _handleLogout(context);
        }
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, color: Colors.red, size: 20),
              SizedBox(width: 12),
              Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _loadWeatherData() async {
    setState(() {
      _isLoadingWeather = true;
    });

    try {
      final coordinates = await _getCityCoordinates(
          userCity ?? 'Gurugram', userState ?? 'Haryana');

      if (coordinates == null) {
        print('❌ Could not fetch coordinates for ${userCity}, ${userState}');
        setState(() {
          _isLoadingWeather = false;
        });
        return;
      }

      print(
          '📍 Fetching weather for: ${userCity}, ${userState} (${coordinates['lat']}, ${coordinates['lon']})');

      final response = await http.get(
        Uri.parse(
            'https://api.open-meteo.com/v1/forecast?latitude=${coordinates['lat']}&longitude=${coordinates['lon']}&current=temperature_2m,wind_speed_10m,relative_humidity_2m,weather_code&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m&timezone=auto'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          weatherData = data;
          _isLoadingWeather = false;
        });
        print('✅ Weather data loaded successfully for ${userCity}');
      } else {
        print('❌ Failed to load weather data: ${response.statusCode}');
        setState(() {
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      print('❌ Error loading weather data: $e');
      setState(() {
        _isLoadingWeather = false;
      });
    }
  }

  Future<Map<String, double>?> _getCityCoordinates(
      String city, String state) async {
    try {
      final query = Uri.encodeComponent('$city, $state, India');
      final response = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1'),
        headers: {
          'User-Agent': 'PropertyRentalApp/1.0',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          return {
            'lat': double.parse(data[0]['lat']),
            'lon': double.parse(data[0]['lon']),
          };
        }
      }

      print('⚠️ Using fallback coordinates for Gurugram');
      return {'lat': 28.4595, 'lon': 77.0266};
    } catch (e) {
      print('❌ Geocoding error: $e');
      return {'lat': 28.4595, 'lon': 77.0266};
    }
  }

  Future<void> _loadPropertiesFromDatabase() async {
    if (!mounted) return;

    setState(() {
      _isLoadingProperties = true;
      _errorMessage = null;
    });

    try {
      print('🔄 Dashboard: Loading properties from MongoDB...');

      final currentOwnerId = await _authService.getCurrentUserId();

      if (currentOwnerId == null || currentOwnerId.isEmpty) {
        throw Exception('User not logged in. Please login again.');
      }

      print('👤 Dashboard: Current Owner ID: $currentOwnerId');

      final dbProperties =
          await _propertyService.getPropertiesByOwnerId(currentOwnerId);

      if (!mounted) return;

      setState(() {
        myProperties.clear();
        myProperties.addAll(dbProperties);
        _isLoadingProperties = false;
      });

      print(
          '✅ Dashboard: Loaded ${dbProperties.length} properties for owner: $currentOwnerId');

      if (dbProperties.isEmpty) {
        print('⚠️ Dashboard: No properties found for this owner');
      }
    } catch (e, stackTrace) {
      print('❌ Dashboard: Error loading properties: $e');
      print('Stack trace: $stackTrace');

      if (!mounted) return;

      setState(() {
        _isLoadingProperties = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadBookingsFromDatabase() async {
    try {
      final currentOwnerId = await _authService.getCurrentUserId();

      print('🔍 DEBUG: Current Owner ID: $currentOwnerId');

      if (currentOwnerId == null || currentOwnerId.isEmpty) {
        print('❌ DEBUG: Owner ID is null or empty');
        return;
      }

      print('🔄 Dashboard: Loading bookings for owner: $currentOwnerId');

      final response = await http.get(
        Uri.parse('$baseUrl/api/bookings/owner/$currentOwnerId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      print('📥 DEBUG: Response status: ${response.statusCode}');
      print('📥 DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        print('🔍 DEBUG: Parsed data success: ${data['success']}');
        print('🔍 DEBUG: Bookings data: ${data['bookings']}');

        if (data['success'] == true && data['bookings'] != null) {
          final bookingsList = List<Map<String, dynamic>>.from(data['bookings']);

          print('✅ DEBUG: Converting ${bookingsList.length} bookings');

          if (mounted) {
            setState(() {
              allBookings = bookingsList;
            });

            print('✅ DEBUG: allBookings now has ${allBookings.length} items');
            print(
                '✅ DEBUG: Active bookings: ${allBookings.where((b) => b['status'] == 'active').length}');
          }
        }
      }
    } catch (e, stackTrace) {
      print('❌ Dashboard: Error loading bookings: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _addNewProperty() async {
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
              if (property['amenities'] != null &&
                  (property['amenities'] as List).isNotEmpty) ...[
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

  Future<void> _deleteProperty(String propertyId, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Property'),
        content: const Text('Are you sure you want to delete this property?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        print('🗑️ Deleting property: $propertyId');

        final result = await _propertyService.deleteProperty(propertyId);

        if (result['success'] == true) {
          setState(() {
            myProperties.removeAt(index);
          });
          print('✅ Property deleted successfully');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Property deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          print('❌ Failed to delete: ${result['message']}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${result['message']}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        print('❌ Error deleting property: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

 int get totalRooms {
  int total = 0;
  for (var property in myProperties) {
    // Only count rooms for PG properties (same logic as beds)
    if (property['type'] == 'PG' && property['rooms'] != null) {
      total += property['rooms'] as int;
      print('🏠 Property ${property['title']}: ${property['rooms']} rooms');
    }
  }
  print('🏠 Total Rooms: $total');
  return total;
}

  int get totalTenants {
    final count = allBookings.where((b) => b['status'] == 'active').length;
    print(
        '📊 totalTenants getter called: allBookings.length=${allBookings.length}, active=$count');
    return count;
  }

  int get vacantBeds {
    // Calculate: Total Beds - Occupied Beds (from active bookings)
    return totalBeds - occupiedBeds;
  }

  int get occupiedBeds {
    // Count beds occupied by active bookings
    int occupied = 0;
    for (var booking in allBookings) {
      if (booking['status'] == 'active') {
        // Each active booking occupies 1 bed
        occupied += 1;
      }
    }
    print('🛏️ Occupied Beds: $occupied (from ${allBookings.where((b) => b['status'] == 'active').length} active bookings)');
    return occupied;
  }

  int get totalBeds {
    int total = 0;
    for (var property in myProperties) {
      // Only count beds for PG properties
      if (property['type'] == 'PG') {
        total += (property['beds'] as int? ?? 2);
      }
    }
    print('🛏️ Total Beds: $total');
    return total;
  }

  String get totalDues {
    double total = 0;
    for (var booking in allBookings) {
      total += (booking['pendingDues'] as num? ?? 0).toDouble();
    }
    if (total >= 1000) {
      return "₹${(total / 1000).toStringAsFixed(1)}k";
    }
    return "₹${total.toInt()}";
  }

  int get totalBookings {
    print('📊 totalBookings getter called: ${allBookings.length}');
    return allBookings.length;
  }

  int get underNoticeTenants {
    return allBookings.where((b) => b['underNotice'] == true).length;
  }

  int get totalLeads {
    return allBookings.where((b) => b['status'] == 'pending').length;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppTheme.primaryLight,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildAppBar(userProvider),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 2.h),
                    _buildWeatherWidget(),
                    SizedBox(height: 3.h),
                    _buildMetricsCards(),
                    SizedBox(height: 3.h),
                    _buildSectionHeader("Quick Actions", ""),
                    SizedBox(height: 2.h),
                    _buildQuickActions(),
                    SizedBox(height: 3.h),
                    _buildSectionHeader("My Documents", "View all"),
                    SizedBox(height: 2.h),
                    _buildMyDocuments(),
                    SizedBox(height: 3.h),
                    _buildSectionHeader("My Properties", "View all"),
                    SizedBox(height: 2.h),
                    _buildMyProperties(),
                    SizedBox(height: 4.h),
                    // ⭐ CORRECTED: Using LoginFooterWidget
                    const LoginFooterWidget(),
                    SizedBox(height: 10.h),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildMyDocuments() {
    return SizedBox(
      height: 14.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        itemCount: recentDocuments.length,
        itemBuilder: (context, index) {
          final document = recentDocuments[index];
          return Padding(
            padding: EdgeInsets.only(right: 3.w),
            child: _buildDocumentCard(document),
          );
        },
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> document) {
    return Container(
      width: 45.w,
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: document['status'] == 'Verified'
              ? Colors.green
              : Colors.grey.shade300,
          width: document['status'] == 'Verified' ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: (document['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  document['icon'] as IconData,
                  color: document['color'] as Color,
                  size: 6.w,
                ),
              ),
              if (document['status'] == 'Verified')
                Icon(Icons.check_circle, color: Colors.green, size: 5.w),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                document['type'],
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 0.5.h),
              Text(
                document['status'],
                style: TextStyle(
                  fontSize: 10.sp,
                  color: document['status'] == 'Verified'
                      ? Colors.green
                      : Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherWidget() {
    if (_isLoadingWeather) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryLight,
                AppTheme.primaryLight.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryLight.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    if (weatherData == null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey.shade400, Colors.grey.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.white, size: 10.w),
              SizedBox(width: 3.w),
              Text(
                'Weather data unavailable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final current = weatherData!['current'];
    final temperature = current['temperature_2m'];
    final windSpeed = current['wind_speed_10m'];
    final humidity = current['relative_humidity_2m'] ?? 0;
    final weatherCode = current['weather_code'] ?? 0;

    IconData weatherIcon = Icons.wb_sunny;
    String weatherDescription = 'Clear';
    Color gradientStart = const Color(0xFF4A90E2);
    Color gradientEnd = const Color(0xFF357ABD);

    if (weatherCode >= 61 && weatherCode <= 67) {
      weatherIcon = Icons.umbrella;
      weatherDescription = 'Rainy';
      gradientStart = const Color(0xFF546E7A);
      gradientEnd = const Color(0xFF37474F);
    } else if (weatherCode >= 51 && weatherCode <= 57) {
      weatherIcon = Icons.grain;
      weatherDescription = 'Drizzle';
      gradientStart = const Color(0xFF78909C);
      gradientEnd = const Color(0xFF546E7A);
    } else if (weatherCode >= 71 && weatherCode <= 77) {
      weatherIcon = Icons.ac_unit;
      weatherDescription = 'Snowy';
      gradientStart = const Color(0xFFB0BEC5);
      gradientEnd = const Color(0xFF90A4AE);
    } else if (weatherCode >= 1 && weatherCode <= 3) {
      weatherIcon = Icons.wb_cloudy;
      weatherDescription = 'Cloudy';
      gradientStart = const Color(0xFF90A4AE);
      gradientEnd = const Color(0xFF78909C);
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [gradientStart, gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradientStart.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            color: Colors.white70, size: 4.w),
                        SizedBox(width: 1.w),
                        Text(
                          '${userCity ?? "Unknown"}, ${userState ?? ""}',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${temperature.toStringAsFixed(1)}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '°C',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      weatherDescription,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Icon(weatherIcon, color: Colors.white, size: 20.w),
              ],
            ),
            SizedBox(height: 2.h),
            Divider(color: Colors.white30, thickness: 1),
            SizedBox(height: 1.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWeatherDetail(
                    Icons.air, 'Wind', '${windSpeed.toStringAsFixed(1)} km/h'),
                Container(width: 1, height: 30, color: Colors.white30),
                _buildWeatherDetail(Icons.water_drop, 'Humidity', '$humidity%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherDetail(IconData icon, String label, String value) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 4.w),
            SizedBox(width: 1.w),
            Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10.sp,
              ),
            ),
          ],
        ),
        SizedBox(height: 0.5.h),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(UserProvider userProvider) {
    return SliverAppBar(
      floating: true,
      snap: true,
      elevation: 0,
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      title: Row(
        children: [
          CustomImageWidget(
            imageUrl: userProvider.userProfilePicture,
            width: 10.w,
            height: 10.w,
            fit: BoxFit.cover,
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome Owner",
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "Manage your properties",
                  style: AppTheme.lightTheme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // IconButton(
        //   onPressed: () {},
        //   icon: CustomIconWidget(
        //     iconName: 'notifications',
        //     color: AppTheme.primaryLight,
        //     size: 6.w,
        //   ),
        // ),
        _buildLogoutMenu(),
        SizedBox(width: 2.w),
      ],
    );
  }

  Widget _buildMetricsCards() {
    final metrics = [
      {
        'value': totalRooms.toString(),
        'label': 'Total\nRooms',
        'icon': Icons.meeting_room,
        'color': Colors.green,
      },
      {
        'value': underNoticeTenants.toString(),
        'label': 'Under Notice\nTenants',
        'icon': Icons.notifications_active,
        'color': Colors.red,
      },
      {
        'value': vacantBeds.toString(),
        'label': 'Vacant\nBeds',
        'icon': Icons.bed_outlined,
        'color': Colors.grey.shade600,
      },
      {
        'value': totalBookings.toString(),
        'label': 'Total\nBookings',
        'icon': Icons.book_online,
        'color': Colors.orange,
      },
      {
        'value': totalBeds.toString(),
        'label': 'Total\nBeds',
        'icon': Icons.hotel,
        'color': Colors.orange.shade700,
      },
      {
        'value': totalTenants.toString(),
        'label': 'Total\nTenants',
        'icon': Icons.people,
        'color': Colors.green,
      },
      {
        'value': totalLeads.toString(),
        'label': 'Total\nLeads',
        'icon': Icons.campaign,
        'color': Colors.green.shade400,
      },
      {
        'value': totalDues,
        'label': 'Total\nDues',
        'icon': Icons.attach_money,
        'color': Colors.orange,
      },
    ];

    return SizedBox(
      height: 13.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        itemCount: metrics.length,
        itemBuilder: (context, index) {
          final metric = metrics[index];
          return Padding(
            padding: EdgeInsets.only(right: 3.w),
            child: _buildMetricCard(
              value: metric['value'] as String,
              label: metric['label'] as String,
              icon: metric['icon'] as IconData,
              color: metric['color'] as Color,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 28.w,
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value,
            style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    height: 1.2,
                    fontSize: 9.sp,
                  ),
                  maxLines: 2,
                ),
              ),
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 5.w,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String actionText) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actionText.isNotEmpty)
            TextButton(
              onPressed: () {
                if (title == "My Properties") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PropertiesListScreen(),
                    ),
                  );
                } else if (title == "My Documents") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyDocumentsScreen(),
                    ),
                  );
                }
              },
              child: Text(
                actionText,
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.primaryLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 3.w,
          mainAxisSpacing: 2.h,
          childAspectRatio: 1.5,
        ),
        itemCount: ownerQuickActions.length,
        itemBuilder: (context, index) {
          final action = ownerQuickActions[index];
          return QuickActionCardWidget(
            title: action["title"] as String,
            subtitle: action["subtitle"] as String,
            iconName: action["icon"] as String,
            color: action["color"] as Color,
            onTap: () {
              final route = action["route"] as String?;

              if (route == "/bank-details") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OwnerBankDetailsScreen(),
                  ),
                ).then((result) {
                  if (result == true && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bank details saved! You can now receive tenant payments.'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                });
              } else if (route == "/booking-requests") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BookingRequestsScreen(),
                  ),
                );
              } else if (route == "/maintenance") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MaintenanceScreen(),
                  ),
                );
              } else if (route == "/analytics") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AnalyticsScreen(),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildMyProperties() {
    if (_isLoadingProperties) {
      return SizedBox(
        height: 40.h,
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryLight,
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return SizedBox(
        height: 30.h,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 8.w, color: Colors.red),
                SizedBox(height: 1.h),
                Text(
                  'Error loading properties',
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 1.h),
                TextButton(
                  onPressed: _loadPropertiesFromDatabase,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (myProperties.isEmpty) {
      return SizedBox(
        height: 40.h,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.home_outlined,
                  size: 12.w,
                  color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                ),
                SizedBox(height: 1.h),
                Text(
                  'No properties yet',
                  style: AppTheme.lightTheme.textTheme.titleMedium,
                ),
                SizedBox(height: 0.5.h),
                Text(
                  'Add your first property',
                  style: AppTheme.lightTheme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 32.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        itemCount: myProperties.length,
        itemBuilder: (context, index) {
          final property = myProperties[index];
          return Padding(
            padding: EdgeInsets.only(right: 4.w),
            child: _buildPropertyCard(property, index),
          );
        },
      ),
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> property, int index) {
    final propertyId = property['_id'] ?? property['id'] ?? '';
    final isVerified = property['isVerified'] == true;

    String? imageUrl;
    if (property['images'] != null && property['images'] is List && (property['images'] as List).isNotEmpty) {
      imageUrl = property['images'][0];
    } else if (property['image'] != null) {
      imageUrl = property['image'];
    }

    return Container(
      width: 75.w,
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: 15.h,
              width: double.infinity,
              color: Colors.grey.shade200,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CustomImageWidget(
                imageUrl: imageUrl,
                height: 15.h,
                width: double.infinity,
                fit: BoxFit.cover,
              )
                  : Center(
                child: Icon(
                  Icons.home,
                  size: 10.w,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ),
          Flexible(
            child: Padding(
              padding: EdgeInsets.all(3.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          property['title'] ?? 'Unnamed Property',
                          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified) ...[
                        SizedBox(width: 2.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 2.w,
                            vertical: 0.5.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.successLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified,
                                color: Colors.white,
                                size: 3.w,
                              ),
                              SizedBox(width: 1.w),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 8.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 4.w,
                        color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
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
                  ),
                  SizedBox(height: 1.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          property['price'] ?? '₹0',
                          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                            color: AppTheme.primaryLight,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "/month",
                        style: AppTheme.lightTheme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showPropertyDetails(property),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.primaryLight),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 1.h),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Details',
                            style: TextStyle(
                              color: AppTheme.primaryLight,
                              fontSize: 10.sp,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 2.w),
                      InkWell(
                        onTap: () => _deleteProperty(propertyId, index),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.all(2.w),
                          child: Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 5.w,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentTabIndex,
      onTap: (index) async {
        print('🎯 Bottom Nav Tapped: Index $index');

        if (index == 0) {
          print('✅ Already on Dashboard');
          return;
        }

        try {
          switch (index) {
            case 1:
              print('🏠 Navigating to Properties List...');
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PropertiesListScreen(),
                ),
              );
              print('✅ Returned from Properties List');
              await _loadPropertiesFromDatabase();
              break;

            case 2:
              print('💬 Navigating to People Screen...');
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PeopleScreen(),
                ),
              );
              print('✅ Returned from People Screen');
              break;

            case 3:
              print('💰 Navigating to Payment Due Screen...');
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaymentDueScreen(),
                ),
              );
              print('✅ Returned from Payment Due Screen');
              break;
          }
        } catch (e, stackTrace) {
          print('❌ Navigation Error: $e');
          print('Stack trace: $stackTrace');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      selectedItemColor: AppTheme.primaryLight,
      unselectedItemColor: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
      selectedFontSize: 11.sp,
      unselectedFontSize: 10.sp,
      items: [
        BottomNavigationBarItem(
          icon: CustomIconWidget(
            iconName: 'home',
            color: _currentTabIndex == 0
                ? AppTheme.primaryLight
                : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            size: 6.w,
          ),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: CustomIconWidget(
            iconName: 'apartment',
            color: _currentTabIndex == 1
                ? AppTheme.primaryLight
                : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            size: 6.w,
          ),
          label: 'Properties',
        ),
        BottomNavigationBarItem(
          icon: CustomIconWidget(
            iconName: 'people',
            color: _currentTabIndex == 2
                ? AppTheme.primaryLight
                : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            size: 6.w,
          ),
          label: 'People',
        ),
        BottomNavigationBarItem(
          icon: CustomIconWidget(
            iconName: 'payment',
            color: _currentTabIndex == 3
                ? AppTheme.primaryLight
                : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            size: 6.w,
          ),
          label: 'Payment',
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _addNewProperty,
      backgroundColor: AppTheme.accentLight,
      foregroundColor: Colors.white,
      icon: CustomIconWidget(
        iconName: 'add_home',
        color: Colors.white,
        size: 5.w,
      ),
      label: Text(
        'Add Property',
        style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _isRefreshing = true;
    });

    await Future.wait([
      _loadPropertiesFromDatabase(),
      _loadBookingsFromDatabase(),
      _loadWeatherData(),
    ]);

    setState(() {
      _isRefreshing = false;
    });
  }
}