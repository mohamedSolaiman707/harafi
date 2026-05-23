import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../widgets/stats_widget.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم - حرافي'),
        actions: [
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
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatsWidget(),
              const SizedBox(height: AppSpacing.xxxl),
              
              // 1. التنبيهات العاجلة (الفنيين الجدد بانتظار المراجعة)
              techsAsync.when(
                data: (techs) {
                  final pending = techs.where((t) => t.status == TechStatus.pending).toList();
                  if (pending.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('طلبات انضمام عاجلة', AppColors.gold, Icons.notification_important),
                      const SizedBox(height: AppSpacing.md),
                      ...pending.take(2).map((tech) => _PendingTechAlert(tech: tech)),
                      const SizedBox(height: AppSpacing.xxxl),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // 2. الوصول السريع
              Text('الوصول السريع', style: AppTextStyles.headlineLarge),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      title: 'إدارة الطلبات',
                      icon: Icons.assignment_outlined,
                      color: AppColors.info,
                      onTap: () => context.push('/admin/orders'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: _QuickActionCard(
                      title: 'إدارة الفنيين',
                      icon: Icons.people_outline,
                      color: AppColors.success,
                      onTap: () => context.push('/admin/techs'),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppSpacing.xxxl),

              // 3. أحدث الطلبات (Activity Log)
              _buildSectionHeader('أحدث الطلبات', AppColors.textPrimary, Icons.history),
              const SizedBox(height: AppSpacing.md),
              ordersAsync.when(
                data: (orders) => _RecentOrdersSection(orders: orders),
                loading: () => const LoadingWidget(),
                error: (e, s) => Text('خطأ في تحميل النشاط: $e'),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // 4. ملخص أداء الفنيين
              _buildSectionHeader('أداء الفنيين المعتمدين', AppColors.textPrimary, Icons.analytics_outlined),
              const SizedBox(height: AppSpacing.md),
              techsAsync.when(
                data: (techs) => TechnicianSummarySection(techs: techs),
                loading: () => const LoadingWidget(),
                error: (e, s) => Text('خطأ في تحميل ملخص الفنيين: $e'),
              ),
            ],
          ),
        ),
      ),
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
              if (context.mounted) context.go('/login');
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

class _PendingTechAlert extends StatelessWidget {
  final Technician tech;
  const _PendingTechAlert({required this.tech});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.gold.withValues(alpha: 0.05),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.gold.withValues(alpha: 0.1),
          child: Text(tech.spec.icon),
        ),
        title: Text(tech.name, style: AppTextStyles.titleLarge),
        subtitle: Text('تخصص ${tech.spec.label} • ${tech.phone}'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.gold),
        onTap: () => context.push('/admin/techs'),
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
    
    final recent = orders.take(5).toList();
    
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
                subtitle: Text(order.status.label),
                trailing: Text(
                  '${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                  style: AppTextStyles.labelMed,
                ),
                onTap: () => context.push('/admin/orders'),
              ),
              if (!isLast) const Divider(height: 1, indent: 70),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class TechnicianSummarySection extends StatelessWidget {
  final List<Technician> techs;
  const TechnicianSummarySection({super.key, required this.techs});

  @override
  Widget build(BuildContext context) {
    final approvedTechs = techs.where((t) => t.status != TechStatus.pending).toList();
    if (approvedTechs.isEmpty) return const Text('لا يوجد فنيين معتمدين بعد.');
    
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: approvedTechs.map((t) {
          final isLast = approvedTechs.last == t;
          return Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.surface1,
                  child: Text(t.spec.icon),
                ),
                title: Text(t.name, style: AppTextStyles.titleMed),
                subtitle: Text('${t.spec.label} • ${t.totalJobs} مهمة'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${t.totalEarnings} ج.م', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 12),
                        Text(' ${t.rating.toStringAsFixed(1)}', style: AppTextStyles.labelMed),
                      ],
                    ),
                  ],
                ),
                onTap: () => context.push('/admin/techs'),
              ),
              if (!isLast) const Divider(height: 1, indent: 70),
            ],
          );
        }).toList(),
      ),
    );
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
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
