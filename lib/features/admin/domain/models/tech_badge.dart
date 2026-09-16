import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class TechBadge {
  final String id;
  final String title;
  final String icon;
  final Color color;
  final String description;

  const TechBadge({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.description,
  });

  static const verified = TechBadge(
    id: 'verified',
    title: 'موثّق رسمياً',
    icon: '⚡',
    color: AppColors.gold,
    description: 'تم توثيق بطاقة الرقم القومي والمستندات الرسمية',
  );

  static const topRated = TechBadge(
    id: 'top_rated',
    title: 'نجم التقييم الذهبي',
    icon: '⭐',
    color: Colors.amber,
    description: 'حاصل على متوسط تقييم 4.8 فما فوق من العملاء',
  );

  static const expert = TechBadge(
    id: 'expert',
    title: 'فني المائة عملية',
    icon: '💯',
    color: AppColors.success,
    description: 'أتم أكثر من 100 خدمة بنجاح واحترافية',
  );

  static const superFast = TechBadge(
    id: 'super_fast',
    title: 'سريع الاستجابة',
    icon: '🚀',
    color: Colors.lightBlue,
    description: 'سرعة استجابة فائقة في التوجه للعميل',
  );

  static const CleanRecord = TechBadge(
    id: 'clean_record',
    title: 'صاحب سجل نظيف',
    icon: '🛡️',
    color: Colors.purpleAccent,
    description: 'بدون أي شكاوى صيانة أو مطالبات ضمان',
  );
}
