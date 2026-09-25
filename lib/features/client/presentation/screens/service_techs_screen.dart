import 'dart:ui';

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
    final titleText =
        service != null ? 'فني ${service!.label}' : 'أفضل الفنيين بالقرب منك';

    return Scaffold(
      backgroundColor: AppColors.background,
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

          return CustomScrollView(
            slivers: [
              // ─── Premium Gradient Header ─────────────────────────────────
              SliverAppBar(
                expandedHeight: 140,
                collapsedHeight: 60,
                pinned: true,
                backgroundColor: AppColors.background,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _GlassIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => context.pop(),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Gradient background
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.background,
                              AppColors.surface1,
                              AppColors.gold.withValues(alpha: 0.08),
                            ],
                          ),
                        ),
                      ),
                      // Decorative glow
                      Positioned(
                        top: -40,
                        right: -40,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.gold.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      // Content
                      Positioned(
                        bottom: 20,
                        left: horizontalPad,
                        right: horizontalPad,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (service != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color:
                                        AppColors.gold.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      service!.icon,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      service!.label,
                                      style: AppTextStyles.labelMed.copyWith(
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              titleText,
                              style: AppTextStyles.displayMedium.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: AppColors.gold,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  userLocation.fullLocation,
                                  style: AppTextStyles.labelMed.copyWith(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Glassmorphism Area Filter ────────────────────────────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyFilterDelegate(
                  child: _AreaFilterBar(
                    ref: ref,
                    selectedArea: selectedArea,
                    userLocation: userLocation,
                  ),
                ),
              ),

              // ─── Smart Match VIP Carousel ─────────────────────────────────
              if (service != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPad,
                      20,
                      0,
                      8,
                    ),
                    child: _SmartMatchSection(
                      service: service!,
                      area: selectedArea,
                    ),
                  ),
                ),

              // ─── Section title ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(horizontalPad, 20, horizontalPad, 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'كل الفنيين المتاحين',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Techs List ───────────────────────────────────────────────
              techsAsync.when(
                data: (techs) {
                  final filteredTechs = _filterTechnicians(
                    techs: techs,
                    selectedArea: selectedArea,
                    userLocation: userLocation,
                    service: service,
                  );

                  if (filteredTechs.isEmpty) {
                    return SliverFillRemaining(
                      child: _buildEmptyState(context, ref, selectedArea),
                    );
                  }

                  if (isDesktop) {
                    return SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        0,
                        horizontalPad,
                        32,
                      ),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 500,
                          crossAxisSpacing: AppSpacing.lg,
                          mainAxisSpacing: AppSpacing.lg,
                          childAspectRatio: 2.8,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _TechListItem(
                            tech: filteredTechs[index],
                            service: service,
                          ),
                          childCount: filteredTechs.length,
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPad,
                      0,
                      horizontalPad,
                      32,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TechListItem(
                            tech: filteredTechs[index],
                            service: service,
                          ),
                        ),
                        childCount: filteredTechs.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: LoadingWidget(),
                ),
                error: (error, stack) => SliverFillRemaining(
                  child: AppErrorWidget(
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
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surface1,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Icon(
                Icons.person_search_outlined,
                size: 48,
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

// ─── Sticky Filter Delegate ───────────────────────────────────────────────────
class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _StickyFilterDelegate({required this.child});

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.85),
            border: Border(
              bottom: BorderSide(
                color: AppColors.borderSubtle.withValues(alpha: 0.6),
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyFilterDelegate oldDelegate) => false;
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

    return SizedBox(
      height: 56,
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
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.gold
                    : AppColors.surface1.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? AppColors.gold
                      : AppColors.borderSubtle,
                  width: selected ? 0 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                area,
                style: AppTextStyles.labelLarge.copyWith(
                  color: selected
                      ? const Color(0xFF090D16)
                      : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
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

// ─── Glass Icon Button ────────────────────────────────────────────────────────
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface1.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 18),
          ),
        ),
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
        // Section Header
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.25),
                      AppColors.gold.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.gold,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ترشيحات المساعد الذكي',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'الأفضل لك بناءً على تقييماتهم وموقعك',
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
        const SizedBox(height: 16),
        // VIP Cards Carousel
        SizedBox(
          height: 185,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 16),
            itemCount: validItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
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
                  (item['reliabilityScore'] as num?)?.toStringAsFixed(0) ?? '0';

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 200,
        decoration: BoxDecoration(
          color: isTop
              ? AppColors.gold.withValues(alpha: 0.06)
              : AppColors.surface1,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isTop
                ? AppColors.gold
                : AppColors.borderSubtle,
            width: isTop ? 1.5 : 1,
          ),
          boxShadow: isTop
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: avatar + status
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.surface2,
                      backgroundImage: tech.photoUrl != null
                          ? NetworkImage(tech.photoUrl!)
                          : null,
                      child: tech.photoUrl == null
                          ? Text(
                              tech.spec.icon,
                              style: const TextStyle(fontSize: 22),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? AppColors.success
                              : AppColors.warning,
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
            // Name
            Text(
              tech.name,
              style: AppTextStyles.titleMed.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Rating + trust
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ثقة $score%',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Book button
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

// ─── Tech List Item (Premium Wide Card) ──────────────────────────────────────
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
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.surface2,
                    backgroundImage: tech.photoUrl != null
                        ? NetworkImage(tech.photoUrl!)
                        : null,
                    child: tech.photoUrl == null
                        ? Text(
                            tech.spec.icon,
                            style: const TextStyle(fontSize: 26),
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
                        border: Border.all(color: AppColors.surface1, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
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
                              fontSize: 15,
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
                    const SizedBox(height: 5),
                    // Badges row
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _Badge(
                          label: tech.rank,
                          color: tech.rankColor,
                        ),
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
                          size: 15,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          tech.rating.toStringAsFixed(1),
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
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
              // Actions column
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
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 90,
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

// ─── Small badge chip ─────────────────────────────────────────────────────────
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

// ─── Smart Match Loading Skeleton ─────────────────────────────────────────────
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 160,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 200,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 185,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 16),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) => Container(
              width: 200,
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: AppColors.surface2,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 120,
                    height: 13,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
