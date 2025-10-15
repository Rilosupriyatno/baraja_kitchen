// services/socket_service.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/order.dart';
import 'order_service.dart';

class SocketService {
  static IO.Socket? _socket;
  static String? _currentBarType;

  /// Connect ke backend socket.io dengan support multiple bars
  static void connect({
    required String outletId,
    String? barType, // 'depan' atau 'belakang'
    Function(Order)? onNewOrder,
    Function(Map<String, dynamic>)? onBeverageOrder,
  }) {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    _currentBarType = barType;

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      print('✅ Socket connected: ${_socket!.id}');

      // Join ke room dapur (backend: join_kitchen_room(outletId, callback))
      _socket!.emitWithAck('join_kitchen_room', outletId, ack: (data) {
        print('Joined kitchen room response: $data');
      });

      // Join ke room bar tertentu jika barType disediakan
      if (_currentBarType != null && _currentBarType!.isNotEmpty) {
        _socket!.emitWithAck('join_bar_room', _currentBarType!, ack: (data) {
          print('Joined bar room response: $data');
        });
        print('✅ Joined bar room: bar_$_currentBarType');
      }
    });

    // 🔹 Event: ada order baru masuk (untuk kitchen)
    _socket!.on('new_order', (data) async {
      print('📥 New order event received: $data');

      try {
        // Ambil ulang semua order biar konsisten mappingnya
        final orders = await OrderService.getKitchenOrders();
        if (onNewOrder != null && orders.isNotEmpty) {
          // Kirim order terbaru ke callback
          onNewOrder(orders.first);
        }
      } catch (e) {
        print('⚠️ Error handling new order: $e');
      }
    });

    // 🔹 Event: ada beverage order baru untuk bar
    _socket!.on('beverage_order_received', (data) {
      print('🥤 Beverage order received: $data');
      
      if (onBeverageOrder != null) {
        onBeverageOrder(Map<String, dynamic>.from(data));
      }
    });

    // 🔹 Event: update status order untuk area tertentu
    _socket!.on('area_order_update', (data) {
      print('📍 Area order update: $data');
      // Handle area-specific order updates jika diperlukan
    });

    _socket!.onDisconnect((_) {
      print('❌ Socket disconnected');
    });

    _socket!.onError((error) {
      print('❌ Socket error: $error');
    });
  }

  /// Join ke bar room tertentu
  static void joinBarRoom(String barType) {
    if (_socket?.connected == true) {
      _socket!.emitWithAck('join_bar_room', barType, ack: (data) {
        print('Joined bar room response: $data');
        _currentBarType = barType;
      });
    }
  }

  /// Leave dari bar room saat ini
  static void leaveBarRoom() {
    if (_socket?.connected == true && _currentBarType != null) {
      _socket!.emit('leave_room', 'bar_$_currentBarType');
      _currentBarType = null;
    }
  }

  /// Switch antara bar depan dan belakang
  static void switchBarRoom(String newBarType) {
    if (_socket?.connected == true) {
      // Leave current bar room jika ada
      if (_currentBarType != null) {
        _socket!.emit('leave_room', 'bar_$_currentBarType');
      }
      
      // Join new bar room
      _socket!.emitWithAck('join_bar_room', newBarType, ack: (data) {
        print('Switched to bar room: $newBarType - Response: $data');
        _currentBarType = newBarType;
      });
    }
  }

  /// Kirim konfirmasi bahwa order beverage sudah mulai diproses
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

  /// Kirim konfirmasi bahwa order beverage sudah selesai
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

  /// Dapatkan status bar saat ini
  static String? getCurrentBarType() {
    return _currentBarType;
  }

  /// Cek apakah connected ke bar room tertentu
  static bool isConnectedToBar(String barType) {
    return _currentBarType == barType;
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _currentBarType = null;
  }
}