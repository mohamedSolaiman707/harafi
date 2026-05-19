class AppConstants {
  static const String appName = 'خدمات منزلية — كفر الزيات';
  
  // Assets
  static const String logoPath = 'assets/images/logo.png';

  // Supabase Configuration
  // Values are injected via --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=...
  
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
