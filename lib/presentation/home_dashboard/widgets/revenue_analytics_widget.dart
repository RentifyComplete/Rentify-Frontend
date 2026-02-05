import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class RevenueAnalyticsWidget extends StatelessWidget {
  const RevenueAnalyticsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock revenue data
    const double monthlyRevenue = 15600.0;
    const double previousMonthRevenue = 14200.0;
    const double growthPercentage = 9.9;

    final List<FlSpot> revenueData = [
      const FlSpot(1, 12000),
      const FlSpot(2, 13500),
      const FlSpot(3, 11800),
      const FlSpot(4, 14200),
      const FlSpot(5, 15600),
      const FlSpot(6, 16800),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowLight,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$${monthlyRevenue.toStringAsFixed(0)}',
                      style: AppTheme.lightTheme.textTheme.headlineMedium
                          ?.copyWith(
                        color: AppTheme.primaryLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Monthly Revenue',
                      style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: AppTheme.successLight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomIconWidget(
                        iconName: 'trending_up',
                        color: AppTheme.successLight,
                        size: 4.w,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        '+${growthPercentage.toStringAsFixed(1)}%',
                        style:
                            AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.successLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 3.h),
            SizedBox(
              height: 20.h,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 2000,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppTheme.lightTheme.colorScheme.outline
                            .withValues(alpha: 0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          const style = TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          );
                          Widget text;
                          switch (value.toInt()) {
                            case 1:
                              text = const Text('Jan', style: style);
                              break;
                            case 2:
                              text = const Text('Feb', style: style);
                              break;
                            case 3:
                              text = const Text('Mar', style: style);
                              break;
                            case 4:
                              text = const Text('Apr', style: style);
                              break;
                            case 5:
                              text = const Text('May', style: style);
                              break;
                            case 6:
                              text = const Text('Jun', style: style);
                              break;
                            default:
                              text = const Text('', style: style);
                              break;
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: text,
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 4000,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Text(
                            '\$${(value / 1000).toInt()}k',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          );
                        },
                        reservedSize: 42,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: false,
                  ),
                  minX: 1,
                  maxX: 6,
                  minY: 10000,
                  maxY: 18000,
                  lineBarsData: [
                    LineChartBarData(
                      spots: revenueData,
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryLight,
                          AppTheme.accentLight,
                        ],
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: AppTheme.primaryLight,
                            strokeWidth: 2,
                            strokeColor:
                                AppTheme.lightTheme.colorScheme.surface,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryLight.withValues(alpha: 0.3),
                            AppTheme.primaryLight.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 2.h),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Average Rent',
                    '\$1,300',
                    'attach_money',
                    AppTheme.successLight,
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: _buildMetricCard(
                    'Collection Rate',
                    '96%',
                    'check_circle',
                    AppTheme.primaryLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, String iconName, Color color) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          CustomIconWidget(
            iconName: iconName,
            color: color,
            size: 6.w,
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  title,
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
