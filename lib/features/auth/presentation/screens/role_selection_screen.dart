import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
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
  late Animation<Offset> _clientCardSlide;
  late Animation<double> _clientCardOpacity;
  late Animation<Offset> _techCardSlide;
  late Animation<double> _techCardOpacity;
  late Animation<double> _footerOpacity;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
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
      begin: const Offset(0, 0.25),
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

    _clientCardSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _clientCardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
      ),
    );

    _techCardSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 0.95, curve: Curves.easeOutCubic),
      ),
    );

    _techCardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 0.9, curve: Curves.easeOut),
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
    final adminTapCount = ref.watch(adminTapCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ─── Ambient Glow Background Animations ────────────────────────
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final pulseValue = _pulseController.value;
              return Stack(
                children: [
                  Positioned(
                    top: -120 + (pulseValue * 20),
                    right: -100 + (pulseValue * 15),
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.gold.withValues(alpha: 0.18 + (pulseValue * 0.08)),
                            AppColors.gold.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -150 + (pulseValue * 25),
                    left: -100,
                    child: Container(
                      width: 360,
                      height: 360,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.accentCyan.withValues(alpha: 0.12 + (pulseValue * 0.06)),
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

          // ─── Main Content ──────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xxl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ─── Animated Logo & Hidden Admin Trigger ──────────
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final pulse = _pulseController.value;
                          return ScaleTransition(
                            scale: _logoScale,
                            child: FadeTransition(
                              opacity: _logoOpacity,
                              child: GestureDetector(
                                onTap: _handleAdminAccess,
                                child: Column(
                                  children: [
                                    Container(
                                      width: 110,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.surface2,
                                            AppColors.surface1,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        border: Border.all(
                                          color: adminTapCount > 0
                                              ? AppColors.gold
                                              : AppColors.gold.withValues(alpha: 0.3 + (pulse * 0.2)),
                                          width: adminTapCount > 0 ? 2.5 : 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.gold.withValues(
                                              alpha: adminTapCount > 0 ? 0.4 : 0.12 + (pulse * 0.08),
                                            ),
                                            blurRadius: 28 + (pulse * 10),
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Icon(
                                            Icons.engineering_rounded,
                                            size: 54,
                                            color: adminTapCount > 0
                                                ? AppColors.gold
                                                : AppColors.textPrimary,
                                          ),
                                          if (adminTapCount > 0)
                                            Positioned(
                                              bottom: 10,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
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
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: AppSpacing.xxl),

                      // ─── Header Titles ─────────────────────────────────
                      SlideTransition(
                        position: _headerSlide,
                        child: FadeTransition(
                          opacity: _headerOpacity,
                          child: Column(
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => AppGradients.goldButton.createShader(bounds),
                                child: Text(
                                  'أهلاً بك في حرفي',
                                  style: AppTextStyles.displayMedium.copyWith(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 34,
                                    letterSpacing: -0.5,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'اختر كيف تريد استخدام التطبيق اليوم للبدء',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xxxl),

                      // ─── Option 1: Client Card ──────────────────────────
                      SlideTransition(
                        position: _clientCardSlide,
                        child: FadeTransition(
                          opacity: _clientCardOpacity,
                          child: _CreativeRoleCard(
                            title: 'أنا عميل',
                            subtitle: 'أبحث عن فني موثوق لإصلاح أعطال منزلي بسرعة وأمان',
                            badgeText: 'طلب خدمة ⚡',
                            icon: Icons.person_search_rounded,
                            accentColor: AppColors.accentCyan,
                            isHighlight: false,
                            onTap: () => _setRole('client', context),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // ─── Option 2: Technician Card ─────────────────────
                      SlideTransition(
                        position: _techCardSlide,
                        child: FadeTransition(
                          opacity: _techCardOpacity,
                          child: _CreativeRoleCard(
                            title: 'أنا فني (حرفي)',
                            subtitle: 'أريد استقبال طلبات العمل وزيادة دخلي اليومي',
                            badgeText: 'انضم إلينا 🛠️',
                            icon: Icons.construction_rounded,
                            accentColor: AppColors.gold,
                            isHighlight: true,
                            onTap: () => _setRole('tech', context),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xxxl),

                      // ─── Footer Trust Badges ───────────────────────────
                      FadeTransition(
                        opacity: _footerOpacity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            _TrustChip(
                              icon: Icons.shield_outlined,
                              label: 'ضمان 30 يوم',
                            ),
                            SizedBox(width: 8),
                            _TrustChip(
                              icon: Icons.verified_outlined,
                              label: 'فنيون معتمدون',
                            ),
                            SizedBox(width: 8),
                            _TrustChip(
                              icon: Icons.bolt_outlined,
                              label: 'استجابة فورية',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreativeRoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String badgeText;
  final IconData icon;
  final Color accentColor;
  final bool isHighlight;
  final VoidCallback onTap;

  const _CreativeRoleCard({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.icon,
    required this.accentColor,
    required this.isHighlight,
    required this.onTap,
  });

  @override
  State<_CreativeRoleCard> createState() => _CreativeRoleCardState();
}

class _CreativeRoleCardState extends State<_CreativeRoleCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool highlight = widget.isHighlight;
    final Color accent = widget.accentColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : (_isHovered ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: highlight
                  ? LinearGradient(
                      colors: [
                        AppColors.surface2,
                        const Color(0xFF1E2613),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        AppColors.surface1,
                        AppColors.surface2,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              border: Border.all(
                color: _isHovered
                    ? accent
                    : (highlight
                        ? accent.withValues(alpha: 0.6)
                        : AppColors.borderSubtle),
                width: _isHovered ? 2.0 : (highlight ? 1.5 : 1.0),
              ),
              boxShadow: [
                if (highlight || _isHovered)
                  BoxShadow(
                    color: accent.withValues(alpha: _isHovered ? 0.3 : 0.15),
                    blurRadius: _isHovered ? 24 : 16,
                    spreadRadius: -2,
                    offset: const Offset(0, 8),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon Container
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: highlight
                            ? accent
                            : accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: accent.withValues(alpha: highlight ? 0.8 : 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          if (highlight)
                            BoxShadow(
                              color: accent.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Icon(
                        widget.icon,
                        color: highlight ? Colors.black : accent,
                        size: 28,
                      ),
                    ),

                    // Badge Chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: highlight ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        widget.badgeText,
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Title & Subtitle
                Text(
                  widget.title,
                  style: AppTextStyles.headlineLarge.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  widget.subtitle,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                    fontSize: 13.5,
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Action Callout Row
                Row(
                  children: [
                    Text(
                      'اضغط هنا للبدء',
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      transform: Matrix4.translationValues(
                        _isHovered || _isPressed ? -6 : 0,
                        0,
                        0,
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TrustChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderSubtle,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.gold),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
