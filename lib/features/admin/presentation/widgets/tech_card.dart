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
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
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
                      final link = WhatsAppUtils.buildLink(
                        tech.phone,
                        'السلام عليكم يا بشمهندس ${tech.name}',
                      );
                      launchUrl(Uri.parse(link));
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('اتصال واتساب'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  color: AppColors.textSecondary,
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
