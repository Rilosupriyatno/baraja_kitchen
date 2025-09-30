// services/socket_service.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/order.dart';
import 'order_service.dart';

class SocketService {
  static IO.Socket? _socket;

  /// Connect ke backend socket.io
  static void connect({
    required String outletId,
    Function(Order)? onNewOrder,
  }) {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';

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
    });

    // 🔹 Event: ada order baru masuk
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

    _socket!.onDisconnect((_) {
      print('❌ Socket disconnected');
    });
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}
