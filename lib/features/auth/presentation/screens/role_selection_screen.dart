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
                    top: -100 + (pulseValue * 20),
                    right: -80 + (pulseValue * 15),
                    child: Container(
                      width: 380,
                      height: 380,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.gold.withValues(alpha: 0.16 + (pulseValue * 0.08)),
                            AppColors.gold.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -120 + (pulseValue * 25),
                    left: -80,
                    child: Container(
                      width: 400,
                      height: 400,
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
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ─── Ultra-Luxury Brand Emblem & Hidden Admin Trigger ──────────
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
                                      width: 104,
                                      height: 104,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(28),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFFD700),
                                            Color(0xFFFF9800),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.gold.withValues(
                                              alpha: adminTapCount > 0 ? 0.5 : 0.25 + (pulse * 0.12),
                                            ),
                                            blurRadius: 32 + (pulse * 10),
                                            spreadRadius: 2,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            width: 96,
                                            height: 96,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(24),
                                              color: const Color(0xFF090D16),
                                            ),
                                            child: Center(
                                              child: ShaderMask(
                                                shaderCallback: (bounds) => AppGradients.goldButton.createShader(bounds),
                                                child: const Icon(
                                                  Icons.handyman_rounded,
                                                  size: 52,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (adminTapCount > 0)
                                            Positioned(
                                              bottom: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.gold,
                                                  borderRadius: BorderRadius.circular(12),
                                                  boxShadow: const [
                                                    BoxShadow(color: Colors.black38, blurRadius: 4),
                                                  ],
                                                ),
                                                child: Text(
                                                  '${5 - adminTapCount}',
                                                  style: const TextStyle(
                                                    color: Color(0xFF090D16),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w900,
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

                      const SizedBox(height: AppSpacing.xl),

                      // ─── Header Titles ─────────────────────────────────
                      SlideTransition(
                        position: _headerSlide,
                        child: FadeTransition(
                          opacity: _headerOpacity,
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'أهلاً بك في ',
                                    style: AppTextStyles.displayMedium.copyWith(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 32,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  ShaderMask(
                                    shaderCallback: (bounds) => AppGradients.goldButton.createShader(bounds),
                                    child: Text(
                                      'حرفي',
                                      style: AppTextStyles.displayMedium.copyWith(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 34,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'اختر نوع الحساب للانتقال السريع إلى المنصة',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 14.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xxl),

                      // ─── Option 1: Client Card ──────────────────────────
                      SlideTransition(
                        position: _clientCardSlide,
                        child: FadeTransition(
                          opacity: _clientCardOpacity,
                          child: _CreativeRoleCard(
                            title: 'أنا عميل',
                            subtitle: 'أبحث عن فني موثوق لإصلاح الأعطال المنزلية بضمان وحجز سريع',
                            badgeLabel: 'طلب خدمة صيانة',
                            badgeIcon: Icons.bolt_rounded,
                            icon: Icons.person_pin_rounded,
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
                            subtitle: 'أريد استقبال طلبات العمل اليومية وتنمية دخلي بحرية كاملة',
                            badgeLabel: 'انضم لشبكة الفنيين',
                            badgeIcon: Icons.engineering_rounded,
                            icon: Icons.handyman_rounded,
                            accentColor: AppColors.gold,
                            isHighlight: true,
                            onTap: () => _setRole('tech', context),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xxl),

                      // ─── Footer Trust Badges ───────────────────────────
                      FadeTransition(
                        opacity: _footerOpacity,
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: const [
                            _TrustChip(
                              icon: Icons.verified_user_rounded,
                              label: 'فنيون مفحوصون',
                            ),
                            _TrustChip(
                              icon: Icons.shield_rounded,
                              label: 'ضمان معتمد',
                            ),
                            _TrustChip(
                              icon: Icons.speed_rounded,
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
  final String badgeLabel;
  final IconData badgeIcon;
  final IconData icon;
  final Color accentColor;
  final bool isHighlight;
  final VoidCallback onTap;

  const _CreativeRoleCard({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.badgeIcon,
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
          scale: _isPressed ? 0.98 : (_isHovered ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: highlight
                  ? const LinearGradient(
                      colors: [
                        Color(0xFF1E293B),
                        Color(0xFF131C2E),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [
                        Color(0xFF131B2A),
                        Color(0xFF0F172A),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isHovered
                    ? accent
                    : (highlight
                        ? accent.withValues(alpha: 0.5)
                        : AppColors.borderSubtle),
                width: _isHovered ? 2.0 : (highlight ? 1.5 : 1.0),
              ),
              boxShadow: [
                if (highlight || _isHovered)
                  BoxShadow(
                    color: accent.withValues(alpha: _isHovered ? 0.28 : 0.14),
                    blurRadius: _isHovered ? 24 : 16,
                    spreadRadius: -2,
                    offset: const Offset(0, 8),
                  )
                else
                  const BoxShadow(
                    color: Colors.black26,
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon Emblem Container
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: highlight
                            ? accent
                            : accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: accent.withValues(alpha: highlight ? 0.9 : 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          if (highlight)
                            BoxShadow(
                              color: accent.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                        ],
                      ),
                      child: Icon(
                        widget.icon,
                        color: highlight ? const Color(0xFF090D16) : accent,
                        size: 26,
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
                          color: accent.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.badgeIcon, size: 14, color: accent),
                          const SizedBox(width: 6),
                          Text(
                            widget.badgeLabel,
                            style: TextStyle(
                              color: accent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
                    color: Colors.white,
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

                // Action Callout Button
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'اضغط للبدء الآن',
                            style: TextStyle(
                              color: accent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            transform: Matrix4.translationValues(
                              _isHovered || _isPressed ? -4 : 0,
                              0,
                              0,
                            ),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              size: 16,
                              color: accent,
                            ),
                          ),
                        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2.withValues(alpha: 0.7),
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
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

