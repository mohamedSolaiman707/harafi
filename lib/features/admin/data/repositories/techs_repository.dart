import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/either.dart';
import '../../../../core/failures.dart';
import '../../domain/dtos/technician_dtos.dart';
import '../../domain/enums/service_type.dart';
import '../../domain/enums/tech_status.dart';
import '../../domain/models/technician.dart';

abstract class TechniciansRepository {
  Future<List<Technician>> getAll();
  Future<Technician> create(Technician tech);
  Future<Technician> update(String id, Map<String, dynamic> data);
  Future<void> delete(String id);
  Stream<List<Technician>> watchAll();

  Future<Either<Failure, Technician>> addTechnician(CreateTechnicianDto dto);
  Future<Either<Failure, List<Technician>>> getAllTechnicians();
  Future<Either<Failure, Technician>> getTechnicianById(String id);
  Future<Either<Failure, List<Technician>>> getTechniciansBySpec(
    ServiceType spec,
  );
  Stream<List<Technician>> watchTechnicians();
  Future<Either<Failure, Technician>> updateTechnician(
    String id,
    UpdateTechnicianDto dto,
  );
  Future<Either<Failure, Technician>> updateTechStatus(
    String id,
    TechStatus status,
  );
  Future<Either<Failure, Technician>> incrementJobCount(String id);
  Future<Either<Failure, Technician>> updateRating(String id, double rating);
  Future<Either<Failure, void>> deleteTechnician(String id);
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
        .maybeSingle();
    if (data == null) throw Exception('فشل إنشاء الفني');
    return Technician.fromJson(data);
  }

  @override
  Future<Technician> update(String id, Map<String, dynamic> data) async {
    final response = await _client
        .from('technicians')
        .update(data)
        .eq('id', id)
        .select()
        .maybeSingle();
    if (response == null) throw Exception('الفني غير موجود');
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

  @override
  Future<Either<Failure, Technician>> addTechnician(
    CreateTechnicianDto dto,
  ) async {
    try {
      final data = await _client
          .from('technicians')
          .insert(dto.toJson())
          .select()
          .maybeSingle();
      if (data == null) return Left(DatabaseFailure('فشل إضافة الفني'));
      return Right(Technician.fromJson(data));
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Technician>>> getAllTechnicians() async {
    try {
      final techs = await getAll();
      return Right(techs);
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Technician>> getTechnicianById(String id) async {
    try {
      final response = await _client
          .from('technicians')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response == null) return Left(DatabaseFailure('الفني غير موجود'));
      return Right(Technician.fromJson(response));
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Technician>>> getTechniciansBySpec(
    ServiceType spec,
  ) async {
    try {
      final response = await _client
          .from('technicians')
          .select()
          .eq('spec', spec.label)
          .order('name', ascending: true);
      return Right(
        (response as List).map((e) => Technician.fromJson(e)).toList(),
      );
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Stream<List<Technician>> watchTechnicians() {
    return watchAll();
  }

  @override
  Future<Either<Failure, Technician>> updateTechnician(
    String id,
    UpdateTechnicianDto dto,
  ) async {
    try {
      final response = await _client
          .from('technicians')
          .update(dto.toJson())
          .eq('id', id)
          .select()
          .maybeSingle();
      if (response == null) return Left(DatabaseFailure('الفني غير موجود لتحديثه'));
      return Right(Technician.fromJson(response));
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Technician>> updateTechStatus(
    String id,
    TechStatus status,
  ) async {
    try {
      final response = await _client
          .from('technicians')
          .update({'status': status.label})
          .eq('id', id)
          .select()
          .maybeSingle();
      if (response == null) return Left(DatabaseFailure('الفني غير موجود لتحديث حالته'));
      return Right(Technician.fromJson(response));
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
)    }
  }

  @override
  Future<Either<Failure, Technician>> incrementJobCount(String id) async {
    try {
      final currentResult = await getTechnicianById(id);
      return await currentResult.when(
        left: (failure) => Left(failure),
        right: (tech) async {
          final response = await _client
              .from('technicians')
              .update({'total_jobs': tech.totalJobs + 1})
              .eq('id', id)
              .select()
              .maybeSingle();
          if (response == null) return Left(DatabaseFailure('فشل تحديث عدد المهام'));
          return Right(Technician.fromJson(response));
        },
      );
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Technician>> updateRating(
    String id,
    double rating,
  ) async {
    try {
      final response = await _client
          .from('technicians')
          .update({'rating': rating})
          .eq('id', id)
          .select()
          .maybeSingle();
      if (response == null) return Left(DatabaseFailure('فشل تحديث التقييم'));
      return Right(Technician.fromJson(response));
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTechnician(String id) async {
    try {
      await delete(id);
      return const Right(null);
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }
}
