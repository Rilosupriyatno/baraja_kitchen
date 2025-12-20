// services/socket_service.dart (UPDATED - Device-Based Socket Events)
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/order.dart';
import '../models/device.dart';
import 'order_service.dart';
import 'background_service.dart';
import 'package:flutter/foundation.dart';

class SocketService {
  static IO.Socket? _socket;
  static Device? _currentDevice;

  /// ✅ Connect with Device object
  static void connect({
    required String outletId,
    required Device device,
    Function(Order)? onNewOrder,
    Function(Map<String, dynamic>)? onBeverageOrder,
    Function(Map<String, dynamic>)? onStockUpdate,
    Function(Map<String, dynamic>)? onImmediatePrint,
    Function(Map<String, dynamic>)? onOrderStatusUpdated,  // ✅ NEW: For Reserved→OnProcess
  }) {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    _currentDevice = device;

    if (kDebugMode) {
      print('╔════════════════════════════════════════════════╗');
      print('📡 SOCKET SERVICE INITIALIZATION');
      print('╠════════════════════════════════════════════════╣');
      print('   Device: ${device.deviceName}');
      print('   Device ID: ${device.deviceId}');
      print('   Outlet: ${outletId}');
      print('   Workstation: ${device.workstationTypeString}');
      print('   Location: ${device.location}');
      print('╚════════════════════════════════════════════════╝');
    }

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableAutoConnect()
          .setReconnectionDelay(500)     // ⚡ OPTIMIZED: 500ms faster reconnect
          .setReconnectionAttempts(10)   // ⚡ OPTIMIZED: More retry attempts
          .setReconnectionDelayMax(3000) // ⚡ Max 3s between retries
          .build(),
    );

    _socket!.onConnect((_) {
      if (kDebugMode) {
        print('✅ Socket connected: ${_socket!.id}');
      }

      // Notify background service about connection status
      BackgroundService().updateSocketStatus(true);

      // Join kitchen room (all devices)
      _socket!.emit('join_kitchen_room', outletId);
      if (kDebugMode) {
        print('✅ Joined kitchen_room for outlet: $outletId');
      }

      // Join bar room if device handles beverages
      if (device.shouldHandleBeverages && device.location.isNotEmpty) {
        _socket!.emit('join_bar_room', device.location);
        if (kDebugMode) {
          print('✅ Joined bar room: bar_${device.location}');
        }
      }

      // Join cashier room (for order updates)
      _socket!.emit('join_cashier_room', {'outletId': outletId});
      if (kDebugMode) {
        print('✅ Joined cashier_room');
      }
    });

    // ============================================
    // 🔥 HIGH PRIORITY: IMMEDIATE PRINT HANDLERS
    // ============================================

    _socket!.on('kitchen_immediate_print', (data) {
      if (kDebugMode) {
        print('╔════════════════════════════════════════════════╗');
        print('🔥 [KITCHEN] Immediate print received');
        print('╠════════════════════════════════════════════════╣');
        print('   Time: ${DateTime.now()}');
        print('   Order ID: ${data['orderId']}');
        print('   Items: ${data['orderItems']?.length ?? 0}');
        print('   Target Device: ${data['targetDevice']}');
        print('   Backend Device ID: ${data['deviceId']}');
        print('   This Device ID: ${device.deviceId}');
        print('╚════════════════════════════════════════════════╝');
      }

      // ✅ CRITICAL: Check device ID match
      final targetDeviceId = data['deviceId'] as String?;
      if (targetDeviceId != null && targetDeviceId.isNotEmpty) {
        if (device.deviceId != targetDeviceId) {
          if (kDebugMode) {
            print('⏭️ [${device.deviceName}] SKIPPING - Not target device');
            print('   Target: $targetDeviceId');
            print('   This: ${device.deviceId}');
          }
          return;
        }

        if (kDebugMode) {
          print('✅ [${device.deviceName}] Device ID MATCH - Processing print');
        }
      }

      if (onImmediatePrint != null) {
        onImmediatePrint(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('beverage_immediate_print', (data) {
      if (kDebugMode) {
        print('╔════════════════════════════════════════════════╗');
        print('🔥 [BEVERAGE] Immediate print received');
        print('╠════════════════════════════════════════════════╣');
        print('   Time: ${DateTime.now()}');
        print('   Order ID: ${data['orderId']}');
        print('   Items: ${data['orderItems']?.length ?? 0}');
        print('   Target Device: ${data['targetDevice']}');
        print('   Backend Device ID: ${data['deviceId']}');
        print('   This Device ID: ${device.deviceId}');
        print('╚════════════════════════════════════════════════╝');
      }

      // ✅ CRITICAL: Check device ID match
      final targetDeviceId = data['deviceId'] as String?;
      if (targetDeviceId != null && targetDeviceId.isNotEmpty) {
        if (device.deviceId != targetDeviceId) {
          if (kDebugMode) {
            print('⏭️ [${device.deviceName}] SKIPPING - Not target device');
            print('   Target: $targetDeviceId');
            print('   This: ${device.deviceId}');
          }
          return;
        }

        if (kDebugMode) {
          print('✅ [${device.deviceName}] Device ID MATCH - Processing print');
        }
      }

      if (onImmediatePrint != null) {
        onImmediatePrint(Map<String, dynamic>.from(data));
      }
    });

    // ============================================
    // STOCK UPDATE EVENTS
    // ============================================

    _socket!.on('stock_updated', (data) {
      if (kDebugMode) {
        print('📦 Stock updated event: ${data['menuItemId']}');
      }
      if (onStockUpdate != null) {
        onStockUpdate(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('stock_calibrated', (data) {
      if (kDebugMode) {
        print('🔄 Stock calibrated event: ${data['menuItemId']}');
      }
      if (onStockUpdate != null) {
        onStockUpdate(Map<String, dynamic>.from(data));
      }
    });

    // ============================================
    // ORDER EVENTS
    // ============================================

    _socket!.on('new_order', (data) async {
      if (kDebugMode) {
        print('╔════════════════════════════════════════════════╗');
        print('🔥 NEW ORDER EVENT RECEIVED - INSTANT');
        print('╠════════════════════════════════════════════════╣');
        print('   Time: ${DateTime.now()}');
        print('   Data: ${data?.toString().substring(0, 100) ?? 'null'}...');
        print('╚════════════════════════════════════════════════╝');
      }

      // ⚡ OPTIMIZED: Just trigger callback immediately
      // Dashboard will handle refresh, no blocking HTTP call here
      if (onNewOrder != null) {
        try {
          // Quick refresh using cached device context
          // This triggers _refreshOrders which handles everything
          onNewOrder(Order(
            orderId: data?['orderId'] ?? data?['order_id'] ?? 'unknown',
            name: data?['customerName'] ?? 'New Order',
            table: data?['tableNumber'] ?? '',
            status: 'Waiting',
            items: [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            createdAtWIB: DateTime.now(),
            updatedAtWIB: DateTime.now(),
            service: data?['orderType'] ?? 'Dine-In',
            orderType: data?['orderType'] ?? 'dine-in',
            source: data?['source'] ?? 'Cashier',
            paymentMethod: 'Cash',
          ));
        } catch (e) {
          if (kDebugMode) print('⚠️ Error in new order callback: $e');
          // Fallback: still notify even with minimal data
          onNewOrder(Order(
            orderId: 'unknown',
            name: 'New Order',
            table: '',
            status: 'Waiting',
            items: [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            createdAtWIB: DateTime.now(),
            updatedAtWIB: DateTime.now(),
            service: 'Dine-In',
            orderType: 'dine-in',
            source: 'Cashier',
            paymentMethod: 'Cash',
          ));
        }
      }
    });

    _socket!.on('beverage_order_received', (data) {
      if (kDebugMode) {
        print('🥤 Beverage order received: ${data['orderId']}');
      }

      if (onBeverageOrder != null) {
        onBeverageOrder(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('area_order_update', (data) {
      if (kDebugMode) {
        print('📍 Area order update: ${data['orderId']} - ${data['status']}');
      }
    });

    // ============================================
    // STATUS UPDATE EVENTS
    // ============================================

    _socket!.on('status_confirmed', (data) {
      if (kDebugMode) {
        print('✅ Order status confirmed: ${data['order_id']} -> ${data['orderStatus']}');
      }
    });

    _socket!.on('order_status_updated', (data) {
      if (kDebugMode) {
        print('╔════════════════════════════════════════════════╗');
        print('🔄 ORDER STATUS UPDATED');
        print('╠════════════════════════════════════════════════╣');
        print('   Order ID: ${data['orderId'] ?? data['order_id']}');
        print('   New Status: ${data['status']}');
        print('   Updated By: ${data['updatedBy']}');
        print('   Time: ${DateTime.now()}');
        print('╚════════════════════════════════════════════════╝');
      }

      // ✅ NEW: Trigger callback untuk handle print jika status = OnProcess
      if (onOrderStatusUpdated != null) {
        onOrderStatusUpdated(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('workstation_order_updated', (data) {
      if (kDebugMode) {
        print('🔄 Workstation order updated: ${data['order_id']}');
        print('   Status: ${data['orderStatus']}');
        print('   Workstation: ${data['workstation']?['type']}');
      }
    });

    _socket!.on('workstation_item_updated', (data) {
      if (kDebugMode) {
        print('🔄 Workstation item updated: ${data['item_id']}');
        print('   Order: ${data['order_id']}');
        print('   Status: ${data['status']}');
      }
    });

    // ============================================
    // CONNECTION EVENTS
    // ============================================

    _socket!.onDisconnect((_) {
      if (kDebugMode) {
        print('❌ Socket disconnected');
      }
      // Notify background service about disconnection
      BackgroundService().updateSocketStatus(false);
    });

    _socket!.onError((error) {
      if (kDebugMode) {
        print('❌ Socket error: $error');
      }
      BackgroundService().updateSocketStatus(false);
    });

    _socket!.onReconnect((_) {
      if (kDebugMode) {
        print('🔄 Socket reconnected - Rejoining rooms...');
      }

      // Rejoin rooms after reconnect
      _socket!.emit('join_kitchen_room', outletId);

      if (_currentDevice?.shouldHandleBeverages == true &&
          _currentDevice!.location.isNotEmpty) {
        _socket!.emit('join_bar_room', _currentDevice!.location);
      }

      _socket!.emit('join_cashier_room', {'outletId': outletId});

      if (kDebugMode) {
        print('✅ Rejoined all rooms after reconnection');
      }
    });

    if (kDebugMode) {
      print('📌 Socket service initialized for: ${device.deviceName}');
    }
  }

  // ============================================
  // BAR ROOM MANAGEMENT
  // ============================================

  static void joinBarRoom(String barLocation) {
    if (_socket?.connected == true) {
      _socket!.emit('join_bar_room', barLocation);
      if (kDebugMode) {
        print('✅ Joined bar room: $barLocation');
      }
    }
  }

  static void leaveBarRoom(String barLocation) {
    if (_socket?.connected == true) {
      _socket!.emit('leave_room', 'bar_$barLocation');
      if (kDebugMode) {
        print('👋 Left bar room: $barLocation');
      }
    }
  }

  static void switchBarRoom(String oldLocation, String newLocation) {
    if (_socket?.connected == true) {
      if (oldLocation.isNotEmpty) {
        _socket!.emit('leave_room', 'bar_$oldLocation');
        if (kDebugMode) {
          print('👋 Left bar room: $oldLocation');
        }
      }

      _socket!.emit('join_bar_room', newLocation);
      if (kDebugMode) {
        print('✅ Switched to bar room: $newLocation');
      }
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
      if (kDebugMode) {
        print('📤 Bar order start sent: $orderId');
      }
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
      if (kDebugMode) {
        print('✅ Bar order complete sent: $orderId');
      }
    }
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  static Device? getCurrentDevice() {
    return _currentDevice;
  }

  static String? getCurrentBarLocation() {
    if (_currentDevice?.shouldHandleBeverages == true) {
      return _currentDevice!.location;
    }
    return null;
  }

  static bool isConnectedToBar(String barLocation) {
    return _currentDevice?.shouldHandleBeverages == true &&
        _currentDevice!.location == barLocation;
  }

  static bool get isConnected {
    return _socket?.connected ?? false;
  }

  static void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _currentDevice = null;
      if (kDebugMode) {
        print('👋 Socket disconnected');
      }
    }
  }

  // ============================================
  // DEBUG HELPERS
  // ============================================

  static void printDeviceInfo() {
    if (_currentDevice == null) {
      if (kDebugMode) {
        print('⚠️ No device connected');
      }
      return;
    }

    if (kDebugMode) {
      print('╔════════════════════════════════════════════════╗');
      print('📱 CURRENT DEVICE INFO');
      print('╠════════════════════════════════════════════════╣');
      print('   Device Name: ${_currentDevice!.deviceName}');
      print('   Device ID: ${_currentDevice!.deviceId}');
      print('   Workstation: ${_currentDevice!.workstationTypeString}');
      print('   Location: ${_currentDevice!.location}');
      print('   Socket Connected: ${_socket?.connected ?? false}');
      print('   Socket ID: ${_socket?.id ?? 'N/A'}');
      print('╚════════════════════════════════════════════════╝');
    }
  }
}