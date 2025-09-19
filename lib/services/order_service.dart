// services/order_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/order.dart';
import '../models/item.dart';
import 'package:flutter/foundation.dart';

class OrderService {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
  

  // Get all kitchen orders - only orders that are relevant for kitchen display
  static Future<List<Order>> getKitchenOrders() async {
    try {
      if (kDebugMode) {
        print("ini adalah base url: $baseUrl");
      }
      // Only get orders with kitchen-relevant statuses
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

  // Update order status
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

  // Private method to map JSON to Order object
  static Order _mapJsonToOrder(Map<String, dynamic> json) {
    // Extract items from JSON
    List<Item> items = [];
    if (json['items'] != null) {
      for (var itemJson in json['items']) {
        String itemName = itemJson['menuItem']['name'];
        int quantity = itemJson['quantity'];

        // Add addons and toppings to item name if they exist
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

    // Determine service type based on orderType
    String service = _getServiceType(json['orderType'], json['source']);

    // Get table number or create identifier
    String table = _getTableIdentifier(json);

    // Parse creation date
    DateTime createdAt = DateTime.parse(json['createdAt']);

    // Create order with status information
    Order order = Order(
      json['user'] ?? 'Guest',
      table,
      service,
      items,
      start: createdAt,
    );

    // Store the original status and order ID for reference
    order.originalStatus = json['status'] ?? 'Waiting';
    order.orderId = json['order_id'] ?? '';

    return order;
  }

  // Helper method to determine service type
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

  // Helper method to get table identifier
  static String _getTableIdentifier(Map<String, dynamic> json) {
    // For dine-in orders, use table number
    if (json['orderType'] == 'Dine-In' && json['tableNumber'] != null && json['tableNumber'].isNotEmpty) {
      return json['tableNumber'];
    }

    // For pickup/delivery, use order ID suffix or user name
    if (json['order_id'] != null) {
      String orderId = json['order_id'];
      // Extract last part of order ID (e.g., "001" from "ORD-05GJH-001")
      List<String> parts = orderId.split('-');
      if (parts.length > 1) {
        return parts.last;
      }
    }

    // Fallback to user name first letter + random number
    String userName = json['user'] ?? 'Guest';
    return userName.isNotEmpty ? '${userName[0].toUpperCase()}1' : 'G1';
  }

  // Get orders by status
  static Future<List<Order>> getOrdersByStatus(String status) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders/kitchen?status=$status'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

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

  // Refresh orders (for periodic updates)
  static Future<Map<String, List<Order>>> refreshOrders() async {
    try {
      final allOrders = await getKitchenOrders();

      // Separate orders by their actual status from database
      List<Order> pending = [];
      List<Order> preparing = [];
      List<Order> completed = [];

      for (var order in allOrders) {
        String status = order.originalStatus?.toLowerCase() ?? '';

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
          // Skip orders with other statuses (pending, reserved, canceled, etc.)
          // Only show orders that are specifically waiting, onprocess, or completed
            if (kDebugMode) {
              print('Order ${order.orderId} has status: ${order.originalStatus} - skipping');
            }
            break;
        }
      }

      return {
        'pending': pending,
        'preparing': preparing,
        'completed': completed,
      };
    } catch (e) {
      throw Exception('Error refreshing orders: $e');
    }
  }
}