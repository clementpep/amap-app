import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/profile_screen.dart';
import '../../features/delivery/screens/delivery_list_screen.dart';
import '../../features/delivery/screens/delivery_detail_screen.dart';
import '../../features/delivery/screens/camera_screen.dart';
import '../../features/delivery/screens/ocr_review_screen.dart';
import '../../features/delivery/screens/basket_form_screen.dart';
import '../../features/products/screens/product_search_screen.dart';
import '../../features/products/screens/product_detail_screen.dart';
import '../../features/products/screens/add_product_screen.dart';
import '../../features/price_comparison/screens/comparison_screen.dart';
import '../../features/price_comparison/screens/price_history_screen.dart';
import '../../features/analytics/screens/dashboard_screen.dart';
import '../widgets/main_shell.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/deliveries',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull != null;
      final isLoading = authState.isLoading;
      if (isLoading) return null;

      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register') ||
          state.matchedLocation.startsWith('/forgot-password');

      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) return '/deliveries';
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),

      // Main shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          // Tab 1: Deliveries
          GoRoute(
            path: '/deliveries',
            builder: (_, __) => const DeliveryListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const CameraScreen(),
              ),
              GoRoute(
                path: 'ocr-review',
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>;
                  return OcrReviewScreen(
                    imagePath: extra['imagePath'] as String,
                    recognizedLines: List<String>.from(extra['lines'] as List),
                  );
                },
              ),
              GoRoute(
                path: 'basket-form',
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return BasketFormScreen(
                    deliveryId: extra?['deliveryId'] as String?,
                    imagePath: extra?['imagePath'] as String?,
                    prefilledItems: extra?['items'] as List<Map<String, dynamic>>?,
                  );
                },
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    DeliveryDetailScreen(deliveryId: state.pathParameters['id']!),
              ),
            ],
          ),

          // Tab 2: Products
          GoRoute(
            path: '/products',
            builder: (_, __) => const ProductSearchScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (_, __) => const AddProductScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    ProductDetailScreen(productId: state.pathParameters['id']!),
              ),
            ],
          ),

          // Tab 3: Compare
          GoRoute(
            path: '/compare',
            builder: (_, __) => const ComparisonScreen(),
            routes: [
              GoRoute(
                path: 'delivery/:id',
                builder: (context, state) =>
                    ComparisonScreen(deliveryId: state.pathParameters['id']),
              ),
              GoRoute(
                path: 'price-history/:productId',
                builder: (context, state) =>
                    PriceHistoryScreen(productId: state.pathParameters['productId']!),
              ),
            ],
          ),

          // Tab 4: Analytics
          GoRoute(
            path: '/analytics',
            builder: (_, __) => const DashboardScreen(),
          ),

          // Profile
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page introuvable: ${state.uri}'),
      ),
    ),
  );
}
