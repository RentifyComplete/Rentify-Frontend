// lib/presentation/home_dashboard/my_properties_screen.dart
// ⭐ Tenant view: Shows booking requests and enables payment when approved
// ✅ FIXED: Proper email retrieval, approval status handling, and payment flow

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import '../../services/payment_service.dart';

class MyPropertiesScreen extends StatefulWidget {
  const MyPropertiesScreen({super.key});

  @override
  State<MyPropertiesScreen> createState() => _MyPropertiesScreenState();
}

class _MyPropertiesScreenState extends State<MyPropertiesScreen> {
  final AuthService _authService = AuthService();
  final PaymentService _paymentService = PaymentService();
  final String baseUrl = 'https://rentify-backend-cdaj.onrender.com';

  List<Map<String, dynamic>> myRequests = [];
  List<Map<String, dynamic>> myBookings = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedTab = 0; // 0 = Requests, 1 = Bookings
  String? _tenantEmail; // Store tenant email once loaded

  @override
  void initState() {
    super.initState();
    _loadTenantData();
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _loadTenantData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) throw Exception('User not logged in');

      print('📱 Current User ID: $currentUserId');

      // ✅ Get tenant email using AuthService
      _tenantEmail = await _getTenantEmail(currentUserId);
      if (_tenantEmail == null || _tenantEmail!.isEmpty) {
        throw Exception('Failed to retrieve tenant email');
      }

      print('📧 Tenant Email: $_tenantEmail');

      // Load booking requests
      await _loadBookingRequests(_tenantEmail!);

      // Load confirmed bookings
      await _loadBookings(_tenantEmail!);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ Error loading tenant data: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ✅ NEW: Get tenant email from database using userId
  Future<String?> _getTenantEmail(String userId) async {
    try {
      // Try from SharedPreferences first (if saved during login)
      final prefs = await SharedPreferences.getInstance();
      String? cachedEmail = prefs.getString('userEmail');
      
      if (cachedEmail != null && cachedEmail.isNotEmpty) {
        print('📧 Using cached email: $cachedEmail');
        return cachedEmail;
      }

      // Otherwise, fetch from MongoDB using AuthService
      try {
        final user = await _authService.getUserById(userId);
        if (user != null && user.email != null && user.email!.isNotEmpty) {
          // Cache for future use
          await prefs.setString('userEmail', user.email!);
          print('📧 Retrieved and cached email from DB: ${user.email}');
          return user.email;
        }
      } catch (dbError) {
        print('⚠️ Database error: $dbError');
      }

      // Fallback: try backend API
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/users/$userId'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true && data['email'] != null) {
            await prefs.setString('userEmail', data['email']);
            print('📧 Retrieved email from API: ${data['email']}');
            return data['email'];
          }
        }
      } catch (apiError) {
        print('⚠️ API error: $apiError');
      }

      return null;
    } catch (e) {
      print('⚠️ Error getting tenant email: $e');
      return null;
    }
  }

  Future<void> _loadBookingRequests(String tenantEmail) async {
    try {
      print('🔄 Loading booking requests for tenant: $tenantEmail');

      final response = await http.get(
        Uri.parse('$baseUrl/api/booking-requests/tenant/$tenantEmail'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      print('📥 Requests Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['requests'] != null) {
          final requests = List<Map<String, dynamic>>.from(data['requests'] ?? []);
          
          // ✅ Sort by status (approved first, then pending, then rejected)
          requests.sort((a, b) {
            final statusOrder = {'approved': 0, 'pending': 1, 'rejected': 2};
            final statusA = (a['status'] as String?)?.toLowerCase() ?? 'pending';
            final statusB = (b['status'] as String?)?.toLowerCase() ?? 'pending';
            
            int orderA = statusOrder[statusA] ?? 3;
            int orderB = statusOrder[statusB] ?? 3;
            
            return orderA.compareTo(orderB);
          });

          if (mounted) {
            setState(() {
              myRequests = requests;
            });
          }
          print('✅ Loaded ${myRequests.length} booking requests (sorted by status)');
          
          // Debug logging
          for (int i = 0; i < myRequests.length; i++) {
            print('Request $i: ${myRequests[i]['propertyName']} - Status: ${myRequests[i]['status']}');
          }
        }
      } else {
        print('⚠️ Unexpected status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('❌ Error loading booking requests: $e');
    }
  }

  Future<void> _loadBookings(String tenantEmail) async {
    try {
      print('🔄 Loading bookings for tenant: $tenantEmail');

      final response = await http.get(
        Uri.parse('$baseUrl/api/bookings/tenant/$tenantEmail'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      print('📥 Bookings Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final bookings = List<Map<String, dynamic>>.from(data['bookings'] ?? []);
          if (mounted) {
            setState(() {
              myBookings = bookings;
            });
          }
          print('✅ Loaded ${myBookings.length} bookings');
        }
      }
    } catch (e) {
      print('❌ Error loading bookings: $e');
    }
  }

  // ⭐ Initiate payment for approved request
  Future<void> _payForApprovedRequest(Map<String, dynamic> request) async {
    try {
      print('\n💳 ========== INITIATING PAYMENT FOR APPROVED REQUEST ==========');

      final monthlyRent = request['monthlyRent'] as int;
      final securityDeposit = request['securityDeposit'] as int;
      final leaseDuration = request['leaseDuration'] as int? ?? 12; // ✅ Get from request
      final baseAmount = monthlyRent + securityDeposit;
      final convenienceFee = ((baseAmount * 2.7) / 100).round();
      final totalAmount = baseAmount + convenienceFee;

      print('Monthly Rent: ₹$monthlyRent');
      print('Security Deposit: ₹$securityDeposit');
      print('Lease Duration: $leaseDuration months');
      print('Convenience Fee: ₹$convenienceFee');
      print('Total Amount: ₹$totalAmount');

      _showPaymentProgressDialog();

      // Create payment order
      final paymentOrder = await _paymentService.createTenantOrder(
        propertyId: request['propertyId'],
        ownerId: request['ownerId'],
        leaseDuration: leaseDuration,        // ✅ ADDED - Required parameter
        tenantName: request['tenantName'],
        tenantEmail: request['tenantEmail'],
        tenantPhone: request['tenantPhone'],
        monthlyRent: monthlyRent,
        securityDeposit: securityDeposit,
        propertyTitle: request['propertyName'],
      );

      print('✅ Payment order created: ${paymentOrder['orderId']}');
      print('Order Amount: ${paymentOrder['amount']}');

      if (mounted) Navigator.pop(context);

      _paymentService.openCheckout(
        orderId: paymentOrder['orderId'],
        amount: paymentOrder['amount'],
        key: paymentOrder['key'],
        name: request['tenantName'],
        email: request['tenantEmail'],
        phone: request['tenantPhone'],
        description: 'Rent for ${request['propertyName']}',
        onSuccess: (PaymentSuccessResponse response) {
          _handlePaymentSuccess(response, request);
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
        } catch (_) {}

        String errorMessage = 'Failed to initiate payment';
        if (e.toString().contains('Missing required fields')) {
          errorMessage = 'Missing required booking information';
        } else if (e.toString().contains('Exception:')) {
          errorMessage = e.toString().replaceAll('Exception:', '').trim();
        } else {
          errorMessage = e.toString();
        }

        _showErrorDialog(errorMessage);
      }
    }
  }

  Future<void> _handlePaymentSuccess(
      PaymentSuccessResponse response,
      Map<String, dynamic> request,
      ) async {
    try {
      print('\n🎉 ========== PAYMENT SUCCESS ==========');

      final isVerified = await _paymentService.verifyPayment(
        orderId: response.orderId ?? '',
        paymentId: response.paymentId ?? '',
        signature: response.signature ?? '',
        propertyData: {
          'propertyId': request['propertyId'],
          'ownerId': request['ownerId'],
          'amount': request['monthlyRent'] + request['securityDeposit'],
        },
      );

      if (!isVerified) {
        _showErrorDialog('Payment verification failed');
        return;
      }

      await _createBookingFromRequest(request, response.paymentId!, response.orderId!);
      await _deleteBookingRequest(request['_id']);
      await _loadTenantData();

      _showPaymentSuccessDialog(request);
    } catch (e) {
      print('❌ Error in payment success handler: $e');
      _showErrorDialog('Error processing payment: $e');
    }
  }

  Future<void> _createBookingFromRequest(
      Map<String, dynamic> request,
      String paymentId,
      String orderId,
      ) async {
    try {
      print('\n💾 ========== SAVING BOOKING ==========');

      final monthlyRent = request['monthlyRent'] as int;
      final securityDeposit = request['securityDeposit'] as int;
      final leaseDuration = request['leaseDuration'] as int? ?? 12;
      final baseAmount = monthlyRent + securityDeposit;
      final convenienceFee = ((baseAmount * 2.7) / 100).round();
      final totalAmount = baseAmount + convenienceFee;

      print('Lease Duration: $leaseDuration months');
      print('Total Amount: ₹$totalAmount');

      final response = await http.post(
        Uri.parse('$baseUrl/api/bookings/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'propertyId': request['propertyId'],
          'tenantId': null,
          'tenantName': request['tenantName'],
          'tenantEmail': request['tenantEmail'],
          'tenantPhone': request['tenantPhone'],
          'monthlyRent': monthlyRent,
          'securityDeposit': securityDeposit,
          'leaseDuration': leaseDuration,      // ✅ ADDED - Required by backend
          'totalAmount': totalAmount,          // ✅ ADDED - Required by backend
          'moveInDate': request['moveInDate'],
          'notes': request['notes'] ?? '',
          'paymentId': paymentId,
          'orderId': orderId,
        }),
      ).timeout(const Duration(seconds: 30));

      print('📥 Booking Response: ${response.statusCode}');
      print('Response Body: ${response.body}');

      // ✅ Accept both 200 and 201 as success
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final bookingId = data['booking']?['_id'] ?? data['bookingId'] ?? 'Unknown';
          print('✅ Booking created successfully with ID: $bookingId');
        } else {
          throw Exception(data['message'] ?? 'Failed to create booking');
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

  Future<void> _deleteBookingRequest(String requestId) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/api/booking-requests/$requestId'),
        headers: {'Content-Type': 'application/json'},
      );
      print('✅ Booking request deleted');
    } catch (e) {
      print('⚠️ Error deleting request: $e');
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
        content: Text(response.message ?? 'Payment was not successful'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPaymentSuccessDialog(Map<String, dynamic> request) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                child: Icon(Icons.check_circle, color: Colors.green, size: 15.w),
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
                'Your booking has been confirmed!\nMoney transferred to property owner.',
                style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 3.h),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                  minimumSize: Size(double.infinity, 6.h),
                ),
                child: const Text('Done', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
  void _showPaymentProgressDialog() {
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
        title: const Text('My Properties'),
        backgroundColor: AppTheme.primaryLight,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadTenantData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(6.h),
          child: Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(child: _buildTabButton('Requests', 0)),
                Expanded(child: _buildTabButton('Bookings', 1)),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : _errorMessage != null
          ? _buildErrorState()
          : RefreshIndicator(
            onRefresh: _loadTenantData,
            color: AppTheme.primaryLight,
            child: _selectedTab == 0 ? _buildRequestsList() : _buildBookingsList(),
          ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 2.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppTheme.primaryLight : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? AppTheme.primaryLight : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 15.w, color: Colors.red),
          SizedBox(height: 2.h),
          Text('Error Loading Data', style: TextStyle(fontSize: 13.sp)),
          SizedBox(height: 1.h),
          Text(_errorMessage!, textAlign: TextAlign.center),
          SizedBox(height: 3.h),
          ElevatedButton(
            onPressed: _loadTenantData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    if (myRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 20.w, color: Colors.grey),
            SizedBox(height: 2.h),
            Text('No booking requests yet', style: TextStyle(fontSize: 11.sp)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(4.w),
      itemCount: myRequests.length,
      itemBuilder: (context, index) => _buildRequestCard(myRequests[index]),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    // ✅ Proper status handling
    final statusRaw = request['status'];
    final status = (statusRaw is String) 
        ? statusRaw.toLowerCase().trim() 
        : 'pending';
    
    Color statusColor;
    String statusText;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusText = 'APPROVED';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'REJECTED';
        break;
      case 'pending':
      default:
        statusColor = Colors.orange;
        statusText = 'PENDING';
    }

    print('🔍 Card Status: ${request['propertyName']} - status=$status');

    return Container(
      margin: EdgeInsets.only(bottom: 3.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == 'approved' ? Colors.green : Colors.grey.shade200,
          width: status == 'approved' ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property Image
          if (request['propertyImage'] != null && request['propertyImage'] != '')
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              child: CustomImageWidget(
                imageUrl: request['propertyImage'],
                height: 30.h,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

          Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        request['propertyName'] ?? 'Property',
                        style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 9.sp,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 1.h),

                // Details
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 4.w, color: AppTheme.primaryLight),
                    SizedBox(width: 2.w),
                    Text('Move-in: ${request['moveInDate'] ?? 'N/A'}'),
                    SizedBox(width: 4.w),
                    Icon(Icons.access_time, size: 4.w, color: AppTheme.primaryLight),
                    SizedBox(width: 2.w),
                    Text('${request['leaseDuration'] ?? 12} months'),
                  ],
                ),

                SizedBox(height: 1.h),

                Row(
                  children: [
                    Icon(Icons.attach_money, size: 4.w, color: AppTheme.successLight),
                    SizedBox(width: 2.w),
                    Text(
                      '₹${request['monthlyRent']}/month',
                      style: TextStyle(
                        color: AppTheme.successLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                // ✅ Only show payment button for approved status
                if (status == 'approved') ...[
                  SizedBox(height: 2.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _payForApprovedRequest(request),
                      icon: Icon(Icons.payment, size: 5.w),
                      label: const Text('Pay Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 1.8.h),
                      ),
                    ),
                  ),
                ],

                // Rejection Reason
                if (status == 'rejected' && request['rejectionReason'] != null) ...[
                  SizedBox(height: 2.h),
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.red, size: 4.w),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: Text(
                            request['rejectionReason'],
                            style: TextStyle(fontSize: 9.sp),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList() {
    if (myBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_outlined, size: 20.w, color: Colors.grey),
            SizedBox(height: 2.h),
            Text('No confirmed bookings yet', style: TextStyle(fontSize: 11.sp)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(4.w),
      itemCount: myBookings.length,
      itemBuilder: (context, index) => _buildBookingCard(myBookings[index]),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    return Container(
      margin: EdgeInsets.only(bottom: 3.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking['propertyTitle'] ?? 'Property',
                    style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 9.sp,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.h),
            Text(
              booking['propertyAddress'] ?? '',
              style: TextStyle(color: Colors.grey, fontSize: 9.sp),
            ),
            SizedBox(height: 2.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Monthly Rent:', style: TextStyle(fontSize: 9.sp)),
                Text(
                  '₹${booking['monthlyRent']}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.sp),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}