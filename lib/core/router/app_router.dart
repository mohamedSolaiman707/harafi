import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/presentation/screens/login_screen.dart';
import '../../../features/client/presentation/screens/home_screen.dart';
import '../../../features/client/presentation/screens/request_screen.dart';
import '../../../features/client/presentation/screens/track_screen.dart';
import '../../../features/client/presentation/screens/services_screen.dart';
import '../../../features/admin/presentation/screens/dashboard_screen.dart';
import '../../../features/admin/presentation/screens/orders_screen.dart';
import '../../../features/admin/presentation/screens/technicians_screen.dart';
import '../../../features/admin/presentation/screens/admin_shell.dart';
import '../../../features/tech/presentation/screens/tech_login_screen.dart';
import '../../../features/tech/presentation/screens/tech_dashboard_screen.dart';
import '../../../features/tech/presentation/screens/tech_order_detail_screen.dart';
import '../../../features/tech/presentation/screens/tech_register_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  overridePlatformDefaultLocation: true,
  redirect: (context, state) {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    final location = state.matchedLocation;
    
    final isAdminRoute = location.startsWith('/admin');
    final isTechRoute = location.startsWith('/tech') && 
                       location != '/tech/login' && 
                       location != '/tech/register';

    if ((isAdminRoute || isTechRoute) && !isLoggedIn) {
      return isAdminRoute ? '/login' : '/tech/login';
    }

    if (location == '/login' && isLoggedIn) {
      return '/admin';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) =>
          AppAnimations.fadeSlide(child: const HomeScreen()),
    ),
    GoRoute(
      path: '/services',
      pageBuilder: (context, state) =>
          AppAnimations.fadeSlide(child: const ServicesScreen()),
    ),
    GoRoute(
      path: '/request',
      pageBuilder: (context, state) =>
          AppAnimations.fadeSlide(child: const RequestScreen()),
    ),
    GoRoute(
      path: '/track/:code',
      pageBuilder: (context, state) => AppAnimations.fadeSlide(
        child: TrackScreen(code: state.pathParameters['code']!),
      ),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) =>
          AppAnimations.fadeSlide(child: const LoginScreen()),
    ),
    
    // Technician Routes
    GoRoute(
      path: '/tech/login',
      pageBuilder: (context, state) =>
          AppAnimations.fadeSlide(child: const TechLoginScreen()),
    ),
    GoRoute(
      path: '/tech/register',
      pageBuilder: (context, state) =>
          AppAnimations.fadeSlide(child: const TechRegisterScreen()),
    ),
    GoRoute(
      path: '/tech/dashboard',
      pageBuilder: (context, state) =>
          AppAnimations.fadeSlide(child: const TechDashboardScreen()),
    ),
    GoRoute(
      path: '/tech/order/:id',
      pageBuilder: (context, state) => AppAnimations.fadeSlide(
        child: TechOrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/tech/profile',
      pageBuilder: (context, state) =>
          AppAnimations.fadeSlide(child: TechProfilePlaceholder()),
    ),

    ShellRoute(
      builder: (context, state, child) => AdminShell(child: child),
      routes: [
        GoRoute(
          path: '/admin',
          pageBuilder: (context, state) =>
              AppAnimations.fadeSlide(child: const DashboardScreen()),
        ),
        GoRoute(
          path: '/admin/orders',
          pageBuilder: (context, state) =>
              AppAnimations.fadeSlide(child: const OrdersScreen()),
        ),
        GoRoute(
          path: '/admin/techs',
          pageBuilder: (context, state) =>
              AppAnimations.fadeSlide(child: const TechniciansScreen()),
        ),
      ],
    ),
  ],
);

// مؤقت حتى إنشاء شاشة الملف الشخصي
class TechProfilePlaceholder extends StatelessWidget {
  const TechProfilePlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person, size: 80, color: AppColors.textSecondary),
            const SizedBox(height: 20),
            const Text('قريباً: إدارة الملف الشخصي والتقييمات'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                context.go('/');
              },
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );
  }
}
