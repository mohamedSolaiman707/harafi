import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  redirect: (context, state) {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    final isAdminRoute = state.uri.toString().startsWith('/admin');
    if (isAdminRoute && !isLoggedIn) return '/login';
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/request',
      builder: (context, state) => const RequestScreen(),
    ),
    GoRoute(
      path: '/track/:code',
      builder: (context, state) => TrackScreen(
        code: state.pathParameters['code']!,
      ),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    // Admin Shell
    ShellRoute(
      builder: (context, state, child) => AdminShell(child: child),
      routes: [
        GoRoute(
          path: '/admin',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/admin/orders',
          builder: (context, state) => const OrdersScreen(),
        ),
        GoRoute(
          path: '/admin/techs',
          builder: (context, state) => const TechniciansScreen(),
        ),
      ],
    ),
  ],
);
