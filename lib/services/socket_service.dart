// services/socket_service.dart - COMPLETE VERSION

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/order.dart';
import 'order_service.dart';

class SocketService {
  static IO.Socket? _socket;
  static String? _currentBarType;

  /// Connect to backend socket.io with immediate print support
  static void connect({
    required String outletId,
    String? barType,
    Function(Order)? onNewOrder,
    Function(Map<String, dynamic>)? onBeverageOrder,
    Function(Map<String, dynamic>)? onStockUpdate,
    Function(Map<String, dynamic>)? onImmediatePrint,
  }) {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    _currentBarType = barType;

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableAutoConnect()
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(5)
          .build(),
    );

    _socket!.onConnect((_) {
      print('✅ Socket connected: ${_socket!.id}');

      // Join kitchen room
      _socket!.emit('join_kitchen_room', outletId);
      print('✅ Joined kitchen_room for outlet: $outletId');

      // Join bar room if specified
      if (_currentBarType != null && _currentBarType!.isNotEmpty) {
        _socket!.emit('join_bar_room', _currentBarType!);
        print('✅ Joined bar room: bar_$_currentBarType');
      }
    });

    // ============================================
    // 🔥 HIGH PRIORITY: IMMEDIATE PRINT HANDLERS
    // ============================================

    _socket!.on('kitchen_immediate_print', (data) {
      print('🔥 [KITCHEN] Immediate print received at: ${DateTime.now()}');
      print('   Order ID: ${data['orderId']}');
      print('   Items: ${data['orderItems']?.length ?? 0}');

      if (onImmediatePrint != null) {
        onImmediatePrint(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('beverage_immediate_print', (data) {
      print('🔥 [BEVERAGE] Immediate print received at: ${DateTime.now()}');
      print('   Order ID: ${data['orderId']}');
      print('   Items: ${data['orderItems']?.length ?? 0}');

      if (onImmediatePrint != null) {
        onImmediatePrint(Map<String, dynamic>.from(data));
      }
    });

    // ============================================
    // STOCK UPDATE EVENTS
    // ============================================

    _socket!.on('stock_updated', (data) {
      print('📦 Stock updated event: $data');
      if (onStockUpdate != null) {
        onStockUpdate(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('stock_calibrated', (data) {
      print('🔄 Stock calibrated event: $data');
      if (onStockUpdate != null) {
        onStockUpdate(Map<String, dynamic>.from(data));
      }
    });

    // ============================================
    // ORDER EVENTS
    // ============================================

    _socket!.on('new_order', (data) async {
      print('🔥 New order event: $data');

      try {
        final orders = await OrderService.getKitchenOrders();
        if (onNewOrder != null && orders.isNotEmpty) {
          onNewOrder(orders.first);
        }
      } catch (e) {
        print('⚠️ Error handling new order: $e');
      }
    });

    _socket!.on('beverage_order_received', (data) {
      print('🥤 Beverage order received: $data');

      if (onBeverageOrder != null) {
        onBeverageOrder(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('area_order_update', (data) {
      print('📍 Area order update: $data');
    });

    // ============================================
    // STATUS UPDATE EVENTS
    // ============================================

    _socket!.on('status_confirmed', (data) {
      print('✅ Order status confirmed: ${data['order_id']} -> ${data['orderStatus']}');
    });

    _socket!.on('order_status_updated', (data) {
      print('🔄 Order status updated: $data');
    });

    // ============================================
    // CONNECTION EVENTS
    // ============================================

    _socket!.onDisconnect((_) {
      print('❌ Socket disconnected');
    });

    _socket!.onError((error) {
      print('❌ Socket error: $error');
    });

    _socket!.onReconnect((_) {
      print('🔄 Socket reconnected');

      // Rejoin rooms after reconnect
      _socket!.emit('join_kitchen_room', outletId);

      if (_currentBarType != null && _currentBarType!.isNotEmpty) {
        _socket!.emit('join_bar_room', _currentBarType!);
      }
    });

    print('🔌 Socket service initialized');
  }

  // ============================================
  // BAR ROOM MANAGEMENT
  // ============================================

  static void joinBarRoom(String barType) {
    if (_socket?.connected == true) {
      _socket!.emit('join_bar_room', barType);
      print('✅ Joined bar room: $barType');
      _currentBarType = barType;
    }
  }

  static void leaveBarRoom() {
    if (_socket?.connected == true && _currentBarType != null) {
      _socket!.emit('leave_room', 'bar_$_currentBarType');
      print('👋 Left bar room: $_currentBarType');
      _currentBarType = null;
    }
  }

  static void switchBarRoom(String newBarType) {
    if (_socket?.connected == true) {
      if (_currentBarType != null) {
        _socket!.emit('leave_room', 'bar_$_currentBarType');
        print('👋 Left bar room: $_currentBarType');
      }

      _socket!.emit('join_bar_room', newBarType);
      print('✅ Switched to bar room: $newBarType');
      _currentBarType = newBarType;
    }
  }

  // ============================================
  // BAR ORDER EVENTS
  // ============================================

  static void sendBarOrderStart({
    required String orderId,
    required String tableNumber,
    required String bartenderName,
    required List<dynamic> items,
  }) {
    if (_socket?.connected == true) {
      _socket!.emit('bar_order_start', {
        'orderId': orderId,
        'tableNumber': tableNumber,
        'bartenderName': bartenderName,
        'items': items,
      });
      print('📤 Bar order start sent: $orderId');
    }
  }

  static void sendBarOrderComplete({
    required String orderId,
    required String tableNumber,
    required String bartenderName,
  }) {
    if (_socket?.connected == true) {
      _socket!.emit('bar_order_complete', {
        'orderId': orderId,
        'tableNumber': tableNumber,
        'bartenderName': bartenderName,
      });
      print('✅ Bar order complete sent: $orderId');
    }
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  static String? getCurrentBarType() {
    return _currentBarType;
  }

  static bool isConnectedToBar(String barType) {
    return _currentBarType == barType;
  }

  static bool get isConnected {
    return _socket?.connected ?? false;
  }

  static void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _currentBarType = null;
      print('👋 Socket disconnected');
    }
  }
}