import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/either.dart';
import '../../../../core/failures.dart';

final jobOutcomesRepositoryProvider = Provider<JobOutcomeRepository>((ref) {
  return JobOutcomeRepository(Supabase.instance.client);
});

class JobOutcomeRepository {
  final SupabaseClient _client;

  JobOutcomeRepository(this._client);

  Future<Either<Failure, void>> create(Map<String, dynamic> data) async {
    try {
      await _client.from('job_outcomes').insert(data);
      return const Right(null);
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }
}
