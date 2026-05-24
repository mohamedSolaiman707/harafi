import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../features/admin/presentation/providers/orders_provider.dart';
import '../../../features/admin/domain/models/order.dart';
import '../../../features/admin/domain/enums/order_status.dart';

enum NotificationType { info, success, warning, urgent }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final NotificationType type;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.type = NotificationType.info,
    this.isRead = false,
  });
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, List<AppNotification>>((ref) {
  return NotificationNotifier(ref);
});

class NotificationNotifier extends StateNotifier<List<AppNotification>> {
  final Ref _ref;
  List<Order> _previousOrders = [];
  AppNotification? _latestIncoming;
  final _audioPlayer = AudioPlayer();
  bool _isInitialized = false;

  NotificationNotifier(this._ref) : super([]) {
    _init();
  }

  AppNotification? get latestIncoming => _latestIncoming;
  
  int get unreadCount => state.where((n) => !n.isRead).length;

  Future<void> _init() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    final userRole = prefs.getString('user_role') ?? 'client';
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final lastTrackedCode = prefs.getString('last_tracked_code');

    // تحديد الـ Stream المناسب بناءً على الدور لضمان وصول التنبيهات
    final providerToListen = _getRelevantProvider(userRole, userId);
    
    if (providerToListen == null) return;

    _ref.listen(providerToListen, (previous, next) {
      final newOrders = next.valueOrNull ?? [];
      
      // تجنب التنبيهات عند أول تحميل للتطبيق
      if (_previousOrders.isEmpty && newOrders.isNotEmpty) {
        _previousOrders = newOrders;
        return;
      }

      for (var order in newOrders) {
        final oldOrder = _previousOrders.where((o) => o.id == order.id).firstOrNull;

        // 1. منطق الأدمن
        if (userRole == 'admin' && oldOrder == null) {
          _notify('طلب جديد: ${order.service.label}', 'العميل ${order.clientName} سجل طلباً جديداً.', NotificationType.urgent, 'new_order.mp3');
        }

        // 2. منطق الفني
        if (userRole == 'tech' && order.techId == userId) {
          if (oldOrder == null) {
            _notify('مهمة جديدة! 🛠️', 'تم إسناد طلب ${order.service.label} إليك.', NotificationType.success, 'new_order.mp3');
          } else if (oldOrder.status != order.status) {
            _notify('تحديث الطلب', 'تغيرت حالة طلب ${order.clientName} إلى ${order.status.label}', NotificationType.info, 'update.mp3');
          }
        }

        // 3. منطق العميل
        if (userRole == 'client' && order.trackingCode == lastTrackedCode) {
          if (oldOrder != null && oldOrder.status != order.status) {
            _notify('تحديث في طلبك ✅', 'حالة طلبك الآن أصبحت: ${order.status.label}', _getBadgeType(order.status), 'update.mp3');
          }
        }
      }
      _previousOrders = newOrders;
    });

    _isInitialized = true;
  }

  ProviderListenable<AsyncValue<List<Order>>>? _getRelevantProvider(String role, String? userId) {
    if (role == 'admin') return ordersStreamProvider;
    if (role == 'tech' && userId != null) return techOrdersStreamProvider(userId);
    return ordersStreamProvider;
  }

  void _notify(String title, String body, NotificationType type, String sound) {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      timestamp: DateTime.now(),
      type: type,
    );
    
    state = [notification, ...state];
    _latestIncoming = notification;
    _playSound(sound);
    
    // إخفاء الـ Overlay بعد 5 ثوانٍ
    Future.delayed(const Duration(seconds: 5), () {
      if (_latestIncoming?.id == notification.id) {
        _latestIncoming = null;
        state = [...state]; 
      }
    });
  }

  NotificationType _getBadgeType(OrderStatus status) {
    if (status == OrderStatus.completed) return NotificationType.success;
    if (status == OrderStatus.cancelled) return NotificationType.urgent;
    return NotificationType.info;
  }

  Future<void> _playSound(String fileName) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$fileName'));
    } catch (_) {}
  }

  void markAsRead(String id) {
    state = [for (final n in state) if (n.id == id) AppNotification(id: n.id, title: n.title, body: n.body, timestamp: n.timestamp, type: n.type, isRead: true) else n];
  }

  void clearLatest() {
    _latestIncoming = null;
    state = [...state];
  }

  void clearAll() {
    state = [];
    _latestIncoming = null;
  }
}
