import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../domain/models/technician.dart';
import '../../domain/enums/tech_status.dart';

class TechCard extends StatelessWidget {
  final Technician tech;
  final VoidCallback? onEdit;

  const TechCard({super.key, required this.tech, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: tech.status == TechStatus.pending 
              ? AppColors.gold.withValues(alpha: 0.5) 
              : AppColors.borderDefault,
          width: tech.status == TechStatus.pending ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            if (tech.status == TechStatus.pending)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.gold, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'طلب انضمام جديد - يحتاج مراجعة',
                      style: AppTextStyles.labelMed.copyWith(color: AppColors.gold),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.surface1,
                  child: Text(
                    tech.spec.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tech.name, style: AppTextStyles.headlineMed),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        tech.spec.label,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: tech.status),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(color: AppColors.borderDefault),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _TechStat(
                  label: 'التقييم',
                  value: tech.rating.toString(),
                  icon: Icons.star,
                  color: Colors.amber,
                ),
                _TechStat(
                  label: 'العمليات',
                  value: tech.totalJobs.toString(),
                  icon: Icons.build,
                  color: AppColors.info,
                ),
                _TechStat(
                  label: 'سعر الزيارة',
                  value: '${tech.visitPrice} ج.م',
                  icon: Icons.payments,
                  color: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(color: AppColors.borderDefault),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderDefault),
                    ),
                    onPressed: () {
                      final uri = WhatsAppUtils.buildUri(
                        tech.phone,
                        'السلام عليكم يا بشمهندس ${tech.name}',
                      );
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('اتصال واتساب'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: onEdit,
                  icon: Icon(
                    tech.status == TechStatus.pending ? Icons.how_to_reg : Icons.edit,
                    color: tech.status == TechStatus.pending ? AppColors.gold : AppColors.textSecondary,
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

class _StatusBadge extends StatelessWidget {
  final TechStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case TechStatus.pending:
        color = AppColors.gold;
        break;
      case TechStatus.available:
        color = AppColors.success;
        break;
      case TechStatus.busy:
        color = AppColors.info;
        break;
      case TechStatus.onLeave:
        color = AppColors.textSecondary;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.labelLarge.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TechStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _TechStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: AppSpacing.sm),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.bodyMed.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
