import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin/data/repositories/job_outcomes_query_repository.dart';
import '../../../admin/domain/models/technician.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../domain/services/technician_learning.dart';

class LearningInsight {
  final String technicianId;
  final int totalOutcomes;
  final int firstVisitFixes;
  final int repeatIssues;
  final int warrantyClaims;
  final int ratedJobs;
  final double firstVisitFixRate;
  final double repeatIssueRate;
  final double warrantyClaimRate;
  final double averageRating;
  final double avgResolutionMinutes;
  final double reliabilityScore;

  const LearningInsight({
    required this.technicianId,
    required this.totalOutcomes,
    required this.firstVisitFixes,
    required this.repeatIssues,
    required this.warrantyClaims,
    required this.ratedJobs,
    required this.firstVisitFixRate,
    required this.repeatIssueRate,
    required this.warrantyClaimRate,
    required this.averageRating,
    required this.avgResolutionMinutes,
    required this.reliabilityScore,
  });
}

final jobOutcomesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(jobOutcomesQueryRepositoryProvider);
  final result = await repo.fetchAll();
  return result.when(
    left: (_) => <Map<String, dynamic>>[],
    right: (rows) => rows,
  );
});

final learningInsightsProvider = Provider.family<LearningInsight?, String>((ref, technicianId) {
  final techs = ref.watch(techniciansProvider).valueOrNull ?? [];
  final outcomes = ref.watch(jobOutcomesProvider).valueOrNull ?? const <Map<String, dynamic>>[];
  final tech = techs.where((item) => item.id == technicianId).firstOrNull;
  if (tech == null) return null;

  final techOutcomes = outcomes.where((row) => row['recommended_technician_id']?.toString() == technicianId).toList();
  final totalOutcomes = techOutcomes.length;
  final firstVisitFixes = techOutcomes.where((row) => row['first_visit_fix'] == true).length;
  final repeatIssues = techOutcomes.where((row) => row['repeat_issue'] == true).length;
  final warrantyClaims = techOutcomes.where((row) => row['warranty_claimed'] == true).length;
  final ratedJobs = techOutcomes.where((row) => row['customer_rating'] != null).length;
  final totalRating = techOutcomes.fold<double>(0, (sum, row) => sum + ((row['customer_rating'] as num?)?.toDouble() ?? 0));
  final totalResolution = techOutcomes.fold<double>(0, (sum, row) => sum + ((row['resolution_time_minutes'] as num?)?.toDouble() ?? 0));

  final firstVisitFixRate = totalOutcomes == 0 ? 0.0 : firstVisitFixes / totalOutcomes;
  final repeatIssueRate = totalOutcomes == 0 ? 0.0 : repeatIssues / totalOutcomes;
  final warrantyClaimRate = totalOutcomes == 0 ? 0.0 : warrantyClaims / totalOutcomes;
  final averageRating = ratedJobs == 0 ? tech.rating : totalRating / ratedJobs;
  final avgResolutionMinutes = totalOutcomes == 0 ? 0.0 : totalResolution / totalOutcomes;
  final reliabilityScore = calculateReliabilityScore(
    totalOutcomes: totalOutcomes,
    firstVisitFixRate: firstVisitFixRate,
    repeatIssueRate: repeatIssueRate,
    warrantyClaimRate: warrantyClaimRate,
    averageRating: averageRating,
    isVerified: tech.isVerified,
    status: tech.status.label,
  );

  return LearningInsight(
    technicianId: technicianId,
    totalOutcomes: totalOutcomes,
    firstVisitFixes: firstVisitFixes,
    repeatIssues: repeatIssues,
    warrantyClaims: warrantyClaims,
    ratedJobs: ratedJobs,
    firstVisitFixRate: firstVisitFixRate,
    repeatIssueRate: repeatIssueRate,
    warrantyClaimRate: warrantyClaimRate,
    averageRating: averageRating,
    avgResolutionMinutes: avgResolutionMinutes,
    reliabilityScore: reliabilityScore,
  );
});
