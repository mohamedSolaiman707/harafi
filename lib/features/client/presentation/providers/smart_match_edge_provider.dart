import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin/domain/enums/service_type.dart';
import '../../../smart_assistant/domain/entities/smart_diagnosis.dart';
import '../../data/repositories/smart_matching_repository.dart';

final smartMatchResultProvider = FutureProvider.autoDispose
    .family<SmartMatchResult, ({ServiceType service, String? area, String? description, SmartDiagnosis? diagnosis})>((ref, input) async {
  final repo = ref.watch(smartMatchingRepositoryProvider);
  return repo.rankTechnicians(
    service: input.service.label,
    area: input.area,
    description: input.description,
    diagnosis: input.diagnosis,
  );
});
