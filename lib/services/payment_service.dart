// lib/services/payment_service.dart - UPDATED WITH CONVENIENCE FEE
// Supports both Owner Service Charge & Tenant Rent Payments
// ⭐ NEW: 2.7% convenience fee for tenant bookings
// ✅ FIXED: Added bookingId and monthsDuration parameters

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/material.dart';

class PaymentService {
  final String baseUrl = 'https://rentify-backend-cdaj.onrender.com';
  late Razorpay _razorpay;

  // Callbacks
  Function(PaymentSuccessResponse)? _onSuccess;
  Function(PaymentFailureResponse)? _onFailure;
  Function(ExternalWalletResponse)? _onExternalWallet;

  PaymentService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  // Calculate service charge for property owners (₹18/bed or ₹18/bhk)
  int calculateServiceCharge(String propertyType, int? beds, String? bhk) {
    const int ratePerUnit = 18;

    if (propertyType == 'PG') {
      return (beds ?? 1) * ratePerUnit;
    } else if (propertyType == 'Flat' || propertyType == 'Apartment') {
      // Extract number from "3 BHK" format
      if (bhk != null) {
        final match = RegExp(r'(\d+)').firstMatch(bhk);
        if (match != null) {
          final bedroomCount = int.parse(match.group(1)!);
          return bedroomCount * ratePerUnit;
        }
      }
      return 1 * ratePerUnit; // Default to 1 BHK
    }

    return ratePerUnit;
  }

  // ========================================
  // 1. CREATE OWNER SERVICE CHARGE ORDER - WITH COUPON SUPPORT
  // For property owners to pay platform fee
  // ========================================
  Future<Map<String, dynamic>> createOrder({
    required String propertyType,
    int? beds,
    String? bhk,
    required String propertyTitle,
    String? couponCode,
  }) async {
    try {
      print('🔵 Creating owner service charge order...');

      final requestBody = {
        'propertyType': propertyType,
        'beds': beds,
        'bhk': bhk,
        'propertyTitle': propertyTitle,
        'couponCode': couponCode,
      };

      print('📤 Request: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/payments/create-order'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('📥 Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == false) {
          throw Exception(data['message'] ?? 'Failed to create order');
        }

        if (data['couponCode'] != null) {
          print('🎟️ Coupon applied: ${data['couponCode']}');
          print('💰 Original: ₹${data['originalAmount']}');
          print('💰 Final: ₹${data['amount']}');
          print('💸 Discount: ${data['discountPercent']}%');
        }

        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Server error');
      }
    } catch (e) {
      print('❌ Error creating order: $e');
      rethrow;
    }
  }

  // ========================================
  // 2. CREATE TENANT RENT ORDER (with auto-transfer to owner)
  // For tenants to pay rent that transfers to property owner
  // ⭐ NEW: Includes 2.7% convenience fee
  // ✅ FIXED: Added bookingId and monthsDuration parameters
  // ========================================
  Future<Map<String, dynamic>> createTenantOrder({
    required String propertyId,
    required String ownerId,
    required int leaseDuration,              // ✅ ADDED - Number of months
    required String tenantName,
    required String tenantEmail,
    required String tenantPhone,
    required int monthlyRent,
    required int securityDeposit,
    required String propertyTitle,
  }) async {
    try {
      print('🔵 Creating tenant rent order...');
      print('  Property ID: $propertyId');
      print('  Owner ID: $ownerId');
      print('  Lease Duration: $leaseDuration months');
      print('  Monthly Rent: ₹$monthlyRent');
      print('  Security Deposit: ₹$securityDeposit');

      // ⭐ Calculate 2.7% convenience fee
      final baseAmount = monthlyRent + securityDeposit;
      final convenienceFee = ((baseAmount * 2.7) / 100).round();
      final totalAmount = baseAmount + convenienceFee;

      print('  Base Amount: ₹$baseAmount');
      print('  Convenience Fee (2.7%): ₹$convenienceFee');
      print('  Total Amount: ₹$totalAmount');

      final requestBody = {
        'propertyId': propertyId,
        'ownerId': ownerId,
        'tenantEmail': tenantEmail,
        'tenantName': tenantName,            // ✅ ADDED
        'tenantPhone': tenantPhone,          // ✅ ADDED
        'monthlyRent': monthlyRent,
        'securityDeposit': securityDeposit,
        'leaseDuration': leaseDuration,      // ✅ ADDED - Required by backend
        'totalAmount': totalAmount,          // ✅ ADDED - Required by backend
        'propertyTitle': propertyTitle,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/payments/create-booking-order'), // ⭐ New endpoint
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('📥 Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == false) {
          throw Exception(data['message'] ?? 'Failed to create order');
        }

        print('✅ Tenant order created: ${data['orderId']}');
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Server error');
      }
    } catch (e) {
      print('❌ Error creating tenant order: $e');
      rethrow;
    }
  }

  // Open Razorpay checkout
  void openCheckout({
    required String orderId,
    required int amount,
    required String key,
    required String name,
    required String email,
    required String phone,
    required String description,
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onFailure,
  }) {
    _onSuccess = onSuccess;
    _onFailure = onFailure;

    var options = {
      'key': key,
      'amount': amount * 100, // in paise
      'name': 'Rentify',
      'order_id': orderId,
      'description': description,
      'prefill': {
        'contact': phone,
        'email': email,
        'name': name,
      },
      'theme': {
        'color': '#4CAF50',
      },
    };

    print('🎯 Opening Razorpay with options:');
    print('   Order ID: $orderId');
    print('   Amount: ₹$amount');

    try {
      _razorpay.open(options);
    } catch (e) {
      print('❌ Error opening Razorpay: $e');
    }
  }

  // Verify payment
  Future<bool> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    required Map<String, dynamic> propertyData,
  }) async {
    try {
      print('🔄 Verifying payment...');

      if (propertyData['couponCode'] != null) {
        print('🎟️ Payment with coupon: ${propertyData['couponCode']}');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/payments/verify-payment'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'razorpay_order_id': orderId,
          'razorpay_payment_id': paymentId,
          'razorpay_signature': signature,
          'propertyData': propertyData,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Payment verified: ${data['success']}');
        return data['success'] == true;
      } else {
        print('❌ Verification failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error verifying payment: $e');
      return false;
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print('✅ Payment successful: ${response.paymentId}');
    _onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('❌ Payment failed: ${response.code} - ${response.message}');
    _onFailure?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('💳 External wallet: ${response.walletName}');
    _onExternalWallet?.call(response);
  }

  void dispose() {
    _razorpay.clear();
  }
}