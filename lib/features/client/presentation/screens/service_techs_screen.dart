import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../admin/domain/enums/service_type.dart';
import '../../../admin/domain/enums/tech_status.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/domain/models/technician.dart';
import '../providers/favorites_provider.dart';

// يبدأ بمدينة العميل — يمكنه التوسع لـ "الكل" بنفسه
final selectedAreaProvider = StateProvider.autoDispose<String>((ref) {
  final userLocation = ref.watch(userLocationProvider);
  return userLocation.city; // يبدأ بمدينة العميل تلقائياً
});

class ServiceTechsScreen extends ConsumerWidget {
  final ServiceType? service;
  const ServiceTechsScreen({super.key, this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techsAsync = ref.watch(techniciansProvider);
    final selectedArea = ref.watch(selectedAreaProvider);
    final userLocation = ref.watch(userLocationProvider);
    final width = MediaQuery.of(context).size.width;

    final titleText = service != null ? 'فنيو ${service!.label}' : 'أمهر الفنيين بالقرب منك';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          children: [
            Text(titleText),
            Text(
              '📍 ${userLocation.fullLocation}',
              style: AppTextStyles.labelMed.copyWith(color: AppColors.gold),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(techniciansProvider);
          await ref.read(techniciansProvider.future);
        },
        child: Column(
          children: [
          _buildAreaFilter(ref, selectedArea, userLocation),

          Expanded(
            child: techsAsync.when(
              data: (techs) {
                // تصفية الفنيين المعتمدين والمطابقين للخدمة
                final filteredTechs = techs.where((t) {
                  final matchesService = service == null || t.spec == service;
                  final isApproved = t.status != TechStatus.pending &&
                      t.walletBalance >= AppConstants.platformFee;

                  // "الكل" → لا قيد جغرافي
                  // مدينة محددة → مطابقة مرنة ومباشرة
                  final techArea = t.area?.trim() ?? '';
                  final currentArea = selectedArea.trim();
                  final matchesArea = currentArea == 'الكل' ||
                      techArea == currentArea ||
                      (techArea.isNotEmpty && currentArea.isNotEmpty && (techArea.contains(currentArea) || currentArea.contains(techArea)));

                  return matchesService && isApproved && matchesArea;
                }).toList();

                // فرز ذكي: متاح أولاً → فنيي مدينة العميل → أعلى تقييم
                filteredTechs.sort((a, b) {
                  // 1. المتاحون أولاً
                  final aAvail = a.status == TechStatus.available ? 0 : 1;
                  final bAvail = b.status == TechStatus.available ? 0 : 1;
                  if (aAvail != bAvail) return aAvail - bAvail;
                  // 2. فنيو مدينة العميل قبل الباقين (في حالة "الكل")
                  if (selectedArea == 'الكل') {
                    final aLocal = a.area?.trim() == userLocation.city.trim() ? 0 : 1;
                    final bLocal = b.area?.trim() == userLocation.city.trim() ? 0 : 1;
                    if (aLocal != bLocal) return aLocal - bLocal;
                  }
                  // 3. أعلى تقييم
                  return b.rating.compareTo(a.rating);
                });

                if (filteredTechs.isEmpty) {
                  return _buildEmptyState(context, ref, selectedArea, userLocation);
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
                        mainAxisExtent: 175,
                      ),
                      itemCount: filteredTechs.length,
                      itemBuilder: (context, index) => _TechListItem(
                        tech: filteredTechs[index],
                        service: service,
                      ),
                    ),
                  ),
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
    ));
  }



  Widget _buildAreaFilter(WidgetRef ref, String currentArea, UserLocation userLocation) {
    // مدن محافظة العميل المختار + الكل
    final governorateCities =
        AppConstants.governoratesAndCities[userLocation.governorate] ?? [];
    final filterAreas = ['الكل', ...governorateCities];

    return Container(
      height: 60,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
        itemCount: filterAreas.length,
        itemBuilder: (context, index) {
          final area = filterAreas[index];
          final isSelected = currentArea == area;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(area),
              selected: isSelected,
              onSelected: (val) {
                if (val) ref.read(selectedAreaProvider.notifier).state = area;
              },
              selectedColor: AppColors.gold,
              backgroundColor: AppColors.surface2,
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF090D16) : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, String area, UserLocation userLocation) {
    final isLocalFilter = area != 'الكل';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_outlined, size: 80, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 24),
            Text(
              isLocalFilter
                  ? 'لا يوجد فنيون في ($area) حالياً'
                  : 'لا يوجد فنيون متوفرون حالياً',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              isLocalFilter
                  ? 'جرّب عرض فنيين من مناطق أخرى قريبة'
                  : 'يمكنك تسجيل طلب عام وسنقوم بتوفير الفني المتاح فوراً',
              style: AppTextStyles.bodyMed.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // زر "عرض كل المناطق" لو الفلتر على مدينة محددة
            if (isLocalFilter) ...[
              SizedBox(
                width: 260,
                child: AppButton(
                  label: 'عرض فنيي كل المناطق',
                  icon: Icons.public_rounded,
                  variant: ButtonVariant.secondary,
                  onTap: () => ref.read(selectedAreaProvider.notifier).state = 'الكل',
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: 260,
              child: AppButton(
                label: 'طلب خدمة الآن',
                icon: Icons.add_task_rounded,
                onTap: () => context.push('/request', extra: service),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TechListItem extends ConsumerWidget {
  final Technician tech;
  final ServiceType? service;

  const _TechListItem({
    required this.tech,
    this.service,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAvailable = tech.status == TechStatus.available;
    final isFav = ref.watch(favoritesProvider).contains(tech.id);

    return AppCard(
      onTap: () => context.push('/tech/portfolio/${tech.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.surface2,
                    backgroundImage: tech.photoUrl != null ? NetworkImage(tech.photoUrl!) : null,
                    child: tech.photoUrl == null ? Text(tech.spec.icon, style: const TextStyle(fontSize: 24)) : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isAvailable ? AppColors.success : (tech.status == TechStatus.busy ? AppColors.warning : AppColors.textMuted),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface1, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            tech.name,
                            style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tech.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, color: AppColors.info, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: tech.rankColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tech.rank,
                            style: AppTextStyles.labelMed.copyWith(
                              color: tech.rankColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${tech.spec.icon} ${tech.spec.label}',
                            style: AppTextStyles.labelMed.copyWith(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          isAvailable ? Icons.circle : Icons.pause_circle_outline,
                          size: 10,
                          color: isAvailable ? AppColors.success : AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAvailable ? 'متاح' : 'مشغول',
                          style: AppTextStyles.labelMed.copyWith(
                            color: isAvailable ? AppColors.success : AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.gold, size: 16),
                        const SizedBox(width: 2),
                        Text(tech.rating.toStringAsFixed(1), style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        Text('📍 ${tech.area ?? "كفر الزيات"}', style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => ref.read(favoritesProvider.notifier).toggleFavorite(tech.id),
                icon: Icon(
                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFav ? Colors.red : AppColors.textMuted,
                  size: 20,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: AppButton(
                    label: 'حجز مباشر',
                    size: ButtonSize.sm,
                    icon: Icons.flash_on_rounded,
                    onTap: () => context.push(
                      '/request',
                      extra: {
                        'service': service ?? tech.spec,
                        'techId': tech.id,
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
