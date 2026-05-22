import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/techs_repository.dart';
import '../../domain/enums/service_type.dart';
import '../../domain/enums/tech_status.dart';
import '../../domain/models/technician.dart';

final techsRepositoryProvider = Provider<TechniciansRepository>((ref) {
  return SupabaseTechniciansRepository(Supabase.instance.client);
});

final techniciansProvider = StreamProvider<List<Technician>>((ref) {
  return ref.watch(techsRepositoryProvider).watchTechnicians();
});

final techsStreamProvider = techniciansProvider;

// Provider للفني الحالي المسجل دخوله
final currentTechnicianProvider = Provider<AsyncValue<Technician?>>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return const AsyncValue.data(null);
  
  final techsAsync = ref.watch(techniciansProvider);
  return techsAsync.whenData((techs) => 
    techs.where((t) => t.id == user.id).firstOrNull
  );
});

final availableTechsProvider = Provider.family<List<Technician>, ServiceType>((
  ref,
  serviceType,
) {
  final techs = ref.watch(techniciansProvider).valueOrNull ?? [];
  return techs
      .where((t) => t.status == TechStatus.available && t.spec == serviceType)
      .toList();
});

final techStatsProvider = Provider<TechStats>((ref) {
  final techs = ref.watch(techniciansProvider).valueOrNull ?? [];
  return TechStats(
    total: techs.length,
    available: techs.where((t) => t.status == TechStatus.available).length,
    busy: techs.where((t) => t.status == TechStatus.busy).length,
  );
});

class TechStats {
  final int total;
  final int available;
  final int busy;
  TechStats({required this.total, required this.available, required this.busy});
}
