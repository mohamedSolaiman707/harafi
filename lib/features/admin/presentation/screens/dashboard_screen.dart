import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../widgets/stats_widget.dart';
import '../providers/techs_provider.dart';
import '../../domain/models/technician.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techsAsync = ref.watch(techniciansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        actions: [
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StatsWidget(),
            const SizedBox(height: AppSpacing.xxxl),
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
            techsAsync.when(
              data: (techs) => TechnicianSummarySection(techs: techs),
              loading: () => const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'حدث خطأ أثناء تحميل بيانات الفنيين',
                  style: AppTextStyles.bodyLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TechnicianSummarySection extends StatelessWidget {
  final List<Technician> techs;
  const TechnicianSummarySection({super.key, required this.techs});

  @override
  Widget build(BuildContext context) {
    if (techs.isEmpty) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'لا يوجد فنيين مسجلين حالياً. أضف فني جديد للبدء.',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1200
        ? 3
        : width > 900
        ? 2
        : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ملخص الفنيين', style: AppTextStyles.headlineLarge),
        const SizedBox(height: AppSpacing.lg),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: techs.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpacing.lg,
            mainAxisSpacing: AppSpacing.lg,
            childAspectRatio: 1.2,
          ),
          itemBuilder: (context, index) {
            return _TechnicianCard(technician: techs[index]);
          },
        ),
      ],
    );
  }
}

class _TechnicianCard extends StatelessWidget {
  final Technician technician;
  const _TechnicianCard({required this.technician});

  @override
  Widget build(BuildContext context) {
    final visitIncome = technician.visitPrice * technician.totalJobs;

    return AppCard(
      color: AppColors.surface3,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  technician.spec.icon,
                  style: const TextStyle(fontSize: 26),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    technician.name,
                    style: AppTextStyles.headlineMed,
                  ),
                ),
                _TechnicianStatusBadge(status: technician.status),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              technician.spec.label,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              runSpacing: AppSpacing.sm,
              spacing: AppSpacing.sm,
              children: [
                _SummaryChip(
                  label: 'الشغلان',
                  value: '${technician.totalJobs}',
                ),
                _SummaryChip(
                  label: 'سعر الزيارة',
                  value: '${technician.visitPrice} ج.م',
                ),
                if (technician.priceRange != null &&
                    technician.priceRange!.isNotEmpty)
                  _SummaryChip(
                    label: 'نطاق الخدمة',
                    value: technician.priceRange!,
                  ),
                _SummaryChip(
                  label: 'دخل زيارات (تقديري)',
                  value: '$visitIncome ج.م',
                ),
                _SummaryChip(
                  label: 'تقييم',
                  value: technician.rating.toStringAsFixed(1),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'السعر النهائي يتحدد بعد زيارة العميل وقياس حجم الشغل.',
              style: AppTextStyles.bodyMed.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TechnicianStatusBadge extends StatelessWidget {
  final dynamic status;
  const _TechnicianStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (status.toString().contains('available')) {
      color = AppColors.success;
    } else if (status.toString().contains('busy')) {
      color = AppColors.info;
    } else {
      color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.labelLarge.copyWith(color: color),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Text(
        '$label: $value',
        style: AppTextStyles.bodyMed.copyWith(color: AppColors.textSecondary),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
