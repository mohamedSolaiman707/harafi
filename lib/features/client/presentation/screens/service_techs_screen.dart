import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../admin/domain/enums/service_type.dart';
import '../../../admin/domain/enums/tech_status.dart';
import '../../../admin/domain/models/technician.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/smart_match_edge_provider.dart';

final selectedAreaProvider = StateProvider<String>((ref) => 'الكل');
final smartMatchExpandedProvider = StateProvider<bool>((ref) => false);

class ServiceTechsScreen extends ConsumerWidget {
  final ServiceType? service;

  const ServiceTechsScreen({super.key, this.service});

  static const double _maxContentWidth = 1000.0;
  static const double _desktopBreakpoint = 750.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techsAsync = ref.watch(techniciansProvider);
    final selectedArea = ref.watch(selectedAreaProvider);
    final userLocation = ref.watch(userLocationProvider);
    final titleText = service != null
        ? 'فني ${service!.label}'
        : 'أفضل الفنيين بالقرب منك';

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isDesktop = screenWidth >= _desktopBreakpoint;
          final horizontalPad = isDesktop
              ? ((screenWidth - _maxContentWidth) / 2).clamp(
                  AppSpacing.xl,
                  double.infinity,
                )
              : AppSpacing.xl.toDouble();

          return Column(
            children: [
              // Filter bar — full width always
              _buildAreaFilter(ref, selectedArea, userLocation),
              if (service != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                  child: _buildSmartMatchHeaderInner(
                    ref,
                    service!,
                    selectedArea,
                    context,
                  ),
                ),
              ],
              Expanded(
                child: techsAsync.when(
                  data: (techs) {
                    final filteredTechs = _filterTechnicians(
                      techs: techs,
                      selectedArea: selectedArea,
                      userLocation: userLocation,
                      service: service,
                    );

                    if (filteredTechs.isEmpty) {
                      return _buildEmptyState(context, ref, selectedArea);
                    }

                    if (isDesktop) {
                      // ─── Desktop: responsive 2-col grid ───────────────────
                      return GridView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPad,
                          vertical: AppSpacing.xl,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 480,
                              crossAxisSpacing: AppSpacing.lg,
                              mainAxisSpacing: AppSpacing.lg,
                              childAspectRatio: 2.6,
                            ),
                        itemCount: filteredTechs.length,
                        itemBuilder: (context, index) => _TechListItem(
                          tech: filteredTechs[index],
                          service: service,
                        ),
                      );
                    }

                    // ─── Mobile: single column list ────────────────────────
                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      itemCount: filteredTechs.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.lg),
                      itemBuilder: (context, index) => _TechListItem(
                        tech: filteredTechs[index],
                        service: service,
                      ),
                    );
                  },
                  loading: () => const LoadingWidget(),
                  error: (error, stack) => AppErrorWidget(
                    message: 'خطأ في جلب الفنيين',
                    error: error,
                    onRetry: () => ref.invalidate(techniciansProvider),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Technician> _filterTechnicians({
    required List<Technician> techs,
    required String selectedArea,
    required UserLocation userLocation,
    required ServiceType? service,
  }) {
    final area = selectedArea.trim();
    final userCity = userLocation.city.trim();

    return techs.where((tech) {
      final matchesService = service == null || tech.spec == service;
      final visible = tech.status != TechStatus.pending;
      if (!matchesService || !visible) return false;

      if (area == 'الكل') return true;

      final techArea = tech.area?.trim() ?? '';
      if (techArea.isEmpty) return false;

      return _normalize(techArea).contains(_normalize(area)) ||
          _normalize(area).contains(_normalize(techArea)) ||
          (_normalize(techArea) == _normalize(userCity) && area == userCity);
    }).toList()..sort((a, b) {
      int statusRank(TechStatus status) {
        if (status == TechStatus.available) return 0;
        if (status == TechStatus.busy) return 1;
        return 2;
      }

      final aRank = statusRank(a.status);
      final bRank = statusRank(b.status);
      if (aRank != bRank) return aRank - bRank;
      return b.rating.compareTo(a.rating);
    });
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(' ', '');
  }

  Widget _buildAreaFilter(
    WidgetRef ref,
    String currentArea,
    UserLocation userLocation,
  ) {
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
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 10,
        ),
        itemCount: filterAreas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final area = filterAreas[index];
          final selected = currentArea == area;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => ref.read(selectedAreaProvider.notifier).state = area,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.gold : AppColors.surface2,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? AppColors.gold
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  area,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: selected
                        ? const Color(0xFF090D16)
                        : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSmartMatchHeaderInner(
    WidgetRef ref,
    ServiceType service,
    String area,
    BuildContext context,
  ) {
    final rankedAsync = ref.watch(
      smartMatchResultProvider((
        service: service,
        area: area == 'الكل' ? null : area,
        description: null,
        diagnosis: null,
      )),
    );

    if (rankedAsync.isLoading) {
      return const _SmartMatchSkeleton();
    }

    if (rankedAsync.hasError) return const SizedBox.shrink();

    final ranked = rankedAsync.valueOrNull;
    if (ranked == null) return const SizedBox.shrink();

    final techs = ref.watch(techniciansProvider).valueOrNull ?? [];

    final validItems = ranked.topTechnicians
        .where((item) {
          final techId = item['technicianId']?.toString();
          return techs.any((t) => t.id == techId);
        })
        .take(3)
        .toList();

    if (validItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.gold,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'اقتراحات المساعد الذكي',
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: validItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final item = validItems[index];
              final tech = techs
                  .where((t) => t.id == item['technicianId']?.toString())
                  .firstOrNull;
              if (tech == null) return const SizedBox.shrink();

              final isTopRecommended =
                  item['technicianId']?.toString() ==
                  ranked.recommendedTechnicianId;
              final score =
                  (item['reliabilityScore'] as num?)?.toStringAsFixed(0) ?? '0';

              return Container(
                width: 280,
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isTopRecommended
                        ? AppColors.gold
                        : AppColors.gold.withValues(alpha: 0.2),
                    width: isTopRecommended ? 2 : 1,
                  ),
                  boxShadow: [
                    if (isTopRecommended)
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.1),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.surface2,
                          backgroundImage: tech.photoUrl != null
                              ? NetworkImage(tech.photoUrl!)
                              : null,
                          child: tech.photoUrl == null
                              ? Text(
                                  tech.spec.icon,
                                  style: const TextStyle(fontSize: 20),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tech.name,
                                style: AppTextStyles.titleMed.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: AppColors.gold,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tech.rating.toStringAsFixed(1),
                                    style: AppTextStyles.labelMed.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'ثقة $score%',
                                      style: AppTextStyles.labelMed.copyWith(
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        label: 'اطلب هذا الفني',
                        icon: Icons.flash_on_rounded,
                        variant: isTopRecommended
                            ? ButtonVariant.primary
                            : ButtonVariant.secondary,
                        size: ButtonSize.sm,
                        onTap: () => context.push(
                          '/request',
                          extra: {
                            'service': service,
                            'techId': tech.id,
                            'fallbackTechIds': ranked.fallbackTechnicianIds,
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, String area) {
    final isLocalFilter = area != 'الكل';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 80,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              isLocalFilter
                  ? 'لا يوجد فنيون في $area حاليًا'
                  : 'لا يوجد فنيون متوفرون حاليًا',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              isLocalFilter
                  ? 'الفلتر شغال، لكن لا توجد نتائج مطابقة لهذا الاختيار الآن.'
                  : 'يمكنك عرض فنيين من كل المناطق أو تسجيل طلب عام وسنقوم بتوفير الفني المتاح فورًا.',
              style: AppTextStyles.bodyMed.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (isLocalFilter) ...[
              SizedBox(
                width: 260,
                child: AppButton(
                  label: 'عرض كل المناطق',
                  icon: Icons.public_rounded,
                  variant: ButtonVariant.secondary,
                  onTap: () =>
                      ref.read(selectedAreaProvider.notifier).state = 'الكل',
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

  const _TechListItem({required this.tech, this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasInsufficientBalance =
        tech.walletBalance < AppConstants.platformFee;
    final effectiveAvailable =
        tech.status == TechStatus.available && !hasInsufficientBalance;
    final effectiveBusy =
        tech.status == TechStatus.busy ||
        (tech.status == TechStatus.available && hasInsufficientBalance);
    final isOnLeave = tech.status == TechStatus.onLeave;
    final isUnavailable =
        isOnLeave ||
        (hasInsufficientBalance && tech.status == TechStatus.available);
    final isFav = ref.watch(favoritesProvider).contains(tech.id);

    return Opacity(
      opacity: isUnavailable ? 0.6 : 1.0,
      child: AppCard(
        onTap: isUnavailable
            ? null
            : () => context.push('/tech/portfolio/${tech.id}'),
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
                      backgroundImage: tech.photoUrl != null
                          ? NetworkImage(tech.photoUrl!)
                          : null,
                      child: tech.photoUrl == null
                          ? Text(
                              tech.spec.icon,
                              style: const TextStyle(fontSize: 24),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: effectiveAvailable
                              ? AppColors.success
                              : (effectiveBusy
                                    ? AppColors.warning
                                    : AppColors.textMuted),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface1,
                            width: 2,
                          ),
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
                              style: AppTextStyles.titleLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (tech.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.info,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
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
                                : (effectiveBusy
                                      ? Icons.access_time_filled
                                      : Icons.pause_circle_filled_rounded),
                            size: 10,
                            color: effectiveAvailable
                                ? AppColors.success
                                : (effectiveBusy
                                      ? AppColors.warning
                                      : AppColors.textMuted),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOnLeave
                                ? 'في استراحة 😴'
                                : (hasInsufficientBalance &&
                                          tech.status == TechStatus.available
                                      ? 'غير متاح حاليًا'
                                      : tech.status.label),
                            style: AppTextStyles.labelMed.copyWith(
                              color: effectiveAvailable
                                  ? AppColors.success
                                  : (effectiveBusy
                                        ? AppColors.warning
                                        : AppColors.textMuted),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.gold,
                            size: 16,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            tech.rating.toStringAsFixed(1),
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '📍 ${tech.area ?? "كفر الزيات"}',
                            style: AppTextStyles.labelMed.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: isUnavailable
                      ? null
                      : () => ref
                            .read(favoritesProvider.notifier)
                            .toggleFavorite(tech.id),
                  icon: Icon(
                    isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFav ? Colors.red : AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: AppButton(
                      label: isUnavailable
                          ? 'غير متاح حاليًا'
                          : (effectiveAvailable ? 'حجز مباشر' : 'حجز موعد'),
                      size: ButtonSize.sm,
                      icon: isUnavailable
                          ? Icons.timer_off_outlined
                          : (effectiveAvailable
                                ? Icons.flash_on_rounded
                                : Icons.event_available),
                      variant: isUnavailable
                          ? ButtonVariant.ghost
                          : (effectiveAvailable
                                ? ButtonVariant.primary
                                : ButtonVariant.secondary),
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

// ─── Skeleton شيمر لبطاقة اقتراحات المساعد الذكي ──────────────────────────
class _SmartMatchSkeleton extends StatelessWidget {
  const _SmartMatchSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 180,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              return Container(
                width: 280,
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.1),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.surface2,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 100,
                                height: 14,
                                color: AppColors.surface2,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 60,
                                height: 12,
                                color: AppColors.surface2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: double.infinity,
                      height: 40,
                      color: AppColors.surface2,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
