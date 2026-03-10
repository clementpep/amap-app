// lib/core/config/supabase_config.dart
// IMPORTANT: In production, use --dart-define or a .env loader.
// Never commit real credentials to git.

class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key',
  );

  static const String storageBucket = 'delivery-photos';
  static const String openFoodFactsBaseUrl = 'https://world.openfoodfacts.org';
  static const String openPricesBaseUrl = 'https://prices.openfoodfacts.org';
}
