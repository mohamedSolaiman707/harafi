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

    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 0,
      right: 0,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface3,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: _getColor(latest.type).withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getColor(latest.type).withOpacity(0.1),
                    child: Icon(_getIcon(latest.type), color: _getColor(latest.type), size: 20),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          latest.title,
                          style: AppTextStyles.titleMed.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          latest.body,
                          style: AppTextStyles.bodyMed,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => ref.read(notificationProvider.notifier).clearLatest(),
                  ),
                ],
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
      default: return AppColors.info;
    }
  }

  IconData _getIcon(NotificationType type) {
    switch (type) {
      case NotificationType.urgent: return Icons.notification_important;
      case NotificationType.success: return Icons.check_circle_outline;
      case NotificationType.warning: return Icons.warning_amber_rounded;
      default: return Icons.info_outline;
    }
  }
}
