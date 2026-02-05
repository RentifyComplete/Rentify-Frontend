// lib/presentation/home_dashboard/tenant_rent_payment_screen.dart
// Monthly rent payment system for tenants with integrated payment history
// ⭐ Tab view: Active Bookings | Payment History
// ⭐ FINAL VERSION - Connected to backend API

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_export.dart';
import '../../providers/user_provider.dart';
import 'tenant_rent_payment_dialog.dart';

class TenantRentPaymentScreen extends StatefulWidget {
  const TenantRentPaymentScreen({super.key});

  @override
  State<TenantRentPaymentScreen> createState() => _TenantRentPaymentScreenState();
}

class _TenantRentPaymentScreenState extends State<TenantRentPaymentScreen>
    with SingleTickerProviderStateMixin {
  final String baseUrl = 'https://rentify-backend-cdaj.onrender.com';

  late TabController _tabController;

  List<Map<String, dynamic>> _tenantBookings = [];
  List<Map<String, dynamic>> _paymentHistory = [];

  bool _isLoadingBookings = true;
  bool _isLoadingHistory = true;

  String? _bookingsError;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTenantBookings();
    _loadPaymentHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTenantBookings() async {
    setState(() {
      _isLoadingBookings = true;
      _bookingsError = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final tenantEmail = userProvider.userEmail;

      if (tenantEmail == null || tenantEmail.isEmpty) {
        throw Exception('User email not found');
      }

// ⭐ Convert to lowercase for case-insensitive matching
      final emailLower = tenantEmail.trim().toLowerCase();

      print('🔍 Loading bookings for tenant: $tenantEmail');

      final response = await http.get(
        Uri.parse('$baseUrl/api/bookings/tenant/$emailLower'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final bookings = (data['bookings'] as List).map((booking) {
            // Safe parsing of rentDueDate with proper null handling
            DateTime? rentDueDate;
            try {
              if (booking['rentDueDate'] != null && booking['rentDueDate'].toString().isNotEmpty) {
                rentDueDate = DateTime.parse(booking['rentDueDate'].toString());
                print('✅ Parsed rentDueDate: $rentDueDate for booking ${booking['_id']}');
              }
            } catch (e) {
              print('⚠️ Error parsing rentDueDate: $e');
            }

            // If no due date, set it to 1 month from now (fallback)
            if (rentDueDate == null) {
              rentDueDate = DateTime.now().add(const Duration(days: 30));
              print('⚠️ No rentDueDate found for booking ${booking['_id']}, using fallback: $rentDueDate');
            }

            // Calculate rent status
            final now = DateTime.now();
            final daysUntilDue = rentDueDate.difference(now).inDays;

            String status = 'active';
            if (daysUntilDue < 0) {
              status = 'overdue';
            } else if (daysUntilDue <= 7) {
              status = 'due_soon';
            }

            // Safe parsing of lastRentPayment
            DateTime? lastPaymentDate;
            try {
              if (booking['lastRentPayment'] != null && booking['lastRentPayment'].toString().isNotEmpty) {
                lastPaymentDate = DateTime.parse(booking['lastRentPayment'].toString());
              }
            } catch (e) {
              print('⚠️ Error parsing lastRentPayment: $e');
            }

            return {
              '_id': booking['_id'] ?? '',
              'propertyId': booking['propertyId'] ?? '',
              'propertyTitle': booking['propertyTitle'] ?? 'Property',
              'propertyAddress': booking['propertyAddress'] ?? 'Address not available',
              'monthlyRent': booking['monthlyRent'] ?? 0,
              'rentDueDate': rentDueDate,
              'lastPaymentDate': lastPaymentDate,
              'status': status,
              'daysUntilDue': daysUntilDue,
              'tenantName': booking['tenantName'] ?? 'Tenant',
              'tenantEmail': booking['tenantEmail'] ?? '',
              'tenantPhone': booking['tenantPhone'] ?? '',
            };
          }).toList();

          setState(() {
            _tenantBookings = bookings;
            _isLoadingBookings = false;
          });

          print('✅ Loaded ${bookings.length} bookings');
        } else {
          throw Exception(data['message'] ?? 'Failed to load bookings');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading bookings: $e');
      setState(() {
        _bookingsError = e.toString();
        _isLoadingBookings = false;
      });
    }
  }

  Future<void> _loadPaymentHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final tenantEmail = userProvider.userEmail;

      if (tenantEmail == null || tenantEmail.isEmpty) {
        throw Exception('User email not found');
      }

// ⭐ Convert to lowercase for case-insensitive matching
      final emailLower = tenantEmail.trim().toLowerCase();

      print('🔍 Loading payment history for: $tenantEmail');

      final response = await http.get(
        Uri.parse('$baseUrl/api/payments/tenant/$emailLower'),
      ).timeout(const Duration(seconds: 30));

      print('📥 Payment History Response: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          _paymentHistory = List<Map<String, dynamic>>.from(
              (data['payments'] ?? []).map((payment) {
                return {
                  'id': payment['_id'] ?? payment['id'] ?? 'N/A',
                  'amount': _parseToInt(payment['amount'], 0),
                  'date': payment['date'] ?? payment['paidOn'] ?? DateTime.now().toIso8601String(),
                  'status': payment['status'] ?? 'paid',
                  'method': payment['method'] ?? 'Razorpay',
                  'transactionId': payment['transactionId'] ?? payment['paymentId'] ?? '',
                  'month': payment['month'] ?? _formatMonth(payment['date'] ?? payment['paidOn']),
                  'paidOn': payment['paidOn'] ?? payment['date'],
                  'monthsPaid': _parseToInt(payment['monthsPaid'], 1),
                  'convenienceFee': _parseToInt(payment['convenienceFee'], 0),
                  'bookingId': payment['bookingId'],
                  'propertyId': payment['propertyId'],
                  'propertyTitle': payment['propertyTitle'] ?? 'Property',
                  'propertyAddress': payment['propertyAddress'] ?? '',
                };
              })
          );

          print('✅ Loaded ${_paymentHistory.length} payment records');
        } else {
          print('⚠️ API returned success: false - ${data['message']}');
          _paymentHistory = [];
        }
      } else if (response.statusCode == 404) {
        print('⚠️ Payment history endpoint not found (404)');
        _paymentHistory = [];
      } else {
        print('❌ Payment API error: ${response.statusCode}');
        _paymentHistory = [];
      }

      setState(() {
        _isLoadingHistory = false;
      });
    } catch (e) {
      print('❌ Error loading payment history: $e');
      setState(() {
        _historyError = e.toString();
        _isLoadingHistory = false;
        _paymentHistory = [];
      });
    }
  }

  // Helper methods
  int _parseToInt(dynamic value, int defaultValue) {
    try {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return defaultValue;
        return int.tryParse(trimmed) ?? defaultValue;
      }
      return defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  String _parseToString(dynamic value, String defaultValue) {
    try {
      if (value == null) return defaultValue;
      return value.toString();
    } catch (e) {
      return defaultValue;
    }
  }

  String _formatMonth(String? dateStr) {
    try {
      if (dateStr == null) return 'Unknown';
      final date = DateTime.parse(dateStr);
      return DateFormat('MMMM yyyy').format(date);
    } catch (e) {
      return 'Unknown';
    }
  }

  void _navigateToPayment(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (context) => TenantRentPaymentDialog(booking: booking),
    ).then((success) {
      if (success == true) {
        _loadTenantBookings();
        _loadPaymentHistory();
      }
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'overdue':
        return Colors.red;
      case 'due_soon':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _getStatusText(String status, int daysUntilDue) {
    switch (status) {
      case 'overdue':
        return 'Overdue by ${daysUntilDue.abs()} day(s)';
      case 'due_soon':
        return 'Due in $daysUntilDue day(s)';
      default:
        return 'Active';
    }
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
          'Rent Payments',
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryLight,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryLight,
          labelStyle: GoogleFonts.poppins(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            Tab(
              icon: Icon(Icons.home_work, size: 5.w),
              text: 'Active Bookings',
            ),
            Tab(
              icon: Icon(Icons.history, size: 5.w),
              text: 'Payment History',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  // ==================== BOOKINGS TAB ====================
  Widget _buildBookingsTab() {
    if (_isLoadingBookings) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryLight),
      );
    }

    if (_bookingsError != null) {
      return _buildErrorState(
        icon: Icons.error_outline,
        title: 'Failed to load bookings',
        message: _bookingsError!,
        onRetry: _loadTenantBookings,
      );
    }

    if (_tenantBookings.isEmpty) {
      return _buildEmptyState(
        icon: Icons.home_outlined,
        title: 'No active bookings',
        message: 'Book a property to see rent payments here',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTenantBookings,
      color: AppTheme.primaryLight,
      child: ListView.builder(
        padding: EdgeInsets.all(4.w),
        itemCount: _tenantBookings.length,
        itemBuilder: (context, index) {
          final booking = _tenantBookings[index];
          return _buildBookingCard(booking);
        },
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] as String;
    final statusColor = _getStatusColor(status);
    final daysUntilDue = booking['daysUntilDue'] as int;

    return Card(
      margin: EdgeInsets.only(bottom: 3.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: status == 'overdue' ? Colors.red.withOpacity(0.3) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Property title and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking['propertyTitle'],
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          booking['propertyAddress'],
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 3.w,
                      vertical: 0.8.h,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          status == 'overdue'
                              ? Icons.warning
                              : status == 'due_soon'
                              ? Icons.access_time
                              : Icons.check_circle,
                          color: statusColor,
                          size: 4.w,
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          _getStatusText(status, daysUntilDue),
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 2.h),
              Divider(color: Colors.grey.shade200),
              SizedBox(height: 2.h),

              // Rent details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoItem(
                    Icons.payments,
                    'Monthly Rent',
                    '₹${booking['monthlyRent']}',
                  ),
                  _buildInfoItem(
                    Icons.calendar_today,
                    'Due Date',
                    DateFormat('MMM dd, yyyy').format(booking['rentDueDate']),
                  ),
                ],
              ),

              if (booking['lastPaymentDate'] != null) ...[
                SizedBox(height: 1.5.h),
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 4.w),
                    SizedBox(width: 2.w),
                    Text(
                      'Last paid: ${DateFormat('MMM dd, yyyy').format(booking['lastPaymentDate'])}',
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],

              SizedBox(height: 2.h),

              // Pay button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _navigateToPayment(booking),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    padding: EdgeInsets.symmetric(vertical: 1.8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payment, color: Colors.white, size: 5.w),
                      SizedBox(width: 2.w),
                      Text(
                        status == 'overdue'
                            ? 'Pay Now (Overdue!)'
                            : 'Pay Rent',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 4.w, color: Colors.grey.shade600),
            SizedBox(width: 1.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.sp,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        SizedBox(height: 0.5.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ==================== PAYMENT HISTORY TAB ====================
  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryLight),
            SizedBox(height: 2.h),
            Text(
              'Loading payment history...',
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (_historyError != null) {
      return _buildErrorState(
        icon: Icons.error_outline,
        title: 'Failed to load payment history',
        message: _historyError!,
        onRetry: _loadPaymentHistory,
      );
    }

    if (_paymentHistory.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No Payment History',
        message: 'Your payment history will appear here once you start making rent payments',
      );
    }

    return Column(
      children: [
        _buildPaymentStats(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPaymentHistory,
            color: AppTheme.primaryLight,
            child: ListView.builder(
              padding: EdgeInsets.all(4.w),
              itemCount: _paymentHistory.length,
              itemBuilder: (context, index) {
                final payment = _paymentHistory[index];
                return _buildPaymentCard(payment);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStats() {
    if (_paymentHistory.isEmpty) return SizedBox.shrink();

    final totalPaid = _paymentHistory.fold<int>(0, (sum, p) => sum + (p['amount'] as int));
    final totalPayments = _paymentHistory.length;
    final totalConvenienceFees = _paymentHistory.fold<int>(0, (sum, p) => sum + (p['convenienceFee'] as int));

    return Container(
      margin: EdgeInsets.all(4.w),
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
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            Icons.payments,
            'Total Paid',
            '₹${NumberFormat('#,##,###').format(totalPaid)}',
          ),
          Container(width: 1, height: 40, color: Colors.white30),
          _buildStatItem(
            Icons.receipt_long,
            'Payments',
            '$totalPayments',
          ),
          Container(width: 1, height: 40, color: Colors.white30),
          _buildStatItem(
            Icons.account_balance_wallet,
            'Fees Paid',
            totalConvenienceFees > 0 ? '₹$totalConvenienceFees' : '₹0',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 5.w),
        SizedBox(height: 0.5.h),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 8.sp,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final isPaid = payment['status']?.toLowerCase() == 'paid';
    final hasConvenienceFee = payment['convenienceFee'] > 0;
    final monthsPaid = payment['monthsPaid'] as int;

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPaid ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
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
      child: InkWell(
        onTap: () => _showPaymentDetails(payment),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment['propertyTitle'] ?? payment['month'] ?? 'Rent Payment',
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryLight,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        if (payment['propertyAddress'] != null && payment['propertyAddress'].toString().isNotEmpty)
                          Text(
                            payment['propertyAddress'],
                            style: GoogleFonts.poppins(
                              fontSize: 9.sp,
                              color: AppTheme.textSecondaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(payment['status'] ?? 'Unknown'),
                ],
              ),
              SizedBox(height: 2.h),

              Divider(color: Colors.grey.shade200),
              SizedBox(height: 1.h),

              // Amount and duration
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount',
                        style: GoogleFonts.poppins(
                          fontSize: 9.sp,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '₹${NumberFormat('#,##,###').format(payment['amount'])}',
                        style: GoogleFonts.poppins(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: isPaid ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  if (monthsPaid > 1)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month, size: 3.w, color: Colors.blue),
                          SizedBox(width: 1.w),
                          Text(
                            '$monthsPaid Months',
                            style: GoogleFonts.poppins(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: 1.5.h),

              // Convenience Fee
              if (hasConvenienceFee)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 3.w, color: Colors.orange),
                      SizedBox(width: 1.w),
                      Text(
                        'Convenience Fee: ₹${payment['convenienceFee']}',
                        style: GoogleFonts.poppins(
                          fontSize: 9.sp,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: 2.h),

              // Payment Details (if paid)
              if (isPaid) ...[
                Row(
                  children: [
                    Icon(Icons.payment, size: 4.w, color: Colors.grey),
                    SizedBox(width: 2.w),
                    Text(
                      payment['method'],
                      style: GoogleFonts.poppins(
                        fontSize: 10.sp,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.check_circle, size: 4.w, color: Colors.green),
                    SizedBox(width: 1.w),
                    if (payment['paidOn'] != null)
                      Text(
                        'Paid on ${DateFormat('MMM dd').format(DateTime.parse(payment['paidOn']))}',
                        style: GoogleFonts.poppins(
                          fontSize: 9.sp,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ],

              // Transaction ID (if available)
              if (payment['transactionId'] != null && payment['transactionId'].toString().isNotEmpty) ...[
                SizedBox(height: 1.h),
                Row(
                  children: [
                    Icon(Icons.tag, size: 3.w, color: Colors.grey),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        'TXN: ${payment['transactionId']}',
                        style: GoogleFonts.poppins(
                          fontSize: 8.sp,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    IconData icon = Icons.info;
    String displayStatus = status;

    final statusLower = status.toLowerCase();
    if (statusLower == 'paid' || statusLower == 'success' || statusLower == 'completed') {
      color = Colors.green;
      icon = Icons.check_circle;
      displayStatus = 'Paid';
    } else if (statusLower == 'pending' || statusLower == 'processing') {
      color = Colors.orange;
      icon = Icons.schedule;
      displayStatus = 'Pending';
    } else if (statusLower == 'failed' || statusLower == 'cancelled') {
      color = Colors.red;
      icon = Icons.cancel;
      displayStatus = 'Failed';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 3.5.w, color: color),
          SizedBox(width: 1.w),
          Text(
            displayStatus,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 9.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDetails(Map<String, dynamic> payment) {
    final isPaid = payment['status']?.toLowerCase() == 'paid';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 12.w,
                height: 0.5.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 3.h),

            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment Details',
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStatusBadge(payment['status'] ?? 'Unknown'),
              ],
            ),
            SizedBox(height: 2.h),

            // Details
            _buildDetailRow('Payment ID', payment['id'] ?? 'N/A'),
            if (payment['propertyTitle'] != null)
              _buildDetailRow('Property', payment['propertyTitle']),
            if (payment['month'] != null)
              _buildDetailRow('Month', payment['month']),
            _buildDetailRow('Amount', '₹${NumberFormat('#,##,###').format(payment['amount'])}'),
            if (payment['monthsPaid'] != null && payment['monthsPaid'] > 1)
              _buildDetailRow('Duration', '${payment['monthsPaid']} months'),
            if (payment['convenienceFee'] != null && payment['convenienceFee'] > 0)
              _buildDetailRow('Convenience Fee', '₹${payment['convenienceFee']}', isHighlight: true),

            if (isPaid) ...[
              if (payment['paidOn'] != null)
                _buildDetailRow('Paid On', DateFormat('MMMM dd, yyyy').format(DateTime.parse(payment['paidOn']))),
              if (payment['method'] != null)
                _buildDetailRow('Payment Method', payment['method']),
              if (payment['transactionId'] != null && payment['transactionId'].toString().isNotEmpty)
                _buildDetailRow('Transaction ID', payment['transactionId']),
            ],

            SizedBox(height: 3.h),

            // Close Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                  padding: EdgeInsets.symmetric(vertical: 1.5.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Close', style: TextStyle(color: Colors.white)),
              ),
            ),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10.sp,
              color: Colors.grey,
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: isHighlight ? Colors.orange.shade700 : AppTheme.textPrimaryLight,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== UTILITY WIDGETS ====================
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20.w, color: Colors.grey.shade300),
          SizedBox(height: 3.h),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 1.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 10.sp,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState({
    required IconData icon,
    required String title,
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15.w, color: Colors.red),
          SizedBox(height: 2.h),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 1.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 10.sp,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 3.h),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh),
            label: Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 1.5.h),
            ),
          ),
        ],
      ),
    );
  }
}