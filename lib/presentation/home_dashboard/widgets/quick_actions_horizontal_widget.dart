import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../routes/app_routes.dart';

class QuickActionsHorizontalWidget extends StatelessWidget {
  final bool isPropertyOwner;

  const QuickActionsHorizontalWidget({
    super.key,
    this.isPropertyOwner = false,
  });

  @override
  Widget build(BuildContext context) {
    final actions = _getActions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Text(
            'Quick Actions',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(height: 2.h),
        SizedBox(
          height: 14.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return Padding(
                padding: EdgeInsets.only(right: 3.w),
                child: _QuickActionCard(
                  title: action['title'] as String,
                  count: action['count'] as String,
                  iconName: action['icon'] as String,
                  color: action['color'] as Color,
                  onTap: () {
                    final route = action['route'] as String?;
                    if (route != null) {
                      Navigator.pushNamed(context, route);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getActions() {
    if (isPropertyOwner) {
      return [
        {
          'title': 'Saved',
          'count': '',
          'icon': 'bookmark',
          'color': AppTheme.primaryLight,
          'route': AppRoutes.savedSearches,
        },
        {
          'title': 'Payment Due',
          'count': '',
          'icon': 'payment',
          'color': AppTheme.warningLight,
          'route': AppRoutes.payments,
        },
        {
          'title': 'Add Tenant',
          'count': '',
          'icon': 'person_add',
          'color': AppTheme.primaryLight,
          'route': AppRoutes.addTenant,
        },
        {
          'title': 'Receive Payment',
          'count': '',
          'icon': 'account_balance_wallet',
          'color': AppTheme.successLight,
          'route': AppRoutes.receivePayment,
        },
        {
          'title': 'Add Expense',
          'count': '',
          'icon': 'receipt_long',
          'color': AppTheme.warningLight,
          'route': AppRoutes.addExpense,
        },
        {
          'title': 'Add Dues',
          'count': '',
          'icon': 'money_off',
          'color': Colors.orange,
          'route': AppRoutes.addDues,
        },
        {
          'title': 'Send Announcement',
          'count': '',
          'icon': 'campaign',
          'color': AppTheme.accentLight,
          'route': AppRoutes.sendAnnouncement,
        },
        {
          'title': 'Add Team Tenant',
          'count': '',
          'icon': 'group_add',
          'color': Colors.purple,
          'route': AppRoutes.addTeamTenant,
        },
        {
          'title': 'Add Bank Account',
          'count': '',
          'icon': 'account_balance',
          'color': Colors.teal,
          'route': AppRoutes.addBankAccount,
        },
        {
          'title': 'Agreement Settings',
          'count': '',
          'icon': 'settings_applications',
          'color': Colors.blueGrey,
          'route': AppRoutes.agreementSettings,
        },
      ];
    } else {
      return [
        {
          'title': 'Saved',
          'count': '3 active alerts',
          'icon': 'bookmark',
          'color': AppTheme.primaryLight,
          'route': AppRoutes.savedSearches,
        },
        {
          'title': 'Payment Due',
          'count': '',
          'icon': 'payment',
          'color': AppTheme.warningLight,
          'route': AppRoutes.payments,
        },
      ];
    }
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String count;
  final String iconName;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.count,
    required this.iconName,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28.w,
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowLight,
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(2.5.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: CustomIconWidget(
                iconName: iconName,
                color: color,
                size: 6.w,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              title,
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (count.isNotEmpty) ...[
              SizedBox(height: 0.5.h),
              Text(
                count,
                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 9.sp,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}