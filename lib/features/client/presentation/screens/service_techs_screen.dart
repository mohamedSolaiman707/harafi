import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../admin/domain/enums/service_type.dart';
import '../../../admin/domain/enums/tech_status.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/domain/models/technician.dart';
import '../providers/favorites_provider.dart';

final selectedAreaProvider = StateProvider.autoDispose<String>((ref) => 'الكل');

class ServiceTechsScreen extends ConsumerWidget {
  final ServiceType service;
  const ServiceTechsScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techsAsync = ref.watch(techniciansProvider);
    final selectedArea = ref.watch(selectedAreaProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('فنيو ${service.label}'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildAreaFilter(ref, selectedArea),
          
          Expanded(
            child: techsAsync.when(
              data: (techs) {
                final filteredTechs = techs.where((t) {
                  final matchesService = t.spec == service;
                  final isApproved = t.status != TechStatus.pending;
                  final matchesArea = selectedArea == 'الكل' || t.area == selectedArea;
                  return matchesService && isApproved && matchesArea;
                }).toList();
                
                if (filteredTechs.isEmpty) {
                  return _buildEmptyState(context, selectedArea);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  itemCount: filteredTechs.length,
                  itemBuilder: (context, index) => _TechListItem(tech: filteredTechs[index]),
                );
              },
              loading: () => const LoadingWidget(),
              error: (e, s) => AppErrorWidget(
                message: 'خطأ في جلب الفنيين',
                error: e,
                onRetry: () => ref.invalidate(techniciansProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaFilter(WidgetRef ref, String currentArea) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: const Border(bottom: BorderSide(color: AppColors.borderDefault)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: AppConstants.areas.length,
        itemBuilder: (context, index) {
          final area = AppConstants.areas[index];
          final isSelected = currentArea == area;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(area),
              selected: isSelected,
              onSelected: (val) {
                if (val) ref.read(selectedAreaProvider.notifier).state = area;
              },
              selectedColor: AppColors.gold.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.gold : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String area) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 80, color: AppColors.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 24),
          Text(
            area == 'الكل' 
              ? 'عذراً، لا يوجد فنيون حالياً لهذه الخدمة' 
              : 'لا يوجد فنيون في منطقة ($area) حالياً',
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.push('/request', extra: service),
            child: const Text('يمكنك تسجيل طلب عام وسنقوم بتوفير فني لك'),
          ),
        ],
      ),
    );
  }
}

class _TechListItem extends ConsumerWidget {
  final Technician tech;
  const _TechListItem({required this.tech});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAvailable = tech.status == TechStatus.available;
    final isFav = ref.watch(favoritesProvider).contains(tech.id);

    return AppCard(
      onTap: () => context.push('/tech/portfolio/${tech.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: AppColors.surface1,
                backgroundImage: tech.photoUrl != null ? NetworkImage(tech.photoUrl!) : null,
                child: tech.photoUrl == null ? Text(tech.spec.icon, style: const TextStyle(fontSize: 28)) : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: isAvailable ? AppColors.success : AppColors.textMuted,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface3, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              tech.name, 
                              style: AppTextStyles.titleLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (tech.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, color: AppColors.info, size: 16),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => ref.read(favoritesProvider.notifier).toggleFavorite(tech.id),
                      icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.red : AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(tech.rating.toStringAsFixed(1), style: AppTextStyles.labelLarge),
                    const SizedBox(width: 12),
                    Text('📍 ${tech.area ?? "كفر الزيات"}', style: AppTextStyles.labelMed.copyWith(color: AppColors.gold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isAvailable ? 'متاح الآن' : 'مشغول حالياً',
                  style: AppTextStyles.labelMed.copyWith(
                    color: isAvailable ? AppColors.success : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.gold),
        ],
      ),
    );
  }
}
