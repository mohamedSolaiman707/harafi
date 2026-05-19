import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/presentation/screens/login_screen.dart';
import '../../../features/client/presentation/screens/home_screen.dart';
import '../../../features/client/presentation/screens/request_screen.dart';
import '../../../features/client/presentation/screens/track_screen.dart';
import '../../../features/admin/presentation/screens/dashboard_screen.dart';
import '../../../features/admin/presentation/screens/orders_screen.dart';
import '../../../features/admin/presentation/screens/technicians_screen.dart';
import '../../../features/admin/presentation/screens/admin_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  // لضمان أن التطبيق يقرأ الرابط الحالي عند البدء على الويب
  overridePlatformDefaultLocation: true,
  redirect: (context, state) {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;

    // استخدام matchedLocation لضمان مطابقة المسار بدقة
    final location = state.matchedLocation;
    final isAdminRoute = location.startsWith('/admin');

    if (isAdminRoute && !isLoggedIn) {
      return '/login';
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
