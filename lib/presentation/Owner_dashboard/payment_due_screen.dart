// ========================================
// PAYMENT DUE SCREEN - FIXED
// ✅ Pay for all properties at once only
// ✅ Fixed due date calculation for multiple months
// ========================================

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/app_export.dart';
import '../../providers/user_provider.dart';
import 'property_payment_screen.dart';

class PaymentDueScreen extends StatefulWidget {
  const PaymentDueScreen({super.key});

  @override
  State<PaymentDueScreen> createState() => _PaymentDueScreenState();
}

class _PaymentDueScreenState extends State<PaymentDueScreen> {
  final String baseUrl = 'https://rentify-backend-cdaj.onrender.com';

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _paymentsHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool afterPayment = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // If loading after payment, add a delay to allow backend to process
    if (afterPayment) {
      print('⏳ Waiting for backend to process payment...');
      await Future.delayed(const Duration(seconds: 3));
    }

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final ownerId = userProvider.userId;

      print('👤 UserProvider userId: $ownerId');

      if (ownerId == null || ownerId.isEmpty) {
        throw Exception('User ID not found');
      }

      print('🔄 Loading properties for owner: $ownerId');

      // Load owner's properties
      final propertiesResponse = await http.get(
        Uri.parse('$baseUrl/api/properties/owner/$ownerId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      print('📥 Properties Response: ${propertiesResponse.statusCode}');
      print('📥 Properties Body: ${propertiesResponse.body}');

      if (propertiesResponse.statusCode == 200) {
        final propertiesData = json.decode(propertiesResponse.body);

        if (propertiesData['success'] == true) {
          final properties = List<Map<String, dynamic>>.from(
              propertiesData['data'] ?? propertiesData['properties'] ?? []
          );

          // Load payment history for the owner
          final paymentsResponse = await http.get(
            Uri.parse('$baseUrl/api/payments/owner/$ownerId'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 30));

          print('📥 Payments Response: ${paymentsResponse.statusCode}');

          if (paymentsResponse.statusCode == 200) {
            final paymentsData = json.decode(paymentsResponse.body);
            _paymentsHistory = List<Map<String, dynamic>>.from(
                paymentsData['payments'] ?? []
            );
            print('✅ Loaded ${_paymentsHistory.length} payment records');

            // Debug: Print payment details
            if (_paymentsHistory.isNotEmpty) {
              print('📋 Recent payments:');
              for (var payment in _paymentsHistory.take(3)) {
                print('  - Type: ${payment['paymentType']}, Status: ${payment['status']}, Months: ${payment['monthsPaid']}, Date: ${payment['createdAt'] ?? payment['paymentDate']}');
              }
            }
          } else if (paymentsResponse.statusCode == 404) {
            print('ℹ️ No payment history found (404)');
            _paymentsHistory = [];
          } else {
            print('⚠️ Unexpected payments response: ${paymentsResponse.statusCode}');
            _paymentsHistory = [];
          }

          setState(() {
            _properties = properties;
            _isLoading = false;
          });

          print('✅ Loaded ${_properties.length} properties');
        } else {
          throw Exception(propertiesData['message'] ?? 'Failed to load properties');
        }
      } else {
        throw Exception('Failed to load properties: ${propertiesResponse.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading data: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // Get last payment date and months paid
  // Get last payment date and months paid
  Map<String, dynamic>? _getLastPaymentInfo() {
    try {
      final serviceChargePayments = _paymentsHistory.where((payment) {
        final status = payment['status']?.toString().toLowerCase() ?? '';
        final paymentType = payment['paymentType']?.toString() ?? '';
        return status == 'completed' && paymentType == 'service_charge';
      }).toList();

      if (serviceChargePayments.isEmpty) {
        // ⭐ NEW: If no service charge payment found, check for property addition payment
        // First month is FREE after adding property
        final propertyAdditionPayments = _paymentsHistory.where((payment) {
          final status = payment['status']?.toString().toLowerCase() ?? '';
          final paymentType = payment['paymentType']?.toString() ?? '';
          return status == 'completed' &&
              (paymentType == 'property_addition' || paymentType == 'add_property');
        }).toList();

        if (propertyAdditionPayments.isNotEmpty) {
          // Sort by date and get the most recent property addition
          propertyAdditionPayments.sort((a, b) {
            final dateA = DateTime.parse(a['createdAt'] ?? a['paymentDate'] ?? '');
            final dateB = DateTime.parse(b['createdAt'] ?? b['paymentDate'] ?? '');
            return dateB.compareTo(dateA);
          });

          final firstPropertyPayment = propertyAdditionPayments.first;
          final additionDate = DateTime.parse(
              firstPropertyPayment['createdAt'] ?? firstPropertyPayment['paymentDate'] ?? ''
          );

          print('🎁 First property added on: $additionDate - First month FREE');

          return {
            'date': additionDate,
            'monthsPaid': 1, // Free first month
            'isFreeMonth': true,
          };
        }

        return null;
      }

      // Sort by date and get the most recent
      serviceChargePayments.sort((a, b) {
        final dateA = DateTime.parse(a['createdAt'] ?? a['paymentDate'] ?? '');
        final dateB = DateTime.parse(b['createdAt'] ?? b['paymentDate'] ?? '');
        return dateB.compareTo(dateA);
      });

      final lastPayment = serviceChargePayments.first;

      return {
        'date': DateTime.parse(
            lastPayment['createdAt'] ?? lastPayment['paymentDate'] ?? ''
        ),
        'monthsPaid': lastPayment['monthsPaid'] ?? 1,
        'isFreeMonth': false,
      };
    } catch (e) {
      print('⚠️ Error getting last payment info: $e');
      return null;
    }
  }

  // ⭐ Calculate next due date based on months paid
  // ⭐ Calculate next due date based on months paid
  DateTime? _getNextDueDate() {
    final paymentInfo = _getLastPaymentInfo();
    if (paymentInfo == null) return null;

    final lastPaymentDate = paymentInfo['date'] as DateTime;
    final monthsPaid = paymentInfo['monthsPaid'] as int;
    final isFreeMonth = paymentInfo['isFreeMonth'] as bool? ?? false;

    // Add the months that were paid
    final dueDate = DateTime(
      lastPaymentDate.year,
      lastPaymentDate.month + monthsPaid,
      lastPaymentDate.day,
    );

    if (isFreeMonth) {
      print('🎁 First month FREE - Property added on: $lastPaymentDate');
    } else {
      print('📅 Last payment: $lastPaymentDate');
    }
    print('📊 Months paid: $monthsPaid');
    print('📅 Calculated due date: $dueDate');

    return dueDate;
  }

  // Calculate service status
  Map<String, dynamic> _getServiceStatus() {
    print('🔍 Calculating service status...');
    print('📊 Total payment records: ${_paymentsHistory.length}');

    final hasAnyPayment = _paymentsHistory.any((payment) {
      final status = payment['status']?.toString().toLowerCase() ?? '';
      final paymentType = payment['paymentType']?.toString() ?? '';
      final isServiceCharge = status == 'completed' && paymentType == 'service_charge';
      if (isServiceCharge) {
        print('✅ Found completed service charge payment');
      }
      return isServiceCharge;
    });

    print('💳 Has any service charge payment: $hasAnyPayment');

    if (!hasAnyPayment) {
      print('❌ No service charge payments found');

      // ⭐ Check if first month is free (property just added)
      final paymentInfo = _getLastPaymentInfo();
      if (paymentInfo != null && paymentInfo['isFreeMonth'] == true) {
        final nextDueDate = _getNextDueDate();
        if (nextDueDate != null) {
          final now = DateTime.now();
          final daysUntilDue = nextDueDate.difference(now).inDays;

          if (daysUntilDue > 7) {
            return {
              'status': 'active',
              'statusText': 'Active - Due in $daysUntilDue days',
              'color': Colors.green,
              'icon': Icons.check_circle,
              'showPayButton': false,
              'dueDate': nextDueDate,
            };
          } else if (daysUntilDue > 0) {
            return {
              'status': 'due_soon',
              'statusText': 'Due in $daysUntilDue days',
              'color': Colors.orange,
              'icon': Icons.schedule,
              'showPayButton': true,
              'dueDate': nextDueDate,
            };
          }
        }
      }

      return {
        'status': 'unpaid',
        'statusText': 'Service Charge Unpaid',
        'color': Colors.red,
        'icon': Icons.warning,
        'showPayButton': true,
        'dueDate': null,
      };
    }

    final nextDueDate = _getNextDueDate();
    print('📅 Next due date: $nextDueDate');

    if (nextDueDate != null) {
      final now = DateTime.now();
      final daysUntilDue = nextDueDate.difference(now).inDays;

      print('⏰ Days until due: $daysUntilDue');

      if (daysUntilDue > 7) {
        return {
          'status': 'active',
          'statusText': 'Active - Due in $daysUntilDue days',
          'color': Colors.green,
          'icon': Icons.check_circle,
          'showPayButton': false,
          'dueDate': nextDueDate,
        };
      } else if (daysUntilDue > 0) {
        return {
          'status': 'due_soon',
          'statusText': 'Due in $daysUntilDue days',
          'color': Colors.orange,
          'icon': Icons.schedule,
          'showPayButton': true,
          'dueDate': nextDueDate,
        };
      } else {
        return {
          'status': 'overdue',
          'statusText': 'Overdue by ${-daysUntilDue} days',
          'color': Colors.red,
          'icon': Icons.error,
          'showPayButton': true,
          'dueDate': nextDueDate,
        };
      }
    }

    return {
      'status': 'paid',
      'statusText': 'Service Charge Paid',
      'color': Colors.green,
      'icon': Icons.check_circle,
      'showPayButton': false,
      'dueDate': nextDueDate,
    };
  }

  // Calculate monthly charge for a single property
  int _calculateMonthlyCharge(Map<String, dynamic> property) {
    const int ratePerUnit = 18;
    final propertyType = property['type']?.toString() ?? 'PG';

    if (propertyType == 'PG') {
      final beds = property['beds'] ?? property['bedrooms'] ?? 1;
      return beds * ratePerUnit;
    } else if (propertyType == 'Flat' || propertyType == 'Apartment') {
      final bhk = property['bhk']?.toString() ?? '1';
      final match = RegExp(r'(\d+)').firstMatch(bhk);
      if (match != null) {
        final bedroomCount = int.parse(match.group(1)!);
        return bedroomCount * ratePerUnit;
      }
      return ratePerUnit;
    }

    return ratePerUnit;
  }

  // ⭐ Calculate total beds across ALL properties
  int _calculateTotalBedsCharge() {
    int totalBeds = 0;

    for (var property in _properties) {
      final propertyType = property['type']?.toString() ?? 'PG';

      if (propertyType == 'PG') {
        final beds = property['beds'] ?? property['bedrooms'] ?? 0;
        totalBeds += beds as int;
      } else if (propertyType == 'Flat' || propertyType == 'Apartment') {
        final bhk = property['bhk']?.toString() ?? '1';
        final match = RegExp(r'(\d+)').firstMatch(bhk);
        if (match != null) {
          final bedroomCount = int.parse(match.group(1)!);
          totalBeds += bedroomCount;
        } else {
          totalBeds += 1;
        }
      } else {
        totalBeds += 1;
      }
    }

    return totalBeds * 18;
  }

  // ⭐ Navigate to payment for ALL properties
  void _navigateToPayment() async {
    if (_properties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No properties to pay for'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final totalBeds = _calculateTotalBedsCharge() ~/ 18;
    final totalMonthlyCharge = _calculateTotalBedsCharge();

    print('💰 Opening payment for all properties');
    print('📊 Total beds across all properties: $totalBeds');
    print('💵 Total monthly charge: ₹$totalMonthlyCharge');

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyPaymentScreen(
          propertyData: {
            'propertyId': _properties.first['_id'],
            'propertyTitle': 'All Properties Service Charge',
            'type': 'Multiple',
            'beds': totalBeds,
            'bhk': null,
            'title': 'Monthly Service Charge',
            'monthlyCharge': totalMonthlyCharge,
          },
          paymentMode: 'subscription',
        ),
      ),
    );

    if (result == true) {
      print('✅ Payment successful, reloading data...');
      await _loadData(afterPayment: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryLight,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Service Charge Payment',
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
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : _errorMessage != null
          ? _buildErrorState()
          : _buildContent(),
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

  Widget _buildContent() {
    final totalBeds = _calculateTotalBedsCharge() ~/ 18;
    final totalMonthlyCharge = _calculateTotalBedsCharge();
    final serviceStatus = _getServiceStatus();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primaryLight,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Status Card
            _buildServiceStatusCard(serviceStatus),
            SizedBox(height: 3.h),

            // Total Service Charge Card with Payment Button
            _buildTotalChargeCard(totalBeds, totalMonthlyCharge, serviceStatus),
            SizedBox(height: 3.h),

            // Properties List Header
            Text(
              'Your Properties',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Service charge covers all properties',
              style: TextStyle(
                fontSize: 10.sp,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 2.h),

            // Properties List
            if (_properties.isEmpty)
              _buildEmptyState()
            else
              ..._properties.map((property) =>
                  _buildPropertyCard(property, serviceStatus)
              ).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceStatusCard(Map<String, dynamic> serviceStatus) {
    final status = serviceStatus['status'] as String;
    final statusText = serviceStatus['statusText'] as String;
    final color = serviceStatus['color'] as Color;
    final icon = serviceStatus['icon'] as IconData;
    final dueDate = serviceStatus['dueDate'] as DateTime?;

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
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
                padding: EdgeInsets.all(2.5.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 8.w),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Status',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11.sp,
                      ),
                    ),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (dueDate != null) ...[
            SizedBox(height: 2.h),
            Divider(color: Colors.white.withOpacity(0.3)),
            SizedBox(height: 1.5.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Colors.white.withOpacity(0.9),
                      size: 5.w,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Next Due Date',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatDate(dueDate),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],

          if (status == 'unpaid') ...[
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 4.w),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      'Please pay the service charge to activate your listings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalChargeCard(int totalBeds, int totalCharge, Map<String, dynamic> serviceStatus) {
    final hasUnpaid = serviceStatus['showPayButton'] == true;

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasUnpaid
              ? [Colors.orange.shade600, Colors.orange.shade400]
              : [Colors.green.shade600, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (hasUnpaid ? Colors.orange : Colors.green).withOpacity(0.3),
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
              Icon(
                hasUnpaid ? Icons.payment : Icons.check_circle_outline,
                color: Colors.white,
                size: 7.w,
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Text(
                  hasUnpaid ? 'Payment Required' : 'Service Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),

          Divider(color: Colors.white.withOpacity(0.3)),
          SizedBox(height: 1.h),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Beds/Units',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 10.sp,
                    ),
                  ),
                  Text(
                    totalBeds.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                height: 6.h,
                width: 1,
                color: Colors.white.withOpacity(0.3),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Monthly Service Charge',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 10.sp,
                    ),
                  ),
                  Text(
                    '₹$totalCharge',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 2.h),

          // ⭐ ALWAYS SHOW PAY BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _navigateToPayment,
              icon: Icon(Icons.payment, size: 20),
              label: Text(
                hasUnpaid ? 'Pay Service Charge' : 'Renew Service Charge',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: hasUnpaid ? Colors.orange.shade700 : Colors.green.shade700,
                padding: EdgeInsets.symmetric(vertical: 1.5.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          SizedBox(height: 1.h),
          Text(
            '₹18 per bed/unit × $totalBeds = ₹$totalCharge/month',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 9.sp,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> property, Map<String, dynamic> serviceStatus) {
    final monthlyCharge = _calculateMonthlyCharge(property);
    final dueDate = serviceStatus['dueDate'] as DateTime?;
    final statusColor = serviceStatus['color'] as Color;

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
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
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.home, color: AppTheme.primaryLight, size: 6.w),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property['title'] ?? 'Property',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      property['type'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),

          Divider(),
          SizedBox(height: 1.h),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Charge',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '₹$monthlyCharge/month',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    property['type'] ?? 'PG',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '${property['beds'] ?? property['bedrooms'] ?? property['bhk'] ?? '1'} Units',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (dueDate != null) ...[
            SizedBox(height: 1.5.h),
            Divider(),
            SizedBox(height: 1.h),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 4.w,
                  color: statusColor,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'Covered by all-properties payment',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          children: [
            Icon(Icons.home_outlined, size: 15.w, color: Colors.grey),
            SizedBox(height: 2.h),
            Text(
              'No Properties Yet',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 1.h),
            Text(
              'Add properties to see payment status',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}