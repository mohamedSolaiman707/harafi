import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../providers/favorites_provider.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favIds = ref.watch(favoritesProvider);
    final techsAsync = ref.watch(techniciansProvider);
    final width = MediaQuery.of(context).size.width;

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

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.xl),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: width > 1200 ? 3 : (width > 800 ? 2 : 1),
                  crossAxisSpacing: AppSpacing.lg,
                  mainAxisSpacing: AppSpacing.lg,
                  mainAxisExtent: 140,
                ),
                itemCount: favTechs.length,
                itemBuilder: (context, index) {
                  return _FavoriteTechItem(tech: favTechs[index]);
                },
              ),
            ),
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
  final dynamic tech;
  const _FavoriteTechItem({required this.tech});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: () => context.push('/tech/portfolio/${tech.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.surface1,
            backgroundImage: tech.photoUrl != null ? NetworkImage(tech.photoUrl!) : null,
            child: tech.photoUrl == null ? Text(tech.spec.icon, style: const TextStyle(fontSize: 24)) : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tech.name, 
                        style: AppTextStyles.titleMed,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (tech.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: AppColors.info, size: 14),
                    ],
                  ],
                ),
                Text(tech.spec.label, style: AppTextStyles.labelMed.copyWith(color: AppColors.gold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(tech.rating.toStringAsFixed(1), style: AppTextStyles.labelLarge),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.red, size: 20),
            onPressed: () => ref.read(favoritesProvider.notifier).toggleFavorite(tech.id),
          ),
        ],
      ),
    );
  }
}
