import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  
  // 1. جلب البيانات فوراً
  yield await repo.getAll();
  
  // 2. تكرار الجلب بشكل دوري
  yield* Stream.periodic(AppConstants.pollingInterval).asyncMap((_) => repo.getAll());
});

final techsStreamProvider = techniciansProvider;

// الفني الحالي الموثق
final currentTechnicianProvider = Provider<AsyncValue<Technician?>>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return const AsyncValue.data(null);
  
  final techsAsync = ref.watch(techniciansProvider);
  return techsAsync.whenData((techs) => 
    techs.where((t) => t.id == user.id).firstOrNull
  );
});

// الفنيين المتاحين للتعيين (يجب أن يكون متاحاً ومعتمداً ومن نفس التخصص)
final availableTechsProvider = Provider.family<List<Technician>, ServiceType>((
  ref,
  serviceType,
) {
  final techs = ref.watch(techniciansProvider).valueOrNull ?? [];
  return techs
      .where((t) => 
        t.status == TechStatus.available && // متاح للعمل
        t.spec == serviceType // نفس التخصص المطلوبة
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
  TechStats({
    required this.total, 
    required this.available, 
    required this.busy, 
    required this.pending,
  });
}
