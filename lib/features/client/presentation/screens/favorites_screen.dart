import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../providers/favorites_provider.dart';
import '../screens/service_techs_screen.dart'; // سنستخدم الـ TechListItem منه

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favIds = ref.watch(favoritesProvider);
    final techsAsync = ref.watch(techniciansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الفنيين المفضلين'),
        centerTitle: true,
      ),
      body: techsAsync.when(
        data: (techs) {
          final favTechs = techs.where((t) => favIds.contains(t.id)).toList();

          if (favTechs.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.xl),
            itemCount: favTechs.length,
            itemBuilder: (context, index) {
              final tech = favTechs[index];
              // إدراج الـ _TechListItem يدوياً هنا لضمان التوافق
              return _FavoriteTechItem(tech: tech);
            },
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, s) => AppErrorWidget(
          message: 'خطأ في تحميل المفضلين',
          error: e,
          onRetry: () => ref.invalidate(techniciansProvider),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border_rounded, size: 80, color: AppColors.textMuted.withValues(alpha: 0.3)),
          const SizedBox(height: 24),
          const Text('قائمة المفضلين فارغة حالياً'),
          const SizedBox(height: 8),
          Text(
            'احفظ الفنيين الذين نالوا إعجابك للوصول إليهم لاحقاً',
            style: AppTextStyles.bodyMed,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('تصفح الخدمات'),
          ),
        ],
      ),
    );
  }
}

class _FavoriteTechItem extends ConsumerWidget {
  final dynamic tech; // Technician
  const _FavoriteTechItem({required this.tech});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: () => context.push('/tech/portfolio/${tech.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.surface1,
            backgroundImage: tech.photoUrl != null ? NetworkImage(tech.photoUrl!) : null,
            child: tech.photoUrl == null ? Text(tech.spec.icon, style: const TextStyle(fontSize: 24)) : null,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tech.name, style: AppTextStyles.titleLarge),
                Text(tech.spec.label, style: AppTextStyles.labelMed.copyWith(color: AppColors.gold)),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    Text(' ${tech.rating.toStringAsFixed(1)}', style: AppTextStyles.labelLarge),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.red),
            onPressed: () => ref.read(favoritesProvider.notifier).toggleFavorite(tech.id),
          ),
        ],
      ),
    );
  }
}
