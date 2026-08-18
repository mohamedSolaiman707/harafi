import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/orders_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

class StatsWidget extends ConsumerWidget {
  const StatsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          padding: EdgeInsets.zero, // إزالة المسافات الافتراضية
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: constraints.maxWidth > 1200 ? 300 : 250,
            mainAxisExtent: 110, 
            crossAxisSpacing: 16, // تقليل المسافات بين الكروت
            mainAxisSpacing: 16,
          ),
          itemCount: 8,
          itemBuilder: (context, index) {
            final cards = [
              _StatItem(
                title: 'إجمالي الطلبات',
                value: stats['total'].toString(),
                icon: Icons.assignment_rounded,
                color: AppColors.info,
              ),
              _StatItem(
                title: 'طلبات معلقة',
                value: stats['pending'].toString(),
                icon: Icons.pending_actions_rounded,
                color: AppColors.gold,
                isAlert: (stats['pending'] as int) > 0,
              ),
              _StatItem(
                title: 'قيد التنفيذ',
                value: stats['active'].toString(),
                icon: Icons.running_with_errors_rounded,
                color: Colors.orangeAccent,
              ),
              _StatItem(
                title: 'طلبات مكتملة',
                value: stats['completed'].toString(),
                icon: Icons.task_alt_rounded,
                color: AppColors.success,
              ),
              _StatItem(
                title: 'إجمالي العمليات',
                value: stats['revenue'].toString(),
                suffix: ' ج.م',
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.success,
              ),
              _StatItem(
                title: 'عمولة المنصة',
                value: (stats['platformRevenue'] ?? 0).toString(),
                suffix: ' ج.م',
                icon: Icons.pie_chart_rounded,
                color: AppColors.gold,
              ),
              _StatItem(
                title: 'إجمالي الفنيين',
                value: stats['techTotal'].toString(),
                icon: Icons.engineering_rounded,
                color: Colors.indigoAccent,
              ),
              _StatItem(
                title: 'طلبات التوظيف',
                value: stats['techPending'].toString(),
                icon: Icons.how_to_reg_rounded,
                color: AppColors.gold,
                isAlert: (stats['techPending'] as int) > 0,
              ),
            ];
            return cards[index];
          },
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String title;
  final String value;
  final String? suffix;
  final IconData icon;
  final Color color;
  final bool isAlert;

  const _StatItem({
    required this.title,
    required this.value,
    this.suffix,
    required this.icon,
    required this.color,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(16), // تقليل نصف القطر قليلاً لشكل أكثر حدة واحترافية
        border: Border.all(
          color: isAlert ? color.withOpacity(0.3) : AppColors.borderSubtle,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.labelMed.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: AppTextStyles.headlineMed.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (suffix != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Text(
                            suffix!,
                            style: AppTextStyles.labelMed.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
