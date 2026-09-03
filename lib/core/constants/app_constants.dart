class AppConstants {
  static const String appName = 'حرفي | Harafi';

  static const String logoPath = 'assets/images/logo2.png';

  static const String supabaseUrl = 'https://afrvjkwcywbrbvzovkyi.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFmcnZqa3djeXdicmJ2em92a3lpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkxNTU0NzQsImV4cCI6MjA5NDczMTQ3NH0.g_LW1UzZmLryiv8Lx_HSt9TOS66DPUSZC6lWjhgCZ9g';

  static const Duration pollingInterval = Duration(seconds: 10);
  static const int platformFee = 30;

  static const Map<String, List<String>> governoratesAndCities = {
    'الغربية': [
      'كفر الزيات',
      'طنطا',
      'المحلة الكبرى',
      'زفتى',
      'سمنود',
      'بسيون',
      'قطور',
    ],
    'القاهرة': [
      'مدينة نصر',
      'التجمع الخامس',
      'المعادي',
      'مصر الجديدة',
      'وسط البلد',
      'الشروق',
    ],
    'الجيزة': [
      'الدقي',
      'المهندسين',
      '6 أكتوبر',
      'الشيخ زايد',
      'الهرم',
      'فيصل',
    ],
    'الإسكندرية': [
      'سموحة',
      'ميامي',
      'المنتزه',
      'سيدي بشر',
      'محرم بك',
    ],
    'المنوفية': [
      'شبين الكوم',
      'منوف',
      'أشمون',
      'السادات',
    ],
  };

  static const List<String> areas = [
    'الكل',
    'حي الزهور',
    'حي السلام',
    'شارع الجلاء',
    'منطقة المحطة',
    'شارع الجيش',
    'حي المعلمين',
    'قرى مجاورة',
  ];

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
