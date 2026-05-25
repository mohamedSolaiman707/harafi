import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
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
    final sidePadding = isDesktop ? screenWidth * 0.04 : AppSpacing.xl;

    if (techsAsync.hasError || ordersAsync.hasError) {
      return Scaffold(
        body: AppErrorWidget(
          message: 'فشل تحميل بيانات لوحة التحكم',
          error: techsAsync.error ?? ordersAsync.error,
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
            // Header مخصص بدلاً من AppBar التقليدي
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(sidePadding, 48, sidePadding, 32),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'أهلاً بك، يا مدير 👋',
                          style: AppTextStyles.headlineLarge.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'إليك ملخص ما يحدث في حرفي اليوم',
                          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const Spacer(),
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
                    // قسم الإحصائيات الرئيسي
                    const StatsWidget(),
                    const SizedBox(height: AppSpacing.xxxl),
                    
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                _buildChartSection(ordersAsync),
                                const SizedBox(height: AppSpacing.xxxl),
                                _buildRecentOrders(ordersAsync, context),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xxxl),
                          Expanded(
                            flex: 1,
                            child: Column(
                              children: [
                                _buildQuickActions(context),
                                const SizedBox(height: AppSpacing.xxxl),
                                _buildPendingAlerts(techsAsync, context),
                                const SizedBox(height: AppSpacing.xxxl),
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
                          const SizedBox(height: AppSpacing.xxl),
                          _buildQuickActions(context),
                          const SizedBox(height: AppSpacing.xxl),
                          _buildChartSection(ordersAsync),
                          const SizedBox(height: AppSpacing.xxl),
                          _buildRecentReviews(ordersAsync, context),
                          const SizedBox(height: AppSpacing.xxl),
                          _buildRecentOrders(ordersAsync, context),
                        ],
                      ),
                    const SizedBox(height: 60),
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
        Container(
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () => _showLogoutDialog(context),
            icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
            tooltip: 'خروج',
          ),
        ),
      ],
    );
  }

  Widget _buildChartSection(AsyncValue<List<Order>> ordersAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('تحليلات الأرباح', AppColors.info, Icons.insights_rounded),
        const SizedBox(height: AppSpacing.lg),
        ordersAsync.when(
          data: (orders) => RevenueChart(orders: orders),
          loading: () => const LoadingWidget(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('الوصول السريع', AppColors.textPrimary, Icons.bolt_rounded),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: _QuickActionCard(title: 'الطلبات', icon: Icons.assignment_rounded, color: AppColors.info, onTap: () => context.push('/admin/orders'))),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _QuickActionCard(title: 'الفنيين', icon: Icons.people_alt_rounded, color: AppColors.success, onTap: () => context.push('/admin/techs'))),
          ],
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
            _buildSectionHeader('طلبات انضمام معلقة', AppColors.gold, Icons.pending_actions_rounded),
            const SizedBox(height: AppSpacing.lg),
            ...pending.take(2).map((tech) => _PendingTechAlert(tech: tech)),
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
        _buildSectionHeader('آخر التقييمات', Colors.amber, Icons.star_rounded),
        const SizedBox(height: AppSpacing.lg),
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
        _buildSectionHeader('الطلبات الجارية', AppColors.success, Icons.schedule_rounded),
        const SizedBox(height: AppSpacing.lg),
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
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد أنك تريد الخروج من لوحة الإدارة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('user_role');
              if (context.mounted) {
                Navigator.pop(context);
                context.go('/welcome');
              }
            },
            child: const Text('خروج', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color, [IconData? icon]) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
        ],
        Text(title, style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
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
    if (reviews.isEmpty) return const Text('لا توجد تقييمات بعد.');

    return Column(
      children: reviews.map((order) => AppCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        color: AppColors.surface1,
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
            child: const Icon(Icons.comment_rounded, size: 16, color: AppColors.gold),
          ),
          title: Text(order.clientName, style: AppTextStyles.titleMed),
          subtitle: Text(order.ratingComment ?? 'بدون تعليق', maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${order.rating}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
              ],
            ),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        color: AppColors.gold.withOpacity(0.05),
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.gold.withOpacity(0.1),
            child: Text(tech.spec.icon, style: const TextStyle(fontSize: 20)),
          ),
          title: Text(tech.name, style: AppTextStyles.titleMed),
          subtitle: Text(tech.spec.label, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.gold),
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
    if (active.isEmpty) return const Text('لا توجد طلبات نشطة حالياً.');
    
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: active.map((order) {
          final isLast = active.last == order;
          return Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.surface2,
                  child: Text(order.service.icon),
                ),
                title: Text(order.clientName, style: AppTextStyles.titleMed),
                subtitle: Text(order.status.label, style: TextStyle(color: _getStatusColor(order.status), fontSize: 12, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () => context.push('/admin/order/${order.id}'),
              ),
              if (!isLast) const Divider(height: 1, indent: 70, color: AppColors.borderSubtle),
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

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: AppColors.surface1,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppTextStyles.titleMed.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
