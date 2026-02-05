import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/app_export.dart';
import '../../services/auth_service.dart';

class BookingRequestsScreen extends StatefulWidget {
  const BookingRequestsScreen({super.key});

  @override
  State<BookingRequestsScreen> createState() => _BookingRequestsScreenState();
}

class _BookingRequestsScreenState extends State<BookingRequestsScreen> {
  final AuthService _authService = AuthService();
  final String baseUrl = 'https://rentify-backend-cdaj.onrender.com';

  List<Map<String, dynamic>> bookingRequests = [];
  bool _isLoading = true;
  String? _errorMessage;
  String selectedFilter = "All";
  final List<String> filters = ["All", "Pending", "Approved", "Rejected"];

  @override
  void initState() {
    super.initState();
    _loadBookingRequests();
  }

  Future<void> _loadBookingRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentOwnerId = await _authService.getCurrentUserId();

      if (currentOwnerId == null || currentOwnerId.isEmpty) {
        throw Exception('User not logged in');
      }

      print('🔄 Loading booking requests for owner: $currentOwnerId');

      final response = await http.get(
        Uri.parse('$baseUrl/api/booking-requests/owner/$currentOwnerId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final requestsData = data['requests'] ?? data['bookingRequests'];

          if (requestsData != null && requestsData is List) {
            bookingRequests = List<Map<String, dynamic>>.from(requestsData);
            print('✅ Loaded ${bookingRequests.length} booking requests');
          } else {
            bookingRequests = [];
          }
        } else {
          bookingRequests = [];
        }
      } else if (response.statusCode == 404) {
        print('⚠️ No booking requests found');
        bookingRequests = [];
      } else {
        throw Exception('Failed to load booking requests: ${response.statusCode}');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('❌ Error loading booking requests: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        bookingRequests = [];
      });
    }
  }

  Future<void> _approveBooking(Map<String, dynamic> request, String roomNumber) async {
    try {
      print('🔄 Approving booking request: ${request['_id']}');
      print('🚪 Allocated room: $roomNumber');

      final response = await http.put(
        Uri.parse('$baseUrl/api/booking-requests/${request['_id']}/approve'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'roomNumber': roomNumber,
        }),
      ).timeout(const Duration(seconds: 30));

      print('📥 Approve Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Booking approved! Room $roomNumber allocated.'),
              backgroundColor: AppTheme.successLight,
            ),
          );

          // Reload booking requests
          await _loadBookingRequests();
        } else {
          throw Exception(data['message'] ?? 'Failed to approve');
        }
      } else {
        throw Exception('Failed to approve booking: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error approving booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectBooking(Map<String, dynamic> request, String reason) async {
    try {
      print('🔄 Rejecting booking request: ${request['_id']}');

      final response = await http.put(
        Uri.parse('$baseUrl/api/booking-requests/${request['_id']}/reject'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'reason': reason}),
      ).timeout(const Duration(seconds: 30));

      print('📥 Reject Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Booking request rejected'),
              backgroundColor: Colors.red,
            ),
          );

          // Reload booking requests
          await _loadBookingRequests();
        } else {
          throw Exception(data['message'] ?? 'Failed to reject');
        }
      } else {
        throw Exception('Failed to reject booking: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error rejecting booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredRequests = selectedFilter == "All"
        ? bookingRequests
        : bookingRequests.where((req) => 
            (req['status'] as String).toLowerCase() == selectedFilter.toLowerCase()
          ).toList();

    final pendingCount = bookingRequests.where((r) => r['status'] == 'pending').length;
    final approvedCount = bookingRequests.where((r) => r['status'] == 'approved').length;
    final rejectedCount = bookingRequests.where((r) => r['status'] == 'rejected').length;

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Booking Requests'),
        backgroundColor: AppTheme.primaryLight,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadBookingRequests,
          ),
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : _errorMessage != null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildStatsBar(pendingCount, approvedCount, rejectedCount),
                    _buildFilterChips(),
                    Expanded(
                      child: filteredRequests.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadBookingRequests,
                              color: AppTheme.primaryLight,
                              child: ListView.builder(
                                padding: EdgeInsets.all(4.w),
                                itemCount: filteredRequests.length,
                                itemBuilder: (context, index) {
                                  return _buildBookingCard(filteredRequests[index]);
                                },
                              ),
                            ),
                    ),
                  ],
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
          Text(
            'Error Loading Requests',
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
            onPressed: _loadBookingRequests,
            icon: Icon(Icons.refresh),
            label: Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(int pending, int approved, int rejected) {
    return Container(
      padding: EdgeInsets.all(4.w),
      color: AppTheme.primaryLight.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.notifications_active, pending.toString(), "Pending"),
          _buildStatItem(Icons.check_circle, approved.toString(), "Approved"),
          _buildStatItem(Icons.cancel, rejected.toString(), "Rejected"),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryLight, size: 8.w),
        SizedBox(height: 0.5.h),
        Text(
          value,
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTheme.lightTheme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 6.h,
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter;

          return Padding(
            padding: EdgeInsets.only(right: 2.w),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  selectedFilter = filter;
                });
              },
              selectedColor: AppTheme.primaryLight.withOpacity(0.2),
              checkmarkColor: AppTheme.primaryLight,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.primaryLight : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> request) {
    final status = (request['status'] as String).toLowerCase();
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
      default:
        statusColor = AppTheme.warningLight;
        statusText = 'PENDING';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 3.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == 'pending' ? AppTheme.warningLight.withOpacity(0.3) : Colors.grey.shade200,
          width: status == 'pending' ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property Image
          if (request['propertyImage'] != null)
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              child: CustomImageWidget(
                imageUrl: request['propertyImage'],
                height: 20.h,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

          Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tenant Info and Status
                Row(
                  children: [
                    Container(
                      width: 12.w,
                      height: 12.w,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person, color: AppTheme.primaryLight, size: 6.w),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request['tenantName'] ?? 'Tenant',
                            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Requested on ${request['requestDate'] ?? 'N/A'}',
                            style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryLight,
                            ),
                          ),
                        ],
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
                        style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 2.h),

                // Property Name
                Text(
                  request['propertyName'] ?? 'Property',
                  style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 1.h),

                // Contact Info
                if (request['tenantEmail'] != null) ...[
                  Row(
                    children: [
                      Icon(Icons.email, size: 4.w, color: AppTheme.primaryLight),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          request['tenantEmail'],
                          style: TextStyle(fontSize: 9.sp),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                ],

                if (request['tenantPhone'] != null) ...[
                  Row(
                    children: [
                      Icon(Icons.phone, size: 4.w, color: AppTheme.primaryLight),
                      SizedBox(width: 2.w),
                      Text(
                        request['tenantPhone'],
                        style: TextStyle(fontSize: 9.sp),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                ],

                // Move-in Date and Duration
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

// ⭐ NEW: Occupancy Type
                Row(
                  children: [
                    Icon(Icons.people, size: 4.w, color: AppTheme.primaryLight),
                    SizedBox(width: 2.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryLight.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${request['occupancyType'] ?? 'Not specified'} Occupancy',
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryLight,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 1.h),

                // Rent Amount
                Row(
                  children: [
                    Icon(Icons.attach_money, size: 4.w, color: AppTheme.successLight),
                    SizedBox(width: 2.w),
                    Text(
                      '₹${request['monthlyRent']}/month',
                      style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.successLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                // Additional Notes
                if (request['notes'] != null && (request['notes'] as String).isNotEmpty) ...[
                  SizedBox(height: 1.h),
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.message, size: 4.w, color: AppTheme.textSecondaryLight),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: Text(
                            request['notes'],
                            style: AppTheme.lightTheme.textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action Buttons - Only show for pending requests
                if (status == 'pending') ...[
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRejectDialog(request),
                          icon: Icon(Icons.close, size: 4.w),
                          label: Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red),
                            padding: EdgeInsets.symmetric(vertical: 1.5.h),
                          ),
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showApproveDialog(request),
                          icon: Icon(Icons.check, size: 4.w),
                          label: Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successLight,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 1.5.h),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Rejection Reason (if rejected)
                if (status == 'rejected' && request['rejectionReason'] != null) ...[
                  SizedBox(height: 2.h),
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.red, size: 4.w),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rejection Reason:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 9.sp,
                                ),
                              ),
                              Text(
                                request['rejectionReason'],
                                style: TextStyle(fontSize: 9.sp),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 1.h),

                // View Details Button
                TextButton(
                  onPressed: () => _viewBookingDetails(request),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('View Full Details'),
                      SizedBox(width: 1.w),
                      Icon(Icons.arrow_forward, size: 4.w),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 20.w, color: Colors.grey),
          SizedBox(height: 2.h),
          Text(
            selectedFilter == 'All' 
                ? 'No booking requests yet'
                : 'No $selectedFilter requests',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Booking requests will appear here',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter Requests'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: filters.map((filter) {
            return RadioListTile<String>(
              title: Text(filter),
              value: filter,
              groupValue: selectedFilter,
              onChanged: (value) {
                setState(() {
                  selectedFilter = value!;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showApproveDialog(Map<String, dynamic> request) {
    final TextEditingController roomNumberController = TextEditingController();
    final occupancyType = request['occupancyType'] ?? 'Not specified';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approve Booking & Allocate Room'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Approve booking request from ${request['tenantName']}?',
                style: TextStyle(fontSize: 11.sp),
              ),
              SizedBox(height: 2.h),

              // Show occupancy type
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryLight.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people, size: 5.w, color: AppTheme.primaryLight),
                    SizedBox(width: 2.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Requested Occupancy',
                          style: TextStyle(
                            fontSize: 9.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '$occupancyType Occupancy',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 2.h),

              // Room allocation
              Text(
                'Allocate Room Number *',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 10.sp,
                ),
              ),
              SizedBox(height: 1.h),
              TextField(
                controller: roomNumberController,
                decoration: InputDecoration(
                  hintText: 'e.g., 101, A-12, Room 5',
                  labelText: 'Room Number',
                  prefixIcon: Icon(Icons.meeting_room, color: AppTheme.primaryLight),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                'The tenant will be notified and can proceed with payment.',
                style: TextStyle(
                  fontSize: 9.sp,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (roomNumberController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter a room number'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _approveBooking(request, roomNumberController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successLight,
            ),
            child: Text('Approve & Allocate'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> request) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reject this booking request from ${request['tenantName']}?'),
            SizedBox(height: 2.h),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Rejection Reason (Optional)',
                hintText: 'Provide a reason for rejection...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectBooking(request, reasonController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _viewBookingDetails(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Booking Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Tenant', request['tenantName'] ?? 'N/A'),
              _buildDetailRow('Email', request['tenantEmail'] ?? 'N/A'),
              _buildDetailRow('Phone', request['tenantPhone'] ?? 'N/A'),
              Divider(height: 2.h),
              _buildDetailRow('Property', request['propertyName'] ?? 'N/A'),
              _buildDetailRow('Move-in Date', request['moveInDate'] ?? 'N/A'),
              _buildDetailRow('Duration', '${request['leaseDuration'] ?? 12} months'),
              _buildDetailRow('Monthly Rent', '₹${request['monthlyRent']}'),
              _buildDetailRow('Security Deposit', '₹${request['securityDeposit']}'),
              if (request['notes'] != null && (request['notes'] as String).isNotEmpty) ...[
                Divider(height: 2.h),
                Text(
                  'Additional Notes:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.sp),
                ),
                SizedBox(height: 0.5.h),
                Text(request['notes'], style: TextStyle(fontSize: 9.sp)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30.w,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 9.sp,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 9.sp),
            ),
          ),
        ],
      ),
    );
  }
}