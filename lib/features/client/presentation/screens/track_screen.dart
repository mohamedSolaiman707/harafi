import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../admin/presentation/providers/orders_provider.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/domain/models/order.dart';
import '../../../admin/domain/enums/order_status.dart';

class TrackScreen extends ConsumerWidget {
  final String code;
  const TrackScreen({super.key, required this.code});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // استخدام StreamProvider لمتابعة الطلب لحظياً
    final ordersStream = ref.watch(ordersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('تتبع حالة الطلب')),
      body: ordersStream.when(
        data: (orders) {
          final order = orders.where((o) => o.trackingCode == code).firstOrNull;
          if (order == null) return _buildNotFound(context);
          return _buildOrderTrackingBody(context, ref, order);
        },
        loading: () => const LoadingWidget(),
        error: (e, s) => AppErrorWidget(message: 'خطأ في التتبع', onRetry: () {}),
      ),
    );
  }

  Widget _buildOrderTrackingBody(BuildContext context, WidgetRef ref, Order order) {
    final techs = ref.watch(techniciansProvider).valueOrNull ?? [];
    final tech = techs.where((t) => t.id == order.techId).firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          _StatusCard(status: order.status),
          const SizedBox(height: AppSpacing.xl),
          if (tech != null) _TechInfoCard(tech: tech),
          const SizedBox(height: AppSpacing.xl),
          _OrderTimeline(currentStatus: order.status),
          const SizedBox(height: AppSpacing.xxl),
          _OrderDetailsCard(order: order),
        ],
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text('عذراً، لم نجد طلباً بهذا الكود'),
          TextButton(onPressed: () => context.go('/'), child: const Text('العودة للرئيسية')),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final OrderStatus status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.gold.withOpacity(0.05),
      child: Column(
        children: [
          Text('حالة طلبك الآن', style: AppTextStyles.bodyMed),
          const SizedBox(height: 8),
          Text(
            status.label,
            style: AppTextStyles.displayMedium.copyWith(color: AppColors.gold),
          ),
        ],
      ),
    );
  }
}

class _TechInfoCard extends StatelessWidget {
  final dynamic tech;
  const _TechInfoCard({required this.tech});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.surface1,
            child: Text(tech.spec.icon, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الفني القادم إليك', style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold)),
                Text(tech.name, style: AppTextStyles.titleLarge),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: AppColors.success),
            onPressed: () => launchUrl(Uri.parse('tel:${tech.phone}')),
          ),
        ],
      ),
    );
  }
}

class _OrderTimeline extends StatelessWidget {
  final OrderStatus currentStatus;
  const _OrderTimeline({required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final stages = [
      OrderStatus.pending,
      OrderStatus.assigned,
      OrderStatus.onTheWay,
      OrderStatus.started,
      OrderStatus.completed,
    ];

    return Column(
      children: stages.map((stage) {
        final isDone = stages.indexOf(currentStatus) >= stages.indexOf(stage);
        final isCurrent = currentStatus == stage;
        
        return Row(
          children: [
            Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isDone ? AppColors.gold : AppColors.surface3,
                    shape: BoxShape.circle,
                    border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
                  ),
                  child: isDone ? const Icon(Icons.check, size: 12, color: Colors.black) : null,
                ),
                if (stage != OrderStatus.completed)
                  Container(width: 2, height: 30, color: isDone ? AppColors.gold : AppColors.surface3),
              ],
            ),
            const SizedBox(width: 16),
            Text(
              stage.label,
              style: AppTextStyles.bodyLarge.copyWith(
                color: isDone ? AppColors.textPrimary : AppColors.textMuted,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _OrderDetailsCard extends StatelessWidget {
  final Order order;
  const _OrderDetailsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surface3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تفاصيل الطلب', style: AppTextStyles.titleLarge),
          const Divider(height: 24),
          _row('نوع الخدمة', order.service.label),
          _row('كود التتبع', order.trackingCode),
          _row('تاريخ الطلب', order.createdAt.toString().split(' ')[0]),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMed),
          Text(value, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
