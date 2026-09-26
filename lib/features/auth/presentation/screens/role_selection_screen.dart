import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../landing/presentation/screens/landing_screen.dart';
import '../providers/auth_screen_providers.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen>
    with TickerProviderStateMixin {
  Timer? _adminTapTimer;
  late AnimationController _entranceController;
  late AnimationController _pulseController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _headerSlide;
  late Animation<double> _headerOpacity;
  late Animation<Offset> _cardsSlide;
  late Animation<double> _cardsOpacity;
  late Animation<double> _footerOpacity;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _headerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
      ),
    );

    _cardsSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _cardsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
      ),
    );

    _footerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _adminTapTimer?.cancel();
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _setRole(String role, BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
    if (context.mounted) {
      context.go(role == 'client' ? '/' : '/tech/login');
    }
  }

  Future<void> _handleAdminAccess() async {
    _adminTapTimer?.cancel();

    final currentCount = ref.read(adminTapCountProvider) + 1;
    ref.read(adminTapCountProvider.notifier).state = currentCount;

    if (currentCount >= 5) {
      ref.read(adminTapCountProvider.notifier).state = 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', 'admin');
      if (mounted) {
        context.push('/login');
      }
    } else {
      _adminTapTimer = Timer(const Duration(milliseconds: 1000), () {
        if (mounted) {
          ref.read(adminTapCountProvider.notifier).state = 0;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // ─── Ambient Glow Background Animations ────────────────────────
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulse = _pulseController.value;
                return Stack(
                  children: [
                    Positioned(
                      top: -120 + (pulse * 30),
                      right: -100 + (pulse * 20),
                      child: Container(
                        width: 500,
                        height: 500,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.gold.withValues(alpha: 0.12 + (pulse * 0.05)),
                              AppColors.gold.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -150 + (pulse * 30),
                      left: -120 + (pulse * 20),
                      child: Container(
                        width: 520,
                        height: 520,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.accentCyan.withValues(alpha: 0.10 + (pulse * 0.05)),
                              AppColors.accentCyan.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // ─── Main Landing Layout ─────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  // ─── Top Navbar ────────────────────────────────────────────
                  _buildLandingNavBar(context),

                  // ─── Scrollable Content ────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
                        vertical: 24,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // ─── Hero Header ─────────────────────────────
                              SlideTransition(
                                position: _headerSlide,
                                child: FadeTransition(
                                  opacity: _headerOpacity,
                                  child: _buildHeroSection(),
                                ),
                              ),

                              const SizedBox(height: 36),

                              // ─── Dual Split Hero Cards (Desktop Grid / Mobile Stack)
                              SlideTransition(
                                position: _cardsSlide,
                                child: FadeTransition(
                                  opacity: _cardsOpacity,
                                  child: isDesktop
                                      ? Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: _LandingRoleCard(
                                                title: 'أنا عميل (أبحث عن فني)',
                                                badgeLabel: 'طلب خدمة صيانة ⚡',
                                                accentColor: AppColors.accentCyan,
                                                gradientColors: const [
                                                  Color(0xFF131B2E),
                                                  Color(0xFF0F172A),
                                                ],
                                                icon: Icons.person_pin_rounded,
                                                features: const [
                                                  'طلب فني صيانة معتمد في أقل من دقيقة',
                                                  'ضمان مجاني لمدة 30 يوماً على كافة الخدمات',
                                                  'أسعار معاينة شفافة وتتبع مباشر للطلب',
                                                ],
                                                ctaLabel: 'تصفح الخدمات واطلب الآن 👈',
                                                onTap: () => _setRole('client', context),
                                              ),
                                            ),
                                            const SizedBox(width: 28),
                                            Expanded(
                                              child: _LandingRoleCard(
                                                title: 'أنا فني محترف (حرفي)',
                                                badgeLabel: 'انضم لشبكة الفنيين 🏆',
                                                accentColor: AppColors.gold,
                                                gradientColors: const [
                                                  Color(0xFF1E2638),
                                                  Color(0xFF121929),
                                                ],
                                                icon: Icons.handyman_rounded,
                                                isHighlight: true,
                                                features: const [
                                                  'استقبال طلبات صيانة يومية وتنمية دخلك',
                                                  'حرية كاملة في اختيار مواعيدك ومناطقك',
                                                  'شارة توثيق معتمدة ومكافآت ترحيبية',
                                                ],
                                                ctaLabel: 'بوابة الفنيين / التسجيل 🚀',
                                                onTap: () => _setRole('tech', context),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          children: [
                                            _LandingRoleCard(
                                              title: 'أنا عميل (أبحث عن فني)',
                                              badgeLabel: 'طلب خدمة صيانة ⚡',
                                              accentColor: AppColors.accentCyan,
                                              gradientColors: const [
                                                Color(0xFF131B2E),
                                                Color(0xFF0F172A),
                                              ],
                                              icon: Icons.person_pin_rounded,
                                              features: const [
                                                'طلب فني صيانة معتمد في أقل من دقيقة',
                                                'ضمان مجاني لمدة 30 يوماً على كافة الخدمات',
                                                'أسعار معاينة شفافة وتتبع مباشر للطلب',
                                              ],
                                              ctaLabel: 'تصفح الخدمات واطلب الآن 👈',
                                              onTap: () => _setRole('client', context),
                                            ),
                                            const SizedBox(height: 20),
                                            _LandingRoleCard(
                                              title: 'أنا فني محترف (حرفي)',
                                              badgeLabel: 'انضم لشبكة الفنيين 🏆',
                                              accentColor: AppColors.gold,
                                              gradientColors: const [
                                                Color(0xFF1E2638),
                                                Color(0xFF121929),
                                              ],
                                              icon: Icons.handyman_rounded,
                                              isHighlight: true,
                                              features: const [
                                                'استقبال طلبات صيانة يومية وتنمية دخلك',
                                                'حرية كاملة في اختيار مواعيدك ومناطقك',
                                                'شارة توثيق معتمدة ومكافآت ترحيبية',
                                              ],
                                              ctaLabel: 'بوابة الفنيين / التسجيل 🚀',
                                              onTap: () => _setRole('tech', context),
                                            ),
                                          ],
                                        ),
                                ),
                              ),

                              const SizedBox(height: 48),

                              // ─── Trust Stats Bar ─────────────────────────
                              FadeTransition(
                                opacity: _footerOpacity,
                                child: _buildStatsTrustBar(isDesktop),
                              ),

                              const SizedBox(height: 40),

                              // ─── Secret Admin Trigger & Footer ───────────
                              FadeTransition(
                                opacity: _footerOpacity,
                                child: _buildFooterSection(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Top Navbar Widget ───────────────────────────────────────────────────────

  Widget _buildLandingNavBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.85),
        border: const Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Logo & Title
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo2.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'حرفي',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.shield_outlined, size: 12, color: AppColors.gold),
                    SizedBox(width: 4),
                    Text(
                      'منصة معتمدة',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Spacer(),

          // Browse Landing Button
          OutlinedButton.icon(
            onPressed: () => context.go('/landing'),
            icon: const Icon(Icons.language_rounded, size: 16),
            label: const Text('الرئيسية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.borderDefault),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Hero Section Widget ─────────────────────────────────────────────────────

  Widget _buildHeroSection() {
    return Column(
      children: [
        // Top Pill Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.auto_awesome, size: 14, color: AppColors.gold),
              SizedBox(width: 6),
              Text(
                'المنصة الأولى لخدمات الصيانة المنزلية في مصر ✨',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Hero Title
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppTextStyles.displayMedium.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 32,
              height: 1.3,
            ),
            children: [
              const TextSpan(text: 'أهلاً بك في منصة '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: ShaderMask(
                  shaderCallback: (bounds) => AppGradients.goldButton.createShader(bounds),
                  child: Text(
                    'حرفي',
                    style: AppTextStyles.displayMedium.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 36,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Subtitle
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            'سواء كنت تبحث عن صيانة فورية بضمان معتمد، أو تريد الانضمام كفني محترف وتنمية دخلك — حدد وجهتك وابدأ الآن',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // ─── Stats & Trust Bar Widget ────────────────────────────────────────────────

  Widget _buildStatsTrustBar(bool isDesktop) {
    final statsAsync = ref.watch(landingStatsProvider);
    final statsMap = statsAsync.valueOrNull ?? {
      'techCount': '+15',
      'completedCount': '+24',
      'satisfactionRate': '99.2%',
    };

    final stats = [
      {'val': statsMap['completedCount'] ?? '+24', 'label': 'طلب منجز بنجاح'},
      {'val': statsMap['techCount'] ?? '+15', 'label': 'فني معتمد ومفحوص'},
      {'val': statsMap['satisfactionRate'] ?? '99.2%', 'label': 'نسبة رضا العملاء'},
      {'val': '30 يوماً', 'label': 'ضمان مجاني معتمد'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface1.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: isDesktop
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: stats.map((s) => _buildStatItem(s['val']!, s['label']!)).toList(),
            )
          : Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.spaceAround,
              children: stats.map((s) => SizedBox(width: 130, child: _buildStatItem(s['val']!, s['label']!))).toList(),
            ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => AppGradients.goldButton.createShader(bounds),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.labelMed.copyWith(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ─── Footer Section Widget with Hidden Admin Secret Trigger ─────────────────

  Widget _buildFooterSection() {
    final adminTapCount = ref.watch(adminTapCountProvider);

    return Column(
      children: [
        // Hidden Admin Trigger on Logo
        FadeTransition(
          opacity: _logoOpacity,
          child: ScaleTransition(
            scale: _logoScale,
            child: GestureDetector(
              onTap: _handleAdminAccess,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface2,
                  border: Border.all(
                    color: adminTapCount > 0 ? AppColors.gold : AppColors.borderSubtle,
                    width: adminTapCount > 0 ? 2 : 1,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.handyman_rounded, color: AppColors.gold, size: 24),
                    if (adminTapCount > 0)
                      Positioned(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${5 - adminTapCount}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'جميع الحقوق محفوظة © لمنصة حرفي ${DateTime.now().year}',
          style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

// ─── Creative Landing Role Card Component ─────────────────────────────────────

class _LandingRoleCard extends StatefulWidget {
  final String title;
  final String badgeLabel;
  final Color accentColor;
  final List<Color> gradientColors;
  final IconData icon;
  final List<String> features;
  final String ctaLabel;
  final bool isHighlight;
  final VoidCallback onTap;

  const _LandingRoleCard({
    required this.title,
    required this.badgeLabel,
    required this.accentColor,
    required this.gradientColors,
    required this.icon,
    required this.features,
    required this.ctaLabel,
    this.isHighlight = false,
    required this.onTap,
  });

  @override
  State<_LandingRoleCard> createState() => _LandingRoleCardState();
}

class _LandingRoleCardState extends State<_LandingRoleCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    final highlight = widget.isHighlight;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : (_isHovered ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _isHovered
                    ? accent
                    : (highlight ? accent.withValues(alpha: 0.5) : AppColors.borderSubtle),
                width: _isHovered ? 2.2 : (highlight ? 1.5 : 1.0),
              ),
              boxShadow: [
                if (_isHovered || highlight)
                  BoxShadow(
                    color: accent.withValues(alpha: _isHovered ? 0.30 : 0.15),
                    blurRadius: _isHovered ? 30 : 18,
                    spreadRadius: -2,
                    offset: const Offset(0, 8),
                  )
                else
                  const BoxShadow(
                    color: Colors.black38,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row (Icon & Badge)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon Emblem
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: highlight ? accent : accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: accent.withValues(alpha: highlight ? 0.9 : 0.3),
                        ),
                        boxShadow: [
                          if (highlight)
                            BoxShadow(
                              color: accent.withValues(alpha: 0.35),
                              blurRadius: 12,
                            ),
                        ],
                      ),
                      child: Icon(
                        widget.icon,
                        color: highlight ? const Color(0xFF090D16) : accent,
                        size: 28,
                      ),
                    ),

                    // Badge Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accent.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        widget.badgeLabel,
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Card Title
                Text(
                  widget.title,
                  style: AppTextStyles.headlineLarge.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 18),

                // Features List
                Column(
                  children: widget.features
                      .map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_rounded, size: 18, color: accent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    f,
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),

                const SizedBox(height: 24),

                // CTA Button
                SizedBox(
                  width: double.infinity,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: highlight ? accent : accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accent.withValues(alpha: highlight ? 1.0 : 0.4),
                      ),
                      boxShadow: highlight
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        widget.ctaLabel,
                        style: TextStyle(
                          color: highlight ? const Color(0xFF090D16) : accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
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
