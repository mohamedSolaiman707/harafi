import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../admin/domain/enums/service_type.dart';

final landingStatsProvider = FutureProvider<Map<String, String>>((ref) async {
  try {
    final supabase = Supabase.instance.client;

    // 1. Real technicians count
    final techRes = await supabase.from('technicians_public').select('id');
    final techCount = (techRes as List).length;

    // 2. Real completed & total orders count
    final ordersRes = await supabase.from('orders').select('id, status');
    final ordersList = ordersRes as List;
    final completedCount = ordersList
        .where((o) => o['status'] == 'completed')
        .length;
    final totalCount = ordersList.length;

    // 3. Real average satisfaction rating
    final ratingRes = await supabase
        .from('technicians_public')
        .select('rating');
    final ratingList = ratingRes as List;
    double avgRating = 4.9;
    if (ratingList.isNotEmpty) {
      double sum = 0;
      int count = 0;
      for (var r in ratingList) {
        final val = (r['rating'] as num?)?.toDouble();
        if (val != null && val > 0) {
          sum += val;
          count++;
        }
      }
      if (count > 0) avgRating = sum / count;
    }

    final realTechDisplay = techCount > 0 ? techCount : 15;
    final realCompletedDisplay = completedCount > 0
        ? completedCount
        : (totalCount > 0 ? totalCount : 24);
    final realSatisfactionDisplay = (avgRating / 5.0 * 100)
        .clamp(95.0, 99.9)
        .toStringAsFixed(1);

    return {
      'techCount': '+$realTechDisplay',
      'completedCount': '+$realCompletedDisplay',
      'satisfactionRate': '$realSatisfactionDisplay%',
    };
  } catch (_) {
    return {
      'techCount': '+15',
      'completedCount': '+24',
      'satisfactionRate': '99.2%',
    };
  }
});

void _navigateToClientRoute(BuildContext context, String path) {
  SharedPreferences.getInstance().then((prefs) {
    prefs.setString('user_role', 'client');
  });
  if (context.mounted) {
    context.push(path);
  }
}

void _navigateToTechRoute(BuildContext context, String path) {
  SharedPreferences.getInstance().then((prefs) {
    prefs.setString('user_role', 'tech');
  });
  if (context.mounted) {
    context.push(path);
  }
}

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _servicesKey = GlobalKey();
  final GlobalKey _howItWorksKey = GlobalKey();
  final GlobalKey _whyKey = GlobalKey();
  final GlobalKey _techKey = GlobalKey();

  void _scrollToKey(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final topInset = MediaQuery.paddingOf(context).top;
    final isMobile = screenWidth < 800;
    final headerBodyHeight = isMobile ? 56.0 : 80.0;
    final headerTotalHeight = headerBodyHeight + topInset;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  SizedBox(height: headerTotalHeight),
                  _LandingHero(
                    isMobile: isMobile,
                    onBookTap: () =>
                        _navigateToClientRoute(context, '/request'),
                    onTechJoinTap: () =>
                        _navigateToTechRoute(context, '/tech/register'),
                  ),
                  _LandingServices(
                    key: _servicesKey,
                    isMobile: isMobile,
                    onServiceTap: (service) => _navigateToClientRoute(
                      context,
                      '/service/${service.name}',
                    ),
                  ),
                  _LandingHowItWorks(key: _howItWorksKey, isMobile: isMobile),
                  _LandingTrustBadges(key: _whyKey, isMobile: isMobile),
                  _LandingTechCTA(
                    key: _techKey,
                    isMobile: isMobile,
                    onJoinTap: () =>
                        _navigateToTechRoute(context, '/tech/register'),
                  ),
                  _LandingFooter(isMobile: isMobile),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _LandingHeader(
                isMobile: isMobile,
                topInset: topInset,
                bodyHeight: headerBodyHeight,
                onNavServices: () => _scrollToKey(_servicesKey),
                onNavHowItWorks: () => _scrollToKey(_howItWorksKey),
                onNavWhy: () => _scrollToKey(_whyKey),
                onNavTech: () => _scrollToKey(_techKey),
                onLoginTap: () => context.push('/login'),
                onClientAppTap: () => _navigateToClientRoute(context, '/'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sticky Header ─────────────────────────────────────────────────────────
class _LandingHeader extends StatelessWidget {
  final bool isMobile;
  final double topInset;
  final double bodyHeight;
  final VoidCallback onNavServices;
  final VoidCallback onNavHowItWorks;
  final VoidCallback onNavWhy;
  final VoidCallback onNavTech;
  final VoidCallback onLoginTap;
  final VoidCallback onClientAppTap;

  const _LandingHeader({
    required this.isMobile,
    required this.topInset,
    required this.bodyHeight,
    required this.onNavServices,
    required this.onNavHowItWorks,
    required this.onNavWhy,
    required this.onNavTech,
    required this.onLoginTap,
    required this.onClientAppTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: topInset),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.94),
        border: const Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: SizedBox(
        height: bodyHeight,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 48),
          child: Row(
            children: [
              // Logo & Brand Name
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: isMobile ? 28 : 32,
                    height: isMobile ? 28 : 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                    ),
                    child: ClipOval(
                      child: Transform.scale(
                        scale: 1.28,
                        child: Image.asset(
                          'assets/images/logo2.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isMobile ? 'حرفي' : 'حرفي',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: isMobile ? 16 : 18,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Navigation Links (Desktop)
              if (!isMobile) ...[
                _NavLink(label: 'الخدمات', onTap: onNavServices),
                _NavLink(label: 'كيف نعمل؟', onTap: onNavHowItWorks),
                _NavLink(label: 'لماذا حرفي؟', onTap: onNavWhy),
                _NavLink(label: 'انضم كفني', onTap: onNavTech),
                const Spacer(),
              ],

              // Actions — one quiet text + one solid CTA
              TextButton(
                onPressed: onLoginTap,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 14,
                    vertical: isMobile ? 12 : 10,
                  ),
                  minimumSize: Size(isMobile ? 44 : 0, isMobile ? 44 : 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'دخول',
                  style: AppTextStyles.titleMed.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 13 : 14,
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 4 : 8),
              if (isMobile)
                OutlinedButton(
                  onPressed: onClientAppTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: BorderSide(
                      color: AppColors.gold.withValues(alpha: 0.6),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'المنصة',
                    style: AppTextStyles.labelMed.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: onClientAppTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: const Color(0xFF090D16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'المنصة',
                    style: AppTextStyles.titleMed.copyWith(
                      color: const Color(0xFF090D16),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NavLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: AppTextStyles.titleMed.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Hero Section ──────────────────────────────────────────────────────────
class _LandingHero extends ConsumerStatefulWidget {
  final bool isMobile;
  final VoidCallback onBookTap;
  final VoidCallback onTechJoinTap;

  const _LandingHero({
    required this.isMobile,
    required this.onBookTap,
    required this.onTechJoinTap,
  });

  @override
  ConsumerState<_LandingHero> createState() => _LandingHeroState();
}

class _LandingHeroState extends ConsumerState<_LandingHero> {
  static const _bgImages = [
    'assets/images/landing_hero_bg.png',
    'assets/images/landing_hero_bg_electrical.png',
    'assets/images/landing_hero_bg_plumbing.png',
  ];

  int _bgIndex = 0;
  Timer? _bgTimer;

  @override
  void initState() {
    super.initState();
    _bgTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() => _bgIndex = (_bgIndex + 1) % _bgImages.length);
    });
  }

  @override
  void dispose() {
    _bgTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = widget.isMobile;
    final statsAsync = ref.watch(landingStatsProvider);
    final statsMap =
        statsAsync.valueOrNull ??
        {
          'techCount': '+15',
          'completedCount': '+24',
          'satisfactionRate': '99.2%',
        };

    final screenHeight = MediaQuery.of(context).size.height;
    final topInset = MediaQuery.paddingOf(context).top;
    final headerBodyHeight = isMobile ? 56.0 : 80.0;
    final headerTotalHeight = headerBodyHeight + topInset;
    final minHeroHeight = screenHeight - headerTotalHeight;

    return Container(
      width: double.infinity,
      color: AppColors.background,
      child: Stack(
        children: [
          // Auto-scrolling specialty backgrounds
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 900),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              child: Image.asset(
                _bgImages[_bgIndex],
                key: ValueKey(_bgImages[_bgIndex]),
                fit: BoxFit.cover,
                // Mobile: keep subject in frame; desktop: right-weighted composition
                alignment: isMobile
                    ? const Alignment(0.35, 0)
                    : Alignment.centerRight,
                gaplessPlayback: true,
              ),
            ),
          ),
          // Darker scrim on mobile — busy photo + small screen needs stronger contrast
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isMobile
                      ? [
                          AppColors.background.withValues(alpha: 0.88),
                          AppColors.background.withValues(alpha: 0.78),
                          AppColors.background.withValues(alpha: 0.94),
                        ]
                      : [
                          AppColors.background.withValues(alpha: 0.78),
                          AppColors.background.withValues(alpha: 0.62),
                          AppColors.background.withValues(alpha: 0.88),
                        ],
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: minHeroHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 20 : 48,
                  isMobile ? 28 : 40,
                  isMobile ? 20 : 48,
                  isMobile ? 24 : 32,
                ),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                    // Compact trust badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 14,
                        vertical: isMobile ? 5 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            size: 15,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isMobile
                                  ? 'منصة معتمدة لصيانة المنزل'
                                  : 'المنصة الأولى المعتمدة لصيانة المنزل والخدمات الفنية',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w600,
                                fontSize: isMobile ? 11.5 : 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isMobile ? 20 : 24),

                    // Title
                    Text(
                      isMobile
                          ? 'صيانة منزلك\nأسرع وأسهل'
                          : 'صيانة منزلك أسرع وأسهل\nمع أفضل الفنيين المعتمدين',
                      textAlign: TextAlign.center,
                      style:
                          (isMobile
                                  ? AppTextStyles.displayMedium
                                  : AppTextStyles.displayLarge)
                              .copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1.5,
                                fontSize: isMobile ? 28 : null,
                                letterSpacing: -0.3,
                              ),
                    ),

                    SizedBox(height: isMobile ? 12 : 14),

                    // One supporting line — keep hero light on mobile
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Text(
                        isMobile
                            ? 'فنيون معتمدون · سباكة · كهرباء · تكييف'
                            : 'خدمات صيانة فورية وموثوقة — سباكة، كهرباء، تكييف، وأجهزة منزلية بأعلى معايير الجودة.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: isMobile
                              ? const Color(0xFFE2E8F0)
                              : AppColors.textSecondary,
                          fontSize: isMobile ? 14.5 : 16,
                          height: 1.55,
                          fontWeight: isMobile
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ),

                    // Desktop-only trust strip (mobile already has badge + subtitle)
                    if (!isMobile) ...[
                      const SizedBox(height: 16),
                      const _HeroTrustStrip(isMobile: false),
                      const SizedBox(height: 28),
                    ] else
                      const SizedBox(height: 28),

                    // Primary CTA
                    SizedBox(
                      width: isMobile ? double.infinity : null,
                      child: ElevatedButton(
                        onPressed: widget.onBookTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: const Color(0xFF090D16),
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 24 : 36,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                          minimumSize: isMobile
                              ? const Size(double.infinity, 52)
                              : null,
                        ),
                        child: Text(
                          'اطلب فني الآن',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: const Color(0xFF090D16),
                            fontWeight: FontWeight.w900,
                            fontSize: isMobile ? 16 : 17,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: isMobile ? 8 : 6),

                    TextButton(
                      onPressed: widget.onTechJoinTap,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: isMobile ? 10 : 6,
                        ),
                        minimumSize: Size(0, isMobile ? 44 : 0),
                      ),
                      child: Text(
                        'انضم كفني إلى المنصة',
                        style: AppTextStyles.titleMed.copyWith(
                          color: AppColors.gold.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 13.5 : 14,
                        ),
                      ),
                    ),

                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: isMobile ? 28 : 28),

                  // Stats — compact strip on mobile, full grid on desktop
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: isMobile
                        ? _MobileStatsStrip(
                            techCount: statsMap['techCount'] ?? '+15',
                            completedCount: statsMap['completedCount'] ?? '+24',
                            satisfactionRate:
                                statsMap['satisfactionRate'] ?? '99.2%',
                          )
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 32,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface1.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Wrap(
                              spacing: 48,
                              runSpacing: 16,
                              alignment: WrapAlignment.spaceAround,
                              children: [
                                _StatItem(
                                  icon: Icons.groups_rounded,
                                  value: statsMap['techCount'] ?? '+15',
                                  label: 'فني معتمد ومفحوص',
                                ),
                                _StatItem(
                                  icon: Icons.task_alt_rounded,
                                  value: statsMap['completedCount'] ?? '+24',
                                  label: 'خدمة صيانة مكتملة',
                                ),
                                _StatItem(
                                  icon: Icons.star_rounded,
                                  value: statsMap['satisfactionRate'] ?? '99.2%',
                                  label: 'نسبة رضا العملاء',
                                ),
                                _StatItem(
                                  icon: Icons.shield_rounded,
                                  value: '100%',
                                  label: 'ضمان سلامة وجودة',
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
                )  ],
      ),
    );
  }
}

/// Compact 3-stat row for mobile — keeps social proof without eating the fold.
class _MobileStatsStrip extends StatelessWidget {
  final String techCount;
  final String completedCount;
  final String satisfactionRate;

  const _MobileStatsStrip({
    required this.techCount,
    required this.completedCount,
    required this.satisfactionRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface1.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CompactStat(value: techCount, label: 'فني معتمد'),
          ),
          Container(width: 1, height: 32, color: AppColors.borderSubtle),
          Expanded(
            child: _CompactStat(value: completedCount, label: 'خدمة مكتملة'),
          ),
          Container(width: 1, height: 32, color: AppColors.borderSubtle),
          Expanded(
            child: _CompactStat(value: satisfactionRate, label: 'رضا العملاء'),
          ),
        ],
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String value;
  final String label;

  const _CompactStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTextStyles.headlineLarge.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: 17,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.labelLarge.copyWith(
            color: const Color(0xFFCBD5E1),
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.gold, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTextStyles.headlineLarge.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: 20,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.textMuted,
            fontSize: 12,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

/// Lightweight trust points — no bordered pills that compete with CTAs.
class _HeroTrustStrip extends StatelessWidget {
  final bool isMobile;

  const _HeroTrustStrip({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final items = isMobile
        ? const ['تسعير عادل', 'ضمان 30 يوم', 'فنيون موثوقون']
        : const [
            'معاينة وتسعير عادل',
            'ضمان 30 يوماً على الإصلاح',
            'فنيون مفحوصون وموثوقون',
          ];

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 0,
      runSpacing: 8,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14),
              child: Text(
                '·',
                style: TextStyle(
                  color: AppColors.textMuted.withValues(alpha: 0.55),
                  fontSize: 16,
                  height: 1,
                ),
              ),
            ),
          Text(
            items[i],
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: isMobile ? 12.5 : 13.5,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Services Showcase Section ──────────────────────────────────────────────
class _LandingServices extends StatelessWidget {
  final bool isMobile;
  final ValueChanged<ServiceType> onServiceTap;

  const _LandingServices({
    super.key,
    required this.isMobile,
    required this.onServiceTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 20 : 64,
        isMobile ? 40 : 64,
        isMobile ? 20 : 64,
        isMobile ? 48 : 64,
      ),
      color: AppColors.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                'خدماتنا المعتمدة',
                style: AppTextStyles.displayMedium.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: isMobile ? 22 : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isMobile
                    ? 'اختر الخدمة ويوصلك أقرب فني متخصص'
                    : 'اختر الخدمة المطلوبة ليصلك أفضل الفنيين المتخصصين في أسرع وقت',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textMuted,
                  fontSize: isMobile ? 14 : null,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isMobile ? 28 : 48),

              Wrap(
                spacing: 20,
                runSpacing: isMobile ? 14 : 20,
                children: ServiceType.values.map((service) {
                  return SizedBox(
                    width: isMobile ? double.infinity : 360,
                    child: _ServiceCard(
                      service: service,
                      onTap: () => onServiceTap(service),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceType service;
  final VoidCallback onTap;

  const _ServiceCard({required this.service, required this.onTap});

  String _getServiceImagePath(ServiceType service) {
    switch (service) {
      case ServiceType.plumbing:
        return 'assets/images/screen1.png';
      case ServiceType.electrical:
        return 'assets/images/screen2.png';
      case ServiceType.carpentry:
        return 'assets/images/screen3.png';
      case ServiceType.ac:
        return 'assets/images/screen5.png';
      case ServiceType.refrigerators:
        return 'assets/images/screen6.png';
      case ServiceType.washingMachines:
        return 'assets/images/screen7.png';
      case ServiceType.screens:
        return 'assets/images/screen8.png';
      case ServiceType.stoves:
        return 'assets/images/screen9.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = _getServiceImagePath(service);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: AppShadows.subtleAmbient,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Image.asset(imagePath, width: 28, height: 28),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'معتمد ⚡',
                      style: AppTextStyles.labelMed.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                service.label,
                style: AppTextStyles.headlineMed.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'فنيون متخصصون ومجهزون بأحدث الأدوات لإصلاح كافة الأعطال بأعلى جودة.',
                style: AppTextStyles.bodyMed.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'احجز الخدمة الآن',
                    style: AppTextStyles.titleMed.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_back_rounded,
                    size: 16,
                    color: AppColors.gold,
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

// ─── How It Works Section ──────────────────────────────────────────────────
class _LandingHowItWorks extends StatelessWidget {
  final bool isMobile;

  const _LandingHowItWorks({super.key, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 64,
        vertical: 64,
      ),
      color: AppColors.surface1,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                'كيف يعمل حرفي؟',
                style: AppTextStyles.displayMedium.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'احصل على خدمتك في 3 خطوات بسيطة ومباشرة',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 48),

              Wrap(
                spacing: 32,
                runSpacing: 32,
                alignment: WrapAlignment.center,
                children: const [
                  _StepCard(
                    stepNumber: '01',
                    icon: Icons.manage_search_rounded,
                    title: 'حدد الخدمة والموقع',
                    description:
                        'اختر نوع الصيانة المطلوبة وموقعك لتوصيلك بأقرب فني معتمد.',
                  ),
                  _StepCard(
                    stepNumber: '02',
                    icon: Icons.badge_rounded,
                    title: 'تأكيد وحضور الفني',
                    description:
                        'يتم إسناد طلبك فوراً وتأكيد الموعد والتواصل المباشر مع الفني.',
                  ),
                  _StepCard(
                    stepNumber: '03',
                    icon: Icons.verified_user_rounded,
                    title: 'إتمام وإستلام بالضمان',
                    description:
                        'انجاز العمل بأسعار عادلة واستلام ضمان معتمد من منصة حرفي.',
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

class _StepCard extends StatelessWidget {
  final String stepNumber;
  final IconData icon;
  final String title;
  final String description;

  const _StepCard({
    required this.stepNumber,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.info, size: 28),
              ),
              Text(
                stepNumber,
                style: AppTextStyles.displayMedium.copyWith(
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: AppTextStyles.headlineMed.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: AppTextStyles.bodyMed.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Trust Badges Section ──────────────────────────────────────────────────
class _LandingTrustBadges extends StatelessWidget {
  final bool isMobile;

  const _LandingTrustBadges({super.key, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 64,
        vertical: 64,
      ),
      color: AppColors.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                'لماذا تختار "حرفي"؟',
                style: AppTextStyles.displayMedium.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'معايير الجودة والأمان التي نلتزم بها في كل خدمة',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 48),

              Wrap(
                spacing: 24,
                runSpacing: 24,
                children: const [
                  _FeatureItem(
                    icon: Icons.verified_rounded,
                    title: 'فنيون مفحوصون وموثوقون',
                    description:
                        'جميع الفنيين يخضعون لفحص جنائي واختبار مهارة دقيق قبل الانضمام للمنصة.',
                  ),
                  _FeatureItem(
                    icon: Icons.request_quote_rounded,
                    title: 'معاينة وتسعير شفاف',
                    description:
                        'يتم تحديد السعر بعد معاينة الفني للعطل وقبل البدء. وفي حال عدم الاتفاق، تُدفع رسوم الزيارة المحددة مسبقاً فقط.',
                  ),
                  _FeatureItem(
                    icon: Icons.shield_outlined,
                    title: 'ضمان 30 يوماً معتمد',
                    description:
                        'ضمان كامل لمدة 30 يوماً على العطل الذي تم إصلاحه وإعادة الصيانة مجاناً في حال تكراره.',
                  ),
                  _FeatureItem(
                    icon: Icons.headset_mic_rounded,
                    title: 'دعم وتتبع مباشر',
                    description:
                        'خدمة عملاء وتتبع حثيث للطلب من لحظة التكليف وحتى الانتهاء بالكامل.',
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

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 270,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.gold, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: AppTextStyles.bodyMed.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Technician Recruitment CTA Section ───────────────────────────────────
class _LandingTechCTA extends StatelessWidget {
  final bool isMobile;
  final VoidCallback onJoinTap;

  const _LandingTechCTA({
    super.key,
    required this.isMobile,
    required this.onJoinTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 64,
        vertical: 64,
      ),
      color: AppColors.surface1,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 28 : 48),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderStrong, width: 1.5),
              boxShadow: AppShadows.cardElevated,
            ),
            child: Flex(
              direction: isMobile ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: isMobile ? 0 : 1,
                  child: Column(
                    crossAxisAlignment: isMobile
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'فرصة عمل للفنيين المتميزين',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'هل أنت فني محترف وتريد زيادة دخلك؟',
                        style: AppTextStyles.displayMedium.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: isMobile ? 22 : 28,
                        ),
                        textAlign: isMobile
                            ? TextAlign.center
                            : TextAlign.start,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'انضم إلى شبكة فنيي "حرفي"، واحصل على طلبات عمل مستمرة في منطقتك، مع مرونة كاملة في ساعات العمل وتسويات مالية سريعة.',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: isMobile
                            ? TextAlign.center
                            : TextAlign.start,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isMobile ? 24 : 0, width: isMobile ? 0 : 32),
                ElevatedButton(
                  onPressed: onJoinTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: const Color(0xFF090D16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 36,
                      vertical: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.engineering_rounded,
                        color: Color(0xFF090D16),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'سجل كفني الآن',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: const Color(0xFF090D16),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Footer Section ────────────────────────────────────────────────────────
class _LandingFooter extends StatelessWidget {
  final bool isMobile;

  const _LandingFooter({required this.isMobile});

  Future<void> _openFacebook() async {
    final uri = Uri.parse(AppConstants.facebookUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 64,
        vertical: 36,
      ),
      color: AppColors.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Flex(
                direction: isMobile ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Transform.scale(
                            scale: 1.28,
                            child: Image.asset(
                              'assets/images/logo2.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'حرفي | Harafi',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 16 : 0),
                  // Facebook Social Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openFacebook,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF1877F2,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFF1877F2,
                            ).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.facebook_rounded,
                              color: Color(0xFF1877F2),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'صفحتنا على فيسبوك',
                              style: AppTextStyles.titleMed.copyWith(
                                color: const Color(0xFF1877F2),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 16 : 0),
                  Text(
                    'جميع الحقوق محفوظة © ${DateTime.now().year}',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textMuted,
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
