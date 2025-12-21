// services/order_service.dart (UPDATED - Using Workstation Endpoints)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/order.dart';
import '../models/device.dart';
import 'package:flutter/foundation.dart';

class OrderService {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://localhost:3000';

  // ✅ NEW: Get orders by workstation type using Device
  static Future<List<Order>> getWorkstationOrders(Device device) async {
    try {
      final workstationType = device.workstationTypeString;

      if (kDebugMode) {
        print('📡 Fetching orders for workstation: $workstationType');
        print('   Device: ${device.deviceName}');
        print('   Location: ${device.location}');
      }

      // 🔧 Build URL with location parameter for bar workstation
      String url = '$baseUrl/api/workstation/$workstationType/orders';
      
      // Add location filter for bar workstation to ensure correct routing
      if (workstationType == 'bar' && device.location.isNotEmpty) {
        url += '?location=${device.location}';
        if (kDebugMode) {
          print('   🔧 Bar routing: filtering by location=${device.location}');
        }
      }

      // ✅ FIX: Add retry mechanism and increased timeout
      int retryCount = 0;
      const int maxRetries = 3;
      Exception? lastException;

      while (retryCount < maxRetries) {
        try {
          final response = await http.get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
            },
          ).timeout(
            const Duration(seconds: 30), // ⚡ OPTIMIZED: 30s timeout (was 15s)
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

          if (response.statusCode == 200) {
            final Map<String, dynamic> data = json.decode(response.body);

            if (data['success'] == true && data['data'] != null) {
              List<dynamic> ordersData = data['data'];

              if (kDebugMode) {
                print('✅ Received ${ordersData.length} orders for $workstationType');
                print('   Query time: ${data['meta']?['queryTime']}');
              }

              return ordersData.map((orderJson) => Order.fromJson(orderJson)).toList();
            } else {
              throw Exception('Invalid response format');
            }
          } else {
            throw Exception('Failed to load workstation orders: ${response.statusCode}');
          }
        } catch (e) {
          lastException = e as Exception;
          retryCount++;
          if (kDebugMode) {
            print('⚠️ Attempt $retryCount failed: $e');
          }
          if (retryCount >= maxRetries) break;
          // Wait before retrying (exponential backoff: 1s, 2s, 3s)
          await Future.delayed(Duration(seconds: retryCount));
        }
      }

      throw lastException ?? Exception('Failed to fetch workstation orders after $maxRetries attempts');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching workstation orders: $e');
      }
      throw Exception('Error fetching workstation orders: $e');
    }
  }

  // ✅ DEPRECATED: Legacy methods for backward compatibility
  @Deprecated('Use getWorkstationOrders(device) instead')
  static Future<List<Order>> getKitchenOrders() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders/kitchen'),
        headers: {'Content-Type': 'application/json'},
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

  @Deprecated('Use getWorkstationOrders(device) instead')
  static Future<List<Order>> getBarOrders() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders/bar'),
        headers: {'Content-Type': 'application/json'},
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

  // ✅ NEW: Update workstation order status
  static Future<bool> updateWorkstationOrderStatus(
      String orderId,
      String status,
      Device device,
      ) async {
    try {
      if (kDebugMode) {
        print('🔄 Updating workstation order status:');
        print('   Order: $orderId');
        print('   Status: $status');
        print('   Device: ${device.deviceName}');
        print('   Workstation: ${device.workstationTypeString}');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/workstation/orders/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': status,
          'workstationId': device.deviceId,
          'workstationName': device.deviceName,
          'workstationType': device.workstationTypeString,
        }),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Order status updated successfully');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('❌ Failed to update order status: ${response.statusCode}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating order status: $e');
      }
      return false;
    }
  }

  // ✅ DEPRECATED: Legacy update methods
  @Deprecated('Use updateWorkstationOrderStatus instead')
  static Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/orders/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': status}),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Error updating order status: $e');
      return false;
    }
  }

  // ✅ NEW: Batch auto-confirm multiple orders
  static Future<bool> batchAutoConfirmOrders(List<String> orderIds) async {
    if (orderIds.isEmpty) return false;

    try {
      if (kDebugMode) {
        print('📤 Batch confirming ${orderIds.length} orders: $orderIds');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/orders/batch-confirm'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'orderIds': orderIds}),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Batch confirm success for ${orderIds.length} orders');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('❌ Batch confirm failed: ${response.statusCode}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error batch confirming orders: $e');
      }
      return false;
    }
  }

  // ✅ Helper: Parse waktu dari database sebagai waktu lokal (strip timezone)
  static DateTime? _parseAsLocalTime(String? timeStr) {
    if (timeStr == null) return null;

    try {
      String cleanTimeStr = timeStr
          .replaceAll(RegExp(r'\+\d{2}:\d{2}$'), '')
          .replaceAll(RegExp(r'-\d{2}:\d{2}$'), '')
          .replaceAll('Z', '');

      return DateTime.parse(cleanTimeStr);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error parsing time string "$timeStr": $e');
      }
      return null;
    }
  }

  // ✅ Helper: Check apakah reservasi sudah waktunya dipindah ke penyiapan
  static bool shouldMoveReservationToPreparation(Order order) {
    if (order.reservationData == null) return false;

    final now = DateTime.now();
    final reservationData = order.reservationData!;
    final servingOption = reservationData['food_serving_option'] ?? 'immediate';

    if (servingOption == 'scheduled') {
      final servingTimeStr = reservationData['food_serving_time'];
      if (servingTimeStr == null) {
        if (kDebugMode) {
          print('⚠️ Scheduled reservation ${order.orderId} has no food_serving_time');
        }
        return _checkImmediatePreparation(order, now);
      }

      final servingTime = _parseAsLocalTime(servingTimeStr);
      if (servingTime == null) return false;

      final diffInMinutes = servingTime.difference(now).inMinutes;

      if (kDebugMode) {
        print('📅 [SCHEDULED] Checking reservation ${order.orderId}:');
        print('   Current time: $now');
        print('   Food serving time (local): $servingTime');
        print('   Difference: $diffInMinutes minutes');
      }

      return diffInMinutes <= 30 && diffInMinutes >= -60;
    } else {
      return _checkImmediatePreparation(order, now);
    }
  }

  static bool _checkImmediatePreparation(Order order, DateTime now) {
    if (order.reservationDateTime == null) return false;

    final reservationTime = order.reservationDateTime!;
    final diffInMinutes = reservationTime.difference(now).inMinutes;

    if (kDebugMode) {
      print('⚡ [IMMEDIATE] Checking reservation ${order.orderId}:');
      print('   Difference: $diffInMinutes minutes');
    }

    return diffInMinutes <= 30 && diffInMinutes >= -60;
  }

  // ✅ NEW: Refresh orders using Device object
  static Future<Map<String, List<Order>>> refreshWorkstationOrders(Device device) async {
    try {
      final allOrders = await getWorkstationOrders(device);

      List<Order> pending = [];
      List<Order> waiting = [];
      List<Order> preparing = [];
      List<Order> completed = [];
      List<Order> reservations = [];

      for (var order in allOrders) {
        if (kDebugMode) {
          print('📦 Order ${order.orderId}:');
          print('   orderType: ${order.orderType}');
          print('   service: ${order.service}');
          print('   status: ${order.status}');
          print('   isReservation check: ${order.service.toLowerCase().contains('reservation') || order.orderType?.toLowerCase() == 'reservation'}');
        }
        String status = order.status.toLowerCase();

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
              print('📅 Reservation ${order.orderId} ready for preparation');
            }
            reservations.add(order);
            continue;
          } else {
            reservations.add(order);
            continue;
          }
        }

        switch (status) {
          case 'waiting':
            waiting.add(order);
            if (kDebugMode) {
              print('🔥 Order ${order.orderId} in WAITING status');
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
        print('✅ ${device.workstationTypeString} orders: '
            'pending=${pending.length}, '
            'waiting=${waiting.length}, '
            'preparing=${preparing.length}, '
            'completed=${completed.length}, '
            'reservations=${reservations.length}');
      }

      return {
        'pending': pending,
        'waiting': waiting,
        'preparing': preparing,
        'completed': completed,
        'reservations': reservations,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error refreshing workstation orders: $e');
      }
      throw Exception('Error refreshing workstation orders: $e');
    }
  }

  // ✅ DEPRECATED: Legacy refresh methods
  // @Deprecated('Use refreshWorkstationOrders(device) instead')
  // static Future<Map<String, List<Order>>> refreshKitchenOrders() async {
  //   try {
  //     final _ = await getKitchenOrders();
  //     // ... existing implementation
  //     return {
  //       'pending': [],
  //       'waiting': [],
  //       'preparing': [],
  //       'completed': [],
  //       'reservations': [],
  //     };
  //   } catch (e) {
  //     throw Exception('Error refreshing kitchen orders: $e');
  //   }
  // }
  //
  // @Deprecated('Use refreshWorkstationOrders(device) instead')
  // static Future<Map<String, List<Order>>> refreshBarOrders(String barType) async {
  //   try {
  //     final allOrders = await getBarOrders();
  //     // ... existing implementation
  //     return {
  //       'pending': [],
  //       'waiting': [],
  //       'preparing': [],
  //       'ready': [],
  //       'completed': [],
  //     };
  //   } catch (e) {
  //     throw Exception('Error refreshing bar orders: $e');
  //   }
  // }

  // Other methods remain unchanged...
  static Future<bool> completeOrderWithItems(
      String orderId,
      List<String> completedItemIds,
      {String? completedBy}
      ) async {
    try {
      final Map<String, dynamic> body = {'completedItems': completedItemIds};
      if (completedBy != null) body['completedBy'] = completedBy;

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

  static Future<Order?> getOrderById(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders/$orderId'),
        headers: {'Content-Type': 'application/json'},
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