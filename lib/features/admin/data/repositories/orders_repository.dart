import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/either.dart';
import '../../../../core/failures.dart';
import '../../domain/dtos/order_dtos.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/models/order.dart';

abstract class OrdersRepository {
  Future<List<Order>> getAll();
  Future<Order> getByTrackingCode(String code);
  Future<List<Order>> getByPhone(String phone);
  Future<Order> create(Order order);
  Future<Order> update(String id, Map<String, dynamic> data);
  Future<void> delete(String id);
  Stream<List<Order>> watchAll();
  Stream<List<Order>> watchTechOrders(String techId);

  Future<Either<Failure, Order>> createOrder(CreateOrderDto dto);
  Future<Either<Failure, List<Order>>> getAllOrders();
  Future<Either<Failure, Order>> getOrderById(String id);
  Future<Either<Failure, Order>> getOrderByTrackingCode(String code);
  Future<Either<Failure, List<Order>>> getOrdersByStatus(OrderStatus status);
  Future<Either<Failure, List<Order>>> getOrdersByTech(String techId);
  Stream<List<Order>> watchOrders();

  Future<Either<Failure, Order>> assignTechnician(
    String orderId,
    String techId, {
    DateTime? estimatedArrival,
  });

  Future<Either<Failure, Order>> updateOrderStatus(
    String orderId,
    OrderStatus status, {
    int? finalPrice,
    String? techNotes,
    DateTime? completedAt,
    String? logMessage,
  });

  Future<Either<Failure, Order>> addAdminNotes(String orderId, String notes);
  Future<Either<Failure, Order>> rateOrder(
    String orderId,
    int rating, {
    String? comment,
  });
  Future<Either<Failure, void>> deleteOrder(String id);
}

class SupabaseOrdersRepository implements OrdersRepository {
  final SupabaseClient _client;
  SupabaseOrdersRepository(this._client);

  static const _orderSelect = '*, order_logs(*)';

  @override
  Future<List<Order>> getAll() async {
    final data = await _client
        .from('orders')
        .select(_orderSelect)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Order.fromJson(e)).toList();
  }

  @override
  Future<Order> getByTrackingCode(String code) async {
    final List data = await _client
        .from('orders')
        .select(_orderSelect)
        .eq('tracking_code', code);

    if (data.isEmpty) throw Exception('الطلب غير موجود');
    return Order.fromJson(data.first);
  }

  @override
  Future<List<Order>> getByPhone(String phone) async {
    final List data = await _client
        .from('orders')
        .select(_orderSelect)
        .eq('client_phone', phone)
        .order('created_at', ascending: false);
    return data.map((e) => Order.fromJson(e)).toList();
  }

  @override
  Future<Order> create(Order order) async {
    final orderData = order.toJson();

    // إزالة الحقول التي يتم إنشاؤها تلقائياً أو التي قد لا تكون موجودة في الجدول
    orderData.remove('id');
    orderData.remove('tracking_code');
    orderData.remove('created_at');
    orderData.remove('updated_at');
    orderData.remove('final_price');
    orderData.remove('admin_notes');
    orderData.remove('tech_notes');
    orderData.remove('rating');
    orderData.remove('order_logs');
    orderData.remove('completed_at');
    orderData.remove(
      'estimated_arrival',
    ); // شيله مؤقتاً لو مش موجود في الداتابيز

    if (orderData['tech_id'] == null ||
        orderData['tech_id'].toString().isEmpty) {
      orderData.remove('tech_id');
    }

    orderData['status'] = order.status.label;

    final List data = await _client
        .from('orders')
        .insert(orderData)
        .select(_orderSelect);

    if (data.isEmpty) throw Exception('فشل إنشاء الطلب');

    await _client.from('order_logs').insert({
      'order_id': data.first['id'],
      'status': OrderStatus.pending.label,
      'message': 'تم استلام الطلب وبانتظار المراجعة',
    });

    return Order.fromJson(data.first);
  }

  @override
  Future<Order> update(String id, Map<String, dynamic> data) async {
    final Map<String, dynamic> updateData = Map<String, dynamic>.from(data);

    if (updateData.containsKey('status')) {
      final status = updateData['status'];
      if (status is OrderStatus) {
        updateData['status'] = status.label;
      }
    }

    final List response = await _client
        .from('orders')
        .update(updateData)
        .eq('id', id)
        .select(_orderSelect);

    if (response.isEmpty) throw Exception('الطلب غير موجود');
    return Order.fromJson(response.first);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('orders').delete().eq('id', id);
  }

  @override
  Stream<List<Order>> watchAll() {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .asyncMap((_) => getAll());
  }

  @override
  Stream<List<Order>> watchTechOrders(String techId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('tech_id', techId)
        .asyncMap((_) async {
          final data = await _client
              .from('orders')
              .select(_orderSelect)
              .eq('tech_id', techId)
              .order('created_at', ascending: false);
          return (data as List).map((e) => Order.fromJson(e)).toList();
        });
  }

  @override
  Future<Either<Failure, Order>> createOrder(CreateOrderDto dto) async {
    try {
      final order = await create(
        Order(
          id: '',
          trackingCode: '',
          clientName: dto.clientName,
          clientPhone: dto.clientPhone,
          service: dto.service,
          area: dto.area,
          description: dto.description,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      return Right(order);
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Order>>> getAllOrders() async {
    try {
      final orders = await getAll();
      return Right(orders);
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Order>> getOrderById(String id) async {
    try {
      final List data = await _client
          .from('orders')
          .select(_orderSelect)
          .eq('id', id);
      if (data.isEmpty) return Left(DatabaseFailure('الطلب غير موجود'));
      return Right(Order.fromJson(data.first));
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Order>> getOrderByTrackingCode(String code) async {
    try {
      final order = await getByTrackingCode(code);
      return Right(order);
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Order>>> getOrdersByStatus(
    OrderStatus status,
  ) async {
    try {
      final response = await _client
          .from('orders')
          .select(_orderSelect)
          .eq('status', status.label)
          .order('created_at', ascending: false);
      return Right((response as List).map((e) => Order.fromJson(e)).toList());
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Order>>> getOrdersByTech(String techId) async {
    try {
      final response = await _client
          .from('orders')
          .select(_orderSelect)
          .eq('tech_id', techId)
          .order('created_at', ascending: false);
      return Right((response as List).map((e) => Order.fromJson(e)).toList());
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Stream<List<Order>> watchOrders() {
    return watchAll();
  }

  @override
  Future<Either<Failure, Order>> assignTechnician(
    String orderId,
    String techId, {
    DateTime? estimatedArrival,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'tech_id': techId,
        'status': OrderStatus.assigned.label,
      };
      // هنا برضه ممكن تضرب لو العمود مش موجود، يفضل تظيفه في الداتابيز
      if (estimatedArrival != null) {
        data['estimated_arrival'] = estimatedArrival.toIso8601String();
      }

      final List response = await _client
          .from('orders')
          .update(data)
          .eq('id', orderId)
          .select(_orderSelect);

      if (response.isEmpty) return Left(DatabaseFailure('لم يتم تحديث الطلب'));

      await _client.from('order_logs').insert({
        'order_id': orderId,
        'status': OrderStatus.assigned.label,
        'message': 'تم تعيين فني للطلب',
      });

      return Right(Order.fromJson(response.first));
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Order>> updateOrderStatus(
    String orderId,
    OrderStatus status, {
    int? finalPrice,
    String? techNotes,
    DateTime? completedAt,
    String? logMessage,
  }) async {
    try {
      final Map<String, dynamic> data = {'status': status.label};

      if (finalPrice != null) data['final_price'] = finalPrice;
      if (techNotes != null) data['tech_notes'] = techNotes;
      if (completedAt != null)
        data['completed_at'] = completedAt.toIso8601String();

      final List response = await _client
          .from('orders')
          .update(data)
          .eq('id', orderId)
          .select(_orderSelect);

      if (response.isEmpty)
        return Left(DatabaseFailure('فشل تحديث حالة الطلب'));

      await _client.from('order_logs').insert({
        'order_id': orderId,
        'status': status.label,
        'message': logMessage ?? 'تم تغيير حالة الطلب إلى ${status.label}',
      });

      return Right(Order.fromJson(response.first));
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Order>> addAdminNotes(
    String orderId,
    String notes,
  ) async {
    try {
      final List response = await _client
          .from('orders')
          .update({'admin_notes': notes})
          .eq('id', orderId)
          .select(_orderSelect);
      if (response.isEmpty) return Left(DatabaseFailure('الطلب غير موجود'));
      return Right(Order.fromJson(response.first));
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Order>> rateOrder(
    String orderId,
    int rating, {
    String? comment,
  }) async {
    try {
      final Map<String, dynamic> data = {'rating': rating};
      if (comment != null) data['rating_comment'] = comment;

      final List response = await _client
          .from('orders')
          .update(data)
          .eq('id', orderId)
          .select(_orderSelect);
      if (response.isEmpty) return Left(DatabaseFailure('الطلب غير موجود'));
      return Right(Order.fromJson(response.first));
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteOrder(String id) async {
    try {
      await _client.from('orders').delete().eq('id', id);
      return const Right(null);
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }
}
