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
          // ─── Ambient Glow Pulse ──────────────────────────────────────
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: _glowOpacity.value),
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
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.surface2, AppColors.surface1],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: const Icon(
                      Icons.engineering_rounded,
                      size: 80,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
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
                          fontSize: 48,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'خيارك الأول للصيانة المنزلية',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ─── Loading Indicator at Bottom ──────────────────────────────
          Positioned(
            bottom: 60,
            child: FadeTransition(
              opacity: _logoOpacity,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
