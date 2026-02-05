import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/app_export.dart';
import './widgets/amenities_grid_widget.dart';
import './widgets/availability_calendar_widget.dart';
import './widgets/host_info_widget.dart';
import './widgets/property_description_widget.dart';
import './widgets/property_image_gallery_widget.dart';
import './widgets/property_info_widget.dart';
import './widgets/reviews_section_widget.dart';
import './widgets/similar_properties_widget.dart';
import './widgets/sticky_action_bar_widget.dart';
import '../../services/backend_service.dart';
import '../../services/payment_service.dart';
import '../home_dashboard/my_properties_screen.dart';

class PropertyDetails extends StatefulWidget {
  final String? propertyId;

  const PropertyDetails({super.key, this.propertyId});

  @override
  State<PropertyDetails> createState() => _PropertyDetailsState();
}

class _PropertyDetailsState extends State<PropertyDetails> {
  final ScrollController _scrollController = ScrollController();
  final BackendService _backendService = BackendService();
  final PaymentService _paymentService = PaymentService();
  final String baseUrl = 'https://rentify-backend-cdaj.onrender.com';

  bool _isAppBarVisible = false;
  bool _isFavorite = false;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? propertyData;
  String? _propertyId;
  String? _requestId; // ⭐ ADD THIS LINE

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  // Around line 37 - UPDATE THIS:
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_propertyId == null) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _propertyId = args?['propertyId'] as String?;
      _requestId = args?['requestId'] as String?; // ⭐ ADD THIS LINE
      _loadPropertyDetails();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _loadPropertyDetails() async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    print('🔄 Loading property details for ID: $_propertyId');

    Map<String, dynamic>? property;

    if (_propertyId != null) {
      property = await _backendService.getPropertyById(_propertyId!);
    } else {
      final properties = await _backendService.getAllProperties();
      if (properties.isNotEmpty) {
        property = properties.first;
      }
    }

    if (property == null) {
      throw Exception('Property not found');
    }

    // ⭐ NEW: Fetch owner details to get phone number
    String? ownerPhone;
    if (property['ownerId'] != null) {
      try {
        final ownerResponse = await http.get(
          Uri.parse('$baseUrl/api/users/${property['ownerId']}'),
        );
        if (ownerResponse.statusCode == 200) {
          final ownerData = json.decode(ownerResponse.body);
          ownerPhone = ownerData['phoneNumber']?.toString() ?? 
                      ownerData['phone']?.toString();
          print('✅ Owner phone fetched: $ownerPhone');
        }
      } catch (e) {
        print('⚠️ Could not fetch owner phone: $e');
      }
    }

    // ⭐ NEW: Add phone to property data
    if (ownerPhone != null) {
      property['ownerPhone'] = ownerPhone;
    }

    final transformedData = _transformPropertyData(property);

    setState(() {
      propertyData = transformedData;
      _isLoading = false;
    });

    print('✅ Property details loaded: ${property['title']}');
  } catch (e) {
    print('❌ Error loading property: $e');
    setState(() {
      _errorMessage = 'Failed to load property details: $e';
      _isLoading = false;
    });
  }
}

  Map<String, dynamic> _transformPropertyData(Map<String, dynamic> property) {
    int price = 0;
    if (property['price'] is String) {
      String priceStr = (property['price'] as String).replaceAll(RegExp(r'[^0-9]'), '');
      price = int.tryParse(priceStr) ?? 0;
    } else if (property['price'] is int) {
      price = property['price'] as int;
    }

    String bhkInfo = property['bhk']?.toString() ??
        property['bedrooms']?.toString() ?? '1';

    String location = '';
    if (property['address'] != null && property['address'].toString().isNotEmpty) {
      location = property['address'].toString();
    }
    if (property['city'] != null && property['city'].toString().isNotEmpty) {
      location += location.isEmpty ? property['city'].toString() : ', ${property['city']}';
    }
    if (property['state'] != null && property['state'].toString().isNotEmpty) {
      location += location.isEmpty ? property['state'].toString() : ', ${property['state']}';
    }
    if (location.isEmpty) {
      location = 'Location not specified';
    }

    return {
      "id": property['_id']?.toString() ?? property['id']?.toString() ?? '',
      "ownerId": property['ownerId']?.toString() ?? '',
      "title": property['title']?.toString() ?? 'Property',
      "location": location,
      "price": '₹$price',
      "priceValue": price,
      "priceType": "per month",
      "rating": (property['rating'] ?? 4.5).toDouble(),
      "reviewCount": (property['reviewCount'] ?? 0) as int,
      "images": (property['images'] != null && (property['images'] as List).isNotEmpty)
          ? (property['images'] as List).map((e) => e.toString()).toList()
          : [
        property['image']?.toString() ??
            'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800'
      ],
      "amenities": _transformAmenities(property['amenities'] ?? []),
      "description": property['description']?.toString() ?? 'No description available',
      "bhk": bhkInfo,
      "bathrooms": property['bathrooms'] ?? 1,
      "area": property['area'] ?? 0,
      "type": property['type']?.toString() ?? 'Flat',
      "isVerified": property['isVerified'] ?? false,
     "host": {
  "name": property['ownerName']?.toString() ?? 'Property Owner',
  "image": "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200",
  "responseTime": "Usually responds within 24 hours",
  "rating": 4.8,
  "properties": 5,
  "phoneNumber": property['ownerPhone']?.toString() ?? '',
  "phone": property['ownerPhone']?.toString() ?? '',
},
      "reviews": [],
      "similarProperties": []
    };
  }

  List<Map<String, dynamic>> _transformAmenities(List<dynamic> amenities) {
    final Map<String, String> amenityIcons = {
      'WiFi': 'wifi',
      'Wi-Fi': 'wifi',
      'AC': 'ac_unit',
      'Air Conditioning': 'ac_unit',
      'Parking': 'local_parking',
      'Gym': 'fitness_center',
      'Gymnasium': 'fitness_center',
      'Swimming Pool': 'pool',
      'Pool': 'pool',
      'Security': 'security',
      '24/7 Security': 'security',
      'Elevator': 'elevator',
      'Lift': 'elevator',
      'Power Backup': 'power',
      'Backup': 'power',
      'Garden': 'local_florist',
      'Balcony': 'balcony',
      'Kitchen': 'kitchen',
      'Furnished': 'weekend',
    };

    return amenities.map((amenity) {
      final name = amenity.toString();
      return {
        "name": name,
        "icon": amenityIcons[name] ?? 'check_circle',
      };
    }).toList();
  }

  void _onScroll() {
    final bool shouldShowAppBar = _scrollController.offset > 200;
    if (shouldShowAppBar != _isAppBarVisible) {
      setState(() {
        _isAppBarVisible = shouldShowAppBar;
      });
    }
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  void _shareProperty() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Property shared successfully!'),
        backgroundColor: AppTheme.lightTheme.colorScheme.primary,
      ),
    );
  }

  void _contactOwner() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contacting property owner...'),
        backgroundColor: AppTheme.lightTheme.colorScheme.primary,
      ),
    );
  }

  void _bookProperty() {
    if (propertyData == null) return;
    _showBookingDialog(propertyData!);
  }

  void _showBookingDialog(Map<String, dynamic> property) {
    DateTime? selectedDate;
    int leaseDuration = 12;
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final monthlyRent = property['priceValue'] as int;
          final securityDeposit = monthlyRent * 2;
          // ⭐ Calculate 2.7% convenience fee
          final baseAmount = monthlyRent + securityDeposit;
          final convenienceFee = ((baseAmount * 2.7) / 100).round();
          final totalAmount = baseAmount + convenienceFee;

          return AlertDialog(
            title: const Text('Book Property'),
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
                      color: AppTheme.primaryLight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _buildPriceRow('Monthly Rent', monthlyRent),
                        Divider(height: 2.h),
                        _buildPriceRow('Security Deposit (2 months)', securityDeposit),
                        Divider(height: 2.h),
                        _buildPriceRow('Convenience Fee (2.7%)', convenienceFee, isConvenienceFee: true), // ⭐ NEW
                        Divider(height: 2.h),
                        _buildPriceRow('Total to Pay Now', totalAmount, isTotal: true),
                      ],
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Your Details',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10.sp),
                  ),
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
                  Text(
                    'Move-in Date *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10.sp),
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
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10.sp),
                  ),
                  SizedBox(height: 1.h),
                  DropdownButtonFormField<int>(
                    value: leaseDuration,
                    decoration: InputDecoration(
                      labelText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    ),
                    items: [
                      for (int i = 1; i <= 12; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text('$i ${i == 1 ? "month" : "months"}'),
                        ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        leaseDuration = value!;
                      });
                    },
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Additional Notes (Optional)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10.sp),
                  ),
                  SizedBox(height: 1.h),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
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
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: (nameController.text.isNotEmpty &&
                    phoneController.text.isNotEmpty &&
                    emailController.text.isNotEmpty &&
                    selectedDate != null)
                    ? () {
                  Navigator.pop(context);
                  _initiatePayment(
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
                child: const Text('Proceed to Payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPriceRow(String label, int amount, {bool isTotal = false, bool isConvenienceFee = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 10.sp : 9.sp,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isConvenienceFee ? Colors.orange.shade700 : Colors.black87,
          ),
        ),
        Text(
          '₹${amount.toString()}',
          style: TextStyle(
            fontSize: isTotal ? 11.sp : 10.sp,
            fontWeight: FontWeight.bold,
            color: isTotal ? AppTheme.primaryLight : (isConvenienceFee ? Colors.orange.shade700 : Colors.black87),
          ),
        ),
      ],
    );
  }

  Future<void> _initiatePayment({
    required Map<String, dynamic> property,
    required Map<String, dynamic> bookingDetails,
  }) async {
    try {
      print('\n🔍 ========== INITIATING PAYMENT ==========');
      print('Property ID: ${property['id']}');
      print('Owner ID: ${property['ownerId']}');
      print('Lease Duration: ${bookingDetails['leaseDuration']} months');
      print('Total Amount: ${bookingDetails['totalAmount']}');

      if (property['ownerId'] == null || property['ownerId'].isEmpty) {
        throw Exception('Property owner information missing');
      }

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
                Text(
                  'Initiating Payment...',
                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );

      final paymentOrder = await _paymentService.createTenantOrder(
        propertyId: property['id'],
        ownerId: property['ownerId'],
        leaseDuration: bookingDetails['leaseDuration'], // ✅ ADDED - Required parameter
        tenantName: bookingDetails['name'],
        tenantEmail: bookingDetails['email'],
        tenantPhone: bookingDetails['phone'],
        monthlyRent: bookingDetails['monthlyRent'],
        securityDeposit: bookingDetails['securityDeposit'],
        propertyTitle: property['title'],
      );

      print('✅ Payment order created: ${paymentOrder['orderId']}');

      if (mounted) Navigator.pop(context);

      _paymentService.openCheckout(
        orderId: paymentOrder['orderId'],
        amount: paymentOrder['amount'],
        key: paymentOrder['key'],
        name: bookingDetails['name'],
        email: bookingDetails['email'],
        phone: bookingDetails['phone'],
        description: 'Rent for ${property['title']}',
        onSuccess: (PaymentSuccessResponse response) {
          _handlePaymentSuccess(response, property, bookingDetails);
        },
        onFailure: (PaymentFailureResponse response) {
          _handlePaymentFailure(response);
        },
      );
    } catch (e, stackTrace) {
      print('❌ Payment error: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        try {
          Navigator.pop(context);
        } catch (navError) {}
        _showErrorDialog('Failed to initiate payment: $e');
      }
    }
  }

  Future<void> _saveBookingToDatabase(
      Map<String, dynamic> property,
      Map<String, dynamic> bookingDetails,
      String paymentId,
      String orderId,
      ) async {
    print('\n💾 ========== SAVING BOOKING ==========');

    try {
      final leaseDuration = bookingDetails['leaseDuration'] as int;
      final totalAmount = bookingDetails['totalAmount'] as int;

      print('Lease Duration: $leaseDuration months');
      print('Total Amount: ₹$totalAmount');
      print('Request ID: $_requestId'); // ⭐ ADD THIS LOG

      final requestBody = {
        'propertyId': property['id'],
        'tenantId': null,
        'tenantName': bookingDetails['name'],
        'tenantEmail': bookingDetails['email'],
        'tenantPhone': bookingDetails['phone'],
        'monthlyRent': bookingDetails['monthlyRent'],
        'securityDeposit': bookingDetails['securityDeposit'],
        'leaseDuration': leaseDuration,
        'totalAmount': totalAmount,
        'moveInDate': bookingDetails['moveInDate'].toIso8601String(),
        'notes': bookingDetails['notes'] ?? '',
        'paymentId': paymentId,
        'orderId': orderId,
        'requestId': _requestId, // ⭐⭐⭐ ADD THIS LINE - CRITICAL! ⭐⭐⭐
      };

      print('📤 Request Body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/bookings/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('📥 Response: ${response.statusCode}');
      print('Response Body: ${response.body}');

      // ✅ Accept both 200 and 201 as success
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final bookingId = data['booking']?['_id'] ?? data['bookingId'] ?? 'Unknown';
          print('✅ Booking saved! ID: $bookingId');
        } else {
          throw Exception('Booking save failed: ${data['message']}');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception('HTTP ${response.statusCode}: ${json.encode(errorData)}');
      }
    } catch (e) {
      print('❌ Error saving booking: $e');
      throw e;
    }
  }

  Future<void> _handlePaymentSuccess(
      PaymentSuccessResponse response,
      Map<String, dynamic> property,
      Map<String, dynamic> bookingDetails,
      ) async {
    print('\n🎉 ========== PAYMENT SUCCESS ==========');

    try {
      final isVerified = await _paymentService.verifyPayment(
        orderId: response.orderId ?? '',
        paymentId: response.paymentId ?? '',
        signature: response.signature ?? '',
        propertyData: {
          'propertyId': property['id'],
          'ownerId': property['ownerId'],
          'amount': bookingDetails['totalAmount'],
          'userDetails': {
            'name': bookingDetails['name'],
            'email': bookingDetails['email'],
            'phone': bookingDetails['phone'],
          },
        },
      );

      if (!isVerified) {
        _showErrorDialog('Payment verification failed');
        return;
      }

      await _saveBookingToDatabase(
        property,
        bookingDetails,
        response.paymentId!,
        response.orderId!,
      );

      final bookingId = 'BK${DateTime.now().millisecondsSinceEpoch}';
      _showPaymentSuccess(bookingId, property, bookingDetails);

    } catch (e) {
      print('❌ Error in payment success: $e');
      _showErrorDialog('Error processing payment: $e');
    }
  }

  void _handlePaymentFailure(PaymentFailureResponse response) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 2.w),
            const Text('Payment Failed'),
          ],
        ),
        content: Text(
          response.message ?? 'Payment was not successful. Please try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
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

  void _showPaymentSuccess(
      String bookingId,
      Map<String, dynamic> property,
      Map<String, dynamic> bookingDetails,
      ) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 15.w,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                'Payment Successful!',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                'Your booking has been confirmed\nMoney transferred to property owner',
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
                    _buildSuccessDetailRow('Property', property['title']),
                    Divider(height: 2.h),
                    _buildSuccessDetailRow(
                      'Move-in Date',
                      DateFormat('MMM dd, yyyy').format(bookingDetails['moveInDate']),
                    ),
                    Divider(height: 2.h),
                    _buildSuccessDetailRow(
                      'Amount Paid',
                      '₹${bookingDetails['totalAmount']}',
                    ),
                    Divider(height: 2.h),
                    _buildSuccessDetailRow('Booking ID', bookingId),
                  ],
                ),
              ),
              SizedBox(height: 3.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyPropertiesScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        side: BorderSide(color: AppTheme.primaryLight),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'View Bookings',
                        style: TextStyle(
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryLight,
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.lightTheme.appBarTheme.backgroundColor,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryLight,
          ),
        ),
      );
    }

    if (_errorMessage != null || propertyData == null) {
      return Scaffold(
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.lightTheme.appBarTheme.backgroundColor,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 2.h),
              Text(
                _errorMessage ?? 'Property not found',
                style: TextStyle(fontSize: 16, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 2.h),
              ElevatedButton(
                onPressed: _loadPropertyDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                  foregroundColor: Colors.white,
                ),
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: PropertyImageGalleryWidget(
                  images: (propertyData!["images"] as List).cast<String>(),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  color: AppTheme.lightTheme.scaffoldBackgroundColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PropertyInfoWidget(
                        title: propertyData!["title"] as String,
                        location: propertyData!["location"] as String,
                        price: propertyData!["price"] as String,
                        priceType: propertyData!["priceType"] as String,
                        rating: propertyData!["rating"] as double,
                        reviewCount: propertyData!["reviewCount"] as int,
                      ),
                      SizedBox(height: 2.h),
                      AmenitiesGridWidget(
                        amenities: (propertyData!["amenities"] as List)
                            .cast<Map<String, dynamic>>(),
                      ),
                      SizedBox(height: 2.h),
                      PropertyDescriptionWidget(
                        description: propertyData!["description"] as String,
                      ),
                      SizedBox(height: 2.h),
                      HostInfoWidget(
                        hostData: propertyData!["host"] as Map<String, dynamic>,
                        onMessageTap: _contactOwner,
                      ),
                      SizedBox(height: 2.h),
                      ReviewsSectionWidget(
                        rating: propertyData!["rating"] as double,
                        reviewCount: propertyData!["reviewCount"] as int,
                        reviews: (propertyData!["reviews"] as List)
                            .cast<Map<String, dynamic>>(),
                      ),
                      SizedBox(height: 2.h),
                      AvailabilityCalendarWidget(),
                      SizedBox(height: 2.h),
                      SimilarPropertiesWidget(
                        properties: (propertyData!["similarProperties"] as List)
                            .cast<Map<String, dynamic>>(),
                      ),
                      SizedBox(height: 10.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: StickyActionBarWidget(
              onContactTap: _contactOwner,
              onBookTap: _bookProperty,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _isAppBarVisible
          ? AppTheme.lightTheme.appBarTheme.backgroundColor
          : Colors.transparent,
      elevation: _isAppBarVisible ? 2.0 : 0.0,
      leading: Container(
        margin: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: _isAppBarVisible
              ? Colors.transparent
              : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          icon: CustomIconWidget(
            iconName: 'arrow_back',
            color: _isAppBarVisible
                ? AppTheme.lightTheme.colorScheme.onSurface
                : Colors.white,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: _isAppBarVisible
          ? Text(
        propertyData?["title"] as String? ?? '',
        style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      )
          : null,
      actions: [
        Container(
          margin: EdgeInsets.all(2.w),
          decoration: BoxDecoration(
            color: _isAppBarVisible
                ? Colors.transparent
                : Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: CustomIconWidget(
              iconName: 'share',
              color: _isAppBarVisible
                  ? AppTheme.lightTheme.colorScheme.onSurface
                  : Colors.white,
              size: 24,
            ),
            onPressed: _shareProperty,
          ),
        ),
        Container(
          margin: EdgeInsets.only(right: 4.w, top: 2.w, bottom: 2.w),
          decoration: BoxDecoration(
            color: _isAppBarVisible
                ? Colors.transparent
                : Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: CustomIconWidget(
              iconName: _isFavorite ? 'favorite' : 'favorite_border',
              color: _isFavorite
                  ? AppTheme.lightTheme.colorScheme.error
                  : (_isAppBarVisible
                  ? AppTheme.lightTheme.colorScheme.onSurface
                  : Colors.white),
              size: 24,
            ),
            onPressed: _toggleFavorite,
          ),
        ),
      ],
    );
  }
}