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
  Future<Either<Failure, Technician>> incrementEarnings(String id, int amount);
  Future<Either<Failure, Technician>> updateRating(String id, double rating);
  Future<Either<Failure, void>> deleteTechnician(String id);
}

class SupabaseTechniciansRepository implements TechniciansRepository {
  final SupabaseClient _client;
  SupabaseTechniciansRepository(this._client);

  @override
  Future<List<Technician>> getAll() async {
    try {
      final data = await _client
          .from('technicians')
          .select()
          .order('name', ascending: true);
      return (data as List).map((e) => Technician.fromJson(e)).toList();
    } catch (e) {
      print('Error in TechniciansRepository.getAll: $e');
      return [];
    }
  }

  @override
  Future<Technician> create(Technician tech) async {
    final List data = await _client
        .from('technicians')
        .upsert(tech.toJson())
        .select();
    if (data.isEmpty) throw Exception('فشل إنشاء الفني');
    return Technician.fromJson(data.first);
  }

  @override
  Future<Technician> update(String id, Map<String, dynamic> data) async {
    final Map<String, dynamic> updateData = Map<String, dynamic>.from(data);
    updateData['id'] = id;
    final List response = await _client
        .from('technicians')
        .upsert(updateData)
        .select();
    if (response.isEmpty) throw Exception('الفني غير موجود');
    return Technician.fromJson(response.first);
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
        .asyncMap((_) => getAll())
        .handleError((error) {
          print('Realtime Stream Error (Technicians): $error');
          return <Technician>[];
        });
  }

  @override
  Future<Either<Failure, Technician>> addTechnician(
    CreateTechnicianDto dto,
  ) async {
    try {
      final List data = await _client
          .from('technicians')
          .upsert(dto.toJson())
          .select();
      if (data.isEmpty) return Left(DatabaseFailure('فشل إضافة الفني'));
      return Right(Technician.fromJson(data.first));
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
      final List response = await _client
          .from('technicians')
          .select()
          .eq('id', id);
      if (response.isEmpty) return Left(DatabaseFailure('الفني غير موجود'));
      return Right(Technician.fromJson(response.first));
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
      final Map<String, dynamic> data = dto.toJson();
      data['id'] = id; // إضافة المعرف لضمان التحديث الصحيح عبر upsert

      final List response = await _client
          .from('technicians')
          .upsert(data)
          .select();
      
      if (response.isEmpty) return Left(DatabaseFailure('تعذر تحديث بيانات الفني. تأكد من صلاحيات النظام.'));
      return Right(Technician.fromJson(response.first));
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
      final List response = await _client
          .from('technicians')
          .upsert({'id': id, 'status': status.label})
          .select();
      if (response.isEmpty) return Left(DatabaseFailure('فشل تحديث حالة الفني'));
      return Right(Technician.fromJson(response.first));
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Technician>> incrementJobCount(String id) async {
    try {
      final currentResult = await getTechnicianById(id);
      return await currentResult.when(
        left: (failure) => Left(failure),
        right: (tech) async {
          final List response = await _client
              .from('technicians')
              .upsert({'id': id, 'total_jobs': tech.totalJobs + 1})
              .select();
          if (response.isEmpty) return Left(DatabaseFailure('فشل تحديث عدد المهام'));
          return Right(Technician.fromJson(response.first));
        },
      );
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Technician>> incrementEarnings(String id, int amount) async {
    try {
      final currentResult = await getTechnicianById(id);
      return await currentResult.when(
        left: (failure) => Left(failure),
        right: (tech) async {
          final List response = await _client
              .from('technicians')
              .upsert({'id': id, 'total_earnings': tech.totalEarnings + amount})
              .select();
          if (response.isEmpty) return Left(DatabaseFailure('فشل تحديث الأرباح'));
          return Right(Technician.fromJson(response.first));
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
      final List response = await _client
          .from('technicians')
          .upsert({'id': id, 'rating': rating})
          .select();
      if (response.isEmpty) return Left(DatabaseFailure('فشل تحديث التقييم'));
      return Right(Technician.fromJson(response.first));
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
