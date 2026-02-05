// lib/presentation/Owner_dashboard/widgets/maintenance_requests_card.dart

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../core/app_export.dart';
import '../../../services/maintenance_service.dart';
import '../../../services/auth_service.dart';
import 'package:intl/intl.dart';
import '../maintenance_screen.dart'; // Navigate to the maintenance screen instead

class MaintenanceRequestsCard extends StatefulWidget {
  const MaintenanceRequestsCard({Key? key}) : super(key: key);

  @override
  State<MaintenanceRequestsCard> createState() => _MaintenanceRequestsCardState();
}

class _MaintenanceRequestsCardState extends State<MaintenanceRequestsCard> {
  final MaintenanceService _maintenanceService = MaintenanceService();
  final AuthService _authService = AuthService();
  
  List<Map<String, dynamic>> _recentRequests = [];
  bool _isLoading = true;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadRecentRequests();
  }

  Future<void> _loadRecentRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = await _authService.getCurrentUserId();
      
      if (userId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get all maintenance requests for the user's property
      final requests = await _maintenanceService.getMaintenanceRequestsByProperty(userId);
      
      // Sort by date and get recent 3
      requests.sort((a, b) {
        DateTime dateA = a['createdAt'] ?? DateTime.now();
        DateTime dateB = b['createdAt'] ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      final recentRequests = requests.take(3).toList();
      final pendingCount = requests.where((r) => r['status'] == 'Pending').length;

      setState(() {
        _recentRequests = recentRequests;
        _pendingCount = pendingCount;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading maintenance requests: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'In Progress':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'Plumbing':
        return Icons.plumbing;
      case 'Electrical':
        return Icons.electrical_services;
      case 'Appliance':
        return Icons.kitchen;
      case 'Carpentry':
        return Icons.carpenter;
      case 'Painting':
        return Icons.format_paint;
      default:
        return Icons.build;
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'Plumbing':
        return Colors.blue;
      case 'Electrical':
        return Colors.yellow.shade700;
      case 'Appliance':
        return Colors.green;
      case 'Carpentry':
        return Colors.brown;
      case 'Painting':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 4.w),
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.build_circle_outlined,
                    color: AppTheme.primaryLight,
                    size: 6.w,
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    'Maintenance Requests',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              if (_pendingCount > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_pendingCount Pending',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 2.h),

          // Content
          if (_isLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: CircularProgressIndicator(
                  color: AppTheme.primaryLight,
                ),
              ),
            )
          else if (_recentRequests.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 12.w,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'No maintenance requests',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _recentRequests.map((request) {
                return Container(
                  margin: EdgeInsets.only(bottom: 2.h),
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      // Category Icon
                      Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(request['category'])
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getCategoryIcon(request['category']),
                          color: _getCategoryColor(request['category']),
                          size: 5.w,
                        ),
                      ),
                      SizedBox(width: 3.w),

                      // Request Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request['title'] ?? 'No Title',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 0.5.h),
                            Row(
                              children: [
                                Text(
                                  request['category'] ?? 'General',
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  ' • ',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                Text(
                                  request['createdAt'] != null
                                      ? DateFormat('MMM dd').format(
                                          request['createdAt'])
                                      : 'N/A',
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Status Badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 2.w,
                          vertical: 0.5.h,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(request['status'] ?? 'Pending')
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _getStatusColor(request['status'] ?? 'Pending'),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          request['status'] ?? 'Pending',
                          style: TextStyle(
                            fontSize: 8.sp,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(request['status'] ?? 'Pending'),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          // View All Button
          SizedBox(height: 1.h),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MaintenanceScreen(),
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 1.5.h),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View All Requests',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryLight,
                      ),
                    ),
                    SizedBox(width: 1.w),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 3.w,
                      color: AppTheme.primaryLight,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}