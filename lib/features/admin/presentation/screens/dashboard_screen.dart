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
import '../../domain/enums/tech_status.dart';

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
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded),
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
              
              // قسم التنبيهات العاجلة (Urgent Actions)
              techsAsync.when(
                data: (techs) {
                  final pending = techs.where((t) => t.status == TechStatus.pending).toList();
                  if (pending.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('طلبات انضمام تنتظر موافقتك', AppColors.gold),
                      const SizedBox(height: AppSpacing.md),
                      ...pending.take(3).map((tech) => _PendingTechAlert(tech: tech)),
                      TextButton(
                        onPressed: () => context.push('/admin/techs'),
                        child: const Text('عرض كل الطلبات...'),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

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
              _buildSectionHeader('آخر الإحصائيات', AppColors.textPrimary),
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

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
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

class TechnicianSummarySection extends StatelessWidget {
  final List<Technician> techs;
  const TechnicianSummarySection({super.key, required this.techs});

  @override
  Widget build(BuildContext context) {
    if (techs.isEmpty) return const Text('لا يوجد فنيين مسجلين بعد.');
    
    final approvedTechs = techs.where((t) => t.status != TechStatus.pending).toList();
    
    return AppCard(
      child: Column(
        children: approvedTechs.map((t) => ListTile(
          title: Text(t.name),
          subtitle: Text(t.spec.label),
          trailing: Text('${t.totalEarnings} ج.م', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
        )).toList(),
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
          Icon(icon, size: 32, color: color),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppTextStyles.titleMed),
        ],
      ),
    );
  }
}
