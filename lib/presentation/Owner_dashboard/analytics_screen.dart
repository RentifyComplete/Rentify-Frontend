import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../core/app_export.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import 'package:mongo_dart/mongo_dart.dart' show where;

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final AuthService _authService = AuthService();
  
  String selectedPeriod = "This Month";
  final List<String> periods = ["This Week", "This Month", "This Year", "All Time"];
  
  bool _isLoading = true;
  Map<String, dynamic> analyticsData = {};
  List<Map<String, dynamic>> monthlyRevenue = [];
  List<Map<String, dynamic>> propertyPerformance = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  // ADDED: Format number method
  String _formatNumber(int number) {
    if (number >= 10000000) {
      return '${(number / 10000000).toStringAsFixed(2)}Cr';
    } else if (number >= 100000) {
      return '${(number / 100000).toStringAsFixed(2)}L';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(2)}K';
    }
    return number.toString();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current user ID
      final userId = await _authService.getCurrentUserId();
      
      if (userId == null) {
        setState(() {
          _errorMessage = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      print('📊 Loading analytics for user: $userId');

      // Map period to API format
      String periodKey = _getPeriodKey(selectedPeriod);

      // Fetch analytics with retry logic
      Map<String, dynamic> data;
      try {
        data = await _analyticsService.getOwnerAnalytics(
          userId,
          period: periodKey,
        );
      } catch (e) {
        print('❌ First attempt failed: $e');
        // Wait and retry once
        await Future.delayed(Duration(seconds: 1));
        data = await _analyticsService.getOwnerAnalytics(
          userId,
          period: periodKey,
        );
      }

      print('📊 Analytics data received: ${data.keys}');
      print('   Total Revenue: ${data['totalRevenue']}');
      print('   Average Rent: ${data['averageRent']}');
      print('   Total Tenants: ${data['totalTenants']}');

      setState(() {
        analyticsData = data;

        // ⭐ DEBUG: Print all analytics data
        print('📊 ========== ANALYTICS DATA DEBUG ==========');
        print('Total Revenue: ${data['totalRevenue']} (${data['totalRevenue'].runtimeType})');
        print('Monthly Collection: ${data['monthlyCollection']} (${data['monthlyCollection'].runtimeType})');
        print('Monthly Dues: ${data['monthlyDues']} (${data['monthlyDues'].runtimeType})');
        print('Total Properties: ${data['totalProperties']}');
        print('Total Tenants: ${data['totalTenants']}');
        print('==========================================');

        monthlyRevenue = List<Map<String, dynamic>>.from(
            data['monthlyRevenue'] ?? []
        );
        propertyPerformance = List<Map<String, dynamic>>.from(
            data['propertyPerformance'] ?? []
        );
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading analytics: $e');
      setState(() {
        _errorMessage = 'Failed to load analytics. Please try again.';
        _isLoading = false;
      });
    }
  }

  String _getPeriodKey(String period) {
    switch (period) {
      case "This Week":
        return "week";
      case "This Month":
        return "month";
      case "This Year":
        return "year";
      case "All Time":
        return "all";
      default:
        return "month";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Property Analytics'),
        backgroundColor: AppTheme.primaryLight,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.date_range),
            onSelected: (value) {
              setState(() {
                selectedPeriod = value;
              });
              _loadAnalytics();
            },
            itemBuilder: (context) => periods.map((period) {
              return PopupMenuItem<String>(
                value: period,
                child: Text(period),
              );
            }).toList(),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 60, color: Colors.red),
                      SizedBox(height: 2.h),
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      SizedBox(height: 2.h),
                      ElevatedButton(
                        onPressed: _loadAnalytics,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAnalytics,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPeriodSelector(),
                        _buildRevenueOverview(),
                        SizedBox(height: 2.h),
                        _buildKeyMetrics(),
                        SizedBox(height: 3.h),
                        _buildTenantInsights(),
                        SizedBox(height: 5.h),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: EdgeInsets.all(4.w),
      color: AppTheme.primaryLight.withOpacity(0.05),
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: AppTheme.primaryLight),
          SizedBox(width: 2.w),
          Text(
            'Period: $selectedPeriod',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Spacer(),
          IconButton(
            icon: Icon(Icons.file_download, color: AppTheme.primaryLight),
            onPressed: _downloadReport,
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueOverview() {
    // Helper function to extract number
    int _extractAmount(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        final cleaned = value.replaceAll(RegExp(r'[₹,\s]'), '');
        return int.tryParse(cleaned) ?? 0;
      }
      return 0;
    }

    final totalRevenue = _extractAmount(analyticsData['totalRevenue']);
    final revenueDisplay = totalRevenue > 0
        ? '₹${_formatNumber(totalRevenue)}'
        : '₹0';

    return Container(
      margin: EdgeInsets.all(4.w),
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryLight, AppTheme.primaryLight.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryLight.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
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
                'Total Revenue',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14.sp,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: _getGrowthColor(analyticsData['revenueGrowth'] ?? '+0%'),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  analyticsData['revenueGrowth'] ?? '+0%',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            revenueDisplay,
            style: TextStyle(
              color: Colors.white,
              fontSize: 32.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 1.h),
          Row(
            children: [
              Icon(
                _isGrowthPositive(analyticsData['revenueGrowth'] ?? '+0%')
                    ? Icons.trending_up
                    : Icons.trending_down,
                color: Colors.white,
                size: 5.w,
              ),
              SizedBox(width: 2.w),
              Text(
                'Compared to previous period',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getGrowthColor(String growth) {
    if (growth.startsWith('+')) {
      return AppTheme.successLight;
    } else if (growth.startsWith('-')) {
      return Colors.red;
    }
    return Colors.grey;
  }

  bool _isGrowthPositive(String growth) {
    return growth.startsWith('+');
  }

  // Replace the _buildKeyMetrics() method (around line 270) with this:

  Widget _buildKeyMetrics() {
    // Helper function to extract number from formatted string like "₹1,23,456"
    int _extractAmount(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        // Remove ₹, commas, and whitespace
        final cleaned = value.replaceAll(RegExp(r'[₹,\s]'), '');
        return int.tryParse(cleaned) ?? 0;
      }
      return 0;
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: GridView.count(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 3.w,
        mainAxisSpacing: 2.h,
        childAspectRatio: 1.5,
        children: [
          _buildMetricCard(
            "Properties",
            (analyticsData['totalProperties'] ?? 0).toString(),
            Icons.home_work,
            AppTheme.primaryLight,
          ),
          _buildMetricCard(
            "Tenants",
            (analyticsData['totalTenants'] ?? 0).toString(),
            Icons.person,
            Colors.purple,
          ),
          _buildMetricCard(
            "Monthly Collection",
            '₹${_formatNumber(_extractAmount(analyticsData['monthlyCollection']))}',
            Icons.trending_up,
            AppTheme.successLight,
          ),
          _buildMetricCard(
            "Monthly Dues",
            '₹${_formatNumber(_extractAmount(analyticsData['monthlyDues']))}',
            Icons.payment,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 7.w),
          SizedBox(height: 0.5.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          SizedBox(height: 0.3.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    if (monthlyRevenue.isEmpty) {
      return SizedBox.shrink();
    }

    // Find max revenue for scaling
    double maxRevenue = monthlyRevenue
        .map((data) => (data['revenue'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);
    
    if (maxRevenue == 0) maxRevenue = 1000; // Prevent division by zero

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue Trend',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 25.h,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: monthlyRevenue.map((data) {
                      double revenue = (data['revenue'] as num).toDouble();
                      double height = (revenue / maxRevenue) * 20.h;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '₹${(revenue / 1000).toInt()}k',
                            style: TextStyle(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryLight,
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Container(
                            width: 10.w,
                            height: height > 0 ? height : 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryLight,
                                  AppTheme.primaryLight.withOpacity(0.6),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            data['month'] ?? '',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: AppTheme.textSecondaryLight,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccupancySection() {
    final occupied = analyticsData['occupiedUnits'] ?? 0;
    final vacant = analyticsData['vacantUnits'] ?? 0;
    final total = occupied + vacant;
    final occupancyRate = (analyticsData['occupancyRate'] ?? 0).toDouble();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Occupancy Overview',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildOccupancyItem("Total", total.toString(), Icons.home_work, Colors.blue),
                    _buildOccupancyItem("Occupied", occupied.toString(), Icons.check_circle, AppTheme.successLight),
                    _buildOccupancyItem("Vacant", vacant.toString(), Icons.cancel, Colors.orange),
                  ],
                ),
                SizedBox(height: 3.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: total > 0 ? occupancyRate / 100 : 0,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.successLight),
                    minHeight: 2.h,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  '${occupancyRate.toInt()}% Occupancy Rate',
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccupancyItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 10.w),
        SizedBox(height: 1.h),
        Text(
          value,
          style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTheme.lightTheme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildPropertyPerformance() {
    if (propertyPerformance.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Text('No property data available'),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Property Performance',
                style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to all properties
                },
                child: Text('View All'),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          ...propertyPerformance.take(4).map((property) => _buildPropertyCard(property)).toList(),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> property) {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  property['name'] ?? 'Unnamed Property',
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 4.w),
                  SizedBox(width: 1.w),
                  Text(
                    property['rating']?.toString() ?? '0.0',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revenue',
                    style: AppTheme.lightTheme.textTheme.bodySmall,
                  ),
                  Text(
                    property['revenue'] ?? '₹0',
                    style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.successLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Occupancy',
                    style: AppTheme.lightTheme.textTheme.bodySmall,
                  ),
                  Text(
                    '${property['occupancy'] ?? 0}%',
                    style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                      color: (property['occupancy'] ?? 0) == 100 
                          ? AppTheme.successLight 
                          : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTenantInsights() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tenant Insights',
                style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if ((analyticsData['totalTenants'] ?? 0) > 0)
                TextButton(
                  onPressed: _showAllTenants,
                  child: Text('View All'),
                ),
            ],
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  "New Tenants",
                  (analyticsData['newTenants'] ?? 0).toString(),
                  Icons.person_add,
                  AppTheme.successLight,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: _buildInsightCard(
                  "Pending Payments",
                  (analyticsData['pendingPayments'] ?? 0).toString(),
                  Icons.payment,
                  AppTheme.warningLight,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  "Leases Expiring",
                  (analyticsData['leasesExpiring'] ?? 0).toString(),
                  Icons.event_busy,
                  Colors.orange,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: _buildInsightCard(
                  "Maintenance",
                  (analyticsData['maintenanceRequests'] ?? 0).toString(),
                  Icons.build,
                  Colors.blue,
                ),
              ),
            ],
          ),
          
          // Show tenant preview if there are tenants
          if ((analyticsData['totalTenants'] ?? 0) > 0) ...[
            SizedBox(height: 3.h),
            _buildTenantPreview(),
          ],
        ],
      ),
    );
  }

  Widget _buildTenantPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Tenants',
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchRecentTenants(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(2.h),
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryLight,
                    strokeWidth: 2,
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'No tenant data available',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              );
            }

            final tenants = snapshot.data!.take(3).toList();
            return Column(
              children: tenants.map((tenant) => _buildTenantPreviewCard(tenant)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTenantPreviewCard(Map<String, dynamic> tenant) {
    final rent = tenant['monthlyRent'] ?? tenant['rent'] ?? 0;
    final name = tenant['tenantName'] ?? tenant['name'] ?? 'Tenant';
    final property = tenant['propertyTitle'] ?? 'Property';
    final dues = (tenant['pendingDues'] ?? 0).toDouble();

    return Container(
      margin: EdgeInsets.only(bottom: 1.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 10.w,
            height: 10.w,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person,
              color: AppTheme.primaryLight,
              size: 5.w,
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  property,
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${_formatNumber(rent.toInt())}',
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.successLight,
                ),
              ),
              Text(
                '/month',
                style: TextStyle(
                  fontSize: 8.sp,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          if (dues > 0) ...[
            SizedBox(width: 2.w),
            Container(
              padding: EdgeInsets.all(1.w),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.warning,
                color: Colors.red,
                size: 4.w,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // FIXED: Changed to use public method/getter instead of private _mongoService
  Future<List<Map<String, dynamic>>> _fetchRecentTenants() async {
    try {
      final db = await _analyticsService.getDatabase();
      final bookings = db.collection('bookings');
      final properties = db.collection('properties');

      final userId = await _authService.getCurrentUserId();
      if (userId == null) return [];

      print('🔍 Fetching tenants for owner: $userId');

      // Get properties for owner
      final ownerProperties = await properties
          .find(where.eq('ownerId', userId))
          .toList();

      print('📊 Found ${ownerProperties.length} properties');

      if (ownerProperties.isEmpty) return [];

      final propertyIds = ownerProperties.map((p) => p['_id'].toString()).toList();
      print('📊 Property IDs: $propertyIds');

      // Try to get bookings by ownerId first (if booking has ownerId field)
      List<Map<String, dynamic>> tenantBookings = await bookings
          .find(where.eq('ownerId', userId))
          .toList();

      print('📊 Found ${tenantBookings.length} bookings by ownerId');

      // If no bookings found by ownerId, try by propertyId
      if (tenantBookings.isEmpty) {
        tenantBookings = await bookings
            .find(where.oneFrom('propertyId', propertyIds))
            .toList();
        print('📊 Found ${tenantBookings.length} bookings by propertyId');
      }

      // Filter active/confirmed bookings and enrich with property info
      final enrichedTenants = <Map<String, dynamic>>[];
      
      for (var booking in tenantBookings) {
        print('   Processing booking: ${booking['_id']} - Status: ${booking['status']}');
        
        if (booking['status'] == 'confirmed' || booking['status'] == 'active') {
          // Find matching property
          final property = ownerProperties.firstWhere(
            (p) => p['_id'].toString() == booking['propertyId'].toString(),
            orElse: () => ownerProperties.isNotEmpty ? ownerProperties.first : {},
          );

          enrichedTenants.add({
            ...booking,
            'propertyTitle': property['title'] ?? 'Property',
            'rent': booking['monthlyRent'] ?? booking['totalAmount'] ?? 0,
          });
          
          print('   ✓ Added tenant: ${booking['tenantName']}');
        }
      }

      print('📊 Total enriched tenants: ${enrichedTenants.length}');

      // Sort by most recent
      enrichedTenants.sort((a, b) {
        final aDate = DateTime.tryParse(a['bookingDate']?.toString() ?? '') ?? DateTime.now();
        final bDate = DateTime.tryParse(b['bookingDate']?.toString() ?? '') ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      return enrichedTenants;
    } catch (e) {
      print('❌ Error fetching recent tenants: $e');
      return [];
    }
  }

  void _showAllTenants() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: EdgeInsets.all(4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 12.w,
                  height: 0.5.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 2.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Tenants',
                    style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchRecentTenants(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Text('No tenants found'),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        return _buildTenantDetailCard(snapshot.data![index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTenantDetailCard(Map<String, dynamic> tenant) {
    final rent = tenant['monthlyRent'] ?? tenant['rent'] ?? 0;
    final name = tenant['tenantName'] ?? tenant['name'] ?? 'Tenant';
    final email = tenant['tenantEmail'] ?? tenant['email'] ?? '';
    final phone = tenant['tenantPhone'] ?? tenant['phone'] ?? '';
    final property = tenant['propertyTitle'] ?? 'Property';
    final dues = (tenant['pendingDues'] ?? 0).toDouble();
    final status = tenant['status'] ?? 'active';

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      name,
                      style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '₹${_formatNumber(rent.toInt())}/month',
                      style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.primaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: status == 'active' 
                      ? Colors.green.shade50 
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w600,
                    color: status == 'active' ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.home, size: 4.w, color: AppTheme.primaryLight),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    property,
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (email.isNotEmpty || phone.isNotEmpty) ...[
            SizedBox(height: 1.h),
            if (email.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.email, size: 4.w, color: Colors.grey.shade600),
                  SizedBox(width: 2.w),
                  Text(
                    email,
                    style: TextStyle(fontSize: 9.sp, color: Colors.grey.shade600),
                  ),
                ],
              ),
            if (phone.isNotEmpty) ...[
              SizedBox(height: 0.5.h),
              Row(
                children: [
                  Icon(Icons.phone, size: 4.w, color: Colors.grey.shade600),
                  SizedBox(width: 2.w),
                  Text(
                    phone,
                    style: TextStyle(fontSize: 9.sp, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ],

          if (dues > 0) ...[
            SizedBox(height: 1.h),
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 4.w),
                  SizedBox(width: 2.w),
                  Text(
                    'Pending Dues: ₹${_formatNumber(dues.toInt())}',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
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

  Widget _buildInsightCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 7.w),
          SizedBox(height: 0.5.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          SizedBox(height: 0.3.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: AppTheme.lightTheme.textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Summary',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildFinancialRow(
                  "Total Revenue", 
                  analyticsData['totalRevenue'] ?? '₹0', 
                  AppTheme.successLight
                ),
                Divider(height: 3.h),
                _buildFinancialRow(
                  "Average Rent", 
                  analyticsData['averageRent'] ?? '₹0', 
                  Colors.blue
                ),
                Divider(height: 3.h),
                _buildFinancialRow(
                  "Properties", 
                  "${analyticsData['totalProperties'] ?? 0} units", 
                  AppTheme.primaryLight
                ),
                Divider(height: 3.h),
                _buildFinancialRow(
                  "Growth", 
                  analyticsData['revenueGrowth'] ?? '+0%', 
                  _getGrowthColor(analyticsData['revenueGrowth'] ?? '+0%')
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.lightTheme.textTheme.bodyLarge,
        ),
        Text(
          value,
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _downloadReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading analytics report...'),
        backgroundColor: AppTheme.primaryLight,
      ),
    );
  }
}