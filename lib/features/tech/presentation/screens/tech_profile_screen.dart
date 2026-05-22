import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../admin/presentation/providers/techs_provider.dart';

class TechProfileScreen extends ConsumerWidget {
  const TechProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techAsync = ref.watch(currentTechnicianProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: techAsync.when(
        data: (tech) {
          if (tech == null) return const Center(child: Text('لم يتم العثور على بيانات الفني'));
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                _buildHeader(tech),
                const SizedBox(height: AppSpacing.xl),
                _buildStatsGrid(tech),
                const SizedBox(height: AppSpacing.xl),
                _buildInfoSection(tech),
                const SizedBox(height: AppSpacing.xxl),
                AppButton(
                  label: 'تسجيل الخروج',
                  variant: ButtonVariant.ghost,
                  onTap: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) context.go('/');
                  },
                ),
              ],
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (err, _) => AppErrorWidget(message: 'حدث خطأ في تحميل البيانات', onRetry: () {}),
      ),
    );
  }

  Widget _buildHeader(dynamic tech) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: AppColors.gold.withValues(alpha: 0.1),
          backgroundImage: tech.photoUrl != null ? NetworkImage(tech.photoUrl!) : null,
          child: tech.photoUrl == null 
            ? Text(tech.spec.icon, style: const TextStyle(fontSize: 40))
            : null,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(tech.name, style: AppTextStyles.displayMedium),
        Text(tech.spec.label, style: AppTextStyles.titleLarge.copyWith(color: AppColors.gold)),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star, color: AppColors.gold, size: 20),
            const SizedBox(width: 4),
            Text('${tech.rating}', style: AppTextStyles.headlineMed),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid(dynamic tech) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'إجمالي الأرباح',
            value: '${tech.totalEarnings} ج.م',
            icon: Icons.payments_outlined,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            label: 'عدد المهام',
            value: '${tech.totalJobs}',
            icon: Icons.task_alt,
            color: AppColors.info,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(dynamic tech) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoTile(label: 'رقم الهاتف', value: tech.phone, icon: Icons.phone_android),
          const Divider(height: AppSpacing.xl),
          _InfoTile(label: 'المنطقة', value: tech.area ?? 'الكل', icon: Icons.location_on_outlined),
          const Divider(height: AppSpacing.xl),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text('نبذة تعريفية', style: AppTextStyles.bodyMed),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tech.bio ?? 'لا يوجد وصف حالياً',
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: color.withValues(alpha: 0.05),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(label, style: AppTextStyles.labelLarge),
          Text(value, style: AppTextStyles.headlineMed.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.bodyMed),
            Text(value, style: AppTextStyles.titleLarge),
          ],
        ),
      ],
    );
  }
}
