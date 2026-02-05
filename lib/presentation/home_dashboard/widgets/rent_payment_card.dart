import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../core/app_export.dart';
import 'package:intl/intl.dart';
// FIXED: Added the missing import for Google Fonts
import 'package:google_fonts/google_fonts.dart';
import '../pay_rent_screen.dart';
import '../payment_history.dart';
import '../tenant_rent_payment_screen.dart';

class RentPaymentCard extends StatelessWidget {
  final int rentAmount;
  final String nextDueDate;
  final VoidCallback onViewHistory;
  final VoidCallback onPayRent;

  const RentPaymentCard({
    super.key,
    required this.rentAmount,
    required this.nextDueDate,
    required this.onViewHistory,
    required this.onPayRent,
  });

  @override
  Widget build(BuildContext context) {
    // Accessing your app's theme settings
    final theme = AppTheme.lightTheme;
    final primaryColor = theme.primaryColor;

    DateTime dueDate = DateTime.parse(nextDueDate);
    String formattedDueDate = DateFormat('EEEE, MMM dd, yyyy').format(dueDate);

    // Simple logic for payment status based on current date
    String status = DateTime.now().isAfter(dueDate) ? 'Overdue' : 'Due Soon';
    Color statusColor = DateTime.now().isAfter(dueDate) ? Colors.red : primaryColor;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rent & Payments 💳',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
                color: theme.textTheme.headlineLarge!.color,
              ),
            ),
            Divider(height: 2.h),

            // Rent Details (Amount and Status)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // Uses NumberFormat for correct currency display (e.g., ₹2,500)
                      '₹${NumberFormat.currency(locale: 'en_IN', symbol: '').format(rentAmount)}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w900,
                        fontSize: 20.sp,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      'Monthly Rent',
                      style: GoogleFonts.poppins(
                        fontSize: 9.sp,
                        color: theme.textTheme.bodyMedium!.color,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    // FIXED: Replaced deprecated `withOpacity` with a non-deprecated alternative
                    color: statusColor.withAlpha((255 * 0.15).round()),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 8.sp,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.h),

            // Due Date
            Row(
              children: [
                CustomIconWidget(iconName: 'schedule', color: primaryColor, size: 14),
                SizedBox(width: 2.w),
                Text(
                  'Due Date: $formattedDueDate',
                  style: GoogleFonts.poppins(
                    fontSize: 10.sp,
                    color: theme.textTheme.bodyMedium!.color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TenantRentPaymentScreen(),
                        ),
                      );
                    },
                    icon: CustomIconWidget(iconName: 'payment', color: Colors.white, size: 18),
                    label: Text('Pay Rent', style: GoogleFonts.poppins(fontSize: 10.sp)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  // FIXED: Moved the 'child' argument to be the last parameter
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PaymentHistoryScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: primaryColor, width: 1.5),
                    ),
                    child: Text('View History', style: GoogleFonts.poppins(fontSize: 10.sp, color: primaryColor)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}