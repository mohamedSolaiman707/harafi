class AppConstants {
  static const String appName = 'خدمات منزلية — كفر الزيات';
  
  // Supabase Configuration
  // These are fetched from environment variables during build time
  // Example: flutter build web --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_key
  static const String supabaseUrl = String.fromEnvironment(
    'https://afrvjkwcywbrbvzovkyi.supabase.co',
    defaultValue: 'YOUR_SUPABASE_URL',
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFmcnZqa3djeXdicmJ2em92a3lpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkxNTU0NzQsImV4cCI6MjA5NDczMTQ3NH0.g_LW1UzZmLryiv8Lx_HSt9TOS66DPUSZC6lWjhgCZ9g',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
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
