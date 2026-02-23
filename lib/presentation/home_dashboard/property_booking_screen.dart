// lib/presentation/home_dashboard/property_booking_screen.dart
// ⭐ UPDATED: property view tracking now sends real name & phone from MongoDB

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/app_export.dart';
import '../../services/backend_service.dart';
import '../../services/auth_service.dart';
import 'my_properties_screen.dart';

class PropertyBookingScreen extends StatefulWidget {
  const PropertyBookingScreen({super.key});

  @override
  State<PropertyBookingScreen> createState() => _PropertyBookingScreenState();
}

class _PropertyBookingScreenState extends State<PropertyBookingScreen> {
  final BackendService _backendService = BackendService();
  final AuthService _authService = AuthService();
  final String baseUrl = 'https://rentify-backend-cdaj.onrender.com';

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _filteredProperties = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedType = 'All';
  RangeValues _priceRange = const RangeValues(0, 100000);
  String _searchQuery = '';
  String _selectedCity = 'All';

  final List<String> _propertyTypes = [
    'All', 'Apartment', 'House', 'Villa', 'Studio', 'Penthouse', 'PG', 'Flat'
  ];
  List<String> _cities = ['All'];

  @override
  void initState() {
    super.initState();
    _loadProperties();
    _searchController.addListener(() {
      setState(() { _searchQuery = _searchController.text; });
      _applyFilters();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // SAFE TYPE HELPERS
  // ============================================================
  int _parseToInt(dynamic value, int defaultValue) {
    try {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        final t = value.trim();
        if (t.isEmpty) return defaultValue;
        return int.tryParse(t) ?? defaultValue;
      }
      return defaultValue;
    } catch (_) { return defaultValue; }
  }

  String _parseToString(dynamic value, String defaultValue) {
    try {
      if (value == null) return defaultValue;
      return value.toString();
    } catch (_) { return defaultValue; }
  }

  bool _parseToBool(dynamic value, bool defaultValue) {
    try {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      if (value is int) return value == 1;
      return defaultValue;
    } catch (_) { return defaultValue; }
  }

  double _parseToDouble(dynamic value, double defaultValue) {
    try {
      if (value == null) return defaultValue;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final t = value.trim();
        if (t.isEmpty) return defaultValue;
        return double.tryParse(t) ?? defaultValue;
      }
      return defaultValue;
    } catch (_) { return defaultValue; }
  }

  List<dynamic> _parseToList(dynamic value) {
    try {
      if (value == null) return [];
      if (value is List) return value;
      if (value is String && value.isNotEmpty) {
        return value.split(',').map((e) => e.trim()).toList();
      }
      return [];
    } catch (_) { return []; }
  }

  // ============================================================
  // RECORD PROPERTY VIEW
  // Fetches tenant's real name & phone from MongoDB via getUserById
  // ============================================================
  Future<void> _recordPropertyView(Map<String, dynamic> property) async {
    try {
      final userEmail = await _authService.getUserEmail();
      if (userEmail == null) return;

      // ── Fetch real name & phone from users collection ──
      String tenantName  = userEmail; // fallback
      String tenantPhone = '';

      try {
        final userId = await _authService.getCurrentUserId();
        if (userId != null) {
          final userModel = await _authService.getUserById(userId);
          if (userModel != null) {
            final personal = userModel.personalDetails ?? {};

            // Name: try common field names in personalDetails
            tenantName = personal['fullName']
                ?? personal['name']
                ?? personal['firstName']
                ?? userModel.email;

            // Phone: try common field names in personalDetails
            tenantPhone = personal['phone']
                ?? personal['phoneNumber']
                ?? personal['mobile']
                ?? personal['contact']
                ?? '';

            print('👤 Tenant: $tenantName | 📞 Phone: $tenantPhone');
          }
        }
      } catch (e) {
        print('⚠️ Could not fetch user profile for view record: $e');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/property-views/record'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'propertyId':  property['_id'],
          'ownerId':     property['ownerId'],
          'tenantEmail': userEmail,
          'tenantName':  tenantName,
          'tenantPhone': tenantPhone,
        }),
      ).timeout(const Duration(seconds: 10));

      print('👁️ View recorded: ${response.statusCode}');
    } catch (e) {
      print('⚠️ Could not record property view: $e');
    }
  }

  // ============================================================
  // GET BOOKING REQUEST STATUS
  // ============================================================
  Future<Map<String, dynamic>?> _getBookingRequestStatus(String propertyId) async {
    try {
      final userEmail = await _authService.getUserEmail();
      if (userEmail == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/booking-requests/tenant/$userEmail'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final requests = data['requests'] as List;
          final request = requests.firstWhere(
            (r) => r['propertyId'] == propertyId,
            orElse: () => null,
          );
          return request;
        }
      }
      return null;
    } catch (e) {
      print('⚠️ Error fetching request status: $e');
      return null;
    }
  }

  // ============================================================
  // LOAD PROPERTIES
  // ============================================================
  Future<void> _loadProperties() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final properties = await _backendService.getAllProperties();
      final userEmail  = await _authService.getUserEmail();

      final transformedProperties = await Future.wait(properties.map((prop) async {
        try {
          int price = 0;
          if (prop['price'] is String) {
            String priceStr = (prop['price'] as String).replaceAll(RegExp(r'[^0-9]'), '');
            price = int.tryParse(priceStr) ?? 0;
          } else if (prop['price'] is int) {
            price = prop['price'] as int;
          }

          int bedrooms = 0;
          if (prop['bedrooms'] != null) {
            bedrooms = prop['bedrooms'] is int
                ? prop['bedrooms']
                : int.tryParse(prop['bedrooms'].toString()) ?? 0;
          } else if (prop['bhk'] != null) {
            String bhkStr = prop['bhk'].toString().split(' ')[0];
            bedrooms = int.tryParse(bhkStr) ?? 0;
          }
          if (bedrooms == 0) bedrooms = 1;

          Map<String, dynamic>? bookingRequest;
          if (userEmail != null) {
            bookingRequest = await _getBookingRequestStatus(prop['_id']);
          }

          return {
            '_id':              _parseToString(prop['_id'], ''),
            'ownerId':          _parseToString(prop['ownerId'], ''),
            'title':            _parseToString(prop['title'], 'Untitled Property'),
            'description':      _parseToString(prop['description'], 'No description available'),
            'type':             _parseToString(prop['type'], 'Apartment'),
            'price':            price,
            'city':             _parseToString(prop['city'], 'Unknown'),
            'state':            _parseToString(prop['state'], ''),
            'address':          _parseToString(prop['address'], ''),
            'bedrooms':         bedrooms,
            'bathrooms':        _parseToInt(prop['bathrooms'], 0),
            'area':             _parseToInt(prop['area'], 0),
            'amenities':        _parseToList(prop['amenities']),
            'images':           _parseToList(prop['images']),
            'image':            _getPropertyImage(prop),
            'rating':           _parseToDouble(prop['rating'], 4.5),
            'isVerified':       _parseToBool(prop['isVerified'], false),
            'bookingStatus':    bookingRequest?['status'] ?? 'none',
            'bookingRequestId': bookingRequest?['_id'],
          };
        } catch (e) {
          return {
            '_id': '', 'ownerId': '',
            'title': 'Error Loading Property',
            'price': 0, 'city': 'Unknown',
            'image': 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800',
            'bookingStatus': 'none',
          };
        }
      }));

      final cities = transformedProperties
          .map((p) => _parseToString(p['city'], 'Unknown'))
          .where((c) => c.isNotEmpty && c != 'Unknown')
          .toSet()
          .toList()
        ..sort();

      setState(() {
        _properties = transformedProperties;
        _filteredProperties = transformedProperties;
        _cities = ['All', ...cities];
        _isLoading = false;
      });

      print('✅ Loaded ${_properties.length} properties');
    } catch (e, st) {
      print('❌ Error loading properties: $e\n$st');
      setState(() { _errorMessage = 'Failed to load properties: $e'; _isLoading = false; });
    }
  }

  String _getPropertyImage(Map<String, dynamic> prop) {
    try {
      final images = _parseToList(prop['images']);
      if (images.isNotEmpty) return _parseToString(images[0], '');
      return _parseToString(prop['image'],
          'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800');
    } catch (_) {
      return 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800';
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredProperties = _properties.where((p) {
        try {
          if (_selectedType != 'All' && p['type'] != _selectedType) return false;
          final price = _parseToInt(p['price'], 0);
          if (price < _priceRange.start || price > _priceRange.end) return false;
          if (_selectedCity != 'All' && p['city'] != _selectedCity) return false;
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            if (!_parseToString(p['title'],   '').toLowerCase().contains(q) &&
                !_parseToString(p['city'],    '').toLowerCase().contains(q) &&
                !_parseToString(p['type'],    '').toLowerCase().contains(q) &&
                !_parseToString(p['address'], '').toLowerCase().contains(q)) return false;
          }
          return true;
        } catch (_) { return false; }
      }).toList();
    });
  }

  // ============================================================
  // FILTER BOTTOM SHEET
  // ============================================================
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(builder: (context, setSheetState) {
        return Padding(
          padding: EdgeInsets.all(5.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: EdgeInsets.only(bottom: 2.h),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text('Filters',
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 2.h),
              Text('Property Type',
                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600)),
              SizedBox(height: 1.h),
              Wrap(
                spacing: 2.w, runSpacing: 1.h,
                children: _propertyTypes.map((type) {
                  final isSelected = _selectedType == type;
                  return FilterChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (_) => setSheetState(() => _selectedType = type),
                    selectedColor: AppTheme.primaryLight.withOpacity(0.2),
                    checkmarkColor: AppTheme.primaryLight,
                  );
                }).toList(),
              ),
              SizedBox(height: 2.h),
              Text('City',
                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600)),
              SizedBox(height: 1.h),
              DropdownButtonFormField<String>(
                value: _selectedCity,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                ),
                items: _cities.map((c) =>
                    DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setSheetState(() => _selectedCity = v!),
              ),
              SizedBox(height: 2.h),
              Text(
                'Price Range: ₹${_priceRange.start.toInt()} - ₹${_priceRange.end.toInt()}',
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600),
              ),
              RangeSlider(
                values: _priceRange, min: 0, max: 100000, divisions: 100,
                activeColor: AppTheme.primaryLight,
                onChanged: (v) => setSheetState(() => _priceRange = v),
              ),
              SizedBox(height: 2.h),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedType = 'All'; _selectedCity = 'All';
                        _priceRange = const RangeValues(0, 100000);
                        _searchController.clear();
                      });
                      _applyFilters();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        side: const BorderSide(color: Colors.grey)),
                    child: const Text('Reset'),
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {});
                      _applyFilters();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryLight,
                        padding: EdgeInsets.symmetric(vertical: 1.5.h)),
                    child: const Text('Apply Filters'),
                  ),
                ),
              ]),
              SizedBox(height: 2.h),
            ],
          ),
        );
      }),
    );
  }

  // ============================================================
  // SHOW PROPERTY DETAILS — records view with real name + phone
  // ============================================================
  void _showPropertyDetails(Map<String, dynamic> property) {
    _recordPropertyView(property); // ← records to backend with real name & phone
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: EdgeInsets.all(5.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: EdgeInsets.only(bottom: 2.h),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _parseToString(property['image'], ''),
                      height: 25.h, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 25.h, color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported, size: 50),
                      ),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _parseToString(property['title'], 'Property'),
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _parseToString(property['type'], 'Apartment'),
                          style: TextStyle(
                              fontSize: 9.sp, color: AppTheme.primaryLight,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  Row(children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                    SizedBox(width: 1.w),
                    Expanded(
                      child: Text(
                        '${_parseToString(property['city'], 'Unknown')}, ${_parseToString(property['state'], '')}',
                        style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600),
                      ),
                    ),
                  ]),
                  if (_parseToString(property['address'], '').isNotEmpty) ...[
                    SizedBox(height: 0.5.h),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.home, size: 16, color: Colors.grey.shade600),
                      SizedBox(width: 1.w),
                      Expanded(
                        child: Text(_parseToString(property['address'], ''),
                            style: TextStyle(fontSize: 9.sp, color: Colors.grey.shade600)),
                      ),
                    ]),
                  ],
                  SizedBox(height: 2.h),
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Monthly Rent',
                            style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade700)),
                        Text('₹${_parseToInt(property['price'], 0)}',
                            style: TextStyle(
                                fontSize: 13.sp, fontWeight: FontWeight.bold,
                                color: AppTheme.primaryLight)),
                      ],
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text('Property Features',
                      style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600)),
                  SizedBox(height: 1.h),
                  Row(children: [
                    _buildFeatureChip(Icons.bed,
                        '${_parseToInt(property['bedrooms'], 0)} Bedrooms'),
                    SizedBox(width: 2.w),
                    _buildFeatureChip(Icons.bathroom,
                        '${_parseToInt(property['bathrooms'], 0)} Bathrooms'),
                  ]),
                  if (_parseToInt(property['area'], 0) > 0) ...[
                    SizedBox(height: 1.h),
                    _buildFeatureChip(Icons.square_foot,
                        '${_parseToInt(property['area'], 0)} sq ft'),
                  ],
                  SizedBox(height: 2.h),
                  if (_parseToString(property['description'], '').isNotEmpty) ...[
                    Text('Description',
                        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600)),
                    SizedBox(height: 1.h),
                    Text(_parseToString(property['description'], ''),
                        style: TextStyle(
                            fontSize: 9.sp, color: Colors.grey.shade700, height: 1.5)),
                    SizedBox(height: 2.h),
                  ],
                  if (_parseToList(property['amenities']).isNotEmpty) ...[
                    Text('Amenities',
                        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600)),
                    SizedBox(height: 1.h),
                    Wrap(
                      spacing: 2.w, runSpacing: 1.h,
                      children: _parseToList(property['amenities'])
                          .map((a) => Chip(
                                label: Text(a.toString(),
                                    style: TextStyle(fontSize: 8.sp)),
                                backgroundColor: Colors.grey.shade100,
                              ))
                          .toList(),
                    ),
                    SizedBox(height: 2.h),
                  ],
                  SizedBox(width: double.infinity, child: _buildActionButton(property)),
                  SizedBox(height: 2.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      decoration: BoxDecoration(
          color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: AppTheme.primaryLight),
        SizedBox(width: 1.w),
        Text(label, style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildActionButton(Map<String, dynamic> property) {
    final status = property['bookingStatus'] ?? 'none';
    switch (status) {
      case 'pending':
        return OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.schedule, size: 18),
          label: const Text('Request Sent'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange,
            disabledForegroundColor: Colors.orange.withOpacity(0.6),
            side: BorderSide(color: Colors.orange.withOpacity(0.6), width: 1.5),
            padding: EdgeInsets.symmetric(vertical: 1.3.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      case 'approved':
        return ElevatedButton.icon(
          onPressed: () => _navigateToPayment(property),
          icon: const Icon(Icons.payment, size: 18),
          label: const Text('Pay Now'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green, foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 1.3.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      case 'rejected':
        return OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.cancel, size: 18),
          label: const Text('Request Rejected'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            disabledForegroundColor: Colors.red.withOpacity(0.6),
            side: BorderSide(color: Colors.red.withOpacity(0.6), width: 1.5),
            padding: EdgeInsets.symmetric(vertical: 1.3.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      default:
        return ElevatedButton.icon(
          onPressed: () => _showBookingDialog(property),
          icon: const Icon(Icons.send, size: 18),
          label: const Text('Send Booking Request'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryLight, foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 1.3.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
    }
  }

  void _navigateToPayment(Map<String, dynamic> property) {
    Navigator.pushNamed(context, '/property-details', arguments: {
      'propertyId': property['_id'],
      'requestId':  property['bookingRequestId'],
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':  return Colors.orange;
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default:         return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':  return 'PENDING';
      case 'approved': return 'APPROVED';
      case 'rejected': return 'REJECTED';
      default:         return '';
    }
  }

  // ============================================================
  // BOOKING DIALOG
  // ============================================================
  void _showBookingDialog(Map<String, dynamic> property) {
    DateTime? selectedDate;
    int leaseDuration = 12;
    String occupancyType = 'Single';
    final nameController  = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final monthlyRent     = _parseToInt(property['price'], 0);
          final securityDeposit = monthlyRent * 2;
          return AlertDialog(
            title: const Text('Send Booking Request'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_parseToString(property['title'], 'Property'),
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.sp)),
                  SizedBox(height: 1.h),
                  Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(children: [
                      _buildPriceRow('Monthly Rent', monthlyRent),
                      Divider(height: 2.h),
                      _buildPriceRow('Security Deposit (2 months)', securityDeposit),
                    ]),
                  ),
                  SizedBox(height: 1.h),
                  Text('💡 Payment will be requested after owner approval',
                      style: TextStyle(
                          fontSize: 9.sp, color: Colors.orange.shade700,
                          fontStyle: FontStyle.italic)),
                  SizedBox(height: 2.h),
                  Text('Your Details',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10.sp)),
                  SizedBox(height: 1.h),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text('Move-in Date *',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10.sp)),
                  SizedBox(height: 1.h),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate:   DateTime.now(),
                        lastDate:    DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) setDialogState(() => selectedDate = date);
                    },
                    child: Container(
                      padding: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDate != null
                                ? DateFormat('MMM dd, yyyy').format(selectedDate!)
                                : 'Select Date',
                            style: TextStyle(
                                color: selectedDate != null ? Colors.black87 : Colors.grey),
                          ),
                          Icon(Icons.calendar_today, color: AppTheme.primaryLight),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text('Lease Duration',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10.sp)),
                  SizedBox(height: 1.h),
                  DropdownButtonFormField<int>(
                    value: leaseDuration,
                    decoration: InputDecoration(
                      labelText: 'Lease Duration',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    ),
                    items: [
                      for (int i = 1; i <= 12; i++)
                        DropdownMenuItem(value: i,
                            child: Text('$i ${i == 1 ? "month" : "months"}')),
                    ],
                    onChanged: (v) => setDialogState(() => leaseDuration = v!),
                  ),
                  SizedBox(height: 2.h),
                  Text('Room Occupancy Type *',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10.sp)),
                  SizedBox(height: 1.h),
                  DropdownButtonFormField<String>(
                    value: occupancyType,
                    decoration: InputDecoration(
                      labelText: 'Occupancy Type',
                      prefixIcon: Icon(Icons.people, color: AppTheme.primaryLight),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Single',    child: Text('Single Occupancy')),
                      DropdownMenuItem(value: 'Double',    child: Text('Double Occupancy (Sharing)')),
                      DropdownMenuItem(value: 'Triple',    child: Text('Triple Occupancy (Sharing)')),
                      DropdownMenuItem(value: 'Quadruple', child: Text('Quadruple Occupancy (Sharing)')),
                    ],
                    onChanged: (v) => setDialogState(() => occupancyType = v!),
                  ),
                  SizedBox(height: 2.h),
                  Text('Additional Notes (Optional)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10.sp)),
                  SizedBox(height: 1.h),
                  TextField(
                    controller: notesController, maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Any specific requirements...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: (nameController.text.isNotEmpty &&
                        phoneController.text.isNotEmpty &&
                        emailController.text.isNotEmpty &&
                        selectedDate != null &&
                        occupancyType.isNotEmpty)
                    ? () {
                        Navigator.pop(context);
                        _sendBookingRequest(
                          property: property,
                          bookingDetails: {
                            'name':            nameController.text,
                            'phone':           phoneController.text,
                            'email':           emailController.text,
                            'moveInDate':      selectedDate!,
                            'leaseDuration':   leaseDuration,
                            'occupancyType':   occupancyType,
                            'notes':           notesController.text,
                            'monthlyRent':     monthlyRent,
                            'securityDeposit': securityDeposit,
                          },
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight),
                child: const Text('Send Request'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPriceRow(String label, int amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 9.sp)),
        Text('₹$amount', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<void> _sendBookingRequest({
    required Map<String, dynamic> property,
    required Map<String, dynamic> bookingDetails,
  }) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: AppTheme.primaryLight),
              SizedBox(height: 2.h),
              Text('Sending Request...',
                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );

      final response = await http.post(
        Uri.parse('$baseUrl/api/booking-requests/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'propertyId':      property['_id'],
          'tenantId':        null,
          'tenantName':      bookingDetails['name'],
          'tenantEmail':     bookingDetails['email'],
          'tenantPhone':     bookingDetails['phone'],
          'monthlyRent':     bookingDetails['monthlyRent'],
          'securityDeposit': bookingDetails['securityDeposit'],
          'moveInDate':      bookingDetails['moveInDate'].toIso8601String(),
          'leaseDuration':   bookingDetails['leaseDuration'],
          'occupancyType':   bookingDetails['occupancyType'],
          'notes':           bookingDetails['notes'] ?? '',
        }),
      ).timeout(const Duration(seconds: 30));

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          await _loadProperties();
          if (mounted) _showRequestSentSuccess(property, bookingDetails);
        } else {
          throw Exception(data['message'] ?? 'Failed to send request');
        }
      } else {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'HTTP ${response.statusCode}');
      }
    } catch (e, st) {
      print('❌ Error sending booking request: $e\n$st');
      if (mounted) {
        try { Navigator.pop(context); } catch (_) {}
        _showErrorDialog('Failed to send request: $e');
      }
    }
  }

  void _showRequestSentSuccess(
      Map<String, dynamic> property, Map<String, dynamic> bookingDetails) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.send, color: Colors.green, size: 15.w),
            ),
            SizedBox(height: 3.h),
            Text('Request Sent!',
                style: TextStyle(
                    fontSize: 13.sp, fontWeight: FontWeight.bold,
                    color: Colors.green)),
            SizedBox(height: 1.h),
            Text(
              'Your booking request has been sent to the property owner.\n\nYou will be notified once the owner reviews your request.',
              style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 3.h),
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                  color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildDetailRow('Property', property['title']),
                Divider(height: 2.h),
                _buildDetailRow('Move-in Date',
                    DateFormat('MMM dd, yyyy').format(bookingDetails['moveInDate'])),
                Divider(height: 2.h),
                _buildDetailRow('Status', 'Pending Approval'),
              ]),
            ),
            SizedBox(height: 3.h),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const MyPropertiesScreen()));
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 1.5.h),
                    side: BorderSide(color: AppTheme.primaryLight),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('View My Requests',
                      style: TextStyle(
                          color: AppTheme.primaryLight, fontWeight: FontWeight.w600)),
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    padding: EdgeInsets.symmetric(vertical: 1.5.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Done',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 9.sp, color: Colors.grey.shade600)),
        Expanded(
          child: Text(value,
              style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 2.w),
          const Text('Error'),
        ]),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Book Property'),
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadProperties, tooltip: 'Refresh'),
          IconButton(
            icon: const Icon(Icons.request_page),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MyPropertiesScreen())),
            tooltip: 'My Requests',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by title, city, type...',
                    prefixIcon: Icon(Icons.search, color: AppTheme.primaryLight),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear())
                        : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.primaryLight, width: 2)),
                    filled: true, fillColor: Colors.white,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              Container(
                decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12)),
                child: IconButton(
                  icon: const Icon(Icons.filter_list, color: Colors.white),
                  onPressed: _showFilterSheet, tooltip: 'Filters',
                ),
              ),
            ]),
          ),

          // Results count
          if (!_isLoading)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Row(children: [
                Text(
                  '${_filteredProperties.length} ${_filteredProperties.length == 1 ? "property" : "properties"} found',
                  style: TextStyle(
                      fontSize: 10.sp, color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500),
                ),
              ]),
            ),

          SizedBox(height: 1.h),

          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryLight))
                : _filteredProperties.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off,
                                size: 80, color: Colors.grey.shade300),
                            SizedBox(height: 2.h),
                            Text('No properties found',
                                style: TextStyle(
                                    fontSize: 12.sp, fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600)),
                            SizedBox(height: 1.h),
                            Text('Try adjusting your search or filters',
                                style: TextStyle(
                                    fontSize: 10.sp, color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.primaryLight,
                        onRefresh: _loadProperties,
                        child: ListView.builder(
                          padding: EdgeInsets.all(4.w),
                          itemCount: _filteredProperties.length,
                          itemBuilder: (context, index) {
                            final property = _filteredProperties[index];
                            final status = property['bookingStatus'] ?? 'none';

                            return Card(
                              margin: EdgeInsets.only(bottom: 3.h),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(16)),
                                      child: Image.network(
                                        property['image'],
                                        height: 20.h,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          height: 20.h,
                                          color: Colors.grey.shade200,
                                          child: const Icon(
                                              Icons.image_not_supported, size: 50),
                                        ),
                                      ),
                                    ),
                                    if (status != 'none')
                                      Positioned(
                                        top: 2.w, right: 2.w,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 3.w, vertical: 1.h),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(status),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(_getStatusText(status),
                                              style: TextStyle(
                                                  color: Colors.white, fontSize: 8.sp,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                  ]),
                                  Padding(
                                    padding: EdgeInsets.all(4.w),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(property['title'],
                                            style: TextStyle(
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.bold),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                        SizedBox(height: 0.5.h),
                                        Row(children: [
                                          Icon(Icons.location_on,
                                              size: 16, color: Colors.grey),
                                          SizedBox(width: 1.w),
                                          Text(
                                            '${property['city']}, ${property['state']}',
                                            style: TextStyle(
                                                fontSize: 10.sp, color: Colors.grey),
                                          ),
                                        ]),
                                        SizedBox(height: 1.h),
                                        Text('₹${property['price']}/month',
                                            style: TextStyle(
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryLight)),
                                        SizedBox(height: 1.5.h),
                                        Row(children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () =>
                                                  _showPropertyDetails(property),
                                              icon: const Icon(Icons.info_outline,
                                                  size: 18),
                                              label: const Text('Details'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppTheme.primaryLight,
                                                side: BorderSide(
                                                    color: AppTheme.primaryLight,
                                                    width: 1.5),
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 1.3.h),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(8)),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 3.w),
                                          Expanded(
                                            flex: 2,
                                            child: _buildActionButton(property),
                                          ),
                                        ]),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}