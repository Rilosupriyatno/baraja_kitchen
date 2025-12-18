// services/background_service.dart
// Background service untuk menjaga koneksi socket dan menerima order saat app di background

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// Background Service untuk Baraja Workstation
/// 
/// Service ini akan:
/// 1. Menjaga koneksi Socket.IO saat app di background
/// 2. Menerima order baru dan immediate print events
/// 3. Menyimpan queue order untuk di-print saat app kembali ke foreground
/// 4. Memainkan notification sound saat ada order baru
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  static const String notificationChannelId = 'baraja_workstation_channel';
  static const String notificationChannelName = 'Baraja Workstation';
  static const int notificationId = 888;

  // Shared Preferences keys
  static const String _deviceDataKey = 'background_device_data';
  static const String _outletIdKey = 'background_outlet_id';
  static const String _pendingOrdersKey = 'pending_orders_queue';
  static const String _immediatePrintQueueKey = 'immediate_print_queue';

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize and start the background service
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      notificationChannelName,
      description: 'Baraja Workstation background service untuk menerima order',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // Don't auto-start, we'll start manually after device selection
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Baraja Workstation',
        initialNotificationContent: 'Initializing...',
        foregroundServiceNotificationId: notificationId,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    if (kDebugMode) {
      print('🔧 Background service initialized');
    }
  }

  /// iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  /// Main entry point for background service
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // Load environment variables
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to load .env in background: $e');
    }

    final prefs = await SharedPreferences.getInstance();

    // Socket connection
    IO.Socket? socket;

    // Notification plugin for sounds
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    if (kDebugMode) {
      print('🚀 Background service started');
    }

    // Listen for stop command
    service.on('stopService').listen((event) {
      if (kDebugMode) print('🛑 Stopping background service...');
      socket?.disconnect();
      socket?.dispose();
      service.stopSelf();
    });

    // Listen for device configuration
    service.on('configureDevice').listen((event) async {
      if (event == null) return;

      final deviceData = event['deviceData'] as String?;
      final outletId = event['outletId'] as String?;

      if (deviceData != null && outletId != null) {
        await prefs.setString(_deviceDataKey, deviceData);
        await prefs.setString(_outletIdKey, outletId);

        // Parse device data
        final device = json.decode(deviceData);
        final deviceName = device['deviceName'] ?? 'Unknown';
        final location = device['location'] ?? '';

        if (kDebugMode) {
          print('📱 Background configured for device: $deviceName');
        }

        // Update notification
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'Baraja Workstation',
            content: 'Online: $deviceName ${location.isNotEmpty ? "- $location" : ""}',
          );
        }

        // Connect socket
        socket?.disconnect();
        socket?.dispose();
        socket = _connectSocket(
          outletId: outletId,
          device: device,
          service: service,
          prefs: prefs,
          notificationsPlugin: flutterLocalNotificationsPlugin,
        );
      }
    });

    // Listen for get pending orders request
    service.on('getPendingOrders').listen((event) async {
      final pendingOrdersJson = prefs.getString(_pendingOrdersKey) ?? '[]';
      final immediatePrintJson = prefs.getString(_immediatePrintQueueKey) ?? '[]';
      
      service.invoke('pendingOrders', {
        'orders': pendingOrdersJson,
        'immediatePrint': immediatePrintJson,
      });

      // Clear queues after sending
      await prefs.remove(_pendingOrdersKey);
      await prefs.remove(_immediatePrintQueueKey);
    });

    // Listen for clear queue command
    service.on('clearQueue').listen((event) async {
      await prefs.remove(_pendingOrdersKey);
      await prefs.remove(_immediatePrintQueueKey);
      if (kDebugMode) print('🗑️ Queues cleared');
    });

    // Try to restore previous configuration
    final savedDeviceData = prefs.getString(_deviceDataKey);
    final savedOutletId = prefs.getString(_outletIdKey);

    if (savedDeviceData != null && savedOutletId != null) {
      final device = json.decode(savedDeviceData);
      final deviceName = device['deviceName'] ?? 'Unknown';
      final location = device['location'] ?? '';

      if (kDebugMode) {
        print('🔄 Restoring previous configuration: $deviceName');
      }

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Baraja Workstation',
          content: 'Online: $deviceName ${location.isNotEmpty ? "- $location" : ""}',
        );
      }

      socket = _connectSocket(
        outletId: savedOutletId,
        device: device,
        service: service,
        prefs: prefs,
        notificationsPlugin: flutterLocalNotificationsPlugin,
      );
    }
  }

  /// Connect to Socket.IO server
  static IO.Socket _connectSocket({
    required String outletId,
    required Map<String, dynamic> device,
    required ServiceInstance service,
    required SharedPreferences prefs,
    required FlutterLocalNotificationsPlugin notificationsPlugin,
  }) {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    final deviceId = device['deviceId'] ?? '';
    final deviceName = device['deviceName'] ?? 'Unknown';
    final location = device['location'] ?? '';
    final shouldHandleBeverages = device['shouldHandleBeverages'] ?? false;

    if (kDebugMode) {
      print('📡 [BG] Connecting to socket: $baseUrl');
      print('   Device: $deviceName');
      print('   Outlet: $outletId');
    }

    final socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableAutoConnect()
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(10)
          .build(),
    );

    socket.onConnect((_) {
      if (kDebugMode) print('✅ [BG] Socket connected');

      // Join rooms
      socket.emit('join_kitchen_room', outletId);
      if (shouldHandleBeverages && location.isNotEmpty) {
        socket.emit('join_bar_room', location);
      }
      socket.emit('join_cashier_room', {'outletId': outletId});

      // Update notification
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Baraja Workstation - Connected',
          content: 'Online: $deviceName ${location.isNotEmpty ? "- $location" : ""}',
        );
      }

      // Notify main app
      service.invoke('socketConnected', {'connected': true});
    });

    socket.onDisconnect((_) {
      if (kDebugMode) print('❌ [BG] Socket disconnected');

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Baraja Workstation - Disconnected',
          content: 'Mencoba reconnect...',
        );
      }

      service.invoke('socketConnected', {'connected': false});
    });

    socket.onReconnect((_) {
      if (kDebugMode) print('🔄 [BG] Socket reconnected');
      
      // Rejoin rooms
      socket.emit('join_kitchen_room', outletId);
      if (shouldHandleBeverages && location.isNotEmpty) {
        socket.emit('join_bar_room', location);
      }
      socket.emit('join_cashier_room', {'outletId': outletId});

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Baraja Workstation - Connected',
          content: 'Online: $deviceName ${location.isNotEmpty ? "- $location" : ""}',
        );
      }
    });

    // Handle new order event
    socket.on('new_order', (data) async {
      if (kDebugMode) {
        print('🔔 [BG] New order received');
      }

      // Show notification
      await _showOrderNotification(
        notificationsPlugin,
        title: 'Order Baru!',
        body: 'Ada order baru yang perlu diproses',
      );

      // Notify main app (if running in foreground)
      service.invoke('newOrder', {'data': json.encode(data)});
    });

    // Handle kitchen immediate print
    socket.on('kitchen_immediate_print', (data) async {
      if (kDebugMode) {
        print('🔥 [BG] Kitchen immediate print received');
        print('   Order ID: ${data['orderId']}');
        print('   Target Device: ${data['deviceId']}');
      }

      // Check if this is for our device
      final targetDeviceId = data['deviceId'] as String?;
      if (targetDeviceId != null && targetDeviceId != deviceId) {
        if (kDebugMode) print('⏭️ [BG] Skipping - not our device');
        return;
      }

      // Queue for print
      await _addToImmediatePrintQueue(prefs, data);

      // Show notification
      await _showOrderNotification(
        notificationsPlugin,
        title: 'Print Order!',
        body: 'Order ${data['orderId']} perlu dicetak',
      );

      // Notify main app
      service.invoke('immediatePrint', {'data': json.encode(data)});
    });

    // Handle beverage immediate print
    socket.on('beverage_immediate_print', (data) async {
      if (kDebugMode) {
        print('🔥 [BG] Beverage immediate print received');
        print('   Order ID: ${data['orderId']}');
        print('   Target Device: ${data['deviceId']}');
      }

      // Check if this is for our device
      final targetDeviceId = data['deviceId'] as String?;
      if (targetDeviceId != null && targetDeviceId != deviceId) {
        if (kDebugMode) print('⏭️ [BG] Skipping - not our device');
        return;
      }

      // Queue for print
      await _addToImmediatePrintQueue(prefs, data);

      // Show notification
      await _showOrderNotification(
        notificationsPlugin,
        title: 'Print Beverage!',
        body: 'Beverage order ${data['orderId']} perlu dicetak',
      );

      // Notify main app
      service.invoke('immediatePrint', {'data': json.encode(data)});
    });

    return socket;
  }

  /// Show notification for new order
  static Future<void> _showOrderNotification(
    FlutterLocalNotificationsPlugin plugin, {
    required String title,
    required String body,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        notificationChannelId,
        notificationChannelName,
        channelDescription: 'Order notifications',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await plugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetails,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Failed to show notification: $e');
    }
  }

  /// Add item to immediate print queue
  static Future<void> _addToImmediatePrintQueue(
    SharedPreferences prefs,
    dynamic data,
  ) async {
    try {
      final existingJson = prefs.getString(_immediatePrintQueueKey) ?? '[]';
      final existing = json.decode(existingJson) as List;
      existing.add(data);
      await prefs.setString(_immediatePrintQueueKey, json.encode(existing));
      if (kDebugMode) print('📝 [BG] Added to print queue, total: ${existing.length}');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to add to queue: $e');
    }
  }

  /// Start the background service with device configuration
  Future<void> startService({
    required String outletId,
    required Map<String, dynamic> deviceData,
  }) async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (!isRunning) {
      await service.startService();
      if (kDebugMode) print('🚀 Background service started');
    }

    // Wait a bit for service to initialize
    await Future.delayed(const Duration(milliseconds: 500));

    // Configure with device data
    service.invoke('configureDevice', {
      'deviceData': json.encode(deviceData),
      'outletId': outletId,
    });

    if (kDebugMode) {
      print('📱 Configured background service:');
      print('   Device: ${deviceData['deviceName']}');
      print('   Outlet: $outletId');
    }
  }

  /// Stop the background service
  Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
    if (kDebugMode) print('🛑 Background service stop requested');
  }

  /// Check if service is running
  Future<bool> isRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }

  /// Get pending orders from background queue
  Future<Map<String, dynamic>> getPendingOrders() async {
    final completer = Completer<Map<String, dynamic>>();
    final service = FlutterBackgroundService();

    // Listen for response
    service.on('pendingOrders').listen((event) {
      if (event != null && !completer.isCompleted) {
        completer.complete({
          'orders': json.decode(event['orders'] ?? '[]'),
          'immediatePrint': json.decode(event['immediatePrint'] ?? '[]'),
        });
      }
    });

    // Request pending orders
    service.invoke('getPendingOrders');

    // Timeout after 2 seconds
    return completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => {'orders': [], 'immediatePrint': []},
    );
  }

  /// Clear pending order queue
  void clearQueue() {
    final service = FlutterBackgroundService();
    service.invoke('clearQueue');
  }

  /// Listen for new orders from background service
  void onNewOrder(Function(Map<String, dynamic>) callback) {
    final service = FlutterBackgroundService();
    service.on('newOrder').listen((event) {
      if (event != null && event['data'] != null) {
        callback(json.decode(event['data']));
      }
    });
  }

  /// Listen for immediate print events from background service
  void onImmediatePrint(Function(Map<String, dynamic>) callback) {
    final service = FlutterBackgroundService();
    service.on('immediatePrint').listen((event) {
      if (event != null && event['data'] != null) {
        callback(json.decode(event['data']));
      }
    });
  }

  /// Listen for socket connection status
  void onSocketStatus(Function(bool) callback) {
    final service = FlutterBackgroundService();
    service.on('socketConnected').listen((event) {
      if (event != null) {
        callback(event['connected'] ?? false);
      }
    });
  }
}
