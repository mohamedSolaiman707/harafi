class AppConstants {
  static const String appName = 'حرفـي | Harafi';
  
  // Assets
  static const String logoPath = 'assets/images/logo.png';

  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // Polling Configuration (Real-time alternative)
  static const Duration pollingInterval = Duration(seconds: 10);

  // UI Strings (يفضل استخدام Enums بدلاً منها في اللوجيك)
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
