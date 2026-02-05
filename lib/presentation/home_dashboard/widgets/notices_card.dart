import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../core/app_export.dart';
import '../all_notices_screen.dart';

class NoticesCard extends StatelessWidget {
  const NoticesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> notices = [
      {
        'id': 1,
        'title': 'Water Supply Interruption',
        'message': 'Water supply will be interrupted on Oct 12 from 10 AM to 2 PM for maintenance.',
        'date': '2025-10-08',
        'isUnread': true,
        'icon': 'water_drop',
        'color': AppTheme.warningLight,
      },
      {
        'id': 2,
        'title': 'Community Event',
        'message': 'Join us for Diwali celebration on Oct 20 in the community hall.',
        'date': '2025-10-05',
        'isUnread': false,
        'icon': 'celebration',
        'color': AppTheme.successLight,
      },
    ];

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
                      color: AppTheme.accentLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: CustomIconWidget(
                      iconName: 'notifications_active',
                      color: AppTheme.accentLight,
                      size: 6.w,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    'Recent Notices',
                    style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: AppTheme.errorLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '1 New',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.errorLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),

          // Notices list
          ...notices.map((notice) => _buildNoticeItem(context, notice)).toList(),

          // View All Notices Button
          SizedBox(height: 1.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AllNoticesScreen(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryLight,
                side: BorderSide(color: AppTheme.primaryLight, width: 1.5),
                padding: EdgeInsets.symmetric(vertical: 1.5.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('View All Notices'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeItem(BuildContext context, Map<String, dynamic> notice) {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: notice['isUnread']
            ? AppTheme.accentLight.withValues(alpha: 0.05)
            : AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: notice['isUnread']
            ? Border.all(color: AppTheme.accentLight.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: notice['color'].withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: CustomIconWidget(
              iconName: notice['icon'],
              color: notice['color'],
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
                        style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (notice['isUnread'])
                      Container(
                        width: 2.w,
                        height: 2.w,
                        decoration: BoxDecoration(
                          color: AppTheme.errorLight,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  notice['message'],
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryLight,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 1.h),
                Text(
                  notice['date'],
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}