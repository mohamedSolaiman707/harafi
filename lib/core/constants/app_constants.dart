class AppConstants {
  static const String appName = 'خدمات منزلية — كفر الزيات';
  
  // Supabase Configuration
  // These are fetched from environment variables during build time
  // Example: flutter build web --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_key
  
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // UI Strings
  static const String plumbing = 'سباكة';
  static const String electrical = 'كهرباء';
  static const String carpentry = 'نجارة';
  
  static const String pending = 'جاري';
  static const String completed = 'مكتمل';
  static const String cancelled = 'ملغي';

  static const String available = 'متاح';
  static const String busy = 'مشغول';
  static const String onLeave = 'إجازة';
}
