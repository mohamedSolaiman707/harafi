import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/either.dart';
import '../../../../core/failures.dart';
import '../../domain/dtos/order_dtos.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/models/order.dart';

abstract class OrdersRepository {
  Future<List<Order>> getAll();
  Future<Order> getByTrackingCode(String code);
  Future<List<Order>> getByPhone(String phone); // الدالة الجديدة
  Future<Order> create(Order order);
  Future<Order> update(String id, Map<String, dynamic> data);
  Future<void> delete(String id);
  Stream<List<Order>> watchAll();

  Future<Either<Failure, Order>> createOrder(CreateOrderDto dto);
  Future<Either<Failure, List<Order>>> getAllOrders();
  Future<Either<Failure, Order>> getOrderById(String id);
  Future<Either<Failure, Order>> getOrderByTrackingCode(String code);
  Future<Either<Failure, List<Order>>> getOrdersByStatus(OrderStatus status);
  Future<Either<Failure, List<Order>>> getOrdersByTech(String techId);
  Stream<List<Order>> watchOrders();
  Future<Either<Failure, Order>> assignTechnician(
    String orderId,
    String techId,
  );
  Future<Either<Failure, Order>> updateOrderStatus(
    String orderId,
    OrderStatus status, {
    int? finalPrice,
  });
  Future<Either<Failure, Order>> addAdminNotes(String orderId, String notes);
  Future<Either<Failure, Order>> rateOrder(String orderId, int rating);
  Future<Either<Failure, void>> deleteOrder(String id);
}

class SupabaseOrdersRepository implements OrdersRepository {
  final SupabaseClient _client;
  SupabaseOrdersRepository(this._client);

  @override
  Future<List<Order>> getAll() async {
    final data = await _client
        .from('orders')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((e) => Order.fromJson(e)).toList();
  }

  @override
  Future<Order> getByTrackingCode(String code) async {
    final List data = await _client
        .from('orders')
        .select()
        .eq('tracking_code', code);
    
    if (data.isEmpty) throw Exception('الطلب غير موجود');
    return Order.fromJson(data.first);
  }

  @override
  Future<List<Order>> getByPhone(String phone) async {
    final List data = await _client
        .from('orders')
        .select()
        .eq('client_phone', phone)
        .order('created_at', ascending: false);
    return data.map((e) => Order.fromJson(e)).toList();
  }

  @override
  Future<Order> create(Order order) async {
    final orderData = order.toJson();
    orderData.remove('id');
    orderData.remove('tracking_code');
    orderData.remove('created_at');
    orderData.remove('updated_at');
    orderData.remove('final_price');
    orderData.remove('admin_notes');
    orderData.remove('rating');

    if (orderData['tech_id'] == null ||
        orderData['tech_id'].toString().isEmpty) {
      orderData.remove('tech_id');
    }

    final List data = await _client
        .from('orders')
        .insert(orderData)
        .select();
        
    if (data.isEmpty) throw Exception('فشل إنشاء الطلب');
    return Order.fromJson(data.first);
  }

  @override
  Future<Order> update(String id, Map<String, dynamic> data) async {
    try {
      final List response = await _client
          .from('orders')
          .update(data)
          .eq('id', id)
          .select();
          
      if (response.isEmpty) throw Exception('لا توجد صلاحية لتحديث هذا الطلب أو أنه غير موجود');
      return Order.fromJson(response.first);
    } catch (e) {
      rethrow;
    }
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
        .order('created_at', ascending: false)
        .map((data) => data.map((e) => Order.fromJson(e)).toList());
  }

  @override
  Future<Either<Failure, Order>> createOrder(CreateOrderDto dto) async {
    try {
      final data = dto.toJson();
      data.remove('final_price');
      data.remove('admin_notes');

      final List response = await _client
          .from('orders')
          .insert(data)
          .select();
          
      if (response.isEmpty) return Left(DatabaseFailure('فشل إنشاء الطلب'));
      return Right(Order.fromJson(response.first));
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
      final List data = await _client.from('orders').select().eq('id', id);
      if (data.isEmpty) {
        return Left(DatabaseFailure('الطلب غير موجود أو ليس لديك صلاحية الوصول إليه.'));
      }
      return Right(Order.fromJson(data.first));
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Order>> getOrderByTrackingCode(String code) async {
    try {
      final List data = await _client
          .from('orders')
          .select()
          .eq('tracking_code', code);
          
      if (data.isEmpty) {
        return Left(DatabaseFailure('كود التتبع غير صحيح أو الطلب غير متاح.'));
      }
      return Right(Order.fromJson(data.first));
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
          .select()
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
          .select()
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
    String techId,
  ) async {
    try {
      final List response = await _client
          .from('orders')
          .update({'tech_id': techId})
          .eq('id', orderId)
          .select();

      if (response.isEmpty) {
        return Left(DatabaseFailure('لم يتم تحديث الطلب.'));
      }
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
  }) async {
    try {
      final Map<String, dynamic> data = {'status': status.label};
      if (finalPrice != null) data['final_price'] = finalPrice;
      final List response = await _client
          .from('orders')
          .update(data)
          .eq('id', orderId)
          .select();
          
      if (response.isEmpty) return Left(DatabaseFailure('فشل تحديث حالة الطلب'));
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
          .select();
      if (response.isEmpty) return Left(DatabaseFailure('الطلب غير موجود لإضافة الملاحظات.'));
      return Right(Order.fromJson(response.first));
    } catch (error) {
      return Left(DatabaseFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Order>> rateOrder(String orderId, int rating) async {
    try {
      final List response = await _client
          .from('orders')
          .update({'rating': rating})
          .eq('id', orderId)
          .select();
      if (response.isEmpty) return Left(DatabaseFailure('الطلب غير موجود لتقييمه.'));
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
