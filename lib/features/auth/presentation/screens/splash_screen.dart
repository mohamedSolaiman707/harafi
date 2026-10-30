import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _glowController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.8, end: 1.1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _glowOpacity = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _logoController.forward();

    _startTransition();
  }

  Future<void> _startTransition() async {
    await Future.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final userRole = prefs.getString('user_role');
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;

    if (kIsWeb) {
      if (userRole == null) {
        context.go('/landing');
      } else {
        _navigateBasedOnRole(userRole, isLoggedIn);
      }
    } else {
      if (userRole == null) {
        context.go('/welcome');
      } else {
        _navigateBasedOnRole(userRole, isLoggedIn);
      }
    }
  }

  void _navigateBasedOnRole(String role, bool isLoggedIn) {
    if (role == 'admin') {
      context.go(isLoggedIn ? '/admin' : '/login');
    } else if (role == 'tech') {
      context.go(isLoggedIn ? '/tech/dashboard' : '/tech/login');
    } else {
      context.go('/');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // ─── Depth & Atmosphere ──────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    AppColors.surface1.withValues(alpha: 0.4),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),

          // ─── Ambient Glow Pulse (Refined) ───────────────────────────
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: _glowOpacity.value * 0.4),
                      AppColors.gold.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              );
            },
          ),

          // ─── Logo & Branding ─────────────────────────────────────────
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _logoScale,
                child: FadeTransition(
                  opacity: _logoOpacity,
                  child: Container(
                    width: 170,
                    height: 170,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface1.withValues(alpha: 0.7),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          blurRadius: 60,
                          spreadRadius: 10,
                        ),
                      ],
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Hero(
                      tag: 'app_logo',
                      child: Image.asset(
                        'assets/images/logo2.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.engineering_rounded,
                          size: 90,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: _logoOpacity,
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => AppGradients.goldButton.createShader(bounds),
                      child: Text(
                        'حرفي',
                        style: AppTextStyles.displayLarge.copyWith(
                          color: Colors.white,
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.gold.withValues(alpha: 0.1), width: 0.5),
                          bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.1), width: 0.5),
                        ),
                      ),
                      child: Text(
                        'خيارك الأول للصيانة المنزلية',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                          letterSpacing: 1.5,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ─── Refined Progress at Bottom ──────────────────────────────
          Positioned(
            bottom: 80,
            child: FadeTransition(
              opacity: _logoOpacity,
              child: Column(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'جاري التحميل...',
                    style: AppTextStyles.labelMed.copyWith(
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
