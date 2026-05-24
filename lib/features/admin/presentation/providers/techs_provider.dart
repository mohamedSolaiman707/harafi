import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/repositories/techs_repository.dart';
import '../../domain/enums/service_type.dart';
import '../../domain/enums/tech_status.dart';
import '../../domain/models/technician.dart';

final techsRepositoryProvider = Provider<TechniciansRepository>((ref) {
  return SupabaseTechniciansRepository(Supabase.instance.client);
});

// تحديث دوري (Polling) للفنيين باستخدام الثابت المعرف في النظام
final techniciansProvider = StreamProvider<List<Technician>>((ref) async* {
  final repo = ref.watch(techsRepositoryProvider);
  
  // جلب البيانات فوراً
  final initialData = await repo.getAll();
  yield initialData;
  
  // تكرار الجلب بشكل دوري
  yield* Stream.periodic(AppConstants.pollingInterval).asyncMap((_) => repo.getAll());
});

final techsStreamProvider = techniciansProvider;

// الفنيون المتميزون (الأعلى تقييماً)
final topRatedTechsProvider = Provider<List<Technician>>((ref) {
  final techs = ref.watch(techniciansProvider).valueOrNull ?? [];
  final approvedTechs = techs.where((t) => t.status != TechStatus.pending).toList();
  // ترتيب حسب التقييم ثم عدد العمليات
  approvedTechs.sort((a, b) {
    int res = b.rating.compareTo(a.rating);
    if (res == 0) return b.totalJobs.compareTo(a.totalJobs);
    return res;
  });
  return approvedTechs.take(5).toList();
});

// الفني الحالي الموثق مع دعم الكاش الدائم (Persistent Cache)
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
    });
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);
      
      if (cachedData != null) {
        final Map<String, dynamic> json = jsonDecode(cachedData);
        final tech = Technician.fromJson(json);
        state = AsyncValue.data(tech);
      }
    } catch (e) {
      // Ignore cache errors
    }
  }

  Future<void> _saveToCache(Technician tech) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(Technician.technicianToJson(tech));
      await prefs.setString(_cacheKey, jsonStr);
    } catch (e) {
      // Ignore cache errors
    }
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    state = const AsyncValue.data(null);
  }
}

// الفنيين المتاحين للتعيين
final availableTechsProvider = Provider.family<List<Technician>, ServiceType>((ref, serviceType) {
  final techs = ref.watch(techniciansProvider).valueOrNull ?? [];
  return techs
      .where((t) => 
        t.status == TechStatus.available && 
        t.spec == serviceType
      )
      .toList();
});

final techStatsProvider = Provider<TechStats>((ref) {
  final techs = ref.watch(techniciansProvider).valueOrNull ?? [];
  return TechStats(
    total: techs.length,
    available: techs.where((t) => t.status == TechStatus.available).length,
    busy: techs.where((t) => t.status == TechStatus.busy).length,
    pending: techs.where((t) => t.status == TechStatus.pending).length,
  );
});

class TechStats {
  final int total;
  final int available;
  final int busy;
  final int pending;
  TechStats({required this.total, required this.available, required this.busy, required this.pending});
}
