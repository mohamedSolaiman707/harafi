import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../providers/notification_provider.dart';

class NotificationSheet extends ConsumerWidget {
  const NotificationSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('التنبيهات', style: AppTextStyles.headlineMed),
                if (notifications.isNotEmpty)
                  TextButton(
                    onPressed: () => ref.read(notificationProvider.notifier).clearAll(),
                    child: const Text('مسح الكل', style: TextStyle(color: AppColors.error)),
                  ),
              ],
            ),
          ),
          if (notifications.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.notifications_none_rounded, size: 64, color: AppColors.textMuted),
                  SizedBox(height: 16),
                  Text('لا توجد تنبيهات جديدة'),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderSubtle),
                itemBuilder: (context, index) {
                  final n = notifications[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    leading: CircleAvatar(
                      backgroundColor: n.isRead ? AppColors.surface3 : AppColors.gold.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.notifications_active_outlined,
                        color: n.isRead ? AppColors.textMuted : AppColors.gold,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      n.title,
                      style: AppTextStyles.titleMed.copyWith(
                        color: n.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.body, style: AppTextStyles.bodyMed),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('HH:mm - yyyy/MM/dd').format(n.timestamp),
                          style: AppTextStyles.labelMed.copyWith(fontSize: 9),
                        ),
                      ],
                    ),
                    onTap: () {
                      ref.read(notificationProvider.notifier).markAsRead(n.id);
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}
