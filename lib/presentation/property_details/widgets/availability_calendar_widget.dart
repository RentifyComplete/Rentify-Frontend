import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class AvailabilityCalendarWidget extends StatefulWidget {
  const AvailabilityCalendarWidget({super.key});

  @override
  State<AvailabilityCalendarWidget> createState() =>
      _AvailabilityCalendarWidgetState();
}

class _AvailabilityCalendarWidgetState
    extends State<AvailabilityCalendarWidget> {
  final DateTime _selectedDate = DateTime.now();
  final DateTime _focusedDate = DateTime.now();
  DateTimeRange? _selectedRange;

  // Mock blocked dates
  final Set<DateTime> _blockedDates = {
    DateTime.now().add(Duration(days: 5)),
    DateTime.now().add(Duration(days: 12)),
    DateTime.now().add(Duration(days: 18)),
    DateTime.now().add(Duration(days: 25)),
  };

  void _showDatePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      initialDateRange: _selectedRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              backgroundColor: AppTheme.lightTheme.colorScheme.surface,
              headerBackgroundColor: AppTheme.lightTheme.colorScheme.primary,
              headerForegroundColor: AppTheme.lightTheme.colorScheme.onPrimary,
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.lightTheme.colorScheme.onPrimary;
                }
                if (states.contains(WidgetState.disabled)) {
                  return AppTheme.lightTheme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.5);
                }
                return AppTheme.lightTheme.colorScheme.onSurface;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.lightTheme.colorScheme.primary;
                }
                return Colors.transparent;
              }),
              rangeSelectionBackgroundColor: AppTheme
                  .lightTheme.colorScheme.primary
                  .withValues(alpha: 0.2),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedRange = picked;
      });
    }
  }

  bool _isDateBlocked(DateTime date) {
    return _blockedDates.any((blockedDate) =>
        blockedDate.year == date.year &&
        blockedDate.month == date.month &&
        blockedDate.day == date.day);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Availability',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTheme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.outline
                    .withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select your stay dates',
                      style:
                          AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: _showDatePicker,
                      child: Text('View Calendar'),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildDateSelector(
                        'Check-in',
                        _selectedRange?.start ?? DateTime.now(),
                        'check_in',
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: _buildDateSelector(
                        'Check-out',
                        _selectedRange?.end ??
                            DateTime.now().add(Duration(days: 1)),
                        'check_out',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3.h),
                _buildAvailabilityLegend(),
                SizedBox(height: 2.h),
                if (_selectedRange != null)
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: AppTheme.lightTheme.colorScheme.primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'check_circle',
                          color: AppTheme.lightTheme.colorScheme.primary,
                          size: 20,
                        ),
                        SizedBox(width: 3.w),
                        Expanded(
                          child: Text(
                            'Selected dates are available for booking',
                            style: AppTheme.lightTheme.textTheme.bodyMedium
                                ?.copyWith(
                              color: AppTheme.lightTheme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
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

  Widget _buildDateSelector(String label, DateTime date, String type) {
    return GestureDetector(
      onTap: _showDatePicker,
      child: Container(
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          border: Border.all(
            color:
                AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 1.h),
            Row(
              children: [
                CustomIconWidget(
                  iconName: type == 'check_in' ? 'login' : 'logout',
                  color: AppTheme.lightTheme.colorScheme.primary,
                  size: 18,
                ),
                SizedBox(width: 2.w),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityLegend() {
    return Row(
      children: [
        _buildLegendItem('Available', AppTheme.lightTheme.colorScheme.primary),
        SizedBox(width: 6.w),
        _buildLegendItem('Blocked', AppTheme.lightTheme.colorScheme.error),
        SizedBox(width: 6.w),
        _buildLegendItem('Selected', AppTheme.lightTheme.colorScheme.tertiary),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3.w,
          height: 3.w,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 2.w),
        Text(
          label,
          style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
            color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
