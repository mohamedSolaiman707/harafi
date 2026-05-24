import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/order.dart';
import '../../domain/enums/order_status.dart';

class RevenueChart extends StatelessWidget {
  final List<Order> orders;
  const RevenueChart({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    // 1. معالجة البيانات لآخر 7 أيام
    final now = DateTime.now();
    final last7Days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    
    final dailyStats = <DateTime, double>{};
    for (var date in last7Days) {
      final dayKey = DateTime(date.year, date.month, date.day);
      dailyStats[dayKey] = 0;
    }

    for (var order in orders) {
      if (order.status == OrderStatus.completed && order.finalPrice != null) {
        final dayKey = DateTime(order.createdAt.year, order.createdAt.month, order.createdAt.day);
        if (dailyStats.containsKey(dayKey)) {
          dailyStats[dayKey] = dailyStats[dayKey]! + order.finalPrice!;
        }
      }
    }

    final spots = dailyStats.entries.indexed.map((e) {
      return FlSpot(e.$1.toDouble(), e.$2.value);
    }).toList();

    return Container(
      height: 300,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('تحليل الإيرادات (آخر 7 أيام)', style: AppTextStyles.titleLarge),
              const Icon(Icons.trending_up, color: AppColors.success, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final index = val.toInt();
                        if (index < 0 || index >= last7Days.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            intl.DateFormat('E', 'ar').format(last7Days[index]),
                            style: AppTextStyles.labelMed,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (val, meta) {
                        return Text(
                          val >= 1000 ? '${(val / 1000).toStringAsFixed(1)}k' : val.toInt().toString(),
                          style: AppTextStyles.labelMed,
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.gold,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.gold.withValues(alpha: 0.1),
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
