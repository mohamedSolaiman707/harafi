import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/technician.dart';

abstract class TechniciansRepository {
  Future<List<Technician>> getAll();
  Future<Technician> create(Technician tech);
  Future<Technician> update(String id, Map<String, dynamic> data);
  Future<void> delete(String id);
  Stream<List<Technician>> watchAll();
}

class SupabaseTechniciansRepository implements TechniciansRepository {
  final SupabaseClient _client;
  SupabaseTechniciansRepository(this._client);

  @override
  Future<List<Technician>> getAll() async {
    final data = await _client
        .from('technicians')
        .select()
        .order('name', ascending: true);
    return (data as List).map((e) => Technician.fromJson(e)).toList();
  }

  @override
  Future<Technician> create(Technician tech) async {
    final data = await _client
        .from('technicians')
        .insert(tech.toJson())
        .select()
        .single();
    return Technician.fromJson(data);
  }

  @override
  Future<Technician> update(String id, Map<String, dynamic> data) async {
    final response = await _client
        .from('technicians')
        .update(data)
        .eq('id', id)
        .select()
        .single();
    return Technician.fromJson(response);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('technicians').delete().eq('id', id);
  }

  @override
  Stream<List<Technician>> watchAll() {
    return _client
        .from('technicians')
        .stream(primaryKey: ['id'])
        .order('name', ascending: true)
        .map((data) => data.map((e) => Technician.fromJson(e)).toList());
  }
}
