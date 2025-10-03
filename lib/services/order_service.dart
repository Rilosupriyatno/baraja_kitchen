// services/order_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/order.dart';
import 'package:flutter/foundation.dart';

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
        // const JsonEncoder encoder = JsonEncoder.withIndent('  ');
        // final prettyData = encoder.convert(data);
        // debugPrint('Fetched orders:\n$prettyData');

        if (data['success'] == true && data['data'] != null) {
          List<dynamic> ordersData = data['data'];
          return ordersData.map((orderJson) => Order.fromJson(orderJson)).toList();
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('Failed to load orders: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching orders: $e');
    }
  }

  // 📹 Update status order
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

  // 📹 Refresh dan kategorikan order
  static Future<Map<String, List<Order>>> refreshOrders() async {
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
            pending.add(order);
            break;
          case 'onprocess':
            preparing.add(order);
            break;
          case 'completed':
            completed.add(order);
            break;
          default:
            if (kDebugMode) {
              print('Order ${order.orderId} has unknown status: ${order.status}');
            }
            break;
        }
      }

      if (kDebugMode) {
        print(
            'Orders categorized: pending=${pending.length}, preparing=${preparing.length}, completed=${completed.length}, reservations=${reservations.length}');
      }

      return {
        'pending': pending,
        'preparing': preparing,
        'completed': completed,
        'reservations': reservations,
      };
    } catch (e) {
      throw Exception('Error refreshing orders: $e');
    }
  }
}