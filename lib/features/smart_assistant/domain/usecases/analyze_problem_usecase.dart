import 'dart:io';
import '../entities/smart_diagnosis.dart';
import '../repositories/smart_assistant_repository.dart';

class AnalyzeProblemUseCase {
  final SmartAssistantRepository repository;

  AnalyzeProblemUseCase(this.repository);

  Future<SmartDiagnosis> call({
    required String description,
    File? image,
    List<FollowUpAnswer> answers = const [],
  }) {
    return repository.analyzeProblem(
      description: description,
      image: image,
      answers: answers,
    );
  }
}
