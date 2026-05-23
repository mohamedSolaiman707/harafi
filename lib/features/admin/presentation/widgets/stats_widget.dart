import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/orders_provider.dart';
import '../../../../core/theme/app_theme.dart';

class StatsWidget extends ConsumerWidget {
  const StatsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1100 ? 5 : (width > 800 ? 3 : 2);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.2,
      children: [
        _StatCard(
          title: 'إجمالي الطلبات',
          value: stats['total'].toString(),
          icon: Icons.assignment,
          color: AppColors.info,
        ),
        _StatCard(
          title: 'طلبات جارية',
          value: stats['pending'].toString(),
          icon: Icons.pending_actions,
          color: Colors.orange,
        ),
        _StatCard(
          title: 'إجمالي الفنيين',
          value: stats['techTotal'].toString(),
          icon: Icons.engineering,
          color: Colors.purple,
        ),
        _StatCard(
          title: 'طلبات انضمام',
          value: stats['techPending'].toString(),
          icon: Icons.person_add_alt_1,
          color: AppColors.gold,
          isAlert: (stats['techPending'] as int) > 0,
        ),
        _StatCard(
          title: 'طلبات مكتملة',
          value: stats['completed'].toString(),
          icon: Icons.task_alt,
          color: AppColors.success,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isAlert;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlert ? AppColors.gold.withOpacity(0.5) : AppColors.borderDefault,
          width: isAlert ? 2 : 1,
        ),
        boxShadow: isAlert ? [BoxShadow(color: AppColors.gold.withOpacity(0.1), blurRadius: 10)] : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: AppTextStyles.displayMedium.copyWith(
                      fontSize: 24,
                      color: isAlert ? AppColors.gold : AppColors.textPrimary,
                    ),
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
