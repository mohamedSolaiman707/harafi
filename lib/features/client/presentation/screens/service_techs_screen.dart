import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../admin/domain/enums/service_type.dart';
import '../../../admin/domain/enums/tech_status.dart';
import '../../../admin/domain/models/technician.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/smart_match_edge_provider.dart';

final selectedAreaProvider = StateProvider<String>((ref) => 'الكل');

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
    final titleText =
        service != null ? 'فني ${service!.label}' : 'أفضل الفنيين';

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
              : AppSpacing.lg.toDouble();

          return Column(
            children: [
              // ─── Area Filter Bar ───────────────────────────────────────────
              _AreaFilterBar(
                ref: ref,
                selectedArea: selectedArea,
                userLocation: userLocation,
              ),

              // ─── Smart Match VIP Carousel ──────────────────────────────────
              if (service != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(horizontalPad, 16, 0, 0),
                  child: _SmartMatchSection(
                    service: service!,
                    area: selectedArea,
                  ),
                ),

              // ─── Techs List ────────────────────────────────────────────────
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
                      return GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPad,
                          16,
                          horizontalPad,
                          32,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 500,
                          crossAxisSpacing: AppSpacing.lg,
                          mainAxisSpacing: AppSpacing.lg,
                          childAspectRatio: 2.8,
                        ),
                        itemCount: filteredTechs.length,
                        itemBuilder: (context, index) => _TechListItem(
                          tech: filteredTechs[index],
                          service: service,
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        16,
                        horizontalPad,
                        32,
                      ),
                      itemCount: filteredTechs.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TechListItem(
                          tech: filteredTechs[index],
                          service: service,
                        ),
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

    return techs
        .where((tech) {
          final matchesService = service == null || tech.spec == service;
          final visible = tech.status != TechStatus.pending;
          if (!matchesService || !visible) return false;

          if (area == 'الكل') return true;

          final techArea = tech.area?.trim() ?? '';
          if (techArea.isEmpty) return false;

          return _normalize(techArea).contains(_normalize(area)) ||
              _normalize(area).contains(_normalize(techArea)) ||
              (_normalize(techArea) == _normalize(userCity) &&
                  area == userCity);
        })
        .toList()
      ..sort((a, b) {
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

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, String area) {
    final isLocalFilter = area != 'الكل';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.surface1,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Icon(
                Icons.person_search_outlined,
                size: 44,
                color: AppColors.textMuted.withValues(alpha: 0.5),
              ),
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

// ─── Area Filter Bar ──────────────────────────────────────────────────────────
class _AreaFilterBar extends StatelessWidget {
  final WidgetRef ref;
  final String selectedArea;
  final UserLocation userLocation;

  const _AreaFilterBar({
    required this.ref,
    required this.selectedArea,
    required this.userLocation,
  });

  @override
  Widget build(BuildContext context) {
    final governorateCities =
        AppConstants.governoratesAndCities[userLocation.governorate] ?? [];
    final filterAreas = ['الكل', ...governorateCities];

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: filterAreas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final area = filterAreas[index];
          final selected = selectedArea == area;
          return GestureDetector(
            onTap: () => ref.read(selectedAreaProvider.notifier).state = area,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Smart Match VIP Carousel Section ────────────────────────────────────────
class _SmartMatchSection extends ConsumerWidget {
  final ServiceType service;
  final String area;

  const _SmartMatchSection({required this.service, required this.area});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankedAsync = ref.watch(
      smartMatchResultProvider((
        service: service,
        area: area == 'الكل' ? null : area,
        description: null,
        diagnosis: null,
      )),
    );

    if (rankedAsync.isLoading) return const _SmartMatchSkeleton();
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
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.gold,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ترشيحات المساعد الذكي',
                    style: AppTextStyles.titleMed.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'الأفضل بناءً على تقييماتهم وموقعك',
                    style: AppTextStyles.labelMed.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 16),
            itemCount: validItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = validItems[index];
              final tech = techs
                  .where((t) => t.id == item['technicianId']?.toString())
                  .firstOrNull;
              if (tech == null) return const SizedBox.shrink();

              final isTop =
                  item['technicianId']?.toString() ==
                  ranked.recommendedTechnicianId;
              final score =
                  (item['reliabilityScore'] as num?)?.toStringAsFixed(0) ??
                  '0';

              return _VipTechCard(
                tech: tech,
                score: score,
                isTop: isTop,
                service: service,
                fallbackTechIds: ranked.fallbackTechnicianIds,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              const Icon(
                Icons.people_rounded,
                color: AppColors.textMuted,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                'كل الفنيين المتاحين',
                style: AppTextStyles.titleMed.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── VIP Tech Card ────────────────────────────────────────────────────────────
class _VipTechCard extends StatelessWidget {
  final Technician tech;
  final String score;
  final bool isTop;
  final ServiceType service;
  final List<String> fallbackTechIds;

  const _VipTechCard({
    required this.tech,
    required this.score,
    required this.isTop,
    required this.service,
    required this.fallbackTechIds,
  });

  @override
  Widget build(BuildContext context) {
    final hasInsufficientBalance =
        tech.walletBalance < AppConstants.platformFee;
    final isAvailable =
        tech.status == TechStatus.available && !hasInsufficientBalance;

    return GestureDetector(
      onTap: () => context.push('/tech/portfolio/${tech.id}'),
      child: Container(
        width: 195,
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isTop ? AppColors.gold : AppColors.borderSubtle,
            width: isTop ? 1.5 : 1,
          ),
          boxShadow: isTop
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
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
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? AppColors.success
                              : AppColors.warning,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.surface1, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (isTop)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '⭐ الأفضل',
                      style: TextStyle(
                        color: Color(0xFF090D16),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tech.name,
              style: AppTextStyles.titleMed.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star_rounded, color: AppColors.gold, size: 13),
                const SizedBox(width: 3),
                Text(
                  tech.rating.toStringAsFixed(1),
                  style: AppTextStyles.labelMed.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ثقة $score%',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'اطلب الآن',
                icon: Icons.flash_on_rounded,
                variant: isTop ? ButtonVariant.primary : ButtonVariant.secondary,
                size: ButtonSize.sm,
                onTap: () => context.push(
                  '/request',
                  extra: {
                    'service': service,
                    'techId': tech.id,
                    'fallbackTechIds': fallbackTechIds,
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tech List Item ───────────────────────────────────────────────────────────
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
      opacity: isUnavailable ? 0.55 : 1.0,
      child: GestureDetector(
        onTap: isUnavailable
            ? null
            : () => context.push('/tech/portfolio/${tech.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
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
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: effectiveAvailable
                            ? AppColors.success
                            : (effectiveBusy
                                  ? AppColors.warning
                                  : AppColors.textMuted),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.surface1, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Info
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
                            size: 15,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _Badge(label: tech.rank, color: tech.rankColor),
                        _Badge(
                          label: '${tech.spec.icon} ${tech.spec.label}',
                          color: AppColors.gold,
                        ),
                        _Badge(
                          label: isOnLeave
                              ? 'في استراحة'
                              : (hasInsufficientBalance &&
                                          tech.status == TechStatus.available
                                      ? 'غير متاح'
                                      : tech.status.label),
                          color: effectiveAvailable
                              ? AppColors.success
                              : (effectiveBusy
                                    ? AppColors.warning
                                    : AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.gold,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          tech.rating.toStringAsFixed(1),
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.textMuted,
                          size: 13,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          tech.area ?? 'كفر الزيات',
                          style: AppTextStyles.labelMed.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                  SizedBox(
                    width: 88,
                    height: 36,
                    child: AppButton(
                      label: isUnavailable
                          ? 'غير متاح'
                          : (effectiveAvailable ? 'حجز' : 'موعد'),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Badge ────────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── Smart Match Skeleton ─────────────────────────────────────────────────────
class _SmartMatchSkeleton extends StatelessWidget {
  const _SmartMatchSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 160,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 16),
            itemCount: 3,
            itemBuilder: (context, index) => Container(
              width: 195,
              margin: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderSubtle),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
