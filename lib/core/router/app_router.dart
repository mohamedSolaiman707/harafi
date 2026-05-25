import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/presentation/screens/login_screen.dart';
import '../../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../../features/client/presentation/screens/home_screen.dart';
import '../../../features/client/presentation/screens/request_screen.dart';
import '../../../features/client/presentation/screens/track_screen.dart';
import '../../../features/client/presentation/screens/services_screen.dart';
import '../../../features/client/presentation/screens/service_techs_screen.dart';
import '../../../features/client/presentation/screens/tech_portfolio_screen.dart';
import '../../../features/client/presentation/screens/client_orders_screen.dart';
import '../../../features/client/presentation/screens/favorites_screen.dart';
import '../../../features/admin/presentation/screens/dashboard_screen.dart';
import '../../../features/admin/presentation/screens/orders_screen.dart';
import '../../../features/admin/presentation/screens/technicians_screen.dart';
import '../../../features/admin/presentation/screens/admin_order_detail_screen.dart';
import '../../../features/admin/presentation/screens/admin_shell.dart';
import '../../../features/tech/presentation/screens/tech_login_screen.dart';
import '../../../features/tech/presentation/screens/tech_dashboard_screen.dart';
import '../../../features/tech/presentation/screens/tech_order_detail_screen.dart';
import '../../../features/tech/presentation/screens/tech_register_screen.dart';
import '../../../features/tech/presentation/screens/tech_profile_screen.dart';
import '../../../features/admin/domain/enums/service_type.dart';

final appRouter = GoRouter(
  initialLocation: '/welcome',
  overridePlatformDefaultLocation: true,
  redirect: (context, state) async {
    final prefs = await SharedPreferences.getInstance();
    final userRole = prefs.getString('user_role');
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    final location = state.matchedLocation;

    final isAuthRoute = location == '/login' || location == '/tech/login' || location == '/tech/register';
    final isWelcomeRoute = location == '/welcome';
    final isAdminRoute = location.startsWith('/admin');

    // 1. إذا لم يتم اختيار دور والمستخدم ليس في مسار مسموح، وجهه للترحيب
    if (userRole == null && !isWelcomeRoute && !isAuthRoute && !isAdminRoute) {
      return '/welcome';
    }

    // 2. إذا كان في صفحة الترحيب وتم تحديد الدور بالفعل، وجهه لمساره الصحيح
    if (userRole != null && isWelcomeRoute) {
      if (userRole == 'admin') return isLoggedIn ? '/admin' : '/login';
      return userRole == 'client' ? '/' : '/tech/dashboard';
    }

    final isTechRoute = location.startsWith('/tech') && !isAuthRoute;

    // 3. حماية مسارات الأدمن والفني
    if ((isAdminRoute || isTechRoute) && !isLoggedIn) {
      return isAdminRoute ? '/login' : '/tech/login';
    }

    // 4. إذا كان مسجل دخول بالفعل، لا تفتح له صفحات اللوجن
    if (location == '/login' && isLoggedIn) return '/admin';
    if (location == '/tech/login' && isLoggedIn) return '/tech/dashboard';

    return null;
  },
  routes: [
    GoRoute(
      path: '/welcome',
      pageBuilder: (context, state) =>
          AppAnimations.fadeSlide(child: const RoleSelectionScreen()),
    ),
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
      path: '/service/:type',
      pageBuilder: (context, state) {
        final typeStr = state.pathParameters['type']!;
        final service = ServiceType.values.firstWhere((e) => e.name == typeStr);
        return AppAnimations.fadeSlide(child: ServiceTechsScreen(service: service));
      },
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
      path: '/my-orders',
      pageBuilder: (context, state) => AppAnimations.fadeSlide(
        child: const ClientOrdersScreen(),
      ),
    ),
    GoRoute(
      path: '/favorites',
      pageBuilder: (context, state) => AppAnimations.fadeSlide(
        child: const FavoritesScreen(),
      ),
    ),
    GoRoute(
      path: '/tech/portfolio/:id',
      pageBuilder: (context, state) => AppAnimations.fadeSlide(
        child: TechPortfolioScreen(techId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) =>
          AppAnimations.fadeSlide(child: const LoginScreen()),
    ),
    
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
          path: '/admin/order/:id',
          pageBuilder: (context, state) => AppAnimations.fadeSlide(
            child: AdminOrderDetailScreen(orderId: state.pathParameters['id']!),
          ),
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
