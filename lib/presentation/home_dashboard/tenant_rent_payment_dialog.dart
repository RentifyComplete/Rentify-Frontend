// lib/presentation/home_dashboard/tenant_rent_payment_dialog.dart
// ⭐ FIXED: Proper booking data extraction and payment flow

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/app_export.dart';

class TenantRentPaymentDialog extends StatefulWidget {
  final Map<String, dynamic> booking;

  const TenantRentPaymentDialog({
    super.key,
    required this.booking,
  });

  @override
  State<TenantRentPaymentDialog> createState() => _TenantRentPaymentDialogState();
}

class _TenantRentPaymentDialogState extends State<TenantRentPaymentDialog> {
  final String baseUrl = 'https://rentify-backend-cdaj.onrender.com';
  final Razorpay _razorpay = Razorpay();
  final TextEditingController _couponController = TextEditingController();

  int _selectedMonths = 1;
  bool _isLoading = false;
  String? _appliedCoupon;
  Map<String, dynamic>? _currentOrderData;

  // Pricing structure
  final Map<int, Map<String, dynamic>> _pricing = {
    1: {'months': 1, 'discount': 0, 'label': '1 Month'},
    3: {'months': 3, 'discount': 5, 'label': '3 Months (5% off)'},
    6: {'months': 6, 'discount': 10, 'label': '6 Months (10% off)'},
    12: {'months': 12, 'discount': 15, 'label': '12 Months (15% off)'},
  };

  @override
  void initState() {
    super.initState();

    // Debug: Print booking structure
    print('🔍 ========== BOOKING DATA STRUCTURE ==========');
    print('Full booking object: ${widget.booking}');
    print('Available keys: ${widget.booking.keys.join(", ")}');
    print('=============================================');

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _couponController.dispose();
    super.dispose();
  }

  // ⭐ FIXED: Safe extraction of booking data with multiple fallbacks
  String? _getBookingId() {
    return widget.booking['_id']?.toString() ??
        widget.booking['id']?.toString() ??
        widget.booking['bookingId']?.toString();
  }

  String? _getPropertyId() {
    // Try direct property ID
    if (widget.booking['propertyId'] != null) {
      return widget.booking['propertyId'].toString();
    }

    // Try nested property object
    if (widget.booking['property'] != null) {
      final property = widget.booking['property'];
      if (property is Map) {
        return property['_id']?.toString() ?? property['id']?.toString();
      }
      return property.toString();
    }

    return null;
  }

  int _getMonthlyRent() {
    final rent = widget.booking['monthlyRent'];
    if (rent is int) return rent;
    if (rent is String) return int.tryParse(rent.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return 0;
  }

  String _getPropertyTitle() {
    return widget.booking['propertyTitle']?.toString() ??
        widget.booking['propertyName']?.toString() ??
        'Property';
  }

  Map<String, dynamic> _calculateAmount() {
    final monthlyRent = _getMonthlyRent();
    final pricing = _pricing[_selectedMonths]!;

    final baseAmount = monthlyRent * pricing['months'] as int;
    final durationDiscount = ((baseAmount * (pricing['discount'] as int)) / 100).round();
    final afterDiscount = baseAmount - durationDiscount;
    final convenienceFee = ((afterDiscount * 2.7) / 100).round();
    final total = afterDiscount + convenienceFee;

    return {
      'monthlyRent': monthlyRent,
      'months': pricing['months'],
      'baseAmount': baseAmount,
      'durationDiscount': durationDiscount,
      'afterDiscount': afterDiscount,
      'convenienceFee': convenienceFee,
      'total': total,
    };
  }

  Future<void> _handlePayment() async {
    setState(() => _isLoading = true);

    try {
      final bookingId = _getBookingId();
      final propertyId = _getPropertyId();

      print('🔍 ========== EXTRACTED DATA ==========');
      print('Booking ID: $bookingId');
      print('Property ID: $propertyId');
      print('Monthly Rent: ${_getMonthlyRent()}');
      print('Selected Months: $_selectedMonths');
      print('====================================');

      if (bookingId == null || bookingId.isEmpty) {
        throw Exception(
            'Missing booking ID. Available fields: ${widget.booking.keys.join(", ")}'
        );
      }

      if (propertyId == null || propertyId.isEmpty) {
        throw Exception(
            'Missing property ID. Available fields: ${widget.booking.keys.join(", ")}'
        );
      }

      print('💰 Creating tenant rent order...');
      print('   Booking ID: $bookingId');
      print('   Property ID: $propertyId');
      print('   Months: $_selectedMonths');

      final requestBody = {
        'bookingId': bookingId,
        'propertyId': propertyId,
        'monthsDuration': _selectedMonths,
        'couponCode': _couponController.text.trim().isEmpty
            ? null
            : _couponController.text.trim(),
      };

      print('📤 Request body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/payments/create-tenant-rent-order'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('📥 Response: ${response.statusCode}');
      print('📦 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          _currentOrderData = data;

          print('✅ Order created: ${data['orderId']}');
          print('💰 Amount: ₹${data['amount']}');

          // Open Razorpay
          final options = {
            'key': data['key'],
            'amount': data['amount'] * 100, // Convert to paise
            'currency': 'INR',
            'name': 'Rentify',
            'description': 'Rent for ${_getPropertyTitle()}',
            'order_id': data['orderId'],
            'prefill': {
              'name': widget.booking['tenantName']?.toString() ?? 'Tenant',
              'email': widget.booking['tenantEmail']?.toString() ?? 'tenant@example.com',
              'contact': widget.booking['tenantPhone']?.toString() ?? '',
            },
            'theme': {
              'color': '#6C63FF',
            },
          };

          _razorpay.open(options);
        } else {
          throw Exception(data['message'] ?? 'Failed to create order');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('❌ Error: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    print('✅ Payment success: ${response.paymentId}');

    try {
      final bookingId = _getBookingId();

      if (bookingId == null) {
        throw Exception('Booking ID missing for verification');
      }

      final verifyResponse = await http.post(
        Uri.parse('$baseUrl/api/payments/verify-tenant-rent-payment'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'razorpay_order_id': response.orderId,
          'razorpay_payment_id': response.paymentId,
          'razorpay_signature': response.signature,
          'bookingId': bookingId,
          'monthsDuration': _selectedMonths,
        }),
      );

      print('📥 Verification response: ${verifyResponse.statusCode}');

      if (verifyResponse.statusCode == 200) {
        final data = json.decode(verifyResponse.body);

        if (data['success'] == true) {
          if (mounted) {
            Navigator.pop(context, true); // Return success
            _showSuccessDialog();
          }
        } else {
          throw Exception(data['message'] ?? 'Payment verification failed');
        }
      } else {
        throw Exception('Verification failed: ${verifyResponse.statusCode}');
      }
    } catch (e) {
      print('❌ Verification error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment verification failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('❌ Payment error: ${response.message}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${response.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('💳 External wallet: ${response.walletName}');
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 15.w),
            SizedBox(height: 2.h),
            Text('Payment Successful!'),
          ],
        ),
        content: Text(
          'Your rent has been paid for $_selectedMonths month(s).\nYour next due date has been updated.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close success dialog
              Navigator.pop(context, true); // Close payment dialog with success
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calculation = _calculateAmount();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(maxHeight: 85.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pay Rent',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          _getPropertyTitle(),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10.sp,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(4.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Duration Selection
                    Text(
                      'Select Duration',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Wrap(
                      spacing: 2.w,
                      runSpacing: 1.h,
                      children: _pricing.entries.map((entry) {
                        final isSelected = _selectedMonths == entry.key;
                        return ChoiceChip(
                          label: Text(entry.value['label']),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedMonths = entry.key);
                          },
                          selectedColor: AppTheme.primaryLight,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),

                    SizedBox(height: 3.h),

                    // Price Breakdown
                    Container(
                      padding: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildPriceRow('Monthly Rent', calculation['monthlyRent']),
                          _buildPriceRow('× ${calculation['months']} months', calculation['baseAmount']),
                          if (calculation['durationDiscount'] > 0) ...[
                            Divider(height: 2.h),
                            _buildPriceRow(
                              'Duration Discount',
                              -calculation['durationDiscount'],
                              isDiscount: true,
                            ),
                          ],
                          Divider(height: 2.h),
                          _buildPriceRow(
                            'Convenience Fee (2.7%)',
                            calculation['convenienceFee'],
                            isConvenienceFee: true,
                          ),
                          Divider(height: 2.h, thickness: 2),
                          _buildPriceRow(
                            'Total to Pay',
                            calculation['total'],
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 3.h),

                    // Coupon Code
                    Text(
                      'Coupon Code (Optional)',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    TextField(
                      controller: _couponController,
                      decoration: InputDecoration(
                        hintText: 'Enter coupon code',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 3.w,
                          vertical: 1.5.h,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pay Button
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handlePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    padding: EdgeInsets.symmetric(vertical: 1.8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                    height: 2.5.h,
                    width: 2.5.h,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    'Pay ₹${calculation['total']}',
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
      ),
    );
  }

  Widget _buildPriceRow(String label, int amount, {
    bool isTotal = false,
    bool isDiscount = false,
    bool isConvenienceFee = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 11.sp : 10.sp,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isConvenienceFee ? Colors.orange.shade700 : Colors.black87,
            ),
          ),
          Text(
            '${isDiscount ? '-' : ''}₹${amount.abs()}',
            style: TextStyle(
              fontSize: isTotal ? 12.sp : 10.sp,
              fontWeight: FontWeight.bold,
              color: isTotal
                  ? AppTheme.primaryLight
                  : isDiscount
                  ? Colors.green
                  : isConvenienceFee
                  ? Colors.orange.shade700
                  : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}