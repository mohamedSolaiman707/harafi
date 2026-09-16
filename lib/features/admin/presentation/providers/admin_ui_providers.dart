import 'package:flutter_riverpod/flutter_riverpod.dart';

/// نص البحث في قائمة الفنيين
final adminTechSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// فلتر قائمة الفنيين: 'all' | 'verified' | 'low_balance'
final adminTechFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
