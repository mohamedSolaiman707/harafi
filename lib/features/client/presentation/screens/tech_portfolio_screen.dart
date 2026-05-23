import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/domain/models/technician.dart';

class TechPortfolioScreen extends ConsumerWidget {
  final String techId;
  const TechPortfolioScreen({super.key, required this.techId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techsAsync = ref.watch(techniciansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي للفني')),
      body: techsAsync.when(
        data: (techs) {
          final tech = techs.where((t) => t.id == techId).firstOrNull;
          if (tech == null) return const Center(child: Text('تعذر العثور على بيانات الفني'));
          return _PortfolioBody(tech: tech);
        },
        loading: () => const LoadingWidget(),
        error: (e, s) => Center(child: Text('خطأ: $e')),
      ),
    );
  }
}

class _PortfolioBody extends StatelessWidget {
  final Technician tech;
  const _PortfolioBody({required this.tech});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: AppSpacing.xxl),
          _buildStatsRow(),
          const SizedBox(height: AppSpacing.xxl),
          _buildBioSection(),
          const SizedBox(height: AppSpacing.xxl),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: AppColors.gold.withValues(alpha: 0.1),
          backgroundImage: tech.photoUrl != null ? NetworkImage(tech.photoUrl!) : null,
          child: tech.photoUrl == null 
              ? Text(tech.spec.icon, style: const TextStyle(fontSize: 48))
              : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(tech.name, style: AppTextStyles.displayMedium),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            tech.spec.label,
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.gold, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatItem(label: 'التقييم', value: tech.rating.toStringAsFixed(1), icon: Icons.star, color: Colors.amber),
        _StatItem(label: 'عملية ناجحة', value: tech.totalJobs.toString(), icon: Icons.verified_user, color: AppColors.success),
        _StatItem(label: 'سعر الزيارة', value: '${tech.visitPrice} ج.م', icon: Icons.payments, color: AppColors.info),
      ],
    );
  }

  Widget _buildBioSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Text('عن الفني وخبراته', style: AppTextStyles.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            tech.bio ?? 'هذا الفني خبير معتمد في شبكة حرافي، يلتزم بتقديم أفضل جودة وأسرع استجابة لعملائنا.',
            style: AppTextStyles.bodyLarge.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        const Text(
          'يمكنك التواصل مع الفني مباشرة بمجرد وصوله أو للتنسيق',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                onPressed: () => launchUrl(Uri.parse('tel:${tech.phone}')),
                icon: const Icon(Icons.phone),
                label: const Text('اتصال مباشر'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: AppTextStyles.headlineMed),
        Text(label, style: AppTextStyles.labelMed),
      ],
    );
  }
}
