// ========================================
// COMPLETE PROPERTY PAYMENT SCREEN - WITH CAPACITY INCREASE
// ✅ Works for THREE modes: Initial property upload + Monthly subscription + Capacity increase (PG ONLY)
// ✅ Full coupon support (RENTIFY25, RENTIFY50, RENTIFY100)
// ✅ Duration selection for subscription (1/3/6/12 months)
// ========================================
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/app_export.dart';
import '../../services/payment_service.dart';
import '../../services/backend_service.dart';
import '../../providers/user_provider.dart';

class PropertyPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> propertyData;
  final String paymentMode; // ⭐ 'initial', 'subscription', or 'capacity_increase'

  const PropertyPaymentScreen({
    Key? key,
    required this.propertyData,
    this.paymentMode = 'initial', // Default to initial payment
  }) : super(key: key);

  @override
  State<PropertyPaymentScreen> createState() => _PropertyPaymentScreenState();
}

class _PropertyPaymentScreenState extends State<PropertyPaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  final BackendService _backendService = BackendService();
  final TextEditingController _couponController = TextEditingController();
  final String baseUrl = 'https://rentify-backend-cdaj.onrender.com';

  bool _isProcessing = false;
  int? _serviceCharge;
  int? _finalAmount;
  String? _appliedCoupon;
  int? _discountPercent;
  int? _discountAmount;

  // ⭐ Subscription duration (only for subscription mode)
  int _selectedMonthsDuration = 1;

  // ⭐ Subscription pricing
  final Map<int, Map<String, dynamic>> _subscriptionPricing = {
    1: {'months': 1, 'price': 499, 'discount': 0},
    3: {'months': 3, 'price': 1299, 'discount': 13},
    6: {'months': 6, 'price': 2399, 'discount': 20},
    12: {'months': 12, 'price': 4499, 'discount': 25},
  };

  // Static coupons
  static const Map<String, int> _availableCoupons = {
    'RENTIFY25': 25,  // 25% off
    'RENTIFY50': 50,  // 50% off
    'RENTIFY100': 100, // 100% off - charges ₹1
  };

  @override
  void initState() {
    super.initState();
    _calculateCharge();
  }

  @override
  void dispose() {
    _couponController.dispose();
    _paymentService.dispose();
    super.dispose();
  }

  // ⭐ UPDATED: Calculate charge based on total beds from propertyData
  void _calculateCharge() {
    // ⭐ FOR CAPACITY INCREASE - use pre-calculated charge from edit screen
    if (widget.paymentMode == 'capacity_increase') {
      final preCalculatedCharge = widget.propertyData['additionalCharge'] as int? ?? 0;
      setState(() {
        _serviceCharge = preCalculatedCharge;
        _finalAmount = preCalculatedCharge;
        _appliedCoupon = null;
        _discountPercent = null;
        _discountAmount = null;
      });
      return;
    }

    // ⭐ FIXED: For subscription mode, use monthly charge and multiply by duration
    if (widget.paymentMode == 'subscription') {
      // Get base monthly charge (beds × 18)
      final monthlyCharge = widget.propertyData['monthlyCharge'] as int? ?? 0;

      // Multiply by selected duration
      final totalCharge = monthlyCharge * _selectedMonthsDuration;

      setState(() {
        _serviceCharge = totalCharge;
        _finalAmount = totalCharge;
        _appliedCoupon = null;
        _discountPercent = null;
        _discountAmount = null;
      });
      return;
    }

    // For initial mode (property_addition), calculate per property
    final propertyType = widget.propertyData['type'] as String;
    final beds = widget.propertyData['beds'] as int?;
    final bhk = widget.propertyData['bhk'] as String?;

    // Calculate base charge (beds × ₹18 or bhk × ₹18)
    int baseCharge = _paymentService.calculateServiceCharge(
      propertyType,
      beds,
      bhk,
    );

    setState(() {
      _serviceCharge = baseCharge;
      _finalAmount = baseCharge;
      _appliedCoupon = null;
      _discountPercent = null;
      _discountAmount = null;
    });
  }

  void _applyCoupon() {
    final couponCode = _couponController.text.trim().toUpperCase();

    if (couponCode.isEmpty) {
      _showSnackBar('Please enter a coupon code', Colors.orange);
      return;
    }

    if (!_availableCoupons.containsKey(couponCode)) {
      _showSnackBar('Invalid coupon code', Colors.red);
      return;
    }

    final discountPercent = _availableCoupons[couponCode]!;
    final discountAmount = ((_serviceCharge ?? 0) * discountPercent / 100).round();

    // Charge ₹1 for 100% discount
    final calculatedAmount = (_serviceCharge ?? 0) - discountAmount;
    final finalAmount = (discountPercent == 100 && calculatedAmount == 0) ? 1 : calculatedAmount;

    setState(() {
      _appliedCoupon = couponCode;
      _discountPercent = discountPercent;
      _discountAmount = discountAmount;
      _finalAmount = finalAmount;
    });

    final message = discountPercent == 100
        ? 'Coupon applied! Pay just ₹1 (99.9% off)'
        : 'Coupon applied! $discountPercent% off';

    _showSnackBar(message, Colors.green);
    FocusScope.of(context).unfocus();
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _discountPercent = null;
      _discountAmount = null;
      _finalAmount = _serviceCharge;
      _couponController.clear();
    });

    _showSnackBar('Coupon removed', Colors.grey);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ⭐ Update duration for subscription
  void _updateDuration(int months) {
    setState(() {
      _selectedMonthsDuration = months;
      _calculateCharge();
    });
  }

  Future<void> _proceedToPayment() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      print('💰 Creating payment order for ₹$_finalAmount');
      print('📋 Payment mode: ${widget.paymentMode}');

      Map<String, dynamic> orderData;

      // ⭐ Different API endpoints based on mode
      // ⭐ Different API endpoints based on mode
      if (widget.paymentMode == 'initial' || widget.paymentMode == 'property_addition') {
        // Initial property upload payment (property_addition for first month free tracking)
        orderData = await _paymentService.createOrder(
          propertyType: widget.propertyData['type'],
          beds: widget.propertyData['beds'],
          bhk: widget.propertyData['bhk'],
          propertyTitle: widget.propertyData['title'],
          couponCode: _appliedCoupon,
        );
      } else if (widget.paymentMode == 'capacity_increase') {
        // ⭐ NEW: Capacity increase payment
        orderData = await _createCapacityIncreaseOrder();
      } else {
        // Subscription payment
        orderData = await _createServiceChargeOrder();
      }

      // Open Razorpay checkout
      _paymentService.openCheckout(
        orderId: orderData['orderId'],
        amount: _finalAmount ?? 0,
        key: orderData['key'],
        name: userProvider.userName ?? 'Owner',
        email: userProvider.userEmail ?? '',
        phone: userProvider.userPhone ?? '',
        description: (widget.paymentMode == 'initial' || widget.paymentMode == 'property_addition')
            ? 'Property Registration - ${widget.propertyData['title']}${_appliedCoupon != null ? ' (Coupon: $_appliedCoupon)' : ''}'
            : widget.paymentMode == 'capacity_increase'
            ? 'Capacity Increase - ${widget.propertyData['propertyTitle']} (PG Beds)'
            : 'Service Charge - ${widget.propertyData['propertyTitle']} ($_selectedMonthsDuration months)',
        onSuccess: (response) => _handlePaymentSuccess(response, orderData),
        onFailure: _handlePaymentFailure,
      );

    } catch (e) {
      print('❌ Error: $e');
      if (mounted) {
        _showSnackBar('Failed to proceed: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
  // ⭐ Helper method to copy images to persistent storage
  Future<List<File>> _copyImagesToAppDir(List<dynamic> images) async {
    final List<File> copiedImages = [];

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/property_images');

      // Create directory if it doesn't exist
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      for (int i = 0; i < images.length; i++) {
        if (images[i] is File) {
          final originalFile = images[i] as File;

          // Check if file exists
          if (await originalFile.exists()) {
            // Get original extension
            final extension = path.extension(originalFile.path);
            final fileName = 'property_${timestamp}_$i$extension';
            final newPath = '${imagesDir.path}/$fileName';

            // Copy file to persistent storage
            final copiedFile = await originalFile.copy(newPath);
            copiedImages.add(copiedFile);
            print('✅ Copied image to: $newPath');
          } else {
            print('⚠️ Original file not found: ${originalFile.path}');
          }
        }
      }

      print('📸 Successfully copied ${copiedImages.length} images');
    } catch (e) {
      print('❌ Error copying images: $e');
    }

    return copiedImages;
  }

  // ⭐ Create capacity increase order for PG bed increase
  Future<Map<String, dynamic>> _createCapacityIncreaseOrder() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    print('🔍 Creating capacity increase order:');
    print('   Property ID: ${widget.propertyData['propertyId']}');
    print('   Owner ID: ${userProvider.userId}');
    print('   Additional Charge: $_serviceCharge');
    print('   New Monthly Charge: ${widget.propertyData['newMonthlyCharge']}');
    print('   Coupon: ${_appliedCoupon ?? 'None'}');

    final response = await http.post(
      Uri.parse('$baseUrl/api/payments/create-capacity-increase-order'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'propertyId': widget.propertyData['propertyId'],
        'ownerId': userProvider.userId,
        'additionalCharge': _serviceCharge,
        'newMonthlyCharge': widget.propertyData['newMonthlyCharge'],
        'couponCode': _appliedCoupon,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        print('✅ Order created with final amount: ₹${data['amount']}');
        if (data['couponCode'] != null && data['couponCode'] != 'none') {
          print('🎟️ Coupon applied: ${data['couponCode']}');
        }
        return data;
      }
    }
    throw Exception('Failed to create capacity increase order');
  }

  // ⭐ Create service charge order for subscription
  Future<Map<String, dynamic>> _createServiceChargeOrder() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // ⭐ Get propertyId - might be 'propertyId' or '_id' depending on source
    final propertyId = widget.propertyData['propertyId'] ??
        widget.propertyData['_id'] ??
        widget.propertyData['id'];

    print('🔍 Creating service charge order:');
    print('   Property ID: $propertyId');
    print('   Owner ID: ${userProvider.userId}');
    print('   Duration: $_selectedMonthsDuration months');
    print('   Monthly Charge: ${widget.propertyData['monthlyCharge']}');
    print('   Total Charge: $_serviceCharge');
    print('   Coupon: ${_appliedCoupon ?? 'None'}');

    final response = await http.post(
      Uri.parse('$baseUrl/api/payments/create-service-charge-order'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'propertyId': propertyId,
        'ownerId': userProvider.userId,
        'monthsDuration': _selectedMonthsDuration,
        'couponCode': _appliedCoupon,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        print('✅ Order created with final amount: ₹${data['amount']}');
        if (data['couponCode'] != null && data['couponCode'] != 'none') {
          print('🎟️ Coupon applied: ${data['couponCode']}');
        }
        return data;
      }
    }
    throw Exception('Failed to create service charge order');
  }


  Future<void> _handlePaymentSuccess(
      PaymentSuccessResponse response,
      Map<String, dynamic> orderData,
      ) async {
    print('✅ Payment Success: ${response.paymentId}');
    print('💰 Amount paid: ₹$_finalAmount');

    try {
      if (widget.paymentMode == 'initial' || widget.paymentMode == 'property_addition') {
        // Initial payment - verify and upload property (property_addition for first month free)
        await _handleInitialPayment(response, orderData);
      } else if (widget.paymentMode == 'capacity_increase') {
        // ⭐ NEW: Handle capacity increase payment
        await _handleCapacityIncreasePayment(response);
      } else {
        // Subscription payment - verify and extend service
        await _handleSubscriptionPayment(response);
      }
    } catch (e) {
      print('❌ Error handling payment success: $e');
      if (mounted) {
        _showSnackBar('Payment successful but processing failed. Contact support.', Colors.orange);
        Navigator.pop(context, false);
      }
    }
  }

  // ⭐ Handle initial property upload payment
  Future<void> _handleInitialPayment(
      PaymentSuccessResponse response,
      Map<String, dynamic> orderData,
      ) async {
    final verified = await _paymentService.verifyPayment(
      orderId: response.orderId ?? '',
      paymentId: response.paymentId ?? '',
      signature: response.signature ?? '',
      propertyData: {
        'propertyId': widget.propertyData['id'],
        'ownerId': widget.propertyData['ownerId'],
        'amount': _finalAmount,
        'originalAmount': _serviceCharge,
        'couponCode': _appliedCoupon,
        'discountPercent': _discountPercent,
        'discountAmount': _discountAmount,
      },
    );

    if (verified) {
      print('📤 Uploading property after payment verification...');
      final result = await _uploadProperty();

      if (mounted) {
        if (result['success'] == true) {
          Navigator.pop(context, true);

          final savedMessage = _appliedCoupon == 'RENTIFY100'
              ? 'Property added for just ₹1! (Almost FREE)'
              : _appliedCoupon != null
              ? 'Payment successful! Property added. (Saved ₹$_discountAmount)'
              : 'Payment successful! Property added.';

          _showSnackBar(savedMessage, Colors.green);
        } else {
          throw Exception('Failed to add property after payment');
        }
      }
    } else {
      throw Exception('Payment verification failed');
    }
  }

  // ⭐ NEW: Handle capacity increase payment
  Future<void> _handleCapacityIncreasePayment(PaymentSuccessResponse response) async {
    final verifyResponse = await http.post(
      Uri.parse('$baseUrl/api/payments/verify-capacity-increase-payment'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'razorpay_order_id': response.orderId,
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature,
        'propertyId': widget.propertyData['propertyId'],
        'additionalCharge': _serviceCharge,
        'newMonthlyCharge': widget.propertyData['newMonthlyCharge'],
      }),
    ).timeout(const Duration(seconds: 30));

    if (verifyResponse.statusCode == 200) {
      final data = json.decode(verifyResponse.body);

      if (data['success'] == true) {
        print('✅ Payment verified and property capacity updated');

        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success

          final message = _appliedCoupon == 'RENTIFY100'
              ? 'Capacity increased for just ₹1! (Almost FREE)'
              : _appliedCoupon != null
              ? 'Payment successful! Capacity updated. (Saved ₹$_discountAmount)'
              : 'Payment successful! PG capacity updated.';

          _showSnackBar(message, Colors.green);
        }
      } else {
        throw Exception('Payment verification failed');
      }
    } else {
      throw Exception('Payment verification failed');
    }
  }

  // ⭐ Handle subscription payment
  Future<void> _handleSubscriptionPayment(PaymentSuccessResponse response) async {
    // ⭐ Get propertyId - might be 'propertyId' or '_id' depending on source
    final propertyId = widget.propertyData['propertyId'] ??
        widget.propertyData['_id'] ??
        widget.propertyData['id'];

    final verifyResponse = await http.post(
      Uri.parse('$baseUrl/api/payments/verify-service-charge-payment'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'razorpay_order_id': response.orderId,
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature,
        'propertyId': propertyId,
        'monthsDuration': _selectedMonthsDuration,
      }),
    ).timeout(const Duration(seconds: 30));

    if (verifyResponse.statusCode == 200) {
      final data = json.decode(verifyResponse.body);

      if (data['success'] == true) {
        print('✅ Payment verified and service extended');

        if (mounted) {
          Navigator.pop(context, true);

          final message = _appliedCoupon == 'RENTIFY100'
              ? 'Service charge paid for just ₹1! (Almost FREE)'
              : _appliedCoupon != null
              ? 'Payment successful! Service activated. (Saved ₹$_discountAmount)'
              : 'Payment successful! Service charge paid.';

          _showSnackBar(message, Colors.green);
        }
      } else {
        throw Exception('Payment verification failed');
      }
    } else {
      throw Exception('Payment verification failed');
    }
  }

  void _handlePaymentFailure(PaymentFailureResponse response) {
    print('❌ Payment Failed: ${response.code} - ${response.message}');

    if (mounted) {
      _showSnackBar('Payment failed: ${response.message}', Colors.red);
    }
  }

  Future<Map<String, dynamic>> _uploadProperty() async {
    try {
      print('📤 ==================== UPLOAD PROPERTY ====================');
      final propertyData = widget.propertyData;

      // Parse price
      String priceStr = propertyData['price']?.toString() ?? '0';
      priceStr = priceStr.replaceAll('₹', '').replaceAll(',', '').trim();

      final rawImages = propertyData['images'] as List? ?? [];

      // ✅ DETECT: Are images Supabase URLs (strings) or File objects?
      final bool isUrlList = rawImages.isNotEmpty && rawImages.first is String;

      if (isUrlList) {
        // ✅ NEW PATH: Images are already uploaded to Supabase as URLs
        final imageUrls = rawImages.cast<String>();
        print('🌐 Using ${imageUrls.length} Supabase URLs');

        final result = await _backendService.uploadPropertyWithUrls(
          title: propertyData['title'] ?? '',
          price: priceStr,
          location: propertyData['location'] ?? '',
          description: propertyData['description'] ?? '',
          ownerId: propertyData['ownerId'] ?? '',
          type: propertyData['type'] ?? '',
          bhk: propertyData['bhk'],
          beds: propertyData['beds'],
          rooms: propertyData['rooms'],
          amenities: List<String>.from(propertyData['amenities'] ?? []),
          imageUrls: imageUrls,
          address: propertyData['address'] ?? '',
          city: propertyData['city'] ?? '',
          state: propertyData['state'] ?? '',
          zipCode: propertyData['zipCode'] ?? '',
          agreementUrl: propertyData['agreementUrl'],  // ✅ ADD THIS
          signatureUrl: propertyData['signatureUrl'],  // ✅ ADD THIS
          ownerName: propertyData['ownerName'],
        );

        print('📥 Upload result: ${result['success']}');
        return result;

      } else {
        // ✅ OLD PATH: Images are File objects (fallback)
        final imageFiles = rawImages.cast<File>();
        print('📁 Using ${imageFiles.length} local File objects');

        // Verify all files exist
        for (var img in imageFiles) {
          if (!await img.exists()) {
            throw Exception('Image file missing: ${img.path}');
          }
        }

        final result = await _backendService.uploadProperty(
          title: propertyData['title'] ?? '',
          price: priceStr,
          location: propertyData['location'] ?? '',
          description: propertyData['description'] ?? '',
          ownerId: propertyData['ownerId'] ?? '',
          type: propertyData['type'] ?? '',
          bhk: propertyData['bhk'],
          beds: propertyData['beds'],
          rooms: propertyData['rooms'],
          amenities: List<String>.from(propertyData['amenities'] ?? []),
          images: imageFiles,
          address: propertyData['address'] ?? '',
          city: propertyData['city'] ?? '',
          state: propertyData['state'] ?? '',
          zipCode: propertyData['zipCode'] ?? '',
        );

        print('📥 Upload result: ${result['success']}');
        return result;
      }

    } catch (e) {
      print('❌ Error uploading property: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  String _getChargeBreakdown() {
  if (widget.paymentMode == 'capacity_increase') {
    final beds = widget.propertyData['beds'] as int? ?? 0;
    return '$beds beds × ₹18 = ₹$_serviceCharge';
  }

  if (widget.paymentMode == 'subscription') {
    final totalBeds = widget.propertyData['beds'] as int? ?? 0;
    final monthlyCharge = widget.propertyData['monthlyCharge'] as int? ?? 0;

    if (_selectedMonthsDuration == 1) {
      return '$totalBeds beds/units × ₹18 × 1 month = ₹$_serviceCharge';
    } else {
      return '$totalBeds beds/units × ₹18 × $_selectedMonthsDuration months = ₹$_serviceCharge';
    }
  }

  final propertyType = widget.propertyData['type'] as String;
  final beds = widget.propertyData['beds'] as int?;
  final rooms = widget.propertyData['rooms'] as int?; // ⭐ GET ROOMS
  final bhk = widget.propertyData['bhk'] as String?;

  if (propertyType == 'PG') {
    // ⭐ Show rooms for context if different from beds
    if (rooms != null && beds != null && rooms != beds) {
      return '${beds} beds × ₹18 = ₹$_serviceCharge (${rooms} room${rooms > 1 ? 's' : ''})';
    } else {
      return '${beds ?? 1} beds × ₹18 = ₹$_serviceCharge';
    }
  } else {
    int bedroomCount = 1;
    if (bhk != null) {
      final match = RegExp(r'(\d+)').firstMatch(bhk);
      if (match != null) {
        bedroomCount = int.parse(match.group(1)!);
      }
    }
    return '$bedroomCount BHK × ₹18 = ₹$_serviceCharge';
  }
}

  String _getPaymentType() {
    if (widget.paymentMode == 'subscription') {
      return '$_selectedMonthsDuration Month${_selectedMonthsDuration > 1 ? 's' : ''}';
    } else if (widget.paymentMode == 'capacity_increase') {
      return 'Capacity Increase';
    }
    return 'One-time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimaryLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.paymentMode == 'initial'
              ? 'Payment Confirmation'
              : widget.paymentMode == 'capacity_increase'
              ? 'Capacity Increase Payment'
              : 'Service Charge Payment',
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Summary Card
            _buildPropertySummaryCard(),
            SizedBox(height: 3.h),

            // ⭐ Duration Selection (only for subscription mode)
            if (widget.paymentMode == 'subscription') ...[
              _buildDurationSelector(),
              SizedBox(height: 3.h),
            ],

            // Coupon Section
            _buildCouponSection(),
            SizedBox(height: 3.h),

            // Service Charge Card
            _buildServiceChargeCard(),
            SizedBox(height: 3.h),

            // Info Card
            _buildInfoCard(),
            SizedBox(height: 4.h),

            // Payment Button
            _buildPaymentButton(),
            SizedBox(height: 2.h),

            // Security Badge
            _buildSecurityBadge(),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertySummaryCard() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.home,
                  color: AppTheme.primaryLight,
                  size: 8.w,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Property Details',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      widget.propertyData['title'] ?? widget.propertyData['propertyTitle'] ?? 'Property',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Divider(color: Colors.grey.shade300),
          SizedBox(height: 2.h),
      _buildDetailRow('Type', widget.propertyData['type'] ?? 'N/A'),

// ⭐⭐⭐ SHOW BOTH ROOMS AND BEDS FOR PG ⭐⭐⭐
if (widget.propertyData['type'] == 'PG') ...[
  // Show rooms (informational)
  if (widget.propertyData['rooms'] != null)
    _buildDetailRow(
      'Rooms', 
      '${widget.propertyData['rooms']} room${(widget.propertyData['rooms'] as int) > 1 ? 's' : ''}'
    ),
  // Show beds (for payment)
  if (widget.propertyData['beds'] != null)
    _buildDetailRow(
      'Beds (for payment)', 
      '${widget.propertyData['beds']} bed${(widget.propertyData['beds'] as int) > 1 ? 's' : ''}'
    ),
],

// For Flat, show BHK
if (widget.propertyData['type'] != 'PG' && widget.propertyData['bhk'] != null)
  _buildDetailRow('BHK', widget.propertyData['bhk']),

if (widget.propertyData['location'] != null)
  _buildDetailRow('Location', widget.propertyData['location']),
if (widget.propertyData['price'] != null)
  _buildDetailRow('Rent', widget.propertyData['price']),
        ],
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Duration',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2.h),
        Row(
          children: _subscriptionPricing.keys.map((months) {
            final pricing = _subscriptionPricing[months]!;
            final isSelected = _selectedMonthsDuration == months;
            final isBestValue = months == 12;

            return Expanded(
              child: GestureDetector(
                onTap: () => _updateDuration(months),
                child: Container(
                  margin: EdgeInsets.only(right: months == 12 ? 0 : 2.w),
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryLight : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryLight : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${pricing['months']}M',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                      if (pricing['discount'] > 0)
                        Text(
                          '${pricing['discount']}%',
                          style: TextStyle(
                            fontSize: 8.sp,
                            color: isSelected ? Colors.white : Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (isBestValue && !isSelected)
                        Text(
                          '🏆',
                          style: TextStyle(fontSize: 8.sp),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCouponSection() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Icon(Icons.local_offer, color: AppTheme.primaryLight, size: 6.w),
              SizedBox(width: 2.w),
              Text(
                'Have a Coupon?',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          if (_appliedCoupon == null) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Enter coupon code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 1.5.h,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 2.w),
                ElevatedButton(
                  onPressed: _applyCoupon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 1.8.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Apply',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 6.w),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _appliedCoupon!,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                        Text(
                          _discountPercent == 100
                              ? 'Almost FREE! Pay just ₹1'
                              : 'You saved ₹$_discountAmount ($_discountPercent% off)',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red),
                    onPressed: _removeCoupon,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceChargeCard() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryLight,
            AppTheme.primaryLight.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryLight.withOpacity(0.3),
            blurRadius: 10,
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
              Text(
                'Service Charge',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 3.w,
                  vertical: 0.5.h,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getPaymentType(),
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            _getChargeBreakdown(),
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          if (_appliedCoupon != null) ...[
            SizedBox(height: 1.h),
            Row(
              children: [
                Text(
                  'Original: ',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                Text(
                  '₹$_serviceCharge',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.white.withOpacity(0.8),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
            SizedBox(height: 0.5.h),
            Row(
              children: [
                Icon(Icons.discount, color: Colors.white, size: 4.w),
                SizedBox(width: 1.w),
                Text(
                  _discountPercent == 100
                      ? 'Discount (99.9%): -₹${_serviceCharge! - 1}'
                      : 'Discount ($_discountPercent%): -₹$_discountAmount',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 2.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹$_finalAmount',
                style: TextStyle(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 2.w),
              Padding(
                padding: EdgeInsets.only(bottom: 1.h),
                child: Text(
                  'INR',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
            ],
          ),
          if (_finalAmount == 1 && _appliedCoupon == 'RENTIFY100') ...[
            SizedBox(height: 1.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '🎉 Almost FREE - Just ₹1!',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 6.w),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              widget.paymentMode == 'initial'
                  ? 'This is a one-time registration fee. Your property will be listed after successful payment.'
                  : widget.paymentMode == 'capacity_increase'
                  ? 'This is a one-time charge for increasing PG beds. Your monthly service charge will be updated.'
                  : 'This payment will extend your property listing for $_selectedMonthsDuration month(s).',
              style: TextStyle(
                fontSize: 10.sp,
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _proceedToPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryLight,
          padding: EdgeInsets.symmetric(vertical: 2.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isProcessing
            ? SizedBox(
          height: 2.5.h,
          width: 2.5.h,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, color: Colors.white),
            SizedBox(width: 2.w),
            Text(
              _finalAmount == 1 && _appliedCoupon == 'RENTIFY100'
                  ? 'Pay ₹1 (Almost FREE!)'
                  : 'Proceed to Payment',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityBadge() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 4.w, color: Colors.grey),
          SizedBox(width: 1.w),
          Text(
            'Secure payment powered by Razorpay',
            style: TextStyle(
              fontSize: 9.sp,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}