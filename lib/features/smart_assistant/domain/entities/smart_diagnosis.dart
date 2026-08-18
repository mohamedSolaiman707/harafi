import '../../../admin/domain/enums/service_type.dart';

class SmartDiagnosis {
  final String? detectedCategory;
  final String? categoryNameAr;
  final double confidence;
  final String problemSummary;
  final String possibleIssue;
  final String recommendedAction;
  final String analysisSource;
  final bool needsTechnician;
  final String urgency;
  final List<String> safetyNotes;
  final List<String> followUpQuestions;

  SmartDiagnosis({
    this.detectedCategory,
    this.categoryNameAr,
    required this.confidence,
    required this.problemSummary,
    required this.possibleIssue,
    this.recommendedAction = '',
    this.analysisSource = 'openai',
    required this.needsTechnician,
    required this.urgency,
    this.safetyNotes = const [],
    this.followUpQuestions = const [],
  });

  ServiceType? get serviceType {
    if (detectedCategory == null) return null;
    return ServiceType.values.where((e) {
      final name = e.name.toLowerCase();
      final cat = detectedCategory!.toLowerCase();
      // Mapping AI categories to ServiceType names
      if (cat == 'electricity') return name == 'electrical';
      if (cat == 'air_conditioning') return name == 'ac';
      if (cat == 'washing_machine') return name == 'washingmachines';
      if (cat == 'refrigerator') return name == 'refrigerators';
      if (cat == 'stove') return name == 'stoves';
      if (cat == 'tv') return name == 'screens';
      return name == cat;
    }).firstOrNull;
  }
}

class FollowUpAnswer {
  final String question;
  final String answer;
  FollowUpAnswer(this.question, this.answer);
}
