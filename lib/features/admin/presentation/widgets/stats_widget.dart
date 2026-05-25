import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/orders_provider.dart';
import '../../../../core/theme/app_theme.dart';

class StatsWidget extends ConsumerWidget {
  const StatsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // استخدام MaxCrossAxisExtent لضمان توزيع احترافي للكروت حسب عرض الشاشة
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: constraints.maxWidth > 1200 ? 250 : 200,
            mainAxisExtent: 100, // ارتفاع ثابت ومريح للكارت
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: 7,
          itemBuilder: (context, index) {
            final cards = [
              _StatItem(
                title: 'إجمالي الطلبات',
                value: stats['total'].toString(),
                icon: Icons.assignment_rounded,
                color: AppColors.info,
              ),
              _StatItem(
                title: 'طلبات جديدة',
                value: stats['pending'].toString(),
                icon: Icons.auto_awesome_rounded,
                color: AppColors.gold,
                isAlert: (stats['pending'] as int) > 0,
              ),
              _StatItem(
                title: 'قيد التنفيذ',
                value: stats['active'].toString(),
                icon: Icons.run_circle_rounded,
                color: Colors.orange,
              ),
              _StatItem(
                title: 'طلبات مكتملة',
                value: stats['completed'].toString(),
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
              ),
              _StatItem(
                title: 'إجمالي الإيرادات',
                value: stats['revenue'].toString(),
                suffix: ' ج.م',
                icon: Icons.payments_rounded,
                color: AppColors.success,
              ),
              _StatItem(
                title: 'إجمالي الفنيين',
                value: stats['techTotal'].toString(),
                icon: Icons.people_alt_rounded,
                color: Colors.purpleAccent,
              ),
              _StatItem(
                title: 'طلبات انضمام',
                value: stats['techPending'].toString(),
                icon: Icons.person_add_rounded,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlert ? color.withOpacity(0.5) : AppColors.borderSubtle,
          width: isAlert ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
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
                        style: AppTextStyles.titleLarge.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isAlert ? color : AppColors.textPrimary,
                        ),
                      ),
                      if (suffix != null)
                        Text(
                          suffix!,
                          style: AppTextStyles.labelMed.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 10,
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
