import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/app_export.dart';

class AllNoticesScreen extends StatefulWidget {
  const AllNoticesScreen({Key? key}) : super(key: key);

  @override
  State<AllNoticesScreen> createState() => _AllNoticesScreenState();
}

class _AllNoticesScreenState extends State<AllNoticesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'All';

  // Mock notices data - Replace with actual API calls
  final List<Map<String, dynamic>> _allNotices = [
    {
      'id': 1,
      'title': 'Water Supply Interruption',
      'message': 'Water supply will be interrupted on Nov 20 from 10 AM to 2 PM for maintenance work. Please store water accordingly.',
      'date': '2025-11-16',
      'category': 'Maintenance',
      'priority': 'High',
      'isUnread': true,
      'icon': 'water_drop',
      'postedBy': 'Building Management',
    },
    {
      'id': 2,
      'title': 'Rent Payment Reminder',
      'message': 'This is a friendly reminder that your rent payment for December is due on Dec 5, 2025. Please ensure timely payment to avoid late fees.',
      'date': '2025-11-15',
      'category': 'Payment',
      'priority': 'High',
      'isUnread': true,
      'icon': 'payment',
      'postedBy': 'Accounts Department',
    },
    {
      'id': 3,
      'title': 'Community Diwali Celebration',
      'message': 'Join us for the annual Diwali celebration on Nov 25 at 6 PM in the community hall. Cultural performances and dinner will be provided.',
      'date': '2025-11-14',
      'category': 'Event',
      'priority': 'Low',
      'isUnread': false,
      'icon': 'celebration',
      'postedBy': 'Residents Association',
    },
    {
      'id': 4,
      'title': 'Parking Area Cleaning',
      'message': 'The parking area will be cleaned on Nov 18. Please move your vehicles to the temporary parking zone between 8 AM - 12 PM.',
      'date': '2025-11-13',
      'category': 'Maintenance',
      'priority': 'Medium',
      'isUnread': false,
      'icon': 'local_parking',
      'postedBy': 'Building Management',
    },
    {
      'id': 5,
      'title': 'New Security Guidelines',
      'message': 'Updated security protocols are now in effect. All residents must display visitor passes for guests. Please collect your passes from the security office.',
      'date': '2025-11-12',
      'category': 'Security',
      'priority': 'High',
      'isUnread': false,
      'icon': 'security',
      'postedBy': 'Security Team',
    },
    {
      'id': 6,
      'title': 'Gym Maintenance Schedule',
      'message': 'The gym will be closed for equipment maintenance from Nov 21-23. We apologize for the inconvenience.',
      'date': '2025-11-11',
      'category': 'Amenity',
      'priority': 'Low',
      'isUnread': false,
      'icon': 'fitness_center',
      'postedBy': 'Amenities Manager',
    },
    {
      'id': 7,
      'title': 'Electricity Bill Increase Notice',
      'message': 'Please note that electricity charges have been revised by the utility company. New rates will be effective from December 2025.',
      'date': '2025-11-10',
      'category': 'Payment',
      'priority': 'Medium',
      'isUnread': false,
      'icon': 'bolt',
      'postedBy': 'Accounts Department',
    },
    {
      'id': 8,
      'title': 'Pet Policy Update',
      'message': 'New pet registration requirements are now mandatory. All pet owners must register with management by Nov 30. Registration forms available at the office.',
      'date': '2025-11-08',
      'category': 'Policy',
      'priority': 'Medium',
      'isUnread': false,
      'icon': 'pets',
      'postedBy': 'Building Management',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredNotices(String filter) {
    if (filter == 'Unread') {
      return _allNotices.where((notice) => notice['isUnread'] == true).toList();
    }
    return _allNotices;
  }

  List<Map<String, dynamic>> _getNoticesByCategory() {
    if (_selectedCategory == 'All') return _getFilteredNotices(_tabController.index == 1 ? 'Unread' : 'All');

    final filtered = _getFilteredNotices(_tabController.index == 1 ? 'Unread' : 'All');
    return filtered.where((notice) => notice['category'] == _selectedCategory).toList();
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Maintenance':
        return Colors.orange;
      case 'Payment':
        return Colors.red;
      case 'Event':
        return Colors.purple;
      case 'Security':
        return Colors.blue;
      case 'Amenity':
        return Colors.green;
      case 'Policy':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.lightTheme;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimaryLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'All Notices',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: primaryColor),
            onSelected: (value) {
              setState(() => _selectedCategory = value);
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'All', child: Text('All Categories')),
              PopupMenuItem(value: 'Maintenance', child: Text('Maintenance')),
              PopupMenuItem(value: 'Payment', child: Text('Payment')),
              PopupMenuItem(value: 'Event', child: Text('Events')),
              PopupMenuItem(value: 'Security', child: Text('Security')),
              PopupMenuItem(value: 'Amenity', child: Text('Amenities')),
              PopupMenuItem(value: 'Policy', child: Text('Policy')),
            ],
          ),
          IconButton(
            icon: Icon(Icons.mark_email_read, color: primaryColor),
            onPressed: _markAllAsRead,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) => setState(() {}),
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          labelStyle: GoogleFonts.poppins(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            Tab(text: 'All (${_getFilteredNotices('All').length})'),
            Tab(text: 'Unread (${_getFilteredNotices('Unread').length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_selectedCategory != 'All') _buildCategoryChip(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNoticesList(_getNoticesByCategory()),
                _buildNoticesList(_getNoticesByCategory()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      color: AppTheme.lightTheme.scaffoldBackgroundColor,
      child: Row(
        children: [
          Chip(
            label: Text(_selectedCategory),
            deleteIcon: Icon(Icons.close, size: 4.w),
            onDeleted: () {
              setState(() => _selectedCategory = 'All');
            },
            backgroundColor: _getCategoryColor(_selectedCategory).withValues(alpha: 0.1),
            labelStyle: GoogleFonts.poppins(
              color: _getCategoryColor(_selectedCategory),
              fontWeight: FontWeight.w600,
              fontSize: 10.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticesList(List<Map<String, dynamic>> notices) {
    if (notices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 25.w,
              color: Colors.grey.shade300,
            ),
            SizedBox(height: 2.h),
            Text(
              'No Notices Found',
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'You\'re all caught up!',
              style: GoogleFonts.poppins(
                fontSize: 10.sp,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(4.w),
      itemCount: notices.length,
      itemBuilder: (context, index) {
        final notice = notices[index];
        return _buildNoticeCard(notice);
      },
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> notice) {
    final isUnread = notice['isUnread'];
    final categoryColor = _getCategoryColor(notice['category']);

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread
              ? AppTheme.primaryLight.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
          width: isUnread ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showNoticeDetails(notice),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getIconData(notice['icon']),
                      color: categoryColor,
                      size: 5.w,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notice['title'],
                                style: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimaryLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isUnread)
                              Container(
                                width: 2.5.w,
                                height: 2.5.w,
                                decoration: BoxDecoration(
                                  color: AppTheme.errorLight,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 0.5.h),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.3.h),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                notice['category'],
                                style: GoogleFonts.poppins(
                                  fontSize: 8.sp,
                                  color: categoryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 2.w),
                            _buildPriorityBadge(notice['priority']),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),

              // Message
              Text(
                notice['message'],
                style: GoogleFonts.poppins(
                  fontSize: 10.sp,
                  color: AppTheme.textSecondaryLight,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2.h),

              Divider(color: Colors.grey.shade200),
              SizedBox(height: 1.h),

              // Footer Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 3.5.w, color: Colors.grey),
                      SizedBox(width: 1.w),
                      Text(
                        notice['postedBy'],
                        style: GoogleFonts.poppins(
                          fontSize: 9.sp,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 3.w, color: Colors.grey),
                      SizedBox(width: 1.w),
                      Text(
                        DateFormat('MMM dd, yyyy').format(DateTime.parse(notice['date'])),
                        style: GoogleFonts.poppins(
                          fontSize: 9.sp,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    final color = _getPriorityColor(priority);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 0.3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        priority,
        style: GoogleFonts.poppins(
          fontSize: 7.sp,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'water_drop':
        return Icons.water_drop;
      case 'payment':
        return Icons.payment;
      case 'celebration':
        return Icons.celebration;
      case 'local_parking':
        return Icons.local_parking;
      case 'security':
        return Icons.security;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'bolt':
        return Icons.bolt;
      case 'pets':
        return Icons.pets;
      default:
        return Icons.notifications;
    }
  }

  void _showNoticeDetails(Map<String, dynamic> notice) {
    final categoryColor = _getCategoryColor(notice['category']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(4.w),
        constraints: BoxConstraints(maxHeight: 80.h),
        child: SingleChildScrollView(
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

              // Title with icon
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getIconData(notice['icon']),
                      color: categoryColor,
                      size: 7.w,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notice['title'],
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                notice['category'],
                                style: GoogleFonts.poppins(
                                  fontSize: 9.sp,
                                  color: categoryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 2.w),
                            _buildPriorityBadge(notice['priority']),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 3.h),

              // Details
              _buildDetailRow('Posted By', notice['postedBy']),
              _buildDetailRow('Date', DateFormat('MMMM dd, yyyy').format(DateTime.parse(notice['date']))),
              _buildDetailRow('Category', notice['category']),
              _buildDetailRow('Priority', notice['priority']),

              SizedBox(height: 2.h),
              Divider(color: Colors.grey.shade300),
              SizedBox(height: 2.h),

              // Full Message
              Text(
                'Message',
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                notice['message'],
                style: GoogleFonts.poppins(
                  fontSize: 10.sp,
                  color: AppTheme.textSecondaryLight,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 3.h),

              // Action Buttons
              Row(
                children: [
                  if (notice['isUnread'])
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _markAsRead(notice['id']);
                        },
                        icon: Icon(Icons.mark_email_read, size: 4.w),
                        label: Text('Mark as Read'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryLight,
                          side: BorderSide(color: AppTheme.primaryLight),
                          padding: EdgeInsets.symmetric(vertical: 1.5.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (notice['isUnread']) SizedBox(width: 3.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryLight,
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Close'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10.sp,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _markAsRead(int noticeId) {
    setState(() {
      final index = _allNotices.indexWhere((n) => n['id'] == noticeId);
      if (index != -1) {
        _allNotices[index]['isUnread'] = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Marked as read'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _markAllAsRead() {
    setState(() {
      for (var notice in _allNotices) {
        notice['isUnread'] = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All notices marked as read'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}