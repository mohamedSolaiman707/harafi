import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../domain/models/technician.dart';
import '../../domain/enums/tech_status.dart';

class TechCard extends StatelessWidget {
  final Technician tech;
  final VoidCallback? onEdit;
  final VoidCallback? onRecharge;

  const TechCard({
    super.key,
    required this.tech,
    this.onEdit,
    this.onRecharge,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLowBalance = tech.walletBalance < AppConstants.platformFee;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isLowBalance
              ? AppColors.error.withValues(alpha: 0.6)
              : (tech.status == TechStatus.pending
                  ? AppColors.gold.withValues(alpha: 0.5)
                  : AppColors.borderDefault),
          width: isLowBalance || tech.status == TechStatus.pending ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _StatusBadge(status: tech.status),
                            if (isLowBalance) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '⚠️ رصيد منخفض',
                                  style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const Spacer(),
                        _buildAvatar(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      tech.name, 
                      style: AppTextStyles.headlineMed,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(tech.spec.label, style: AppTextStyles.bodyMed.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: AppSpacing.sm),
                    _buildRankBadge(),
                    const Spacer(),
                    const Divider(color: AppColors.borderSubtle, height: 24),
                    _buildStatsGrid(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            _buildActionRow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tech.rankColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tech.rankColor.withValues(alpha: 0.2)),
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3), width: 2),
          ),
          child: CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.surface2,
            backgroundImage: tech.photoUrl != null && tech.photoUrl!.isNotEmpty 
                ? NetworkImage(tech.photoUrl!) 
                : null,
            child: (tech.photoUrl == null || tech.photoUrl!.isEmpty) 
                ? Text(tech.spec.icon, style: const TextStyle(fontSize: 24)) 
                : null,
          ),
        ),
        if (tech.isVerified)
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: AppColors.surface1,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified,
                color: AppColors.info,
                size: 20,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final isLowBalance = tech.walletBalance < AppConstants.platformFee;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _TechStat(label: 'التقييم', value: tech.rating.toStringAsFixed(1), icon: Icons.star_rounded, color: Colors.amber),
        _TechStat(label: 'العمليات', value: tech.totalJobs.toString(), icon: Icons.handyman_rounded, color: AppColors.info),
        _TechStat(
          label: 'المحفظة',
          value: '${tech.walletBalance}ج',
          icon: Icons.account_balance_wallet_rounded,
          color: isLowBalance ? AppColors.error : AppColors.gold,
        ),
        _TechStat(label: 'الزيارة', value: '${tech.visitPrice}', icon: Icons.confirmation_number_rounded, color: AppColors.textMuted),
      ],
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          if (onRecharge != null)
            IconButton(
              onPressed: onRecharge,
              icon: const Icon(Icons.add_card_rounded, color: AppColors.gold, size: 20),
              tooltip: 'شحن محفظة الفني ⚡',
            ),
          Expanded(
            child: TextButton.icon(
              onPressed: () => launchUrl(
                WhatsAppUtils.buildUri(tech.phone, 'السلام عليكم يا بشمهندس ${tech.name}'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.chat_bubble_rounded, size: 16),
              label: const Text('واتساب'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: Icon(
              tech.status == TechStatus.pending ? Icons.how_to_reg : Icons.edit_note_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
            tooltip: 'تعديل البيانات',
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
