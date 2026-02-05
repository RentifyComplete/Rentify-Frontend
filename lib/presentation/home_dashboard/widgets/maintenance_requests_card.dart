import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../core/app_export.dart';
import '../../../services/maintenance_service.dart';
import '../maintenance_screen.dart';
import '../all_maintenance_requests_screen.dart';

class MaintenanceRequestsCard extends StatefulWidget {
  final String? tenantId;
  final String? propertyId;

  const MaintenanceRequestsCard({
    super.key,
    this.tenantId,
    this.propertyId,
  });

  @override
  State<MaintenanceRequestsCard> createState() => _MaintenanceRequestsCardState();
}

class _MaintenanceRequestsCardState extends State<MaintenanceRequestsCard> {
  final MaintenanceService _maintenanceService = MaintenanceService();
  List<Map<String, dynamic>> _recentRequests = [];
  int _pendingCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaintenanceRequests();
  }

  Future<void> _loadMaintenanceRequests() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Fetch maintenance requests from database
      List<Map<String, dynamic>> allRequests = [];
      
      if (widget.tenantId != null) {
        // Fetch requests for specific tenant
        allRequests = await _maintenanceService.getMaintenanceRequestsByTenant(widget.tenantId!);
      } else if (widget.propertyId != null) {
        // Fetch requests for specific property
        allRequests = await _maintenanceService.getMaintenanceRequestsByProperty(widget.propertyId!);
      } else {
        // Fetch all requests (for admin/owner view)
        allRequests = await _maintenanceService.getAllMaintenanceRequests();
      }

      // Count pending requests
      final pendingCount = allRequests
          .where((req) => req['status']?.toString().toLowerCase() == 'pending')
          .length;

      // Get recent requests (max 2 for the card)
      final recentRequests = allRequests.take(2).toList();

      setState(() {
        _recentRequests = recentRequests;
        _pendingCount = pendingCount;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading maintenance requests: $e');
      setState(() {
        _recentRequests = [];
        _pendingCount = 0;
        _isLoading = false;
      });
    }
  }

  String _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'plumbing':
        return 'water_drop';
      case 'electrical':
        return 'bolt';
      case 'appliance':
        return 'kitchen';
      case 'carpentry':
        return 'carpenter';
      case 'painting':
        return 'format_paint';
      case 'ac':
      case 'cooling':
        return 'ac_unit';
      default:
        return 'build';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppTheme.successLight;
      case 'in progress':
        return Colors.blue;
      case 'pending':
        return AppTheme.warningLight;
      case 'cancelled':
        return Colors.red;
      default:
        return AppTheme.warningLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: AppTheme.warningLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: CustomIconWidget(
                      iconName: 'build',
                      color: AppTheme.warningLight,
                      size: 6.w,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Requests',
                        style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryLight,
                        ),
                      ),
                      _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 60,
                              child: Center(
                                child: SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.warningLight,
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              '$_pendingCount Pending',
                              style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.warningLight,
                              ),
                            ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MaintenanceRequestScreen(
                        tenantId: widget.tenantId,
                        propertyId: widget.propertyId,
                      ),
                    ),
                  );
                  
                  // Reload requests if a new one was created
                  if (result == true) {
                    _loadMaintenanceRequests();
                  }
                },
                icon: CustomIconWidget(
                  iconName: 'add',
                  color: Colors.white,
                  size: 4.w,
                ),
                label: Text('New'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),

          // Loading state
          if (_isLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: CircularProgressIndicator(),
              ),
            ),

          // Empty state
          if (!_isLoading && _recentRequests.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Column(
                  children: [
                    Icon(
                      Icons.build_circle_outlined,
                      size: 15.w,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'No maintenance requests yet',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11.sp,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'Create your first request by tapping "New"',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 9.sp,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // Recent requests list (only if not loading and has data)
          if (!_isLoading && _recentRequests.isNotEmpty)
            ..._recentRequests.map((request) => _buildRequestItem(context, request)).toList(),

          // View all button (only show if there are requests)
          if (!_isLoading && _recentRequests.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Center(
              child: TextButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllMaintenanceRequestsScreen(),
                    ),
                  );
                  
                  // Reload if needed
                  if (result == true) {
                    _loadMaintenanceRequests();
                  }
                },
                child: Text('View All Requests'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestItem(BuildContext context, Map<String, dynamic> request) {
    final status = request['status']?.toString() ?? 'Pending';
    final category = request['category']?.toString() ?? 'Other';
    final title = request['title']?.toString() ?? 'Untitled Request';
    final description = request['description']?.toString() ?? 'No description';
    final date = request['createdAt']?.toString() ?? 
                 request['date']?.toString() ?? 
                 DateTime.now().toString().split(' ')[0];
    
    final statusColor = _getStatusColor(status);
    final icon = _getCategoryIcon(category);

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: CustomIconWidget(
              iconName: icon,
              color: statusColor,
              size: 6.w,
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 0.5.h),
                Text(
                  description,
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 1.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 8.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      date.split(' ')[0], // Show only date part
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryLight,
                        fontSize: 8.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          CustomIconWidget(
            iconName: 'arrow_forward_ios',
            color: AppTheme.textSecondaryLight,
            size: 4.w,
          ),
        ],
      ),
    );
  }
}