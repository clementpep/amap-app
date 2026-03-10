import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';

// Simple router without complex providers for initial load
import 'package:go_router/go_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('🚀 Initializing Supabase...');
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
      debug: true, // Enable debug to see what's happening
    );
    print('✅ Supabase initialized successfully');
  } catch (e, stackTrace) {
    print('❌ Supabase initialization failed: $e');
    print('Stack trace: $stackTrace');
    // Continue anyway to show the interface
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
    return MaterialApp.router(
      title: 'AMAP',
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
    );
  }
}

// Simplified router without complex auth logic
final _router = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          Text('Erreur de navigation: ${state.error}'),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            child: const Text('Retour à l\'accueil'),
          ),
        ],
      ),
    ),
  ),
);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon AMAP'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.eco, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Application AMAP',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Gérez vos paniers bio avec facilité'),
                    const SizedBox(height: 16),
                    // Supabase Status
                    Row(
                      children: [
                        Icon(
                          Icons.cloud, 
                          color: supabase.auth.currentUser != null ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          supabase.auth.currentUser != null 
                            ? '✅ Connecté à Supabase' 
                            : '🔄 Supabase prêt (non connecté)',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'URL: ${SupabaseConfig.supabaseUrl}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Features Grid
            Text(
              'Fonctionnalités disponibles',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _FeatureCard(
                  icon: Icons.shopping_basket,
                  title: 'Livraisons',
                  subtitle: 'Gérer les paniers',
                  color: Colors.green,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fonction disponible après connexion')),
                    );
                  },
                ),
                _FeatureCard(
                  icon: Icons.camera_alt,
                  title: 'Scanner',
                  subtitle: 'Photos de tickets',
                  color: Colors.blue,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('OCR et scan de produits')),
                    );
                  },
                ),
                _FeatureCard(
                  icon: Icons.compare_arrows,
                  title: 'Comparaison',
                  subtitle: 'Prix bio/conventionnel',
                  color: Colors.orange,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Économies calculées automatiquement')),
                    );
                  },
                ),
                _FeatureCard(
                  icon: Icons.analytics,
                  title: 'Analytics',
                  subtitle: 'Statistiques mensuelles',
                  color: Colors.purple,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Graphiques et tendances')),
                    );
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login),
                label: const Text('Se connecter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Test connexion'),
                      content: Text('Supabase URL: ${SupabaseConfig.supabaseUrl}\nStatut: Prêt'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.info),
                label: const Text('Tester la connexion'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.login, size: 64),
              SizedBox(height: 20),
              Text(
                'Connexion AMAP',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Text('Authentification Supabase intégrée'),
              SizedBox(height: 20),
              Text('Interface en cours de développement...'),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}