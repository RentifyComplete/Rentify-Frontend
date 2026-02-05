import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../core/app_export.dart';
import '../../services/maintenance_service.dart';

class AllMaintenanceRequestsScreen extends StatefulWidget {
  final String? tenantId;
  final String? propertyId;

  const AllMaintenanceRequestsScreen({
    Key? key,
    this.tenantId,
    this.propertyId,
  }) : super(key: key);

  @override
  State<AllMaintenanceRequestsScreen> createState() => _AllMaintenanceRequestsScreenState();
}

class _AllMaintenanceRequestsScreenState extends State<AllMaintenanceRequestsScreen> {
  final MaintenanceService _maintenanceService = MaintenanceService();
  List<Map<String, dynamic>> _allRequests = [];
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

      List<Map<String, dynamic>> allRequests = [];
      
      if (widget.tenantId != null) {
        allRequests = await _maintenanceService.getMaintenanceRequestsByTenant(widget.tenantId!);
      } else if (widget.propertyId != null) {
        allRequests = await _maintenanceService.getMaintenanceRequestsByProperty(widget.propertyId!);
      } else {
        allRequests = await _maintenanceService.getAllMaintenanceRequests();
      }

      setState(() {
        _allRequests = allRequests;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading maintenance requests: $e');
      setState(() {
        _allRequests = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRequest(String requestId, int index) async {
    try {
      print('🗑️ Attempting to delete request with ID: $requestId');
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: AppTheme.primaryLight,
                ),
                SizedBox(height: 2.h),
                Text(
                  'Deleting request...',
                  style: AppTheme.lightTheme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );

      // Delete from database
      final success = await _maintenanceService.deleteMaintenanceRequest(requestId);
      
      print('🗑️ Delete operation result: $success');

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (success) {
        print('✅ Request deleted successfully, updating UI');
        // Remove from local list
        setState(() {
          _allRequests.removeAt(index);
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'check_circle',
                    color: Colors.white,
                    size: 5.w,
                  ),
                  SizedBox(width: 2.w),
                  Text('Request deleted successfully'),
                ],
              ),
              backgroundColor: AppTheme.successLight,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('❌ Delete operation returned false');
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'error',
                    color: Colors.white,
                    size: 5.w,
                  ),
                  SizedBox(width: 2.w),
                  Text('Failed to delete request'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Exception during delete: $e');
      // Close loading dialog if still open
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context, String title) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CustomIconWidget(
                  iconName: 'delete',
                  color: Colors.red,
                  size: 6.w,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Text(
                  'Delete Request',
                  style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this request?',
                style: AppTheme.lightTheme.textTheme.bodyMedium,
              ),
              SizedBox(height: 1.h),
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"$title"',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textSecondaryLight,
                  ),
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                'This action cannot be undone.',
                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppTheme.textSecondaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomIconWidget(
                    iconName: 'delete',
                    color: Colors.white,
                    size: 4.w,
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    'Delete',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'All Maintenance Requests',
          style: AppTheme.lightTheme.textTheme.titleLarge,
        ),
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: CustomIconWidget(
            iconName: 'arrow_back',
            size: 6.w,
          ),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.build_circle_outlined,
                        size: 20.w,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'No maintenance requests',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMaintenanceRequests,
                  child: ListView.builder(
                    padding: EdgeInsets.all(4.w),
                    itemCount: _allRequests.length,
                    itemBuilder: (context, index) {
                      final request = _allRequests[index];
                      return _buildRequestItem(context, request, index);
                    },
                  ),
                ),
    );
  }

  Widget _buildRequestItem(BuildContext context, Map<String, dynamic> request, int index) {
    final status = request['status']?.toString() ?? 'Pending';
    final category = request['category']?.toString() ?? 'Other';
    final title = request['title']?.toString() ?? 'Untitled Request';
    final description = request['description']?.toString() ?? 'No description';
    final createdAt = request['createdAt'];
    
    // Format date properly
    String date;
    if (createdAt is DateTime) {
      date = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
    } else if (createdAt != null) {
      date = createdAt.toString().split(' ')[0];
    } else {
      date = DateTime.now().toString().split(' ')[0];
    }
    
    // Get MongoDB ObjectId as hex string
    // MongoDB returns ObjectId like: ObjectId("692226a0da9ef7b0eb000000")
    // We need to extract just the hex part: "692226a0da9ef7b0eb000000"
    String requestId = '';
    final id = request['_id'];
    if (id != null) {
      final idStr = id.toString();
      // Extract hex string from ObjectId("...")
      if (idStr.contains('ObjectId("') && idStr.contains('")')) {
        requestId = idStr.substring(idStr.indexOf('"') + 1, idStr.lastIndexOf('"'));
      } else {
        requestId = idStr;
      }
    }
    
    final statusColor = _getStatusColor(status);
    final icon = _getCategoryIcon(category);

    return Dismissible(
      key: Key(requestId.isEmpty ? 'request_$index' : requestId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(context, title);
      },
      onDismissed: (direction) {
        _deleteRequest(requestId, index);
      },
      background: Container(
        margin: EdgeInsets.only(bottom: 2.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade400, Colors.red.shade600],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 5.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'delete',
              color: Colors.white,
              size: 7.w,
            ),
            SizedBox(height: 0.5.h),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 9.sp,
              ),
            ),
          ],
        ),
      ),
      child: Card(
        margin: EdgeInsets.only(bottom: 2.h),
        elevation: 0,
        color: AppTheme.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () {
            // Navigate to request details
            // Navigator.push(...);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(3.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(2.5.w),
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
                            padding: EdgeInsets.symmetric(
                              horizontal: 2.w,
                              vertical: 0.5.h,
                            ),
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
                          CustomIconWidget(
                            iconName: 'calendar_today',
                            size: 3.w,
                            color: AppTheme.textSecondaryLight,
                          ),
                          SizedBox(width: 1.w),
                          Text(
                            date.split(' ')[0],
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
          ),
        ),
      ),
    );
  }
}