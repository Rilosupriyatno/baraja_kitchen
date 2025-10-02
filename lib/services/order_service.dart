// services/order_service.dart
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
        const JsonEncoder encoder = JsonEncoder.withIndent('  ');
        final prettyData = encoder.convert(data);
        debugPrint('Fetched orders:\n$prettyData');

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

  // 🔹 Update status order
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

  // 🔹 Refresh dan kategorikan order
  static Future<Map<String, List<Order>>> refreshOrders() async {
    try {
      final allOrders = await getKitchenOrders();

      List<Order> pending = [];
      List<Order> preparing = [];
      List<Order> completed = [];
      List<Order> reservations = [];

      for (var order in allOrders) {
        String status = order.status.toLowerCase();

        // Skip cancelled/paid (kecuali reservasi)
        if (status == 'cancelled' || status == 'paid') {
          if (kDebugMode) {
            print('Order ${order.orderId} has status: ${order.status} - skipping');
          }
          continue;
        }

        // Pisahkan reservation
        if (order.service.toLowerCase().contains('reservation')) {
          reservations.add(order);
          continue;
        }

        // Kategorikan berdasarkan status
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
