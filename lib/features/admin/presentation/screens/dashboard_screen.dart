import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/notification_icon.dart';
import '../widgets/stats_widget.dart';
import '../widgets/revenue_chart.dart';
import '../providers/techs_provider.dart';
import '../providers/orders_provider.dart';
import '../../domain/models/technician.dart';
import '../../domain/models/order.dart';
import '../../domain/enums/tech_status.dart';
import '../../domain/enums/order_status.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techsAsync = ref.watch(techsStreamProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1100;
    final sidePadding = isDesktop ? screenWidth * 0.04 : AppSpacing.lg;

    if (techsAsync.hasError || ordersAsync.hasError) {
      final error = techsAsync.error ?? ordersAsync.error;
      return Scaffold(
        body: AppErrorWidget(
          message: AppErrorHandler.translate(error!),
          error: error,
          onRetry: () {
            ref.invalidate(techsStreamProvider);
            ref.invalidate(ordersStreamProvider);
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async {
          ref.invalidate(techsStreamProvider);
          ref.invalidate(ordersStreamProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(sidePadding, 48, sidePadding, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'لوحة التحكم',
                            style: AppTextStyles.displayMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1.2,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'تحديث مباشر للنظام',
                                style: AppTextStyles.bodyMed.copyWith(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildTopActions(context),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: sidePadding),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const StatsWidget(),
                    const SizedBox(height: AppSpacing.lg),

                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                _buildChartSection(ordersAsync),
                                const SizedBox(height: AppSpacing.lg),
                                _buildRecentOrders(ordersAsync, context),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            flex: 1,
                            child: Column(
                              children: [
                                _buildPendingAlerts(techsAsync, context),
                                const SizedBox(height: AppSpacing.lg),
                                _buildRecentReviews(ordersAsync, context),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildPendingAlerts(techsAsync, context),
                          const SizedBox(height: AppSpacing.md),
                          _buildChartSection(ordersAsync),
                          const SizedBox(height: AppSpacing.md),
                          _buildRecentReviews(ordersAsync, context),
                          const SizedBox(height: AppSpacing.md),
                          _buildRecentOrders(ordersAsync, context),
                        ],
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopActions(BuildContext context) {
    return Row(
      children: [
        const NotificationIcon(),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => _showLogoutDialog(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildChartSection(AsyncValue<List<Order>> ordersAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('تحليلات النشاط', AppColors.info, Icons.analytics_rounded),
        const SizedBox(height: AppSpacing.md),
        ordersAsync.when(
          data: (orders) => RevenueChart(orders: orders),
          loading: () => const LoadingWidget(),
          error: (e, __) => Center(child: Text(AppErrorHandler.translate(e), style: const TextStyle(color: AppColors.textMuted))),
        ),
      ],
    );
  }

  Widget _buildPendingAlerts(AsyncValue<List<Technician>> techsAsync, BuildContext context) {
    return techsAsync.when(
      data: (techs) {
        final pending = techs.where((t) => t.status == TechStatus.pending).toList();
        if (pending.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('طلبات التوثيق', AppColors.gold, Icons.verified_user_rounded),
            const SizedBox(height: AppSpacing.md),
            ...pending.take(3).map((tech) => _PendingTechAlert(tech: tech)),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildRecentReviews(AsyncValue<List<Order>> ordersAsync, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('أحدث تقييمات العملاء', Colors.amber, Icons.star_rounded),
        const SizedBox(height: AppSpacing.md),
        ordersAsync.when(
          data: (orders) => _RecentReviewsSection(orders: orders),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildRecentOrders(AsyncValue<List<Order>> ordersAsync, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('العمليات الجارية', AppColors.success, Icons.sync_rounded),
        const SizedBox(height: AppSpacing.md),
        ordersAsync.when(
          data: (orders) => _RecentOrdersSection(orders: orders),
          loading: () => const LoadingWidget(),
          error: (e, s) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تسجيل الخروج', textAlign: TextAlign.center),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من النظام الإداري؟', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error.withOpacity(0.1), foregroundColor: AppColors.error, elevation: 0),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('user_role');
              if (context.mounted) { Navigator.pop(context); context.go('/welcome'); }
            },
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title, style: AppTextStyles.titleMed.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.1)),
      ],
    );
  }
}

class _RecentReviewsSection extends StatelessWidget {
  final List<Order> orders;
  const _RecentReviewsSection({required this.orders});
  @override
  Widget build(BuildContext context) {
    final reviews = orders.where((o) => o.rating != null && o.rating! > 0).take(3).toList();
    if (reviews.isEmpty) return const Text('لا توجد تقييمات حديثة.', style: TextStyle(color: AppColors.textMuted));
    return Column(
      children: reviews.map((order) => AppCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        color: AppColors.surface1,
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          leading: const CircleAvatar(radius: 16, backgroundColor: AppColors.surface2, child: Icon(Icons.person_outline_rounded, size: 16, color: AppColors.textSecondary)),
          title: Text(order.clientName, style: AppTextStyles.titleMed),
          subtitle: Text(order.ratingComment ?? 'لا يوجد تعليق', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyMed),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Text('${order.rating}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(width: 2), const Icon(Icons.star_rounded, size: 12, color: Colors.amber)]),
          ),
          onTap: () => context.push('/admin/order/${order.id}'),
        ),
      )).toList(),
    );
  }
}

class _PendingTechAlert extends StatelessWidget {
  final Technician tech;
  const _PendingTechAlert({required this.tech});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        color: AppColors.surface1,
        padding: EdgeInsets.zero,
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          leading: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(tech.spec.icon, style: const TextStyle(fontSize: 16))),
          title: Text(tech.name, style: AppTextStyles.titleMed),
          subtitle: Text(tech.spec.label, style: AppTextStyles.labelMed.copyWith(color: AppColors.gold)),
          trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
          onTap: () => context.push('/admin/techs'),
        ),
      ),
    );
  }
}

class _RecentOrdersSection extends StatelessWidget {
  final List<Order> orders;
  const _RecentOrdersSection({required this.orders});
  @override
  Widget build(BuildContext context) {
    final active = orders.where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled).take(5).toList();
    if (active.isEmpty) return const Text('لا توجد عمليات جارية حالياً.', style: TextStyle(color: AppColors.textMuted));
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: active.map((order) {
          final isLast = active.last == order;
          return Column(
            children: [
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                leading: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)), child: Text(order.service.icon, style: const TextStyle(fontSize: 16))),
                title: Text(order.clientName, style: AppTextStyles.titleMed),
                subtitle: Text(order.status.label, style: TextStyle(color: _getStatusColor(order.status), fontSize: 11, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                onTap: () => context.push('/admin/order/${order.id}'),
              ),
              if (!isLast) const Divider(height: 1, indent: 54, color: AppColors.borderSubtle),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending: return AppColors.gold;
      case OrderStatus.assigned: return AppColors.info;
      case OrderStatus.onTheWay: return Colors.orange;
      case OrderStatus.started: return Colors.blue;
      default: return AppColors.textSecondary;
    }
  }
}
