import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 44,
        height: 44,
        child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 3),
      ),
    );
  }
}
