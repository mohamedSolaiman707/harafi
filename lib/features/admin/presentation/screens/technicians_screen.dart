import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/techs_provider.dart';
import '../widgets/tech_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';

class TechniciansScreen extends ConsumerWidget {
  const TechniciansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techsAsync = ref.watch(techsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الفنيين'),
        actions: [
          IconButton(
            onPressed: () {
              // Show add technician dialog
            },
            icon: const Icon(Icons.person_add),
          ),
        ],
      ),
      body: techsAsync.when(
        data: (techs) {
          if (techs.isEmpty) {
            return const Center(child: Text('لا يوجد فنيين مسجلين حالياً'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: techs.length,
            itemBuilder: (context, index) {
              final tech = techs[index];
              return TechCard(
                tech: tech,
                onEdit: () {
                  // Show edit dialog
                },
              );
            },
          );
        },
        loading: () => const LoadingWidget(),
        error: (err, stack) => AppErrorWidget(
          message: 'حدث خطأ أثناء تحميل بيانات الفنيين',
          onRetry: () => ref.refresh(techsStreamProvider),
        ),
      ),
    );
  }
}
