import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin/data/repositories/job_outcomes_query_repository.dart';
import '../../../admin/domain/enums/service_type.dart';
import '../../../admin/domain/enums/tech_status.dart';
import '../../../admin/domain/models/technician.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../smart_assistant/domain/entities/smart_diagnosis.dart';
import '../../domain/services/technician_learning.dart';

class RankedTechnician {
  final Technician technician;
  final double score;
  final double reliabilityScore;
  final String reason;
  final int matchedJobs;
  final int firstVisitFixes;
  final int repeatIssues;

  const RankedTechnician({
    required this.technician,
    required this.score,
    required this.reliabilityScore,
    required this.reason,
    required this.matchedJobs,
    required this.firstVisitFixes,
    required this.repeatIssues,
  });
}

final smartMatchingProvider = Provider.family<List<RankedTechnician>, ({ServiceType service, String? area, SmartDiagnosis? diagnosis})>((ref, input) {
  final techs = ref.watch(techniciansProvider).valueOrNull ?? [];
  final outcomesAsync = ref.watch(jobOutcomesProvider);
  final outcomes = outcomesAsync.valueOrNull ?? const <Map<String, dynamic>>[];

  final candidates = techs.where((t) => t.spec == input.service && t.status != TechStatus.pending).toList();

  return candidates.map((tech) {
    final techOutcomes = outcomes.where((row) => row['recommended_technician_id']?.toString() == tech.id).toList();
    final matchedJobs = techOutcomes.length;
    final firstVisitFixes = techOutcomes.where((row) => row['first_visit_fix'] == true).length;
    final repeatIssues = techOutcomes.where((row) => row['repeat_issue'] == true).length;
    final firstVisitRate = matchedJobs == 0 ? 0.0 : firstVisitFixes / matchedJobs;
    final repeatRate = matchedJobs == 0 ? 0.0 : repeatIssues / matchedJobs;
    final reliabilityBaseScore = calculateReliabilityScore(
      totalOutcomes: tech.totalJobs,
      firstVisitFixRate: firstVisitRate,
      repeatIssueRate: repeatRate,
      warrantyClaimRate: 0,
      averageRating: tech.rating,
      isVerified: tech.isVerified,
      status: tech.status.label,
    );

    final areaScore = _areaScore(tech, input.area);
    final ratingScore = tech.rating * 12;
    final volumeScore = tech.totalJobs >= 50 ? 10 : tech.totalJobs * 0.2;
    final availabilityScore = switch (tech.status) {
      TechStatus.available => 25,
      TechStatus.busy => 10,
      TechStatus.onLeave => 0,
      TechStatus.pending => 0,
    };
    final verificationScore = tech.isVerified ? 8 : 0;

    final diagnosisBoost = _diagnosisBoost(tech, input.diagnosis);
    final score = areaScore + ratingScore + reliabilityBaseScore + volumeScore + availabilityScore + verificationScore + diagnosisBoost;
    final reason = _buildReason(tech, firstVisitRate, repeatRate, areaScore, diagnosisBoost);

    return RankedTechnician(
      technician: tech,
      score: score,
      reliabilityScore: reliabilityBaseScore,
      reason: reason,
      matchedJobs: matchedJobs,
      firstVisitFixes: firstVisitFixes,
      repeatIssues: repeatIssues,
    );
  }).toList()
    ..sort((a, b) => b.score.compareTo(a.score));
});

final jobOutcomesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(jobOutcomesQueryRepositoryProvider);
  final result = await repo.fetchAll();
  return result.when(
    left: (_) => <Map<String, dynamic>>[],
    right: (rows) => rows,
  );
});

double _areaScore(Technician tech, String? area) {
  final techArea = tech.area?.trim() ?? '';
  final requested = area?.trim() ?? '';
  if (techArea.isEmpty || requested.isEmpty) return 0;
  if (techArea == requested || techArea.contains(requested) || requested.contains(techArea)) return 12;
  return 0;
}

double _diagnosisBoost(Technician tech, SmartDiagnosis? diagnosis) {
  if (diagnosis == null) return 0;
  final summary = diagnosis.problemSummary.toLowerCase();
  final issue = diagnosis.possibleIssue.toLowerCase();
  final specLabel = tech.spec.label.toLowerCase();
  if (summary.contains(specLabel) || issue.contains(specLabel)) return 8;
  if (diagnosis.recommendedAction.toLowerCase().contains('فني') || diagnosis.recommendedAction.toLowerCase().contains('مختص')) return 4;
  return 0;
}

String _buildReason(Technician tech, double firstVisitRate, double repeatRate, double areaScore, double diagnosisBoost) {
  final parts = <String>[];
  if (areaScore > 0) parts.add('قريب من منطقتك');
  if (tech.isVerified) parts.add('موثق');
  if (firstVisitRate >= 0.7 && tech.totalJobs >= 5) parts.add('نتائج أول زيارة قوية');
  if (repeatRate <= 0.1 && tech.totalJobs >= 5) parts.add('نسبة رجوع أعطال منخفضة');
  if (diagnosisBoost > 0) parts.add('مطابق لتحليل المشكلة');
  if (parts.isEmpty) parts.add('أعلى توازن بين التقييم والتوفر');
  return parts.take(3).join(' · ');
}
