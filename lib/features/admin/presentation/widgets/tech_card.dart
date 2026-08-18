import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../domain/models/technician.dart';
import '../../domain/enums/tech_status.dart';
import '../../../../shared/widgets/app_card.dart';

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
    final bool isPending = tech.status == TechStatus.pending;
    final bool isOnLeave = tech.status == TechStatus.onLeave;
    final bool isBusy = tech.status == TechStatus.busy;

    // تحديد لون الحالة بدقة: رصيد منخفض > انتظار > استراحة > مشغول > متاح
    final Color statusColor = isLowBalance 
        ? AppColors.error 
        : (isPending 
            ? AppColors.gold 
            : (isOnLeave 
                ? AppColors.textMuted // لون رمادي للاستراحة
                : (isBusy ? AppColors.info : AppColors.success)));

    return AppCard(
      padding: EdgeInsets.zero,
      color: AppColors.surface1,
      border: Border.all(
        color: statusColor.withOpacity(0.15),
        width: 1,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: statusColor.withOpacity(0.6), width: 3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _buildAvatar(isOnLeave),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tech.name,
                              style: AppTextStyles.titleMed.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            _StatusBadge(status: tech.status),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              tech.spec.label,
                              style: AppTextStyles.labelMed.copyWith(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (tech.isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, color: AppColors.info, size: 14),
                            ],
                            const Spacer(),
                            _buildRankInfo(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface2.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _KpiMetric(label: 'التقييم', value: tech.rating.toStringAsFixed(1), icon: Icons.star_rounded, color: Colors.amber),
                    _KpiDivider(),
                    _KpiMetric(label: 'العمليات', value: tech.totalJobs.toString(), icon: Icons.bolt_rounded, color: AppColors.info),
                    _KpiDivider(),
                    _KpiMetric(
                      label: 'المحفظة',
                      value: '${tech.walletBalance}ج',
                      icon: Icons.account_balance_wallet_rounded,
                      color: isLowBalance ? AppColors.error : AppColors.success,
                    ),
                    _KpiDivider(),
                    _KpiMetric(label: 'الزيارة', value: '${tech.visitPrice}ج', icon: Icons.payments_rounded, color: AppColors.textMuted),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _PrimaryWhatsAppButton(
                      onTap: () => launchUrl(
                        WhatsAppUtils.buildUri(tech.phone, 'السلام عليكم يا بشمهندس ${tech.name}'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SecondaryIconButton(
                    icon: Icons.add_card_rounded,
                    color: AppColors.success,
                    onTap: onRecharge,
                    tooltip: 'شحن رصيد',
                  ),
                  const SizedBox(width: 8),
                  _SecondaryIconButton(
                    icon: isPending ? Icons.how_to_reg_rounded : Icons.settings_suggest_rounded,
                    color: AppColors.textSecondary,
                    onTap: onEdit,
                    tooltip: 'إدارة',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(bool isOnLeave) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderSubtle, width: 1.5),
      ),
      child: Opacity(
        opacity: isOnLeave ? 0.6 : 1.0, // تعتيم صورة الفني في حالة الإجازة
        child: CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.surface2,
          backgroundImage: tech.photoUrl != null && tech.photoUrl!.isNotEmpty
              ? NetworkImage(tech.photoUrl!)
              : null,
          child: (tech.photoUrl == null || tech.photoUrl!.isEmpty)
              ? Text(tech.spec.icon, style: const TextStyle(fontSize: 18))
              : null,
        ),
      ),
    );
  }

  Widget _buildRankInfo() {
    return Text(
      tech.rank.toUpperCase(),
      style: AppTextStyles.labelMed.copyWith(
        color: tech.rankColor.withOpacity(0.9),
        fontWeight: FontWeight.w900,
        fontSize: 9,
        letterSpacing: 0.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 9),
      ),
    );
  }
}

class _KpiMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiMetric({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 11),
            const SizedBox(width: 4),
            Text(value, style: AppTextStyles.titleMed.copyWith(fontWeight: FontWeight.w900, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 8, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _KpiDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 18, width: 1, color: AppColors.borderSubtle);
  }
}

class _PrimaryWhatsAppButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PrimaryWhatsAppButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gold.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.gold, size: 15),
              const SizedBox(width: 8),
              Text(
                'تواصل واتساب',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.gold, 
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String tooltip;
  const _SecondaryIconButton({required this.icon, required this.color, this.onTap, required this.tooltip});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: tooltip,
          child: Container(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }
}
