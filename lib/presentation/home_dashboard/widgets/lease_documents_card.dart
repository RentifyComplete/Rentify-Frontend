import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../core/app_export.dart';
import '../all_documents_screen.dart';  // ADD THIS IMPORT

class LeaseDocumentsCard extends StatelessWidget {
  final String leaseEndDate;
  final int securityDeposit;

  const LeaseDocumentsCard({
    Key? key,
    required this.leaseEndDate,
    required this.securityDeposit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.description,
                  color: AppTheme.primaryLight,
                  size: 6.w,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lease Agreement',
                      style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Ends on $leaseEndDate',
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryLight,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Security Deposit',
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryLight,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    '₹${securityDeposit.toStringAsFixed(0)}',
                    style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 2.h),
          // UPDATED: View All Documents Button
          InkWell(
            onTap: () {
              print('🔍 Navigating to All Documents Screen');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AllDocumentsScreen()),
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 4.w),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryLight, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    color: AppTheme.primaryLight,
                    size: 5.w,
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    'View All Documents',
                    style: TextStyle(
                      color: AppTheme.primaryLight,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}