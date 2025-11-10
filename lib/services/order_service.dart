// services/order_service.dart (FIXED VERSION - Support Takeaway/Pickup/Delivery)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/order.dart';
import 'package:flutter/foundation.dart';

class OrderService {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://localhost:3000';

  // 🔹 Ambil semua order untuk kitchen
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

  // 🔹 Ambil semua order untuk bar
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

  // 🔹 Ambil semua order beverage
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

  // 🔹 Update status order (untuk kitchen)
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

  // 🔹 Update status order untuk bar
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

  // 🔹 Update status item beverage
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

  // 🔹 Start beverage order preparation
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
      return false;
    }
  }

  // 🔹 Complete beverage order
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
      return false;
    }
  }

  // ✅ Helper: Check apakah reservasi sudah waktunya dipindah ke penyiapan
  static bool shouldMoveReservationToPreparation(Order order) {
    if (order.reservationData == null) return false;

    final now = DateTime.now();
    final reservationData = order.reservationData!;

    // 🎯 Cek food_serving_option
    final servingOption = reservationData['food_serving_option'] ?? 'immediate';

    if (servingOption == 'scheduled') {
      // ✅ SCHEDULED: Gunakan food_serving_time sebagai patokan
      final servingTimeStr = reservationData['food_serving_time'];
      if (servingTimeStr == null) {
        if (kDebugMode) {
          print('⚠️ Scheduled reservation ${order.orderId} has no food_serving_time, fallback to immediate');
        }
        // Fallback ke immediate jika tidak ada food_serving_time
        return _checkImmediatePreparation(order, now);
      }

      try {
        final servingTime = DateTime.parse(servingTimeStr);
        final diffInMinutes = servingTime.difference(now).inMinutes;

        if (kDebugMode) {
          print('📅 [SCHEDULED] Checking reservation ${order.orderId}:');
          print('   Current time: $now');
          print('   Food serving time: $servingTime');
          print('   Difference: $diffInMinutes minutes');
        }

        // Mulai persiapan 30 menit sebelum food_serving_time
        return diffInMinutes <= 30 && diffInMinutes >= -60;
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error parsing food_serving_time: $e');
        }
        return false;
      }
    } else {
      // ✅ IMMEDIATE: Gunakan reservation_time sebagai patokan (default behavior)
      return _checkImmediatePreparation(order, now);
    }
  }

  // 🆕 Helper untuk cek immediate preparation
  static bool _checkImmediatePreparation(Order order, DateTime now) {
    if (order.reservationDateTime == null) return false;

    final reservationTime = order.reservationDateTime!;
    final diffInMinutes = reservationTime.difference(now).inMinutes;

    if (kDebugMode) {
      print('⚡ [IMMEDIATE] Checking reservation ${order.orderId}:');
      print('   Current time: $now');
      print('   Reservation time: $reservationTime');
      print('   Difference: $diffInMinutes minutes');
    }

    // Mulai persiapan 30 menit sebelum reservation_time
    return diffInMinutes <= 30 && diffInMinutes >= -60;
  }

  // 🆕 Helper: Get preparation start time untuk display
  static DateTime? getPreparationStartTime(Order order) {
    if (order.reservationData == null) return null;

    final reservationData = order.reservationData!;
    final servingOption = reservationData['food_serving_option'] ?? 'immediate';

    if (servingOption == 'scheduled') {
      final servingTimeStr = reservationData['food_serving_time'];
      if (servingTimeStr != null) {
        try {
          final servingTime = DateTime.parse(servingTimeStr);
          // 30 menit sebelum serving time
          return servingTime.subtract(const Duration(minutes: 30));
        } catch (e) {
          // Fallback ke reservation time
          return order.reservationDateTime?.subtract(const Duration(minutes: 30));
        }
      }
    }

    // Default: 30 menit sebelum reservation time
    return order.reservationDateTime?.subtract(const Duration(minutes: 30));
  }

  // 🆕 Helper: Get countdown text untuk reservasi
  static String getReservationCountdownText(Order order) {
    final prepStartTime = getPreparationStartTime(order);
    if (prepStartTime == null) return '-';

    final now = DateTime.now();
    final diff = prepStartTime.difference(now);

    if (diff.isNegative) {
      // Sudah waktunya mulai persiapan
      if (order.reservationData?['food_serving_option'] == 'scheduled') {
        final servingTimeStr = order.reservationData?['food_serving_time'];
        if (servingTimeStr != null) {
          try {
            final servingTime = DateTime.parse(servingTimeStr);
            final servingDiff = servingTime.difference(now);

            if (servingDiff.isNegative) {
              return 'Sudah lewat waktu serving';
            }

            final hours = servingDiff.inHours;
            final minutes = servingDiff.inMinutes.remainder(60);
            return 'Serving dalam ${hours > 0 ? '$hours jam ' : ''}$minutes menit';
          } catch (e) {
            return 'Waktunya mulai persiapan';
          }
        }
      }
      return 'Waktunya mulai persiapan';
    }

    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);

    if (hours > 0) {
      return 'Mulai persiapan dalam $hours jam $minutes menit';
    } else {
      return 'Mulai persiapan dalam $minutes menit';
    }
  }

  // ✅ Helper: Filter order untuk bar berdasarkan area meja
  static List<Order> _filterOrdersByBarArea(List<Order> orders, String barType) {
    final filtered = orders.where((order) {
      // ✅ Order tanpa table (takeaway/pickup/delivery) - tampilkan di SEMUA bar
      if (order.table.isEmpty) {
        if (kDebugMode) {
          print('📦 Order ${order.orderId} is non-dine-in (${order.orderType}) - showing in all bars');
        }
        return true; // ✅ TAMPILKAN DI SEMUA BAR
      }

      final tableNumber = order.table.toUpperCase();
      final firstChar = tableNumber[0];

      if (barType == 'depan') {
        // Bar depan: meja A-I dan angka
        return (firstChar.compareTo('A') >= 0 && firstChar.compareTo('I') <= 0) ||
            RegExp(r'^[0-9]').hasMatch(firstChar);
      } else if (barType == 'belakang') {
        // Bar belakang: hanya meja J-Z
        return firstChar.compareTo('J') >= 0 && firstChar.compareTo('Z') <= 0;
      }

      return false;
    }).toList();

    return filtered;
  }

  // ✅ Helper: Filter hanya item minuman dari order (FIXED VERSION)
  static List<Order> _filterBeverageItems(List<Order> orders) {
    final filteredOrders = <Order>[];

    for (var order in orders) {
      // Gunakan method isBarItem dari model OrderItem
      final beverageItems = order.items.where((item) => item.isBarItem).toList();

      if (beverageItems.isEmpty) continue;

      // Return order baru hanya dengan item minuman
      filteredOrders.add(Order(
        orderId: order.orderId,
        name: order.name,
        table: order.table,
        status: order.status,
        items: beverageItems,
        createdAt: order.createdAt,
        updatedAt: order.updatedAt,
        createdAtWIB: order.createdAtWIB,
        updatedAtWIB: order.updatedAtWIB,
        service: order.service,
        orderType: order.orderType,
        reservationDateTime: order.reservationDateTime,
        totalPrice: order.totalPrice,
        source: order.source,
        paymentMethod: order.paymentMethod,
      ));
    }

    return filteredOrders;
  }

  // 🔹 Refresh dan kategorikan order untuk KITCHEN
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
          continue;
        }


        bool isReservation = order.service.toLowerCase().contains('reservation') ||
            order.orderType?.toLowerCase() == 'reservation';

        if (isReservation) {
          if (status == 'onprocess') {
            preparing.add(order);
            continue;
          } else if (status == 'completed') {
            completed.add(order);
            continue;
          }

          if (shouldMoveReservationToPreparation(order)) {
            if (kDebugMode) {
              print('🔄 Moving reservation ${order.orderId} to preparation');
            }

            bool updated = await updateOrderStatus(order.orderId!, 'OnProcess');

            if (updated) {
              // ✅ Jangan modifikasi order langsung, langsung add ke preparing
              preparing.add(order);
            } else {
              reservations.add(order);
            }
            continue;
          } else {
            reservations.add(order);
            continue;
          }
        }

        // ✅ Kategorikan berdasarkan status (termasuk Takeaway/Pickup/Delivery)
        switch (status) {
          case 'waiting':
          // ✅ AUTO-CONFIRM untuk non-reservation orders (termasuk Takeaway/Pickup/Delivery)
            if (kDebugMode) {
              print('🚀 Auto-confirming ${order.orderType ?? 'order'} ${order.orderId} from Waiting to OnProcess');
            }

            bool updated = await updateOrderStatus(order.orderId!, 'OnProcess');

            if (updated) {
              // ✅ Jangan modifikasi order.status, langsung masukkan ke preparing
              preparing.add(order);

              if (kDebugMode) {
                print('✅ Order ${order.orderId} moved to preparing');
              }
            } else {
              // Fallback jika gagal update
              if (kDebugMode) {
                print('⚠️ Failed to auto-confirm ${order.orderId}, keeping in pending');
              }
              pending.add(order);
            }
            break;

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
            pending.add(order);
            break;
        }
      }

      if (kDebugMode) {
        print('✅ Kitchen orders: pending=${pending.length}, preparing=${preparing.length}, completed=${completed.length}, reservations=${reservations.length}');
      }

      return {
        'pending': pending,
        'preparing': preparing,
        'completed': completed,
        'reservations': reservations,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error refreshing kitchen orders: $e');
      }
      throw Exception('Error refreshing kitchen orders: $e');
    }
  }

  // 🔹 Refresh dan kategorikan order untuk BAR (FIXED VERSION)
  static Future<Map<String, List<Order>>> refreshBarOrders(String barType) async {
    try {
      List<Order> allOrders;

      // Coba ambil dari endpoint bar terlebih dahulu
      try {
        allOrders = await getBarOrders();
      } catch (e) {
        // Fallback: ambil semua beverage orders
        allOrders = await getAllBeverageOrders();
      }

      // Filter berdasarkan area meja (termasuk Takeaway/Pickup/Delivery)
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

        switch (status) {
          case 'waiting':
          // ✅ AUTO-CONFIRM untuk bar orders (termasuk Takeaway/Pickup/Delivery)
            if (kDebugMode) {
              print('🍹 Auto-confirming bar order ${order.orderId} (${order.orderType ?? 'dine-in'}) from Waiting to OnProcess');
            }

            bool updated = await updateOrderStatus(order.orderId!, 'OnProcess');

            if (updated) {
              // order.status = 'OnProcess';
              preparing.add(order);
            } else {
              pending.add(order);
            }
            break;

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
            pending.add(order);
            break;
        }
      }

      if (kDebugMode) {
        print('✅ Bar $barType orders: pending=${pending.length}, preparing=${preparing.length}, ready=${ready.length}, completed=${completed.length}');
      }

      return {
        'pending': pending,
        'preparing': preparing,
        'ready': ready,
        'completed': completed,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BAR SERVICE] Error: $e');
      }
      throw Exception('Error refreshing bar orders: $e');
    }
  }

  // 🔹 Legacy method untuk backward compatibility
  static Future<Map<String, List<Order>>> refreshOrders() async {
    return await refreshKitchenOrders();
  }

  // 🔹 Complete order dengan items tertentu
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
          'ngrok-skip-browser-warning': 'true'
        },
        body: json.encode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 🔹 Get order by ID
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
      return null;
    }
  }
}