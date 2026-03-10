import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('🚀 Initializing Supabase...');
    print('URL: ${SupabaseConfig.supabaseUrl}');
    print('Key: ${SupabaseConfig.supabaseAnonKey.substring(0, 20)}...');
    
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
      debug: true,
    );
    
    print('✅ Supabase initialized successfully');
  } catch (error, stackTrace) {
    print('❌ Supabase initialization failed: $error');
    print('Stack trace: $stackTrace');
    
    // Continue anyway - let the app start without Supabase
    print('🔄 Continuing without Supabase...');
  }

  runApp(
    const ProviderScope(
      child: AmapApp(),
    ),
  );
}

class AmapApp extends ConsumerWidget {
  const AmapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'AMAP',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
    );
  }
}
