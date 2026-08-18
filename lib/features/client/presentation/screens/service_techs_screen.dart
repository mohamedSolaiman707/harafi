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
import '../../../smart_assistant/domain/entities/smart_diagnosis.dart';
import '../providers/smart_match_edge_provider.dart';
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
          if (service != null) ...[
            const SizedBox(height: 12),
            _buildSmartMatchHeader(ref, service!, selectedArea,context),
          ],

          Expanded(
            child: techsAsync.when(
              data: (techs) {
                // تصفية الفنيين: نظهر المتاح والمشغول والذين في إجازة (استراحة)
                final filteredTechs = techs.where((t) {
                  final matchesService = service == null || t.spec == service;
                  
                  // تعديل هنا: نسمح بظهور الفني حتى لو كان في إجازة (onLeave)
                  final isVisible = t.status != TechStatus.pending;

                  final techArea = t.area?.trim() ?? '';
                  final currentArea = selectedArea.trim();
                  final matchesArea = currentArea == 'الكل' ||
                      techArea == currentArea ||
                      (techArea.isNotEmpty && currentArea.isNotEmpty && (techArea.contains(currentArea) || currentArea.contains(techArea)));

                  return matchesService && isVisible && matchesArea;
                }).toList();

                // فرز ذكي: متاح أولاً -> مشغول -> استراحة آخراً
                filteredTechs.sort((a, b) {
                  int getStatusWeight(TechStatus s) {
                    if (s == TechStatus.available) return 0;
                    if (s == TechStatus.busy) return 1;
                    return 2; // الاستراحة آخراً
                  }
                  
                  final aWeight = getStatusWeight(a.status);
                  final bWeight = getStatusWeight(b.status);
                  
                  if (aWeight != bWeight) return aWeight - bWeight;
                  
                  if (selectedArea == 'الكل') {
                    final aLocal = a.area?.trim() == userLocation.city.trim() ? 0 : 1;
                    final bLocal = b.area?.trim() == userLocation.city.trim() ? 0 : 1;
                    if (aLocal != bLocal) return aLocal - bLocal;
                  }
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

  Widget _buildSmartMatchHeader(WidgetRef ref, ServiceType service, String area, BuildContext context) {
    final rankedAsync = ref.watch(
      smartMatchResultProvider((service: service, area: area == 'الكل' ? null : area, description: null, diagnosis: null)),
    );
    final ranked = rankedAsync.valueOrNull;
    if (ranked == null) {
      return const SizedBox.shrink();
    }

    final top = ranked.topTechnicians.take(3).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    final techs = ref.watch(techniciansProvider).valueOrNull ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        color: AppColors.surface1,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.gold, size: 18),
                const SizedBox(width: 8),
                Text('اقتراحات المساعد الذكي', style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold)),
              ],
            ),
            const SizedBox(height: 10),
            ...top.map((item) {
              final tech = techs.where((t) => t.id == item['technicianId']).firstOrNull;
              if (tech == null) return const SizedBox.shrink();
              final rank = top.indexOf(item) + 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Text('$rank', style: AppTextStyles.labelMed.copyWith(color: AppColors.gold, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tech.name, style: AppTextStyles.bodyLarge),
                          const SizedBox(height: 2),
                          Text(
                            item['reason']?.toString() ?? '',
                            style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text((item['score'] as num?)?.toStringAsFixed(0) ?? '0', style: AppTextStyles.labelMed.copyWith(color: AppColors.gold, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 32,
                          child: AppButton(
                            label: 'اختيار',
                            size: ButtonSize.sm,
                            onTap: () => context.push('/request', extra: {
                              'service': service,
                              'techId': tech.id,
                            }),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
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
    // شرط الرصيد الكافي
    final hasInsufficientBalance = tech.walletBalance < AppConstants.platformFee;
    
    // معالجة الحالة أمام العميل
    final bool effectiveAvailable = tech.status == TechStatus.available && !hasInsufficientBalance;
    final bool effectiveBusy = tech.status == TechStatus.busy || (tech.status == TechStatus.available && hasInsufficientBalance);
    final bool isOnLeave = tech.status == TechStatus.onLeave;
    
    // هل الفني "غير متاح" لأي سبب؟ (رصيد أو استراحة)
    final bool isUnavailable = isOnLeave || (hasInsufficientBalance && tech.status == TechStatus.available);

    final isFav = ref.watch(favoritesProvider).contains(tech.id);

    return Opacity(
      opacity: isUnavailable ? 0.6 : 1.0,
      child: AppCard(
        // تعديل هنا: منع التنقل للملف الشخصي إذا كان غير متاح
        onTap: isUnavailable ? null : () => context.push('/tech/portfolio/${tech.id}'),
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
                          color: effectiveAvailable ? AppColors.success : (effectiveBusy ? AppColors.warning : AppColors.textMuted),
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
                            effectiveAvailable 
                              ? Icons.circle 
                              : (effectiveBusy ? Icons.access_time_filled : Icons.pause_circle_filled_rounded),
                            size: 10,
                            color: effectiveAvailable ? AppColors.success : (effectiveBusy ? AppColors.warning : AppColors.textMuted),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOnLeave 
                              ? 'في استراحة 😴' 
                              : (hasInsufficientBalance && tech.status == TechStatus.available ? 'غير متاح حالياً' : tech.status.label),
                            style: AppTextStyles.labelMed.copyWith(
                              color: effectiveAvailable ? AppColors.success : (effectiveBusy ? AppColors.warning : AppColors.textMuted),
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
                  onPressed: isUnavailable ? null : () => ref.read(favoritesProvider.notifier).toggleFavorite(tech.id),
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
                      label: isUnavailable 
                          ? 'غير متاح حالياً' 
                          : (effectiveAvailable ? 'حجز مباشر' : 'حجز موعد'),
                      size: ButtonSize.sm,
                      icon: isUnavailable 
                          ? Icons.timer_off_outlined 
                          : (effectiveAvailable ? Icons.flash_on_rounded : Icons.event_available),
                      variant: isUnavailable 
                          ? ButtonVariant.ghost 
                          : (effectiveAvailable ? ButtonVariant.primary : ButtonVariant.secondary),
                      onTap: isUnavailable 
                          ? null 
                          : () => context.push(
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
      ),
    );
  }
}
