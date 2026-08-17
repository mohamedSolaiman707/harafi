import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/repositories/techs_repository.dart';
import '../../domain/enums/service_type.dart';
import '../../domain/enums/tech_status.dart';
import '../../domain/models/technician.dart';
import 'orders_provider.dart';

final techsRepositoryProvider = Provider<TechniciansRepository>((ref) {
  return SupabaseTechniciansRepository(Supabase.instance.client);
});

// 1. مزود الفنيين الخام (جلب دوري من قاعدة البيانات)
final _rawTechsProvider = StreamProvider<List<Technician>>((ref) async* {
  final repo = ref.watch(techsRepositoryProvider);
  yield await repo.getAll();
  yield* Stream.periodic(AppConstants.pollingInterval).asyncMap((_) => repo.getAll());
});

// 2. المزود النهائي (StreamProvider ليدعم .future مع منع الـ Flicker)
final techniciansProvider = StreamProvider<List<Technician>>((ref) {
  final techsAsync = ref.watch(_rawTechsProvider);
  final ordersAsync = ref.watch(ordersStreamProvider);

  // نستخدم الـ Stream الخاص بـ _rawTechsProvider كأساس
  return techsAsync.when(
    data: (techs) {
      final orders = ordersAsync.valueOrNull ?? [];
      
      // حساب التقييمات في الذاكرة (سريع جداً ولا يسبب تحميل)
      final calculatedTechs = techs.map((tech) {
        final techOrders = orders.where((o) => 
          (o.techId == tech.id || o.techId == tech.phone) && 
          o.rating != null && o.rating! > 0
        ).toList();
        
        if (techOrders.isNotEmpty) {
          final double total = techOrders.fold(0.0, (sum, o) => sum + (o.rating as num));
          return tech.copyWith(rating: total / techOrders.length);
        }
        return tech;
      }).toList();
      
      return Stream.value(calculatedTechs);
    },
    // إرجاع الستريم الأصلي في حالة التحميل أو الخطأ
    loading: () => ref.watch(_rawTechsProvider.stream),
    error: (e, s) => Stream.error(e, s),
  );
});

final techsStreamProvider = techniciansProvider;

// الفنيون المتميزون بالقرب من العميل
final topRatedTechsProvider = Provider<List<Technician>>((ref) {
  final techs = ref.watch(techniciansProvider).valueOrNull ?? [];
  final userLocation = ref.watch(userLocationProvider);

  final approvedTechs = techs.where((t) => 
    t.status != TechStatus.pending && 
    t.walletBalance >= AppConstants.platformFee
  ).toList();

  final userCity = userLocation.city.trim();
  final userGov = userLocation.governorate.trim();
  final govCities = AppConstants.governoratesAndCities[userGov] ?? [];

  int locationScore(Technician t) {
    final techArea = t.area?.trim() ?? '';
    if (techArea.isEmpty) return 0;
    if (techArea == userCity || techArea.contains(userCity) || userCity.contains(techArea)) return 2;
    if (govCities.any((city) => techArea.contains(city) || city.contains(techArea))) return 1;
    return 0;
  }

  int rankScore(Technician t) {
    if (t.totalJobs >= 50 && t.rating >= 4.7) return 4;
    if (t.totalJobs >= 30 && t.rating >= 4.5) return 3;
    if (t.isVerified) return 2;
    if (t.totalJobs >= 10) return 1;
    return 0;
  }

  approvedTechs.sort((a, b) {
    int locDiff = locationScore(b) - locationScore(a);
    if (locDiff != 0) return locDiff;
    int rankDiff = rankScore(b) - rankScore(a);
    if (rankDiff != 0) return rankDiff;
    int ratingDiff = b.rating.compareTo(a.rating);
    if (ratingDiff != 0) return ratingDiff;
    return b.totalJobs.compareTo(a.totalJobs);
  });
  return approvedTechs.take(8).toList();
});

// الفني الحالي الموثق مع دعم الكاش
final currentTechnicianProvider = StateNotifierProvider<CurrentTechNotifier, AsyncValue<Technician?>>((ref) {
  return CurrentTechNotifier(ref);
});

class CurrentTechNotifier extends StateNotifier<AsyncValue<Technician?>> {
  final Ref _ref;
  static const _cacheKey = 'cached_tech_profile';

  CurrentTechNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    await _loadFromCache();
    _ref.listen(techniciansProvider, (previous, next) {
      _updateFromTechs(next);
    }, fireImmediately: true);
  }

  void _updateFromTechs(AsyncValue<List<Technician>> next) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      state = const AsyncValue.data(null);
      return;
    }

    next.whenData((techs) {
      final tech = techs.where((t) => t.id == user.id).firstOrNull;
      if (tech != null) {
        state = AsyncValue.data(tech);
        _saveToCache(tech);
      }
    });
  }

  void updateTech(Technician tech) {
    state = AsyncValue.data(tech);
    _saveToCache(tech);
    _ref.invalidate(techsRepositoryProvider); 
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);
      if (cachedData != null) {
        state = AsyncValue.data(Technician.fromJson(jsonDecode(cachedData)));
      }
    } catch (_) {}
  }

  Future<void> _saveToCache(Technician tech) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(Technician.technicianToJson(tech)));
    } catch (_) {}
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    state = const AsyncValue.data(null);
  }
}

final availableTechsProvider = Provider.family<List<Technician>, ServiceType>((ref, serviceType) {
  final techs = ref.watch(techniciansProvider).valueOrNull ?? [];
  return techs.where((t) => t.status == TechStatus.available && t.spec == serviceType && t.walletBalance >= AppConstants.platformFee).toList();
});

final techStatsProvider = Provider<TechStats>((ref) {
  final techs = ref.watch(techniciansProvider).valueOrNull ?? [];
  return TechStats(
    total: techs.length,
    available: techs.where((t) => t.status == TechStatus.available).length,
    busy: techs.where((t) => t.status == TechStatus.busy).length,
    pending: techs.where((t) =>  t.status == TechStatus.pending).length,
  );
});

class TechStats {
  final int total; final int available; final int busy; final int pending;
  TechStats({required this.total, required this.available, required this.busy, required this.pending});
}
