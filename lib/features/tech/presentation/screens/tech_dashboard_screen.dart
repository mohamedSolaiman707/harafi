import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../admin/presentation/providers/orders_provider.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/domain/enums/order_status.dart';
import '../../../admin/domain/enums/tech_status.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class TechDashboardScreen extends ConsumerWidget {
  const TechDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For now, we'll assume a dummy tech ID or get it from auth
    // In a real scenario, this would come from Supabase Auth
    final techOrdersAsync = ref.watch(ordersStreamProvider); // We'll filter this later or use a specific provider

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الفني'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/tech/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(ordersStreamProvider),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: _buildTechStatusCard(ref),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              sliver: SliverToBoxAdapter(
                child: Text('طلباتك القادمة', style: AppTextStyles.headlineMed),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            ordersAsyncToSliver(techOrdersAsync),
          ],
        ),
      ),
    );
  }

  Widget ordersAsyncToSliver(AsyncValue techOrdersAsync) {
    return techOrdersAsync.when(
      data: (orders) {
        // Filter orders for the current tech (placeholder logic)
        final myOrders = orders.where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled).toList();
        
        if (myOrders.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('لا توجد طلبات معينة لك حالياً')),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final order = myOrders[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
                child: _TechOrderCard(order: order),
              );
            },
            childCount: myOrders.length,
          ),
        );
      },
      loading: () => const SliverFillRemaining(child: LoadingWidget()),
      error: (err, stack) => SliverFillRemaining(
        child: AppErrorWidget(message: 'خطأ في تحميل البيانات', onRetry: () {}),
      ),
    );
  }

  Widget _buildTechStatusCard(WidgetRef ref) {
    return AppCard(
      color: AppColors.surface2,
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.gold,
            child: Icon(Icons.engineering, color: Colors.black),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أهلاً بك يا بطل!', style: AppTextStyles.titleLarge),
                Text('حالتك الآن: متاح', style: AppTextStyles.bodyMed.copyWith(color: AppColors.success)),
              ],
            ),
          ),
          Switch(
            value: true,
            activeColor: AppColors.success,
            onChanged: (val) {},
          ),
        ],
      ),
    );
  }
}

class _TechOrderCard extends StatelessWidget {
  final dynamic order; // Use Order model
  const _TechOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/tech/order/${order.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(order.trackingCode, style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold)),
              ),
              _StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(order.clientName, style: AppTextStyles.titleLarge),
          Text(order.area ?? 'بدون منطقة', style: AppTextStyles.bodyMed),
          const Divider(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'عرض التفاصيل',
                  size: ButtonSize.sm,
                  variant: ButtonVariant.ghost,
                  onTap: () => context.push('/tech/order/${order.id}'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              IconButton(
                icon: const Icon(Icons.phone, color: AppColors.success),
                onPressed: () => launchUrl(Uri.parse('tel:${order.clientPhone}')),
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366)),
                onPressed: () {
                  final uri = WhatsAppUtils.buildUri(order.clientPhone, 'السلام عليكم، أنا الفني من حرافي وبخصوص طلبك...');
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Text(status.label, style: AppTextStyles.labelMed),
    );
  }
}
