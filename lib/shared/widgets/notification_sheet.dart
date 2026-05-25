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
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.lg),
          // مقبض السحب العلوي (Drag handle)
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مركز التنبيهات', style: AppTextStyles.headlineMed),
                    const SizedBox(height: 4),
                    Text(
                      notifications.isEmpty 
                          ? 'لا توجد إشعارات حالياً' 
                          : 'لديك $unreadCount تنبيه جديد',
                      style: AppTextStyles.bodyMed.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
                if (notifications.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => ref.read(notificationProvider.notifier).clearAll(),
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: const Text('مسح الكل'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  ),
              ],
            ),
          ),
          const Divider(color: AppColors.borderSubtle),
          
          if (notifications.isEmpty)
            _buildEmptyState()
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final n = notifications[index];
                  return _NotificationItem(n: n, ref: ref);
                },
              ),
            ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Icon(
              Icons.notifications_none_rounded, 
              size: 56, 
              color: AppColors.textMuted.withOpacity(0.4)
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'هدوء تام هنا...', 
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.textSecondary)
          ),
          const SizedBox(height: 8),
          Text(
            'سنخبرك فور حدوث أي جديد في النظام', 
            style: AppTextStyles.bodyMed.copyWith(color: AppColors.textMuted)
          ),
        ],
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final dynamic n;
  final WidgetRef ref;

  const _NotificationItem({required this.n, required this.ref});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: n.isRead ? Colors.transparent : AppColors.gold.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: n.isRead ? AppColors.borderSubtle : AppColors.gold.withOpacity(0.25),
          width: n.isRead ? 1 : 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: n.isRead ? AppColors.surface3 : AppColors.gold.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            n.isRead ? Icons.notifications_outlined : Icons.notifications_active_rounded,
            color: n.isRead ? AppColors.textMuted : AppColors.gold,
            size: 20,
          ),
        ),
        title: Text(
          n.title,
          style: AppTextStyles.titleMed.copyWith(
            color: n.isRead ? AppColors.textSecondary : AppColors.textPrimary,
            fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              n.body, 
              style: AppTextStyles.bodyMed.copyWith(height: 1.4)
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  DateFormat('HH:mm - yyyy/MM/dd').format(n.timestamp),
                  style: AppTextStyles.labelMed.copyWith(fontSize: 10),
                ),
                const Spacer(),
                if (!n.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
        onTap: () {
          ref.read(notificationProvider.notifier).markAsRead(n.id);
        },
      ),
    );
  }
}
