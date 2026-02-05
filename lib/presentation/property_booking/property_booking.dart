import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/app_export.dart';
import '../../services/properties_service.dart';
import '../../providers/user_provider.dart';
import '../../presentation/property_details/property_details.dart';

class PropertyBookingScreen extends StatefulWidget {
  const PropertyBookingScreen({super.key});

  @override
  State<PropertyBookingScreen> createState() => _PropertyBookingScreenState();
}

class _PropertyBookingScreenState extends State<PropertyBookingScreen> {
  final PropertiesService _propertiesService = PropertiesService();
  final String baseUrl = 'https://rentify-backend-cdaj.onrender.com';
  
  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _filteredProperties = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filters
  String _selectedType = 'All';
  RangeValues _priceRange = const RangeValues(0, 100000);
  String _searchQuery = '';
  String _selectedCity = 'All';

  final List<String> _propertyTypes = [
    'All',
    'Apartment',
    'House',
    'Villa',
    'Studio',
    'Penthouse',
    'Flat',
  ];
  List<String> _cities = ['All'];

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔄 Loading properties for booking...');
      final properties = await _propertiesService.getAllProperties();

      final transformedProperties = properties.map((prop) {
        // Parse price
        int price = 0;
        if (prop['price'] is String) {
          String priceStr = (prop['price'] as String).replaceAll(RegExp(r'[^0-9]'), '');
          price = int.tryParse(priceStr) ?? 0;
        } else if (prop['price'] is int) {
          price = prop['price'] as int;
        }

        // Parse bedrooms
        int bedrooms = 0;
        if (prop['bedrooms'] != null) {
          bedrooms = prop['bedrooms'] is int ? prop['bedrooms'] : int.tryParse(prop['bedrooms'].toString()) ?? 0;
        } else if (prop['bhk'] != null) {
          String bhkStr = prop['bhk'].toString().split(' ')[0];
          bedrooms = int.tryParse(bhkStr) ?? 0;
        }

        return {
          '_id': prop['_id']?.toString() ?? prop['id']?.toString() ?? '',
          'title': prop['title'] ?? 'Untitled Property',
          'description': prop['description'] ?? 'No description available',
          'type': prop['type'] ?? 'Flat',
          'price': price,
          'city': prop['city'] ?? 'Unknown',
          'state': prop['state'] ?? '',
          'address': prop['address'] ?? '',
          'bedrooms': bedrooms,
          'bathrooms': prop['bathrooms'] ?? 1,
          'area': prop['area'] ?? 0,
          'amenities': prop['amenities'] ?? [],
          'images': prop['images'] ?? [],
          'image': (prop['images'] != null && (prop['images'] as List).isNotEmpty)
              ? prop['images'][0]
              : prop['image'] ?? 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800',
          'rating': prop['rating'] ?? 4.5,
          'isVerified': prop['isVerified'] ?? false,
          'availableFrom': prop['availableFrom'] ?? DateTime.now().toIso8601String(),
          'ownerId': prop['ownerId'] ?? prop['owner'] ?? '',
          'ownerName': prop['ownerName'] ?? 'Property Owner',
          'ownerContact': prop['ownerContact'] ?? '',
        };
      }).toList();

      final cities = transformedProperties
          .map((p) => p['city'] as String)
          .where((city) => city != 'Unknown')
          .toSet()
          .toList();
      cities.sort();

      setState(() {
        _properties = transformedProperties;
        _filteredProperties = transformedProperties;
        _cities = ['All', ...cities];
        _isLoading = false;
      });

      print('✅ Loaded ${_properties.length} properties for booking');
    } catch (e) {
      print('❌ Error loading properties: $e');
      setState(() {
        _errorMessage = 'Failed to load properties: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredProperties = _properties.where((property) {
        if (_selectedType != 'All' && property['type'] != _selectedType) {
          return false;
        }

        final price = property['price'] as int;
        if (price < _priceRange.start || price > _priceRange.end) {
          return false;
        }

        if (_selectedCity != 'All' && property['city'] != _selectedCity) {
          return false;
        }

        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final title = (property['title'] as String).toLowerCase();
          final city = (property['city'] as String).toLowerCase();
          final type = (property['type'] as String).toLowerCase();

          if (!title.contains(query) && !city.contains(query) && !type.contains(query)) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFilterSheet(),
    );
  }

  Widget _buildFilterSheet() {
    String tempSelectedType = _selectedType;
    String tempSelectedCity = _selectedCity;
    RangeValues tempPriceRange = _priceRange;

    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          height: 70.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filters',
                      style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          tempSelectedType = 'All';
                          tempSelectedCity = 'All';
                          tempPriceRange = const RangeValues(0, 100000);
                        });
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(4.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Property Type',
                        style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Wrap(
                        spacing: 2.w,
                        runSpacing: 1.h,
                        children: _propertyTypes.map((type) {
                          final isSelected = tempSelectedType == type;
                          return ChoiceChip(
                            label: Text(type),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                tempSelectedType = type;
                              });
                            },
                            selectedColor: AppTheme.primaryLight,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        'City',
                        style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      DropdownButtonFormField<String>(
                        value: tempSelectedCity,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 1.5.h,
                          ),
                        ),
                        items: _cities.map((city) {
                          return DropdownMenuItem(
                            value: city,
                            child: Text(city),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() {
                            tempSelectedCity = value!;
                          });
                        },
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        'Price Range',
                        style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        '₹${tempPriceRange.start.toInt()} - ₹${tempPriceRange.end.toInt()}',
                        style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      RangeSlider(
                        values: tempPriceRange,
                        min: 0,
                        max: 100000,
                        divisions: 100,
                        activeColor: AppTheme.primaryLight,
                        onChanged: (values) {
                          setModalState(() {
                            tempPriceRange = values;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedType = tempSelectedType;
                        _selectedCity = tempSelectedCity;
                        _priceRange = tempPriceRange;
                      });
                      _applyFilters();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryLight,
                      padding: EdgeInsets.symmetric(vertical: 1.8.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Apply Filters',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ STEP 1: Show booking request dialog (NO PAYMENT)
  void _showBookingRequestDialog(Map<String, dynamic> property) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    DateTime? selectedDate;
    int leaseDuration = 12;
    final TextEditingController nameController = TextEditingController(text: userProvider.userName);
    final TextEditingController phoneController = TextEditingController(text: userProvider.userPhone);
    final TextEditingController emailController = TextEditingController(text: userProvider.userEmail);
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          int monthlyRent = property['price'] as int;
          final securityDeposit = monthlyRent * 2;
          final convenienceFee = (monthlyRent * 0.027).round();
          final totalAmount = monthlyRent + securityDeposit + convenienceFee;

          return AlertDialog(
            title: const Text('Send Booking Request'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property['title'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11.sp,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _buildPriceRow('Monthly Rent', monthlyRent),
                        Divider(height: 2.h),
                        _buildPriceRow('Security Deposit (2 months)', securityDeposit),
                        Divider(height: 2.h),
                        _buildPriceRow('Convenience Fee (2.7%)', convenienceFee, isOrange: true),
                        Divider(height: 2.h),
                        _buildPriceRow('Total Amount', totalAmount, isTotal: true),
                      ],
                    ),
                  ),
                  SizedBox(height: 2.h),

                  Text(
                    'Your Details',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 10.sp,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    ),
                  ),
                  SizedBox(height: 2.h),

                  Text(
                    'Move-in Date *',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 10.sp,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setDialogState(() {
                          selectedDate = date;
                        });
                      }
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
                              color: selectedDate != null ? Colors.black87 : Colors.grey,
                            ),
                          ),
                          Icon(Icons.calendar_today, color: AppTheme.primaryLight),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 2.h),

                  Text(
                    'Lease Duration',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 10.sp,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  DropdownButtonFormField<int>(
                    value: leaseDuration,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    ),
                    items: [6, 12, 24, 36].map((months) {
                      return DropdownMenuItem(
                        value: months,
                        child: Text('$months months'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        leaseDuration = value!;
                      });
                    },
                  ),
                  SizedBox(height: 2.h),

                  Text(
                    'Additional Notes (Optional)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 10.sp,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Any specific requirements...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: (nameController.text.isNotEmpty &&
                    phoneController.text.isNotEmpty &&
                    emailController.text.isNotEmpty &&
                    selectedDate != null)
                    ? () {
                  Navigator.pop(context);
                  _sendBookingRequest(
                    property: property,
                    bookingDetails: {
                      'name': nameController.text,
                      'phone': phoneController.text,
                      'email': emailController.text,
                      'moveInDate': selectedDate!,
                      'leaseDuration': leaseDuration,
                      'notes': notesController.text,
                      'monthlyRent': monthlyRent,
                      'securityDeposit': securityDeposit,
                      'convenienceFee': convenienceFee,
                      'totalAmount': totalAmount,
                    },
                  );
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                ),
                child: const Text('Send Request'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPriceRow(String label, int amount, {bool isTotal = false, bool isOrange = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 10.sp : 9.sp,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isOrange ? Colors.orange : Colors.black87,
          ),
        ),
        Text(
          '₹${amount.toString()}',
          style: TextStyle(
            fontSize: isTotal ? 11.sp : 10.sp,
            fontWeight: FontWeight.bold,
            color: isTotal ? AppTheme.primaryLight : (isOrange ? Colors.orange : Colors.black87),
          ),
        ),
      ],
    );
  }

  // ✅ STEP 2: Send booking request to backend (NO PAYMENT)
  Future<void> _sendBookingRequest({
    required Map<String, dynamic> property,
    required Map<String, dynamic> bookingDetails,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(6.w),
          margin: EdgeInsets.symmetric(horizontal: 10.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryLight),
              SizedBox(height: 2.h),
              Text(
                'Sending Request to Owner...',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      print('📤 Sending booking request to backend...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/booking-requests/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'propertyId': property['_id'],
          'propertyName': property['title'],
          'propertyImage': property['image'],
          'propertyAddress': '${property['address']}, ${property['city']}',
          'ownerId': property['ownerId'],
          'ownerName': property['ownerName'],
          'tenantName': bookingDetails['name'],
          'tenantEmail': bookingDetails['email'],
          'tenantPhone': bookingDetails['phone'],
          'moveInDate': DateFormat('yyyy-MM-dd').format(bookingDetails['moveInDate']),
          'leaseDuration': bookingDetails['leaseDuration'],
          'monthlyRent': bookingDetails['monthlyRent'],
          'securityDeposit': bookingDetails['securityDeposit'],
          'notes': bookingDetails['notes'],
          'status': 'pending',
        }),
      ).timeout(const Duration(seconds: 30));

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('✅ Booking request created successfully');
          _showRequestSentDialog(property);
        } else {
          throw Exception(data['message'] ?? 'Failed to create request');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error sending booking request: $e');
      if (mounted) {
        try {
          Navigator.pop(context);
        } catch (_) {}
        _showErrorDialog('Failed to send request: $e');
      }
    }
  }

  // ✅ STEP 3: Show request sent confirmation
  void _showRequestSentDialog(Map<String, dynamic> property) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send,
                  color: Colors.blue,
                  size: 15.w,
                ),
              ),
              SizedBox(height: 3.h),

              Text(
                'Request Sent!',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                'Your booking request has been sent to the property owner',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 3.h),

              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSuccessDetailRow('Property', property['title'] as String),
                    Divider(height: 2.h),
                    _buildSuccessDetailRow('Owner', property['ownerName'] as String),
                    Divider(height: 2.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 9.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Pending Approval',
                            style: TextStyle(
                              fontSize: 8.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 3.h),

              Text(
                'You can view this request in the "My Properties" → "Requests" tab.\nYou will be notified once the owner reviews your request.',
                style: TextStyle(
                  fontSize: 8.sp,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 2.h),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    padding: EdgeInsets.symmetric(vertical: 1.8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.sp,
            color: Colors.grey.shade600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 9.sp,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 2.w),
            const Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

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
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(4.w),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Search by name, city, or type...',
                prefixIcon: Icon(Icons.search, color: AppTheme.primaryLight),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                    });
                    _applyFilters();
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryLight),
                ),
              ),
            ),
          ),

          if (_selectedType != 'All' || _selectedCity != 'All')
            Container(
              height: 6.h,
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (_selectedType != 'All')
                    Padding(
                      padding: EdgeInsets.only(right: 2.w),
                      child: Chip(
                        label: Text(_selectedType),
                        deleteIcon: Icon(Icons.close, size: 4.w),
                        onDeleted: () {
                          setState(() {
                            _selectedType = 'All';
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                  if (_selectedCity != 'All')
                    Chip(
                      label: Text(_selectedCity),
                      deleteIcon: Icon(Icons.close, size: 4.w),
                      onDeleted: () {
                        setState(() {
                          _selectedCity = 'All';
                        });
                        _applyFilters();
                      },
                    ),
                ],
              ),
            ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredProperties.length} Properties Available',
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showFilterSheet,
                  icon: Icon(Icons.tune, size: 4.w),
                  label: const Text('Filters'),
                ),
              ],
            ),
          ),

          Expanded(
            child: _buildPropertiesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertiesList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryLight),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 12.w, color: Colors.red),
            SizedBox(height: 2.h),
            Text(
              'Failed to load properties',
              style: TextStyle(color: Colors.red, fontSize: 11.sp),
            ),
            SizedBox(height: 1.h),
            ElevatedButton(
              onPressed: _loadProperties,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredProperties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 12.w, color: Colors.grey),
            SizedBox(height: 2.h),
            Text(
              'No properties found',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Try adjusting your filters',
              style: TextStyle(color: Colors.grey, fontSize: 9.sp),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProperties,
      color: AppTheme.primaryLight,
      child: ListView.builder(
        padding: EdgeInsets.all(4.w),
        itemCount: _filteredProperties.length,
        itemBuilder: (context, index) {
          final property = _filteredProperties[index];
          return _buildPropertyCard(property);
        },
      ),
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> property) {
    return Card(
      margin: EdgeInsets.only(bottom: 3.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PropertyDetails(
                propertyId: property['_id'] as String,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: CustomImageWidget(
                    imageUrl: property['image'] as String,
                    width: double.infinity,
                    height: 25.h,
                    fit: BoxFit.cover,
                  ),
                ),
                if (property['isVerified'] == true)
                  Positioned(
                    top: 2.w,
                    left: 2.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, color: Colors.white, size: 3.w),
                          SizedBox(width: 1.w),
                          Text(
                            'Verified',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  top: 2.w,
                  right: 2.w,
                  child: Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite_border,
                      color: Colors.white,
                      size: 5.w,
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          property['title'] as String,
                          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        '₹${property['price']}/mo',
                        style: TextStyle(
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),

                  Row(
                    children: [
                      Icon(Icons.location_on, size: 4.w, color: Colors.grey),
                      SizedBox(width: 1.w),
                      Expanded(
                        child: Text(
                          '${property['city']}, ${property['state']}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 9.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.5.h),

                  Row(
                    children: [
                      _buildDetailChip(Icons.bed, '${property['bedrooms']} Beds'),
                      SizedBox(width: 2.w),
                      _buildDetailChip(Icons.bathtub, '${property['bathrooms']} Baths'),
                      SizedBox(width: 2.w),
                      _buildDetailChip(Icons.square_foot, '${property['area']} sq.ft'),
                    ],
                  ),
                  SizedBox(height: 1.5.h),

                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          property['type'] as String,
                          style: TextStyle(
                            color: AppTheme.primaryLight,
                            fontSize: 8.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.star, color: Colors.amber, size: 4.w),
                      SizedBox(width: 1.w),
                      Text(
                        '${property['rating']}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 9.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),

                  if ((property['amenities'] as List).isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amenities',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 9.sp,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Wrap(
                          spacing: 2.w,
                          runSpacing: 0.5.h,
                          children: (property['amenities'] as List)
                              .take(3)
                              .map((amenity) => Chip(
                            label: Text(
                              amenity.toString(),
                              style: TextStyle(fontSize: 7.sp),
                            ),
                            backgroundColor: Colors.grey.shade100,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ))
                              .toList(),
                        ),
                        SizedBox(height: 1.h),
                      ],
                    ),

                  // Book Now Button - Inside the card padding
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        print('🟢 Book Now button tapped');
                        _showBookingRequestDialog(property);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryLight,
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Book Now',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 4.w, color: Colors.grey.shade600),
        SizedBox(width: 1.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 8.sp,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}