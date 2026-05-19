import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../features/admin/domain/enums/service_type.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            actions: [
              IconButton(
                onPressed: () => context.push('/admin'),
                icon: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white),
                tooltip: 'دخول الإدارة',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                AppConstants.appName,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                  ),
                ),
                child: const Icon(
                  Icons.home_repair_service,
                  size: 80,
                  color: Colors.white24,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'اختر الخدمة المطلوبة',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'نوفر لك أفضل الحرفيين في كفر الزيات بضغطة زر',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: ServiceType.values.map((type) {
                      return _ServiceCard(
                        type: type,
                        onTap: () => context.push('/request', extra: type),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 40),
                  _TrackingSection(),
                  const SizedBox(height: 60),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.push('/login'),
                      icon: const Icon(Icons.lock_outline, size: 16),
                      label: const Text('دخول الإدارة'),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceType type;
  final VoidCallback onTap;

  const _ServiceCard({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(type.icon, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              type.label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingSection extends StatelessWidget {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تتبع طلبك',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'أدخل كود التتبع (مثال: A1B2C3D4)',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  if (_controller.text.isNotEmpty) {
                    context.push('/track/${_controller.text}');
                  }
                },
                child: const Text('تتبع'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
