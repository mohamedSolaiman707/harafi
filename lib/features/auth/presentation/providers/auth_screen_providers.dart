import 'package:flutter_riverpod/flutter_riverpod.dart';

/// حالة تحميل شاشة دخول الأدمن
final loginLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);

/// حالة تحميل شاشة دخول الفني
final techLoginLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);

/// عداد النقرات لزر المطور/الأدمن السري
final adminTapCountProvider = StateProvider.autoDispose<int>((ref) => 0);
