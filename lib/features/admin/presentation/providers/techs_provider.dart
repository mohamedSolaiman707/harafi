import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/techs_repository.dart';
import '../../domain/models/technician.dart';

final techsRepositoryProvider = Provider<TechniciansRepository>((ref) {
  return SupabaseTechniciansRepository(Supabase.instance.client);
});

final techsStreamProvider = StreamProvider<List<Technician>>((ref) {
  return ref.watch(techsRepositoryProvider).watchAll();
});
