import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/either.dart';
import '../../../../core/failures.dart';

final jobOutcomesQueryRepositoryProvider = Provider<JobOutcomesQueryRepository>((ref) {
  return JobOutcomesQueryRepository(Supabase.instance.client);
});

class JobOutcomesQueryRepository {
  final SupabaseClient _client;

  JobOutcomesQueryRepository(this._client);

  Future<Either<Failure, List<Map<String, dynamic>>>> fetchAll() async {
    try {
      final data = await _client
          .from('job_outcomes')
          .select()
          .order('created_at', ascending: false);

      final list = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return Right(list);
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }
}
