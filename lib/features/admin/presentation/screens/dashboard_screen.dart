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
      appBar: AppBar(
        title: const Text('لوحة التحكم - حرفي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.textMuted),
            tooltip: 'تبديل نوع الحساب',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('user_role');
              if (context.mounted) context.go('/welcome');
            },
          ),
          const NotificationIcon(),
          IconButton(
            onPressed: () => _showLogoutDialog(context),
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(techsStreamProvider);
          ref.invalidate(ordersStreamProvider);
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? screenWidth * 0.05 : AppSpacing.xl,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatsWidget(),
              const SizedBox(height: AppSpacing.xxxl),
              
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // العمود الأيسر (الرئيسي)
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          ordersAsync.when(
                            data: (orders) => RevenueChart(orders: orders),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                          const SizedBox(height: AppSpacing.xxxl),
                          _buildRecentOrders(ordersAsync),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxxl),
                    // العمود الأيمن (الجانبي)
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          _buildQuickActions(context),
                          const SizedBox(height: AppSpacing.xxxl),
                          _buildPendingAlerts(techsAsync),
                          const SizedBox(height: AppSpacing.xxxl),
                          ordersAsync.when(
                            data: (orders) => _RecentReviewsSection(orders: orders),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                // التصميم المعتاد للموبايل
                Column(
                  children: [
                    _buildPendingAlerts(techsAsync),
                    _buildQuickActions(context),
                    const SizedBox(height: AppSpacing.xxxl),
                    ordersAsync.when(
                      data: (orders) => RevenueChart(orders: orders),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    _RecentReviewsSection(orders: ordersAsync.valueOrNull ?? []),
                    const SizedBox(height: AppSpacing.xxxl),
                    _buildRecentOrders(ordersAsync),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الوصول السريع', style: AppTextStyles.headlineMed),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: _QuickActionCard(title: 'الطلبات', icon: Icons.assignment, color: AppColors.info, onTap: () => context.push('/admin/orders'))),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _QuickActionCard(title: 'الفنيين', icon: Icons.people, color: AppColors.success, onTap: () => context.push('/admin/techs'))),
          ],
        ),
      ],
    );
  }

  Widget _buildPendingAlerts(AsyncValue<List<Technician>> techsAsync) {
    return techsAsync.when(
      data: (techs) {
        final pending = techs.where((t) => t.status == TechStatus.pending).toList();
        if (pending.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('طلبات انضمام عاجلة', AppColors.gold, Icons.notification_important),
            const SizedBox(height: AppSpacing.md),
            ...pending.take(2).map((tech) => _PendingTechAlert(tech: tech)),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildRecentOrders(AsyncValue<List<Order>> ordersAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('أحدث الطلبات النشطة', AppColors.textPrimary, Icons.history),
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
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد أنك تريد الخروج من لوحة التحكم؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
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
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
        ] else ...[
          Container(width: 4, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
        ],
        Text(title, style: AppTextStyles.headlineMed.copyWith(color: color)),
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
    if (reviews.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rate_rounded, color: Colors.amber, size: 24),
                const SizedBox(width: 12),
                Text('آخر التقييمات', style: AppTextStyles.headlineMed),
              ],
            ),
            TextButton(onPressed: () {}, child: const Text('الكل')),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...reviews.map((order) => AppCard(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          color: AppColors.surface3,
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: AppColors.surface1, child: Icon(Icons.comment_outlined, size: 18, color: AppColors.gold)),
            title: Text(order.clientName, style: AppTextStyles.titleMed),
            subtitle: Text(order.ratingComment ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${order.rating}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                const Icon(Icons.star, size: 14, color: Colors.amber),
              ],
            ),
            onTap: () => context.push('/admin/order/${order.id}'),
          ),
        )),
      ],
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
        color: AppColors.gold.withValues(alpha: 0.05),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.gold.withValues(alpha: 0.1),
            child: Text(tech.spec.icon),
          ),
          title: Text(tech.name, style: AppTextStyles.titleMed),
          subtitle: Text(tech.spec.label),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.gold),
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
    if (orders.isEmpty) return const Text('لا توجد طلبات مسجلة بعد.');
    
    final recent = orders.where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled).take(5).toList();
    if (recent.isEmpty) return const Text('لا توجد طلبات نشطة حالياً.');
    
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: recent.map((order) {
          final isLast = recent.last == order;
          return Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.surface1,
                  child: Text(order.service.icon),
                ),
                title: Text(order.clientName, style: AppTextStyles.titleMed),
                subtitle: Text(order.status.label, style: TextStyle(color: _getStatusColor(order.status))),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => context.push('/admin/order/${order.id}'),
              ),
              if (!isLast) const Divider(height: 1, indent: 70),
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
      color: AppColors.surface3,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: AppTextStyles.titleMed, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
