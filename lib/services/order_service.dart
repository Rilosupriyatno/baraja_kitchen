// services/order_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/order.dart';
import '../models/item.dart';
import 'package:flutter/foundation.dart';

class OrderService {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://localhost:3000';

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
        debugPrint('Fetched orders: $data');

        if (data['success'] == true && data['data'] != null) {
          List<dynamic> ordersData = data['data'];
          return ordersData.map((orderJson) => _mapJsonToOrder(orderJson)).toList();
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

  static Order _mapJsonToOrder(Map<String, dynamic> json) {
    List<Item> items = [];
    if (json['items'] != null) {
      for (var itemJson in json['items']) {
        String itemName = itemJson['menuItem']['name'];
        int quantity = itemJson['quantity'];

        List<String> extras = [];
        if (itemJson['addons'] != null && itemJson['addons'].isNotEmpty) {
          for (var addon in itemJson['addons']) {
            extras.add(addon['name']);
          }
        }

        if (itemJson['toppings'] != null && itemJson['toppings'].isNotEmpty) {
          for (var topping in itemJson['toppings']) {
            extras.add(topping['name']);
          }
        }

        if (extras.isNotEmpty) {
          itemName += ' (${extras.join(', ')})';
        }

        items.add(Item(itemName, quantity));
      }
    }

    String service = _getServiceType(json['orderType'], json['source']);
    String table = _getTableIdentifier(json);

    DateTime createdAt = DateTime.parse(json['createdAt']);
    DateTime? updatedAt =
    json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null;

    Order order = Order(
      json['user'] ?? 'Guest',
      table,
      service,
      items,
      start: createdAt,
      updatedAt: updatedAt, // ✅ simpan updatedAt
    );

    order.originalStatus = json['status'] ?? 'Waiting';
    order.orderId = json['order_id'] ?? '';

    return order;
  }

  static String _getServiceType(String? orderType, String? source) {
    if (orderType == null) return 'Unknown';

    switch (orderType.toLowerCase()) {
      case 'dine-in':
        return 'Dine In';
      case 'pickup':
        return 'Pickup';
      case 'delivery':
        return 'Delivery';
      default:
        return orderType;
    }
  }

  static String _getTableIdentifier(Map<String, dynamic> json) {
    if (json['orderType'] == 'Dine-In' &&
        json['tableNumber'] != null &&
        json['tableNumber'].isNotEmpty) {
      return json['tableNumber'];
    }

    if (json['order_id'] != null) {
      String orderId = json['order_id'];
      List<String> parts = orderId.split('-');
      if (parts.length > 1) {
        return parts.last;
      }
    }

    String userName = json['user'] ?? 'Guest';
    return userName.isNotEmpty ? '${userName[0].toUpperCase()}1' : 'G1';
  }

  static Future<Map<String, List<Order>>> refreshOrders() async {
    try {
      final allOrders = await getKitchenOrders();

      List<Order> pending = [];
      List<Order> preparing = [];
      List<Order> completed = [];
      List<Order> reservations = [];

      for (var order in allOrders) {
        String status = order.originalStatus?.toLowerCase() ?? '';

        // ✅ Skip order yang cancelled/paid (kecuali reservasi yang perlu ditampilkan)
        if (status == 'cancelled' || status == 'paid') {
          if (kDebugMode) {
            print('Order ${order.orderId} has status: ${order.originalStatus} - skipping');
          }
          continue;
        }

        // ✅ Pisahkan order reservation ke list terpisah (setelah cek status)
        if (order.service.toLowerCase().contains('reservation')) {
          reservations.add(order);
          continue;
        }

        // ✅ Kategorikan berdasarkan status
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
              print('Order ${order.orderId} has unknown status: ${order.originalStatus}');
            }
            break;
        }
      }

      if (kDebugMode) {
        print('Orders categorized: pending=${pending.length}, preparing=${preparing.length}, completed=${completed.length}, reservations=${reservations.length}');
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
