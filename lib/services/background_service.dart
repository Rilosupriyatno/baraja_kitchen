// services/background_service.dart
// Background service untuk menjaga notifikasi foreground dan menerima data saat app di background
// NOTE: Socket connection ditangani oleh SocketService, bukan di sini untuk menghindari duplikasi

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background Service untuk Baraja Workstation
/// 
/// Service ini akan:
/// 1. Menampilkan foreground notification agar app tetap hidup di background
/// 2. Menyimpan queue order yang diterima untuk di-print saat app kembali ke foreground
/// 3. NOTE: Socket connection TIDAK dibuat di sini - ditangani oleh SocketService
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  // Stream subscriptions untuk proper cleanup
  StreamSubscription<Map<String, dynamic>?>? _newOrderSubscription;
  StreamSubscription<Map<String, dynamic>?>? _immediatePrintSubscription;
  StreamSubscription<Map<String, dynamic>?>? _socketStatusSubscription;
  StreamSubscription<Map<String, dynamic>?>? _pendingOrdersSubscription;
  bool _isInitialized = false;

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
        initialNotificationContent: 'Menunggu konfigurasi...',
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
            title: 'Baraja Workstation - Online',
            content: '$deviceName ${location.isNotEmpty ? "- $location" : ""}',
          );
        }
      }
    });

    // Listen for socket status updates from foreground
    service.on('updateSocketStatus').listen((event) async {
      if (event == null) return;
      
      final connected = event['connected'] as bool? ?? false;
      final deviceName = prefs.getString(_deviceDataKey);
      String name = 'Unknown';
      String location = '';
      
      if (deviceName != null) {
        try {
          final device = json.decode(deviceName);
          name = device['deviceName'] ?? 'Unknown';
          location = device['location'] ?? '';
        } catch (_) {}
      }

      if (service is AndroidServiceInstance) {
        if (connected) {
          service.setForegroundNotificationInfo(
            title: 'Baraja Workstation - Online',
            content: '$name ${location.isNotEmpty ? "- $location" : ""}',
          );
        } else {
          service.setForegroundNotificationInfo(
            title: 'Baraja Workstation - Offline',
            content: 'Mencoba reconnect...',
          );
        }
      }
    });

    // Listen for new order notification from foreground socket
    service.on('notifyNewOrder').listen((event) async {
      if (event == null) return;
      
      if (kDebugMode) {
        print('🔔 [BG] New order notification received from foreground');
      }

      // Show notification
      await _showOrderNotification(
        flutterLocalNotificationsPlugin,
        title: 'Order Baru!',
        body: event['message'] as String? ?? 'Ada order baru yang perlu diproses',
      );
    });

    // Listen for immediate print notification from foreground socket
    service.on('notifyImmediatePrint').listen((event) async {
      if (event == null) return;
      
      final orderId = event['orderId'] as String? ?? '';
      
      if (kDebugMode) {
        print('🔥 [BG] Immediate print notification received: $orderId');
      }

      // Queue for print if app is in background
      await _addToImmediatePrintQueue(prefs, event);

      // Show notification
      await _showOrderNotification(
        flutterLocalNotificationsPlugin,
        title: 'Print Order!',
        body: 'Order $orderId perlu dicetak',
      );
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

    // Restore previous configuration for notification display
    final savedDeviceData = prefs.getString(_deviceDataKey);
    if (savedDeviceData != null) {
      final device = json.decode(savedDeviceData);
      final deviceName = device['deviceName'] ?? 'Unknown';
      final location = device['location'] ?? '';

      if (kDebugMode) {
        print('🔄 Restoring previous configuration: $deviceName');
      }

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Baraja Workstation',
          content: '$deviceName ${location.isNotEmpty ? "- $location" : ""} - Menunggu koneksi...',
        );
      }
    } else {
      // No saved config - show waiting status
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Baraja Workstation',
          content: 'Menunggu pilihan device...',
        );
      }
    }
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

  /// Update socket status in background service notification
  void updateSocketStatus(bool connected) {
    final service = FlutterBackgroundService();
    service.invoke('updateSocketStatus', {'connected': connected});
  }

  /// Notify background service of new order (from foreground socket)
  void notifyNewOrder(String message) {
    final service = FlutterBackgroundService();
    service.invoke('notifyNewOrder', {'message': message});
  }

  /// Notify background service of immediate print (from foreground socket)
  void notifyImmediatePrint(Map<String, dynamic> data) {
    final service = FlutterBackgroundService();
    service.invoke('notifyImmediatePrint', data);
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
    
    // Cancel any existing pending orders subscription
    await _pendingOrdersSubscription?.cancel();

    // Create one-time listener
    _pendingOrdersSubscription = service.on('pendingOrders').listen((event) {
      if (event != null && !completer.isCompleted) {
        completer.complete({
          'orders': json.decode(event['orders'] ?? '[]'),
          'immediatePrint': json.decode(event['immediatePrint'] ?? '[]'),
        });
        // Cancel subscription after receiving response
        _pendingOrdersSubscription?.cancel();
        _pendingOrdersSubscription = null;
      }
    });

    // Request pending orders
    service.invoke('getPendingOrders');

    // Timeout after 2 seconds
    return completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        _pendingOrdersSubscription?.cancel();
        _pendingOrdersSubscription = null;
        return {'orders': [], 'immediatePrint': []};
      },
    );
  }

  /// Clear pending order queue
  void clearQueue() {
    final service = FlutterBackgroundService();
    service.invoke('clearQueue');
  }

  /// Listen for new orders from background service
  void onNewOrder(Function(Map<String, dynamic>) callback) {
    // Cancel any existing subscription first
    _newOrderSubscription?.cancel();
    
    final service = FlutterBackgroundService();
    _newOrderSubscription = service.on('newOrder').listen((event) {
      if (event != null && event['data'] != null) {
        try {
          callback(json.decode(event['data']));
        } catch (e) {
          if (kDebugMode) print('❌ Error parsing new order data: $e');
        }
      }
    });
    
    if (kDebugMode) print('📡 New order listener registered');
  }

  /// Listen for immediate print events from background service
  void onImmediatePrint(Function(Map<String, dynamic>) callback) {
    // Cancel any existing subscription first
    _immediatePrintSubscription?.cancel();
    
    final service = FlutterBackgroundService();
    _immediatePrintSubscription = service.on('immediatePrint').listen((event) {
      if (event != null && event['data'] != null) {
        try {
          callback(json.decode(event['data']));
        } catch (e) {
          if (kDebugMode) print('❌ Error parsing immediate print data: $e');
        }
      }
    });
    
    if (kDebugMode) print('📡 Immediate print listener registered');
  }

  /// Listen for socket connection status
  void onSocketStatus(Function(bool) callback) {
    // Cancel any existing subscription first
    _socketStatusSubscription?.cancel();
    
    final service = FlutterBackgroundService();
    _socketStatusSubscription = service.on('socketConnected').listen((event) {
      if (event != null) {
        callback(event['connected'] ?? false);
      }
    });
    
    if (kDebugMode) print('📡 Socket status listener registered');
  }

  /// Dispose all listeners - MUST be called when dashboard is disposed
  Future<void> dispose() async {
    if (kDebugMode) print('🧹 Disposing background service listeners...');
    
    await _newOrderSubscription?.cancel();
    _newOrderSubscription = null;
    
    await _immediatePrintSubscription?.cancel();
    _immediatePrintSubscription = null;
    
    await _socketStatusSubscription?.cancel();
    _socketStatusSubscription = null;
    
    await _pendingOrdersSubscription?.cancel();
    _pendingOrdersSubscription = null;
    
    _isInitialized = false;
    
    if (kDebugMode) print('✅ Background service listeners disposed');
  }
}
