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
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: tech.status == TechStatus.pending 
              ? AppColors.gold.withOpacity(0.5) 
              : AppColors.borderDefault,
          width: tech.status == TechStatus.pending ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatusBadge(status: tech.status),
                        const Spacer(),
                        _buildAvatar(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(tech.name, style: AppTextStyles.headlineMed),
                    Text(tech.spec.label, style: AppTextStyles.bodyMed.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: AppSpacing.md),
                    _buildRankBadge(),
                    const Spacer(),
                    const Divider(color: AppColors.borderSubtle),
                    const Spacer(),
                    _buildStatsGrid(),
                  ],
                ),
              ),
            ),
            _buildActionRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tech.rankColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tech.rankColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tech.rankIcon, color: tech.rankColor, size: 12),
          const SizedBox(width: 6),
          Text(
            tech.rank,
            style: AppTextStyles.labelMed.copyWith(color: tech.rankColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold.withOpacity(0.3), width: 2),
      ),
      child: CircleAvatar(
        radius: 28,
        backgroundColor: AppColors.surface2,
        backgroundImage: tech.photoUrl != null ? NetworkImage(tech.photoUrl!) : null,
        child: tech.photoUrl == null ? Text(tech.spec.icon, style: const TextStyle(fontSize: 24)) : null,
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _TechStat(label: 'التقييم', value: tech.rating.toStringAsFixed(1), icon: Icons.star_rounded, color: Colors.amber),
        _TechStat(label: 'العمليات', value: tech.totalJobs.toString(), icon: Icons.handyman_rounded, color: AppColors.info),
        _TechStat(label: 'الأرباح', value: '${tech.totalEarnings}', icon: Icons.account_balance_wallet_rounded, color: AppColors.success),
        _TechStat(label: 'الزيارة', value: '${tech.visitPrice}', icon: Icons.confirmation_number_rounded, color: AppColors.textMuted),
      ],
    );
  }

  Widget _buildActionRow() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onEdit,
            icon: Icon(
              tech.status == TechStatus.pending ? Icons.how_to_reg : Icons.edit_note_rounded,
              color: AppColors.textSecondary,
            ),
            tooltip: 'تعديل البيانات',
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextButton.icon(
              onPressed: () => launchUrl(
                WhatsAppUtils.buildUri(tech.phone, 'السلام عليكم يا بشمهندس ${tech.name}'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.chat_bubble_rounded, size: 18),
              label: const Text('واتساب الفني'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
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
      case TechStatus.pending: color = AppColors.gold; break;
      case TechStatus.available: color = AppColors.success; break;
      case TechStatus.busy: color = AppColors.info; break;
      case TechStatus.onLeave: color = AppColors.textMuted; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: AppTextStyles.labelMed.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _TechStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _TechStat({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.titleMed.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ],
    );
  }
}
