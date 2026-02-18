// lib/presentation/home_dashboard/home_dashboard.dart
// ⭐ UPDATED:
// 1. Removed Quick Actions from Home tab
// 2. Replaced ALL mock data in Profile section with real data from backend
// 3. Added real booking data, maintenance requests, and documents

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../Owner_dashboard/owner_dashboard.dart';
import '../../core/app_export.dart';
import '../../services/backend_service.dart';
import '../../services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/user_provider.dart';
import '../../providers/document_provider.dart'; // ⭐ NEW
import 'widgets/featured_property_card_widget.dart';
import 'widgets/location_weather_widget.dart';
import 'widgets/occupancy_overview_widget.dart';
import 'widgets/revenue_analytics_widget.dart';
import 'property_booking_screen.dart';
import 'tenant_rent_payment_screen.dart';
import 'my_properties_screen.dart';
// Profile imports
import 'widgets/tenant_overview_card.dart';
import 'widgets/rent_payment_card.dart';
import 'widgets/maintenance_requests_card.dart';
import 'widgets/lease_documents_card.dart';
// ⭐ REMOVED: import 'widgets/quick_action_menu.dart'; - Not using quick actions in profile
import './widgets/login_footer_widget.dart';
import 'edit_profile_screen.dart';
import 'widgets/document_upload_widget.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with TickerProviderStateMixin {
  int _currentTabIndex = 0;
  bool _isPropertyOwner = false;
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;

  final BackendService _backendService = BackendService();
  final AuthService _authService = AuthService();
  final String baseUrl = 'https://rentify-backend-cdaj.onrender.com';

  List<Map<String, dynamic>> featuredProperties = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Weather data
  Map<String, dynamic>? weatherData;
  bool _isLoadingWeather = true;
  String? userCity;
  String? userState;

  // ⭐ NEW: Real tenant booking data
  Map<String, dynamic>? _activeBooking;
  bool _isLoadingBooking = true;

  // ⭐ NEW: Real maintenance requests
  List<Map<String, dynamic>> _maintenanceRequests = [];
  bool _isLoadingMaintenance = true;

  @override
  void initState() {
    super.initState();
    _loadProperties();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      await userProvider.loadUserData();

      if (mounted) {
        setState(() {
          userCity = userProvider.userCity;
          userState = userProvider.userState;
        });

        print('📍 Tenant location loaded: $userCity, $userState');

        _loadWeatherData();

        // ⭐ NEW: Load real tenant data
        _loadActiveBooking();
        _loadMaintenanceRequests();
      }
    });
  }

  // ⭐ NEW: Load active booking for tenant
  // ⭐ FIXED: Load active booking with proper error handling
  Future<void> _loadActiveBooking() async {
    setState(() {
      _isLoadingBooking = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final tenantEmail = userProvider.userEmail;

      if (tenantEmail.isEmpty) {
        print('⚠️ No tenant email found');
        _activeBooking = null;
        return;
      }

      print('🔍 Loading active booking for: $tenantEmail');

      final response = await http.get(
        Uri.parse('$baseUrl/api/bookings/tenant/$tenantEmail'),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⏰ Booking API timeout');
          throw Exception('Request timeout');
        },
      );

      print('📥 Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && (data['bookings'] as List).isNotEmpty) {
          _activeBooking = data['bookings'].first;
          print('✅ Booking loaded: ${_activeBooking!['propertyTitle']}');
          print('🚪 Room Number: ${_activeBooking!['roomNumber']}'); // ⭐ NEW LOG
          print('👥 Occupancy Type: ${_activeBooking!['occupancyType']}'); // ⭐ NEW LOG
        } else {
          print('⚠️ No bookings found');
          _activeBooking = null;
        }
      } else if (response.statusCode == 404) {
        print('⚠️ Booking API not found (404)');
        _activeBooking = null;
      } else {
        print('❌ API error: ${response.statusCode}');
        _activeBooking = null;
      }
    } catch (e) {
      print('❌ Error: $e');
      _activeBooking = null;
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBooking = false;
        });
      }
    }
  }

  // ⭐ NEW: Load maintenance requests
  // ⭐ FIXED: Load maintenance with proper error handling
  Future<void> _loadMaintenanceRequests() async {
    setState(() {
      _isLoadingMaintenance = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final tenantEmail = userProvider.userEmail;

      if (tenantEmail.isEmpty) {
        print('⚠️ No tenant email');
        _maintenanceRequests = [];
        return;
      }

      print('🔍 Loading maintenance for: $tenantEmail');

      final response = await http.get(
        Uri.parse('$baseUrl/api/maintenance/tenant/$tenantEmail'),
      ).timeout(
        const Duration(seconds: 5), // ⭐ 5 seconds instead of 30!
        onTimeout: () {
          print('⏰ Maintenance API timeout');
          throw Exception('Request timeout');
        },
      );

      print('📥 Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          _maintenanceRequests = List<Map<String, dynamic>>.from(data['requests'] ?? []);
          print('✅ Loaded ${_maintenanceRequests.length} requests');
        } else {
          _maintenanceRequests = [];
        }
      } else if (response.statusCode == 404) {
        // ⭐ Handle 404 gracefully
        print('⚠️ Maintenance API not found (404)');
        _maintenanceRequests = [];
      } else {
        print('❌ API error: ${response.statusCode}');
        _maintenanceRequests = [];
      }
    } catch (e) {
      print('❌ Error: $e');
      _maintenanceRequests = [];
    } finally {
      // ⭐ CRITICAL: Always stop loading
      if (mounted) {
        setState(() {
          _isLoadingMaintenance = false;
        });
      }
    }
  }
Future<void> _handleLogout(BuildContext context) async {
  print('🚪 User logging out...');
  
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
    // 1. Logout using auth service (this should clear session)
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
      final coordinates = await _getCityCoordinates(userCity ?? 'Gurugram', userState ?? 'Haryana');

      if (coordinates == null) {
        print('❌ Could not fetch coordinates for ${userCity}, ${userState}');
        setState(() {
          _isLoadingWeather = false;
        });
        return;
      }

      print('📍 Fetching weather for: ${userCity}, ${userState} (${coordinates['lat']}, ${coordinates['lon']})');

      final response = await http.get(
        Uri.parse(
            'https://api.open-meteo.com/v1/forecast?latitude=${coordinates['lat']}&longitude=${coordinates['lon']}&current=temperature_2m,wind_speed_10m,relative_humidity_2m,weather_code&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m&timezone=auto'
        ),
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

  Future<Map<String, double>?> _getCityCoordinates(String city, String state) async {
    try {
      final query = Uri.encodeComponent('$city, $state, India');
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1'),
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

  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔄 Loading properties from backend...');
      final properties = await _backendService.getAllProperties();

      final transformedProperties = properties.map((prop) {
        return {
          "id": prop['_id'],
          "title": prop['title'],
          "location": '${prop['city']}, ${prop['state']}',
          "price": prop['price'],
          "rating": prop['rating'] ?? 4.5,
          "image": (prop['images'] != null && (prop['images'] as List).isNotEmpty)
              ? prop['images'][0]
              : prop['image'] ?? 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800',
          "type": prop['type'],
          "amenities": prop['amenities'] ?? [],
          "isVerified": prop['isVerified'] ?? false,
        };
      }).toList();

      setState(() {
        featuredProperties = transformedProperties;
        _isLoading = false;
      });

      print('✅ Loaded ${featuredProperties.length} properties');
    } catch (e) {
      print('❌ Error loading properties: $e');
      setState(() {
        _errorMessage = 'Failed to load properties: $e';
        _isLoading = false;
      });
    }
  }

  void _navigateToBooking() {
    print('');
    print('📅📅📅 NAVIGATING TO BOOKING SCREEN');
    print('════════════════════════════════════════');

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            print('✅ Building PropertyBookingScreen widget...');
            return const PropertyBookingScreen();
          },
        ),
      ).then((_) {
        print('✅ Returned from Booking screen');
        setState(() {
          _currentTabIndex = 0;
        });
      }).catchError((error) {
        print('❌ Navigation error: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open bookings: $error'),
            backgroundColor: Colors.red,
          ),
        );
      });
    } catch (e, stack) {
      print('❌ Exception during navigation: $e');
      print('Stack trace: $stack');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: Could not open bookings screen'),
          backgroundColor: Colors.red,
        ),
      );
    }

    print('════════════════════════════════════════');
    print('');
  }

  void _navigateToMyProperties() {
    print('🏠 Navigating to My Properties screen');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MyPropertiesScreen(),
      ),
    );
  }

  void _navigateToRentPayments() {
    print('💰 Navigating to Rent Payments screen');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TenantRentPaymentScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppTheme.primaryLight,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 2.h),
                    if (_currentTabIndex == 2)
                      _buildProfileContent()
                    else ...[
                      _buildWeatherWidget(),
                      SizedBox(height: 3.h),
                      _isPropertyOwner
                          ? _buildOwnerContent()
                          : _buildTenantContent(),
                      SizedBox(height: 2.h),
                    ],
                    SizedBox(height: 4.h),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      child: const LoginFooterWidget(),
                    ),

                    SizedBox(height: 10.h),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _currentTabIndex != 2 ? _buildFloatingActionButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
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
    Color gradientStart = Color(0xFF4A90E2);
    Color gradientEnd = Color(0xFF357ABD);

    if (weatherCode >= 61 && weatherCode <= 67) {
      weatherIcon = Icons.umbrella;
      weatherDescription = 'Rainy';
      gradientStart = Color(0xFF546E7A);
      gradientEnd = Color(0xFF37474F);
    } else if (weatherCode >= 51 && weatherCode <= 57) {
      weatherIcon = Icons.grain;
      weatherDescription = 'Drizzle';
      gradientStart = Color(0xFF78909C);
      gradientEnd = Color(0xFF546E7A);
    } else if (weatherCode >= 71 && weatherCode <= 77) {
      weatherIcon = Icons.ac_unit;
      weatherDescription = 'Snowy';
      gradientStart = Color(0xFFB0BEC5);
      gradientEnd = Color(0xFF90A4AE);
    } else if (weatherCode >= 1 && weatherCode <= 3) {
      weatherIcon = Icons.wb_cloudy;
      weatherDescription = 'Cloudy';
      gradientStart = Color(0xFF90A4AE);
      gradientEnd = Color(0xFF78909C);
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
              offset: Offset(0, 4),
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
                        Icon(Icons.location_on, color: Colors.white70, size: 4.w),
                        SizedBox(width: 1.w),
                        Text(
                          '$userCity, $userState',
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
                _buildWeatherDetail(Icons.air, 'Wind', '${windSpeed.toStringAsFixed(1)} km/h'),
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

  Widget _buildAppBar() {
    final userProvider = Provider.of<UserProvider>(context);
    final userName = userProvider.userName;
    final userProfilePic = userProvider.userProfilePicture;

    if (_currentTabIndex == 2) {
      return SliverAppBar(
        floating: true,
        snap: true,
        elevation: 0,
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        title: Text(
          "My Profile",
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/tenant-notifications');
            },
            icon: CustomIconWidget(
              iconName: 'notifications',
              color: AppTheme.primaryLight,
              size: 6.w,
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/tenant-settings');
            },
            icon: CustomIconWidget(
              iconName: 'settings',
              color: AppTheme.primaryLight,
              size: 6.w,
            ),
          ),
          _buildLogoutMenu(),
          SizedBox(width: 2.w),
        ],
      );
    }

    // Home/Bookings tabs AppBar
    return SliverAppBar(
      floating: true,
      snap: true,
      elevation: 0,
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      title: Row(
        children: [
          CustomImageWidget(
            imageUrl: userProfilePic,
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
                  _isPropertyOwner
                      ? "Welcome back, $userName!"
                      : "Good morning, $userName!",
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _isPropertyOwner ? "Manage your properties" : "Find your perfect home",
                  style: AppTheme.lightTheme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (!_isPropertyOwner)
          IconButton(
            onPressed: _navigateToRentPayments,
            icon: CustomIconWidget(
              iconName: 'payment',
              color: AppTheme.primaryLight,
              size: 6.w,
            ),
            tooltip: 'Pay Rent',
          ),
        if (!_isPropertyOwner)
          IconButton(
            onPressed: _navigateToMyProperties,
            icon: CustomIconWidget(
              iconName: 'home_work',
              color: AppTheme.primaryLight,
              size: 6.w,
            ),
            tooltip: 'My Properties',
          ),
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

  // ⭐ UPDATED: Removed QuickActionsHorizontalWidget from tenant content
  Widget _buildTenantContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Featured Properties", "View all"),
        SizedBox(height: 2.h),
        _buildFeaturedProperties(),
        SizedBox(height: 3.h),

        // Rent Payment Card (Quick Access)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: _navigateToRentPayments,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryLight.withOpacity(0.1),
                      AppTheme.primaryLight.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.payment,
                        color: Colors.white,
                        size: 8.w,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pay Monthly Rent',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryLight,
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            'View due dates & pay rent for your properties',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: AppTheme.primaryLight,
                      size: 5.w,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 3.h),

        // ⭐ REMOVED: QuickActionsHorizontalWidget(isPropertyOwner: false),

        _buildSectionHeader("Recently Viewed", "View all"),
        SizedBox(height: 2.h),
        _buildRecentlyViewed(),
      ],
    );
  }

  Widget _buildOwnerContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Occupancy Overview", ""),
        SizedBox(height: 2.h),
        OccupancyOverviewWidget(),
        SizedBox(height: 3.h),
        _buildSectionHeader("Revenue Analytics", "View details"),
        SizedBox(height: 2.h),
        RevenueAnalyticsWidget(),
        SizedBox(height: 3.h),
      ],
    );
  }

  // ⭐ UPDATED: Profile content with REAL data from backend
  Widget _buildProfileContent() {
    final userProvider = Provider.of<UserProvider>(context);

    // Show loading state
    if (_isLoadingBooking) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Column(
          children: [
            SizedBox(height: 10.h),
            CircularProgressIndicator(color: AppTheme.primaryLight),
            SizedBox(height: 2.h),
            Text(
              'Loading your profile...',
              style: TextStyle(fontSize: 11.sp, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // ⭐ Use real booking data with safe fallbacks
    final hasActiveBooking = _activeBooking != null;

    // ⭐ NEW: Calculate lease end date from booking data
    String leaseEndDate = DateTime.now().add(Duration(days: 365)).toIso8601String();
    if (hasActiveBooking && _activeBooking!['moveInDate'] != null && _activeBooking!['leaseDuration'] != null) {
      final moveInDate = DateTime.parse(_activeBooking!['moveInDate']);
      final leaseDurationMonths = _activeBooking!['leaseDuration'] as int;
      leaseEndDate = moveInDate.add(Duration(days: leaseDurationMonths * 30)).toIso8601String();
    }

    // ⭐ Map booking data to profile format
    final profileData = {
      "name": userProvider.userName,
      "profilePicture": userProvider.userProfilePicture,
      "propertyName": _activeBooking?['propertyTitle'] ?? 'No Active Booking',
      "propertyAddress": _activeBooking?['propertyAddress'] ?? 'Book a property to see details here',
      "rentAmount": _activeBooking?['monthlyRent'] ?? 0,
      "nextDueDate": _activeBooking?['rentDueDate'] ?? DateTime.now().add(Duration(days: 30)).toIso8601String(),
      "pendingMaintenanceCount": _maintenanceRequests.where((req) => req['status'] == 'pending').length,
      "leaseEndDate": leaseEndDate,
      "securityDeposit": _activeBooking?['securityDeposit'] ?? 0,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ⭐ MAIN USER INFO CARD
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 8.w,
                    backgroundImage: NetworkImage(userProvider.userProfilePicture),
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userProvider.userName,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          userProvider.userEmail,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (userProvider.userPhone.isNotEmpty) ...[
                          SizedBox(height: 0.5.h),
                          Text(
                            userProvider.userPhone,
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(),
                        ),
                      );
                    },
                    icon: Icon(Icons.edit, color: AppTheme.primaryLight),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 2.h),

        // ⭐ NO BOOKING STATE
        if (!hasActiveBooking) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Card(
              elevation: 2,
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child: Column(
                  children: [
                    Icon(
                      Icons.home_outlined,
                      size: 15.w,
                      color: AppTheme.primaryLight,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'No Active Booking',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryLight,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'Book a property to see your rental details here',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 2.h),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _currentTabIndex = 1);
                        _navigateToBooking();
                      },
                      icon: Icon(Icons.search),
                      label: Text('Browse Properties'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryLight,
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 1.5.h,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 2.h),
        ],

        // ⭐ PROPERTY INFO CARD WITH ROOM NUMBER (Only when has booking)
        if (hasActiveBooking) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryLight,
                    AppTheme.primaryVariantLight,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryLight.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Property Info
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CustomIconWidget(
                              iconName: 'home',
                              color: Colors.white,
                              size: 5.w,
                            ),
                            SizedBox(width: 2.w),
                            Expanded(
                              child: Text(
                                profileData['propertyName'] as String,
                                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 1.h),
                        Row(
                          children: [
                            CustomIconWidget(
                              iconName: 'location_on',
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 4.w,
                            ),
                            SizedBox(width: 2.w),
                            Expanded(
                              child: Text(
                                profileData['propertyAddress'] as String,
                                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // ⭐ NEW: Room Number & Occupancy Display
                        // ⭐ FIXED: Show occupancy even if room number is null
                        if ((_activeBooking!['roomNumber'] != null &&
                            _activeBooking!['roomNumber'].toString().isNotEmpty) ||
                            (_activeBooking!['occupancyType'] != null &&
                                _activeBooking!['occupancyType'].toString().isNotEmpty)) ...[
                          SizedBox(height: 1.h),
                          Divider(color: Colors.white.withValues(alpha: 0.3), thickness: 1),
                          SizedBox(height: 1.h),
                          Row(
                            children: [
                              // Room Number - only show if available
                              if (_activeBooking!['roomNumber'] != null &&
                                  _activeBooking!['roomNumber'].toString().isNotEmpty)
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(2.w),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.meeting_room,
                                          color: Colors.white,
                                          size: 5.w,
                                        ),
                                      ),
                                      SizedBox(width: 2.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Room No.',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.7),
                                                fontSize: 9.sp,
                                              ),
                                            ),
                                            Text(
                                              _activeBooking!['roomNumber'].toString(),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Occupancy Type - always show if available
                              if (_activeBooking!['occupancyType'] != null &&
                                  _activeBooking!['occupancyType'].toString().isNotEmpty)
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(2.w),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.people,
                                          color: Colors.white,
                                          size: 5.w,
                                        ),
                                      ),
                                      SizedBox(width: 2.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Occupancy',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.7),
                                                fontSize: 9.sp,
                                              ),
                                            ),
                                            Text(
                                              _activeBooking!['occupancyType'] ?? 'Single',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 2.h),

                  // Summary Stats
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(3.w),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomIconWidget(
                                iconName: 'paid',
                                color: AppTheme.accentLight,
                                size: 6.w,
                              ),
                              SizedBox(height: 1.h),
                              Text(
                                'Next Rent Due',
                                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              SizedBox(height: 0.5.h),
                              Text(
                                '₹${_formatCurrency(profileData['rentAmount'] as int)}',
                                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                _formatDate(profileData['nextDueDate'] as String),
                                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(3.w),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomIconWidget(
                                iconName: 'calendar_today',
                                color: AppTheme.accentLight,
                                size: 6.w,
                              ),
                              SizedBox(height: 1.h),
                              Text(
                                'Lease Ends',
                                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              SizedBox(height: 0.5.h),
                              Text(
                                _formatDate(profileData['leaseEndDate'] as String),
                                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                _getDaysRemaining(profileData['leaseEndDate'] as String),
                                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 2.h),
        ],

        SizedBox(height: 1.h),

        // Rent & Payments - Only show if has active booking
        if (hasActiveBooking) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Text(
              "Rent & Payments",
              style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 1.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: RentPaymentCard(
              rentAmount: profileData['rentAmount'] as int,
              nextDueDate: profileData['nextDueDate'] as String,
              onViewHistory: () {
                Navigator.pushNamed(context, '/payment-history');
              },
              onPayRent: _navigateToRentPayments,
            ),
          ),
          SizedBox(height: 3.h),
        ],

        // Maintenance - Always show (can request even without booking)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Text(
            "Maintenance",
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(height: 1.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: _isLoadingMaintenance
              ? Container(
            height: 15.h,
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryLight),
            ),
          )
              : MaintenanceRequestsCard(
            tenantId: userProvider.userEmail,
          ),
        ),
        SizedBox(height: 3.h),

        // Lease & Documents - Only show if has active booking
        // Lease & Documents - Only show if has active booking
        if (hasActiveBooking) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Text(
              "Lease & Documents",
              style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 1.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: LeaseDocumentsCard(
              leaseEndDate: profileData['leaseEndDate'] as String,
              securityDeposit: profileData['securityDeposit'] as int,
            ),
          ),
          SizedBox(height: 2.h),

          // ✅ ADD THIS: Rental Agreement Section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: FutureBuilder<String?>(
              future: _backendService.getPropertyAgreementUrl(
                _activeBooking!['propertyId']?.toString() ?? '',
              ),
              builder: (context, snapshot) {
                final agreementUrl = snapshot.data;
                final hasAgreement = agreementUrl != null && agreementUrl.isNotEmpty;

                return Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: hasAgreement ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasAgreement ? Colors.green.shade200 : Colors.orange.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description,
                        color: hasAgreement ? Colors.green.shade700 : Colors.orange.shade700,
                        size: 6.w,
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rental Agreement',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: hasAgreement
                                    ? Colors.green.shade900
                                    : Colors.orange.shade900,
                              ),
                            ),
                            Text(
                              hasAgreement
                                  ? 'Tap to download your agreement'
                                  : 'Agreement not yet generated',
                              style: TextStyle(
                                fontSize: 9.sp,
                                color: hasAgreement
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        SizedBox(
                          width: 5.w,
                          height: 5.w,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (hasAgreement)
                        ElevatedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(agreementUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: Icon(Icons.download, size: 4.w),
                          label: Text('Download', style: TextStyle(fontSize: 9.sp)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 3.h),
        ],

        // Documents Upload - Always show
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: DocumentUploadWidget(),
        ),
        SizedBox(height: 3.h),
      ],
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
              onPressed: () {},
              child: Row(
                children: [
                  Text(
                    actionText,
                    style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primaryLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 1.w),
                  CustomIconWidget(
                    iconName: 'arrow_forward',
                    color: AppTheme.primaryLight,
                    size: 4.w,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturedProperties() {
    if (_isLoading) {
      return SizedBox(
        height: 32.h,
        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryLight)),
      );
    }

    if (_errorMessage != null) {
      return SizedBox(
        height: 32.h,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 12.w, color: Colors.red),
              SizedBox(height: 2.h),
              Text('Failed to load properties', style: TextStyle(color: Colors.red)),
              TextButton(onPressed: _loadProperties, child: Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (featuredProperties.isEmpty) {
      return SizedBox(
        height: 32.h,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.home_outlined, size: 12.w, color: Colors.grey),
              SizedBox(height: 2.h),
              Text('No properties available', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 32.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        itemCount: featuredProperties.length,
        itemBuilder: (context, index) {
          final property = featuredProperties[index];
          return Padding(
            padding: EdgeInsets.only(right: 4.w),
            child: FeaturedPropertyCardWidget(
              property: property,
              onTap: () => _showPropertyDetailsPopup(property), // ⭐ CHANGED
              onFavorite: () {},
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentlyViewed() {
    if (featuredProperties.isEmpty) {
      return SizedBox(
        height: 25.h,
        child: Center(
          child: Text('No recently viewed properties', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return SizedBox(
      height: 25.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        itemCount: featuredProperties.length > 2 ? 2 : featuredProperties.length,
        itemBuilder: (context, index) {
          final property = featuredProperties[index];
          return Padding(
            padding: EdgeInsets.only(right: 4.w),
            child: SizedBox(
              width: 70.w,
              child: FeaturedPropertyCardWidget(
                property: property,
                onTap: () => _showPropertyDetailsPopup(property), // ⭐ CHANGED
                onFavorite: () {},
                isCompact: true,
              ),
            ),
          );
        },
      ),
    );
  }

  // ⭐ NEW: Show property details in popup
  void _showPropertyDetailsPopup(Map<String, dynamic> property) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: EdgeInsets.all(5.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: EdgeInsets.only(bottom: 2.h),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Property Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      property['image'] ?? '',
                      height: 25.h,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 25.h,
                          color: Colors.grey.shade200,
                          child: Icon(Icons.image_not_supported, size: 50),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: 2.h),

                  // Title and Type
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          property['title'] ?? 'Property',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          property['type'] ?? 'Apartment',
                          style: TextStyle(
                            fontSize: 9.sp,
                            color: AppTheme.primaryLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 1.h),

                  // Location
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                      SizedBox(width: 1.w),
                      Expanded(
                        child: Text(
                          property['location'] ?? 'Unknown Location',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 2.h),

                  // Price
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Monthly Rent',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '₹${property['price']?.toString() ?? '0'}/month',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 2.h),

                  // Rating
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 20),
                      SizedBox(width: 1.w),
                      Text(
                        '${property['rating'] ?? 4.5}',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 2.w),
                      if (property['isVerified'] == true)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, color: Colors.green, size: 14),
                              SizedBox(width: 1.w),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  SizedBox(height: 2.h),

                  // Amenities
                  if (property['amenities'] != null && (property['amenities'] as List).isNotEmpty) ...[
                    Text(
                      'Amenities',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Wrap(
                      spacing: 2.w,
                      runSpacing: 1.h,
                      children: (property['amenities'] as List)
                          .map((amenity) => Chip(
                        label: Text(
                          amenity.toString(),
                          style: TextStyle(fontSize: 8.sp),
                        ),
                        backgroundColor: Colors.grey.shade100,
                      ))
                          .toList(),
                    ),
                    SizedBox(height: 2.h),
                  ],

                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryLight,
                        padding: EdgeInsets.symmetric(vertical: 1.8.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 2.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    if (_isPropertyOwner) {
      return BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          print('📱 Owner tab tapped: $index');
          setState(() => _currentTabIndex = index);

          switch (index) {
            case 0:
              print('🏠 Home');
              break;
            case 1:
              print('📅 Bookings');
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        selectedItemColor: AppTheme.primaryLight,
        unselectedItemColor: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
        items: [
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'home',
              color: _currentTabIndex == 0 ? AppTheme.primaryLight : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 6.w,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'book_online',
              color: _currentTabIndex == 1 ? AppTheme.primaryLight : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 6.w,
            ),
            label: 'Bookings',
          ),
        ],
      );
    }

    return BottomNavigationBar(
      currentIndex: _currentTabIndex,
      onTap: (index) {
        print('📱 Tenant tab tapped: $index');
        setState(() => _currentTabIndex = index);

        switch (index) {
          case 0:
            print('🏠 Home');
            break;
          case 1:
            print('📅 Bookings');
            _navigateToBooking();
            break;
          case 2:
            print('👤 Profile');
            break;
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      selectedItemColor: AppTheme.primaryLight,
      unselectedItemColor: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
      items: [
        BottomNavigationBarItem(
          icon: CustomIconWidget(
            iconName: 'home',
            color: _currentTabIndex == 0 ? AppTheme.primaryLight : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            size: 6.w,
          ),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: CustomIconWidget(
            iconName: 'book_online',
            color: _currentTabIndex == 1 ? AppTheme.primaryLight : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            size: 6.w,
          ),
          label: 'Bookings',
        ),
        BottomNavigationBarItem(
          icon: CustomIconWidget(
            iconName: 'person',
            color: _currentTabIndex == 2 ? AppTheme.primaryLight : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            size: 6.w,
          ),
          label: 'Profile',
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        if (_isPropertyOwner) {
          Navigator.pushNamed(context, '/add-property');
        } else {
          Navigator.pushNamed(context, '/search');
        }
      },
      backgroundColor: AppTheme.accentLight,
      foregroundColor: Colors.white,
      icon: CustomIconWidget(
        iconName: _isPropertyOwner ? 'add_home' : 'search',
        color: Colors.white,
        size: 5.w,
      ),
      label: Text(
        _isPropertyOwner ? 'Add Property' : 'Search',
        style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      _loadProperties(),
      _loadWeatherData(),
      _loadActiveBooking(),
      _loadMaintenanceRequests(),
      Provider.of<UserProvider>(context, listen: false).refreshUserData(),
    ]);
  }

  // Helper methods for formatting
  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day} ${months[date.month - 1]}, ${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _getDaysRemaining(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = date.difference(now).inDays;
      if (difference < 0) return 'Expired';
      if (difference == 0) return 'Today';
      if (difference == 1) return 'Tomorrow';
      if (difference < 30) return '$difference days left';
      final months = (difference / 30).floor();
      return '$months month${months > 1 ? 's' : ''} left';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}