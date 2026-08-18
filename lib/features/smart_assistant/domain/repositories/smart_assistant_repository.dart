import 'dart:io';
import '../entities/smart_diagnosis.dart';

abstract class SmartAssistantRepository {
  Future<SmartDiagnosis> analyzeProblem({
    required String description,
    File? image,
    List<FollowUpAnswer> answers = const [],
  });
}
