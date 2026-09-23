import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../providers/notification_provider.dart';

class NotificationOverlay extends ConsumerWidget {
  const NotificationOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(notificationProvider.notifier).latestIncoming;

    if (latest == null) return const SizedBox.shrink();

    final accentColor = _getColor(latest.type);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 0,
      right: 0,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -30 * (1 - value)),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface3.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 1,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        ref.read(notificationProvider.notifier).clearLatest();
                        if (latest.orderId != null) {
                          ref.read(notificationProvider.notifier).clearUnreadForOrder(latest.orderId!);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_getIcon(latest.type), color: accentColor, size: 22),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          latest.title,
                                          style: AppTextStyles.titleMed.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        'الآن',
                                        style: AppTextStyles.labelMed.copyWith(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    latest.body,
                                    style: AppTextStyles.bodyMed.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (latest.type == NotificationType.chat) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.info.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  'عرض 💬',
                                  style: AppTextStyles.labelMed.copyWith(
                                    color: AppColors.info,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                              onPressed: () => ref.read(notificationProvider.notifier).clearLatest(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getColor(NotificationType type) {
    switch (type) {
      case NotificationType.urgent: return AppColors.error;
      case NotificationType.success: return AppColors.success;
      case NotificationType.warning: return AppColors.gold;
      case NotificationType.chat: return AppColors.info;
      default: return AppColors.info;
    }
  }

  IconData _getIcon(NotificationType type) {
    switch (type) {
      case NotificationType.urgent: return Icons.notification_important;
      case NotificationType.success: return Icons.check_circle_outline;
      case NotificationType.warning: return Icons.warning_amber_rounded;
      case NotificationType.chat: return Icons.mark_chat_unread_rounded;
      default: return Icons.info_outline;
    }
  }
}
