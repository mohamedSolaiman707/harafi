import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../features/admin/presentation/providers/orders_provider.dart';
import '../../../features/admin/domain/models/order.dart';
import '../../../features/admin/domain/enums/order_status.dart';

enum NotificationType { info, success, warning, urgent, chat }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final NotificationType type;
  final String? orderId;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.type = NotificationType.info,
    this.orderId,
    this.isRead = false,
  });
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, List<AppNotification>>((ref) {
  return NotificationNotifier(ref);
});

final unreadMsgCountsProvider = Provider<Map<String, int>>((ref) {
  ref.watch(notificationProvider);
  return ref.read(notificationProvider.notifier).unreadMsgCounts;
});

class NotificationNotifier extends StateNotifier<List<AppNotification>> {
  final Ref _ref;
  List<Order> _previousOrders = [];
  AppNotification? _latestIncoming;
  final _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  final Set<String> _notifiedMsgIds = {};
  bool _initialMsgFetchDone = false;
  final Map<String, int> _unreadMsgCounts = {};

  NotificationNotifier(this._ref) : super([]) {
    _init();
  }

  AppNotification? get latestIncoming => _latestIncoming;
  
  int get unreadCount => state.where((n) => !n.isRead).length;

  Map<String, int> get unreadMsgCounts => Map.unmodifiable(_unreadMsgCounts);

  int getUnreadCountForOrder(String orderId) => _unreadMsgCounts[orderId] ?? 0;

  void clearUnreadForOrder(String orderId) {
    if ((_unreadMsgCounts[orderId] ?? 0) > 0) {
      _unreadMsgCounts[orderId] = 0;
      state = [...state];
    }
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    
    final prefs = await SharedPreferences.getInstance();
    final userRole = prefs.getString('user_role') ?? 'client';
    final userId = Supabase.instance.client.auth.currentUser?.id;

    _initOrdersListener(userRole, userId);
    _initChatMessagesListener();
  }

  void _initOrdersListener(String userRole, String? userId) {
    final providerToListen = _getRelevantProvider(userRole, userId);
    if (providerToListen == null) return;

    final Set<String> notifiedEventKeys = {};

    _ref.listen(providerToListen, (previous, next) async {
      final newOrders = next.valueOrNull ?? [];
      
      // تجنب التنبيهات عند أول تحميل للتطبيق
      if (_previousOrders.isEmpty && newOrders.isNotEmpty) {
        _previousOrders = newOrders;
        return;
      }

      final freshPrefs = await SharedPreferences.getInstance();
      final activeRole = freshPrefs.getString('user_role') ?? 'client';
      final activeUserId = Supabase.instance.client.auth.currentUser?.id;
      final lastTrackedCode = freshPrefs.getString('last_tracked_code');

      for (var order in newOrders) {
        final oldOrder = _previousOrders.where((o) => o.id == order.id).firstOrNull;

        // 1. منطق الأدمن (فقط إذا كان دور المستخدم الحالي أدمن)
        if (activeRole == 'admin' && oldOrder == null) {
          final eventKey = 'admin_new_${order.id}';
          if (!notifiedEventKeys.contains(eventKey)) {
            notifiedEventKeys.add(eventKey);
            _notify('طلب جديد: ${order.service.label}', 'العميل ${order.clientName} سجل طلباً جديداً.', NotificationType.urgent, 'new_order.mp3', orderId: order.id);
          }
        }

        // 2. منطق الفني (فقط إذا كان دور المستخدم الحالي فني ومسجل دخول ومسند له هذا الطلب)
        if (activeRole == 'tech' && activeUserId != null && order.techId == activeUserId) {
          final isNewlyAssigned = oldOrder == null || oldOrder.techId != activeUserId;
          if (isNewlyAssigned) {
            final eventKey = 'tech_assigned_${order.id}_$activeUserId';
            if (!notifiedEventKeys.contains(eventKey)) {
              notifiedEventKeys.add(eventKey);
              _notify('مهمة جديدة! 🛠️', 'تم إسناد طلب ${order.service.label} إليك.', NotificationType.success, 'new_order.mp3', orderId: order.id);
            }
          } else if (oldOrder.status != order.status) {
            final eventKey = 'tech_status_${order.id}_${order.status.name}';
            if (!notifiedEventKeys.contains(eventKey)) {
              notifiedEventKeys.add(eventKey);
              _notify('تحديث الطلب', 'تغيرت حالة طلب ${order.clientName} إلى ${order.status.label}', NotificationType.info, 'update.mp3', orderId: order.id);
            }
          }
        }

        // 3. منطق العميل (فقط إذا كان الدور عميل وهناك تحديث في حالة طلبه الخاص)
        if (activeRole == 'client' && lastTrackedCode != null && order.trackingCode == lastTrackedCode) {
          if (oldOrder != null && oldOrder.status != order.status) {
            final eventKey = 'client_status_${order.id}_${order.status.name}';
            if (!notifiedEventKeys.contains(eventKey)) {
              notifiedEventKeys.add(eventKey);
              _notify('تحديث في طلبك ✅', 'حالة طلبك الآن أصبحت: ${order.status.label}', _getBadgeType(order.status), 'update.mp3', orderId: order.id);
            }
          }
        }
      }
      _previousOrders = newOrders;
    });
  }

  void _initChatMessagesListener() {
    try {
      Supabase.instance.client
          .from('order_messages')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(20)
          .listen((rows) async {
            if (!_initialMsgFetchDone) {
              for (var row in rows) {
                final id = row['id'] as String?;
                if (id != null) _notifiedMsgIds.add(id);
              }
              _initialMsgFetchDone = true;
              return;
            }

            final freshPrefs = await SharedPreferences.getInstance();
            final activeRole = freshPrefs.getString('user_role') ?? 'client';

            for (var row in rows) {
              final msgId = row['id'] as String?;
              final senderType = row['sender_type'] as String?;
              final senderName = row['sender_name'] as String? ?? 'رسالة جديدة';
              final messageText = row['message'] as String? ?? '';
              final orderId = row['order_id'] as String?;

              if (msgId == null || senderType == null || _notifiedMsgIds.contains(msgId)) {
                continue;
              }

              _notifiedMsgIds.add(msgId);

              // تنبيه المستخدم إذا كانت الرسالة واردة من الطرف الآخر
              bool shouldNotify = false;
              if (activeRole == 'tech' && senderType != 'tech') {
                shouldNotify = true;
              } else if (activeRole == 'client' && senderType != 'client') {
                shouldNotify = true;
              } else if (activeRole == 'admin' && senderType != 'admin') {
                shouldNotify = true;
              }

              if (shouldNotify) {
                if (orderId != null) {
                  _unreadMsgCounts[orderId] = (_unreadMsgCounts[orderId] ?? 0) + 1;
                }

                _notify(
                  '💬 رسالة جديدة من $senderName',
                  messageText,
                  NotificationType.chat,
                  'update.mp3',
                  orderId: orderId,
                );
              }
            }
          }, onError: (_) {});
    } catch (_) {}
  }

  ProviderListenable<AsyncValue<List<Order>>>? _getRelevantProvider(String role, String? userId) {
    if (role == 'admin') return ordersStreamProvider;
    if (role == 'tech' && userId != null) return techOrdersStreamProvider(userId);
    return ordersStreamProvider;
  }

  void _notify(String title, String body, NotificationType type, String sound, {String? orderId}) {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      timestamp: DateTime.now(),
      type: type,
      orderId: orderId,
    );
    
    state = [notification, ...state];
    _latestIncoming = notification;
    _playSound(sound);
    
    // إخفاء الـ Overlay بعد 6 ثوانٍ
    Future.delayed(const Duration(seconds: 6), () {
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
    state = [for (final n in state) if (n.id == id) AppNotification(id: n.id, title: n.title, body: n.body, timestamp: n.timestamp, type: n.type, orderId: n.orderId, isRead: true) else n];
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
