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
import '../../../features/tech/presentation/screens/tech_profile_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  overridePlatformDefaultLocation: true,
  redirect: (context, state) {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    final location = state.matchedLocation;
    
    // حماية مسارات الإدارة
    final isAdminRoute = location.startsWith('/admin');
    // حماية مسارات الفنيين (ماعدا صفحات الدخول والتسجيل)
    final isTechRoute = location.startsWith('/tech') && 
                       location != '/tech/login' && 
                       location != '/tech/register';

    if ((isAdminRoute || isTechRoute) && !isLoggedIn) {
      return isAdminRoute ? '/login' : '/tech/login';
    }

    // منع المسجلين دخول من العودة لصفحات الدخول
    if (location == '/login' && isLoggedIn) return '/admin';
    if (location == '/tech/login' && isLoggedIn) return '/tech/dashboard';

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
    
    // Technician System
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
          AppAnimations.fadeSlide(child: const TechProfileScreen()),
    ),

    // Admin System (ShellRoute for BottomNav/Sidebar)
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
