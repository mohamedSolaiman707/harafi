import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/domain/models/technician.dart';
import '../../../admin/domain/enums/tech_status.dart';
import '../providers/favorites_provider.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favIds = ref.watch(favoritesProvider);
    final techsAsync = ref.watch(techniciansProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الفنيين المفضلين'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Builder(builder: (context) {
        final techs = techsAsync.valueOrNull;

        if (techs == null && techsAsync.isLoading) {
          return const LoadingWidget();
        }
        if (techs == null) {
          return AppErrorWidget(
            message: 'خطأ في تحميل المفضلين',
            error: techsAsync.error,
            onRetry: () => ref.invalidate(techniciansProvider),
          );
        }

        final favTechs = techs.where((t) => favIds.contains(t.id)).toList();

        if (favTechs.isEmpty) {
          return _buildEmptyState(context);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              child: Text(
                '${favTechs.length} فنيين محفوظين',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold.withOpacity(0.7)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                itemCount: favTechs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: _FavoriteTechCard(tech: favTechs[index]),
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border_rounded, size: 80, color: AppColors.gold.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('قائمة المفضلين فارغة', style: AppTextStyles.headlineMed),
        ],
      ),
    );
  }
}

class _FavoriteTechCard extends ConsumerWidget {
  final Technician tech;
  const _FavoriteTechCard({required this.tech});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dynamic status handling in Arabic
    final (statusColor, statusLabel) = switch (tech.status) {
      TechStatus.available => (Colors.green, 'متاح الآن'),
      TechStatus.busy => (Colors.orange, 'مشغول'),
      TechStatus.onLeave => (Colors.redAccent, 'في إجازة'),
      _ => (AppColors.textMuted, 'غير نشط حالياً'),
    };

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Glassmorphic Background
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface1.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar with status dot
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.gold, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 35,
                              backgroundColor: AppColors.surface3,
                              backgroundImage: tech.photoUrl != null ? NetworkImage(tech.photoUrl!) : null,
                              child: tech.photoUrl == null 
                                ? Text(tech.spec.icon, style: const TextStyle(fontSize: 28)) 
                                : null,
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.surface1, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Info Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tech.name,
                              style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w900, fontSize: 19),
                            ),
                            Text(
                              tech.spec.label,
                              style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            // Stars and Jobs in Arabic
                            Row(
                              children: [
                                Row(
                                  children: List.generate(5, (i) => Icon(
                                    Icons.star_rounded,
                                    color: i < tech.rating.floor() ? Colors.amber : Colors.grey.withOpacity(0.3),
                                    size: 18,
                                  )),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${tech.totalJobs} مهمة مكتملة ',
                                  style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Heart Icon
                      IconButton(
                        onPressed: () => ref.read(favoritesProvider.notifier).toggleFavorite(tech.id),
                        icon: const Icon(Icons.favorite_rounded, color: Colors.red, size: 28),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Bottom Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: AppColors.textMuted, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            tech.area ?? "غير محدد",
                            style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Ripple Effect Overlay
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.push('/tech/portfolio/${tech.id}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
