// services/order_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/order.dart';
import 'package:flutter/foundation.dart';

// Provide a safe fallback 'category' getter for OrderItem in case the model
// doesn't expose a category field; this returns null so existing null-aware
// code continues to work without compile errors.
extension OrderItemCategoryExtension on OrderItem {
  String? get category => null;
}

class OrderService {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://localhost:3000';

  // 📹 Ambil semua order untuk kitchen
  static Future<List<Order>> getKitchenOrders() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders/kitchen'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          List<dynamic> ordersData = data['data'];
          return ordersData.map((orderJson) => Order.fromJson(orderJson)).toList();
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('Failed to load kitchen orders: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching kitchen orders: $e');
    }
  }

  // 📹 Ambil semua order untuk bar
  static Future<List<Order>> getBarOrders() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders/bar'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          List<dynamic> ordersData = data['data'];
          return ordersData.map((orderJson) => Order.fromJson(orderJson)).toList();
        } else {
          throw Exception('Invalid response format for bar orders');
        }
      } else {
        throw Exception('Failed to load bar orders: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching bar orders: $e');
    }
  }

  // 📹 Ambil semua order beverage
  static Future<List<Order>> getAllBeverageOrders() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders/beverage'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          List<dynamic> ordersData = data['data'];
          return ordersData.map((orderJson) => Order.fromJson(orderJson)).toList();
        } else {
          throw Exception('Invalid response format for beverage orders');
        }
      } else {
        throw Exception('Failed to load beverage orders: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching beverage orders: $e');
    }
  }

  // 📹 Update status order (untuk kitchen)
  static Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/orders/$orderId/status'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'status': status,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating order status: $e');
      }
      return false;
    }
  }

  // 📹 Update status order untuk bar
  static Future<bool> updateBarOrderStatus(String orderId, String status, {String? bartenderName}) async {
    try {
      final Map<String, dynamic> body = {'status': status};
      if (bartenderName != null) {
        body['bartenderName'] = bartenderName;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/orders/bar/$orderId/status'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating bar order status: $e');
      }
      return false;
    }
  }

  // 📹 Update status item beverage
  static Future<bool> updateBeverageItemStatus(String orderId, String itemId, String status, {String? bartenderName}) async {
    try {
      final Map<String, dynamic> body = {'status': status};
      if (bartenderName != null) {
        body['bartenderName'] = bartenderName;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/orders/beverage/$orderId/status'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'itemId': itemId,
          'status': status,
          'bartenderName': bartenderName,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating beverage item status: $e');
      }
      return false;
    }
  }

  // 📹 Start beverage order preparation
  static Future<bool> startBeverageOrder(String orderId, String bartenderName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/orders/beverage/$orderId/start'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'bartenderName': bartenderName,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error starting beverage order: $e');
      }
      return false;
    }
  }

  // 📹 Complete beverage order
  static Future<bool> completeBeverageOrder(String orderId, {String? bartenderName, List<String>? completedItems}) async {
    try {
      final Map<String, dynamic> body = {};
      if (bartenderName != null) {
        body['bartenderName'] = bartenderName;
      }
      if (completedItems != null) {
        body['completedItems'] = completedItems;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/orders/beverage/$orderId/complete'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error completing beverage order: $e');
      }
      return false;
    }
  }

  // ✅ Helper: Check apakah reservasi sudah waktunya dipindah ke penyiapan
  static bool shouldMoveReservationToPreparation(Order order) {
    if (order.reservationDateTime == null) return false;

    final now = DateTime.now();
    final reservationTime = order.reservationDateTime!;

    // Hitung selisih waktu dalam menit
    final diff = reservationTime.difference(now);
    final diffInMinutes = diff.inMinutes;

    if (kDebugMode) {
      print('🕐 Checking reservation ${order.orderId}:');
      print('   Current time: $now');
      print('   Reservation time: $reservationTime');
      print('   Difference: $diffInMinutes minutes');
    }

    // Pindahkan jika waktu reservasi 30 menit atau kurang dari sekarang
    // Dan belum terlalu lewat (maksimal 60 menit setelah waktu reservasi)
    return diffInMinutes <= 30 && diffInMinutes >= -60;
  }

  // ✅ Helper: Filter order untuk bar berdasarkan area meja
  static List<Order> _filterOrdersByBarArea(List<Order> orders, String barType) {
    return orders.where((order) {
      if (order.table == null || order.table!.isEmpty) return false;

      final tableNumber = order.table!.toUpperCase();
      final firstChar = tableNumber[0];

      if (barType == 'depan') {
        // Bar depan: meja A-I
        return firstChar.compareTo('A') >= 0 && firstChar.compareTo('I') <= 0;
      } else if (barType == 'belakang') {
        // Bar belakang: meja J-Z
        return firstChar.compareTo('J') >= 0 && firstChar.compareTo('Z') <= 0;
      }

      return false;
    }).toList();
  }

  // ✅ Helper: Filter hanya item minuman dari order
  static List<Order> _filterBeverageItems(List<Order> orders) {
    return orders.map((order) {
      final beverageItems = order.items.where((item) {
        final category = item.category?.toLowerCase() ?? '';
        final name = item.name.toLowerCase();

        return category.contains('minuman') ||
            category.contains('beverage') ||
            category.contains('drink') ||
            name.contains('jus') ||
            name.contains('soda') ||
            name.contains('kopi') ||
            name.contains('teh') ||
            name.contains('air') ||
            name.contains('mocktail') ||
            name.contains('cocktail') ||
            name.contains('bir') ||
            name.contains('wine');
      }).toList();

      if (beverageItems.isEmpty) return null;

      // Return order baru hanya dengan item minuman
      return Order(
        orderId: order.orderId,
        name: order.name,
        table: order.table,
        status: order.status,
        items: beverageItems,
        createdAt: order.createdAt,
        updatedAt: order.updatedAt,
        service: order.service,
        orderType: order.orderType,
        reservationDateTime: order.reservationDateTime,
        totalPrice: order.totalPrice, source: '', paymentMethod: '',
      );
    }).where((order) => order != null).cast<Order>().toList();
  }

  // 📹 Refresh dan kategorikan order untuk KITCHEN
  static Future<Map<String, List<Order>>> refreshKitchenOrders() async {
    try {
      final allOrders = await getKitchenOrders();

      List<Order> pending = [];
      List<Order> preparing = [];
      List<Order> completed = [];
      List<Order> reservations = [];

      for (var order in allOrders) {
        String status = order.status.toLowerCase();

        // Skip cancelled/paid
        if (status == 'cancelled' || status == 'paid') {
          if (kDebugMode) {
            print('Order ${order.orderId} has status: ${order.status} - skipping');
          }
          continue;
        }

        // ✅ Cek apakah ini reservasi
        bool isReservation = order.service.toLowerCase().contains('reservation') ||
            order.orderType?.toLowerCase() == 'reservation';

        if (isReservation) {
          // Jika sudah status OnProcess atau Completed, masukkan ke preparing/completed
          if (status == 'onprocess') {
            preparing.add(order);
            if (kDebugMode) {
              print('✅ Reservation ${order.orderId} already in preparation');
            }
            continue;
          } else if (status == 'completed') {
            completed.add(order);
            continue;
          }

          // Cek apakah perlu dipindah ke preparation
          if (shouldMoveReservationToPreparation(order)) {
            if (kDebugMode) {
              print('🔄 Moving reservation ${order.orderId} to preparation');
              print('   Time: ${order.reservationDateTime}');
            }

            // Auto-update status jadi OnProcess
            bool updated = await updateOrderStatus(order.orderId!, 'OnProcess');

            if (updated) {
              // Update status lokal
              order.status = 'OnProcess';
              preparing.add(order);
              if (kDebugMode) {
                print('✅ Successfully moved ${order.orderId} to preparation');
              }
            } else {
              // Jika gagal update, tetap di reservations
              reservations.add(order);
              if (kDebugMode) {
                print('❌ Failed to update ${order.orderId}, keeping in reservations');
              }
            }
            continue;
          } else {
            // Tetap di reservations
            reservations.add(order);
            if (kDebugMode) {
              print('⏰ Reservation ${order.orderId} not ready yet');
            }
            continue;
          }
        }

        // Kategorikan berdasarkan status (non-reservation)
        switch (status) {
          case 'waiting':
          case 'pending':
            pending.add(order);
            break;
          case 'onprocess':
          case 'preparing':
            preparing.add(order);
            break;
          case 'completed':
          case 'ready':
            completed.add(order);
            break;
          default:
            if (kDebugMode) {
              print('Order ${order.orderId} has unknown status: ${order.status}');
            }
            // Default ke pending untuk status unknown
            pending.add(order);
            break;
        }
      }

      if (kDebugMode) {
        print(
            'Kitchen orders categorized: pending=${pending.length}, preparing=${preparing.length}, completed=${completed.length}, reservations=${reservations.length}');
      }

      return {
        'pending': pending,
        'preparing': preparing,
        'completed': completed,
        'reservations': reservations,
      };
    } catch (e) {
      throw Exception('Error refreshing kitchen orders: $e');
    }
  }

  // 📹 Refresh dan kategorikan order untuk BAR
  static Future<Map<String, List<Order>>> refreshBarOrders(String barType) async {
    try {
      List<Order> allOrders;

      // Coba ambil dari endpoint bar terlebih dahulu
      try {
        allOrders = await getBarOrders();
      } catch (e) {
        // Fallback: ambil semua beverage orders dan filter berdasarkan area
        if (kDebugMode) {
          print('⚠️ Bar endpoint not available, using fallback: $e');
        }
        allOrders = await getAllBeverageOrders();
      }

      // Filter berdasarkan area meja
      allOrders = _filterOrdersByBarArea(allOrders, barType);

      // Filter hanya item minuman
      allOrders = _filterBeverageItems(allOrders);

      List<Order> pending = [];
      List<Order> preparing = [];
      List<Order> completed = [];
      List<Order> ready = [];

      for (var order in allOrders) {
        String status = order.status.toLowerCase();

        // Skip cancelled/paid
        if (status == 'cancelled' || status == 'paid') {
          continue;
        }

        // Untuk bar, kita handle status yang berbeda
        switch (status) {
          case 'waiting':
          case 'pending':
            pending.add(order);
            break;
          case 'onprocess':
          case 'preparing':
            preparing.add(order);
            break;
          case 'ready':
          case 'ready_to_serve':
            ready.add(order);
            break;
          case 'completed':
          case 'served':
            completed.add(order);
            break;
          default:
          // Default ke pending untuk status unknown
            pending.add(order);
            break;
        }
      }

      if (kDebugMode) {
        print(
            'Bar ($barType) orders categorized: pending=${pending.length}, preparing=${preparing.length}, ready=${ready.length}, completed=${completed.length}');
      }

      return {
        'pending': pending,
        'preparing': preparing,
        'ready': ready,
        'completed': completed,
      };
    } catch (e) {
      throw Exception('Error refreshing bar orders: $e');
    }
  }

  // 📹 Legacy method untuk backward compatibility
  static Future<Map<String, List<Order>>> refreshOrders() async {
    return await refreshKitchenOrders();
  }

  // 📹 Complete order dengan items tertentu (untuk batch completion)
  static Future<bool> completeOrderWithItems(String orderId, List<String> completedItemIds, {String? completedBy}) async {
    try {
      final Map<String, dynamic> body = {
        'completedItems': completedItemIds,
      };

      if (completedBy != null) {
        body['completedBy'] = completedBy;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/orders/$orderId/complete'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error completing order with items: $e');
      }
      return false;
    }
  }

  // 📹 Get order by ID
  static Future<Order?> getOrderById(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders/$orderId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          return Order.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting order by ID: $e');
      }
      return null;
    }
  }
}