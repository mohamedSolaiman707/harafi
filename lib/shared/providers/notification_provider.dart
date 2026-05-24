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

  NotificationNotifier(this._ref) : super([]) {
    _listenToOrders();
  }

  AppNotification? get latestIncoming => _latestIncoming;

  void _listenToOrders() {
    _ref.listen(ordersStreamProvider, (previous, next) async {
      final newOrders = next.valueOrNull ?? [];
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role');
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final lastTrackedCode = prefs.getString('last_tracked_code');
      
      if (_previousOrders.isEmpty) {
        _previousOrders = newOrders;
        return;
      }

      for (var order in newOrders) {
        // 1. تنبيه للأدمن
        if (userRole == 'admin' && !_previousOrders.any((o) => o.id == order.id)) {
          _addNotification(
            'طلب جديد: ${order.service.label}',
            'العميل ${order.clientName} سجل طلباً جديداً الآن.',
            NotificationType.urgent,
          );
          _playSound('new_order.mp3');
        }

        // 2. تنبيه للفني
        if (userRole == 'tech' && order.techId == userId) {
          final oldOrder = _previousOrders.where((o) => o.id == order.id).firstOrNull;
          if (oldOrder != null && oldOrder.status != order.status) {
            _addNotification(
              'تحديث في الطلب 🔧',
              'تغيرت حالة طلب العميل ${order.clientName} إلى ${order.status.label}',
              NotificationType.success,
            );
            _playSound('update.mp3');
          } else if (oldOrder == null) {
            _addNotification(
              'مهمة جديدة مسندة إليك! 🛠️',
              'لديك طلب ${order.service.label} جديد للعميل ${order.clientName}.',
              NotificationType.success,
            );
            _playSound('new_order.mp3');
          }
        }

        // 3. جديد: تنبيه للعميل (إذا كان يراقب طلباً معيناً)
        if (userRole == 'client' && order.trackingCode == lastTrackedCode) {
          final oldOrder = _previousOrders.where((o) => o.id == order.id).firstOrNull;
          if (oldOrder != null && oldOrder.status != order.status) {
            _addNotification(
              'تحديث في طلبك ✅',
              'حالة طلبك الآن: ${order.status.label}',
              _getBadgeType(order.status),
            );
            _playSound('update.mp3');
          }
        }
      }
      _previousOrders = newOrders;
    });
  }

  NotificationType _getBadgeType(OrderStatus status) {
    if (status == OrderStatus.completed) return NotificationType.success;
    if (status == OrderStatus.cancelled) return NotificationType.urgent;
    return NotificationType.info;
  }

  void _addNotification(String title, String body, NotificationType type) {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      timestamp: DateTime.now(),
      type: type,
    );
    state = [notification, ...state];
    _latestIncoming = notification;
    
    Future.delayed(const Duration(seconds: 5), () {
      if (_latestIncoming?.id == notification.id) {
        _latestIncoming = null;
        state = [...state]; 
      }
    });
  }

  Future<void> _playSound(String fileName) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      // Ignore audio errors on web
    }
  }

  void markAsRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id) AppNotification(id: n.id, title: n.title, body: n.body, timestamp: n.timestamp, type: n.type, isRead: true)
        else n,
    ];
  }

  void clearAll() {
    state = [];
    _latestIncoming = null;
  }

  int get unreadCount => state.where((n) => !n.isRead).length;
}
