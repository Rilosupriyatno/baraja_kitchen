// services/thermal_print_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../models/order.dart';
import 'package:intl/intl.dart';
import 'print_tracking_service.dart'; // Import print tracking service

enum PrinterConnectionType { wifi, bluetooth }

class ThermalPrintService {
  static final ThermalPrintService _instance = ThermalPrintService._internal();
  factory ThermalPrintService() => _instance;
  ThermalPrintService._internal() {
    _loadPrinterConfig();
  }

  // Key untuk penyimpanan
  static const String _printerConfigKey = 'printer_config';
  static const String _autoPrintEnabledKey = 'auto_print_enabled';

  // Konfigurasi printer WiFi
  String? _printerIp;
  int _printerPort = 9100;

  // Konfigurasi printer Bluetooth
  BluetoothDevice? _bluetoothDevice;
  PrinterConnectionType _connectionType = PrinterConnectionType.wifi;

  // Auto print setting
  bool _autoPrintEnabled = true;

  // Track order yang sudah pernah diprint
  final Set<String> _printedOrders = <String>{};

  // Error tracking
  int _consecutiveFailures = 0;
  DateTime? _lastFailureTime;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  static const Duration _connectionTimeout = Duration(seconds: 10);

  // Bar Type Context
  String? _barType;

  // SharedPreferences instance
  late SharedPreferences _prefs;

  /// Initialize shared preferences
  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Load saved printer configuration
  Future<void> _loadPrinterConfig() async {
    await _initPreferences();

    final configJson = _prefs.getString(_printerConfigKey);
    final savedAutoPrint = _prefs.getBool(_autoPrintEnabledKey);

    if (savedAutoPrint != null) {
      _autoPrintEnabled = savedAutoPrint;
    }

    if (configJson != null) {
      try {
        final config = json.decode(configJson);
        final connectionType = config['connectionType'];

        if (connectionType == 'wifi') {
          _printerIp = config['printerIp'];
          _printerPort = config['printerPort'] ?? 9100;
          _connectionType = PrinterConnectionType.wifi;

          if (kDebugMode) {
            print('🖨️ Loaded WiFi printer config: $_printerIp:$_printerPort');
          }
        } else if (connectionType == 'bluetooth') {
          final deviceJson = config['bluetoothDevice'];
          if (deviceJson != null) {
            _bluetoothDevice = BluetoothDevice(
              address: deviceJson['address'],
              name: deviceJson['name'],
              type: BluetoothDeviceType.unknown,
            );
            _connectionType = PrinterConnectionType.bluetooth;

            if (kDebugMode) {
              print('🖨️ Loaded Bluetooth printer config: ${_bluetoothDevice?.name}');
            }
          }
        }

        // Coba koneksi otomatis saat load
        if (isConfigured) {
          _autoConnect();
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error loading printer config: $e');
        }
      }
    }
  }

  /// Save printer configuration
  Future<void> _savePrinterConfig() async {
    await _initPreferences();

    final config = <String, dynamic>{
      'connectionType': _connectionType == PrinterConnectionType.wifi ? 'wifi' : 'bluetooth',
      'savedAt': DateTime.now().toIso8601String(),
    };

    if (_connectionType == PrinterConnectionType.wifi) {
      config['printerIp'] = _printerIp;
      config['printerPort'] = _printerPort;
    } else {
      if (_bluetoothDevice != null) {
        config['bluetoothDevice'] = {
          'address': _bluetoothDevice!.address,
          'name': _bluetoothDevice!.name,
        };
      }
    }

    await _prefs.setString(_printerConfigKey, json.encode(config));

    if (kDebugMode) {
      print('💾 Printer configuration saved');
    }
  }

  /// Save auto print setting
  Future<void> _saveAutoPrintSetting() async {
    await _initPreferences();
    await _prefs.setBool(_autoPrintEnabledKey, _autoPrintEnabled);
  }

  /// Auto connect to saved printer
  Future<void> _autoConnect() async {
    if (!isConfigured) return;

    if (kDebugMode) {
      print('🔄 Attempting auto-connect to printer...');
    }

    final success = await testConnection();

    if (success) {
      if (kDebugMode) {
        print('✅ Auto-connect successful');
      }
    } else {
      if (kDebugMode) {
        print('❌ Auto-connect failed');
      }
    }
  }

  /// Set bar type untuk context printing
  void setBarType(String? barType) {
    _barType = barType;
    if (kDebugMode) {
      print('🖨️ [PRINT SERVICE] Bar Type set to: ${barType ?? "null (KITCHEN)"}');
      print('🖨️ [PRINT SERVICE] Header akan jadi: "$_workstationName"');
    }
  }

  /// Get display name untuk header struk
  String get _workstationName {
    if (_barType == null) return 'KITCHEN';
    if (_barType == 'depan') return 'BAR DEPAN';
    if (_barType == 'belakang') return 'BAR BELAKANG';
    return 'BAR';
  }

  /// Set konfigurasi printer WiFi
  void configurePrinter(String ip, {int port = 9100}) {
    _printerIp = ip;
    _printerPort = port;
    _connectionType = PrinterConnectionType.wifi;
    _resetErrorTracking();

    _savePrinterConfig(); // Simpan konfigurasi

    if (kDebugMode) {
      print('🖨️ Printer WiFi dikonfigurasi: $ip:$port');
    }
  }

  /// Set konfigurasi printer Bluetooth
  void configureBluetoothPrinter(BluetoothDevice device) {
    _bluetoothDevice = device;
    _connectionType = PrinterConnectionType.bluetooth;
    _resetErrorTracking();

    _savePrinterConfig(); // Simpan konfigurasi

    if (kDebugMode) {
      print('🖨️ Printer Bluetooth dikonfigurasi: ${device.name}');
    }
  }

  /// Set auto print enabled
  void setAutoPrintEnabled(bool enabled) {
    _autoPrintEnabled = enabled;
    _saveAutoPrintSetting(); // Simpan setting

    if (kDebugMode) {
      print('🖨️ Auto print ${enabled ? 'enabled' : 'disabled'}');
    }
  }

  /// Reset error tracking
  void _resetErrorTracking() {
    _consecutiveFailures = 0;
    _lastFailureTime = null;
  }

  /// Check if should attempt print based on failure history
  bool _shouldAttemptPrint() {
    if (_consecutiveFailures >= _maxRetries) {
      if (_lastFailureTime != null) {
        final timeSinceLastFailure = DateTime.now().difference(_lastFailureTime!);
        // Wait 5 minutes before trying again after max failures
        if (timeSinceLastFailure < const Duration(minutes: 5)) {
          if (kDebugMode) {
            print('⏸️ Print paused due to consecutive failures. Wait ${5 - timeSinceLastFailure.inMinutes} more minutes.');
          }
          return false;
        } else {
          // Reset after cool-down period
          _resetErrorTracking();
        }
      }
    }
    return true;
  }

  /// Record print failure
  void _recordFailure() {
    _consecutiveFailures++;
    _lastFailureTime = DateTime.now();
    if (kDebugMode) {
      print('❌ Print failure recorded. Total consecutive failures: $_consecutiveFailures');
    }
  }

  /// Record print success
  void _recordSuccess() {
    if (_consecutiveFailures > 0) {
      if (kDebugMode) {
        print('✅ Print successful. Resetting error tracking.');
      }
      _resetErrorTracking();
    }
  }

  /// Cek apakah printer sudah dikonfigurasi
  bool get isConfigured =>
      (_connectionType == PrinterConnectionType.wifi && _printerIp != null) ||
          (_connectionType == PrinterConnectionType.bluetooth && _bluetoothDevice != null);

  /// Get connection type
  PrinterConnectionType get connectionType => _connectionType;

  /// Get printer info
  String get printerInfo {
    if (_connectionType == PrinterConnectionType.wifi) {
      return 'WiFi: $_printerIp:$_printerPort';
    } else {
      return 'Bluetooth: ${_bluetoothDevice?.name ?? "Unknown"}';
    }
  }

  /// Get printer health status
  String get printerHealthStatus {
    if (!isConfigured) return 'Not Configured';
    if (_consecutiveFailures == 0) return 'healthy';
    if (_consecutiveFailures < _maxRetries) return 'Warning ($consecutiveFailures failures)';
    return 'Offline';
  }

  int get consecutiveFailures => _consecutiveFailures;

  /// Request Bluetooth permissions
  Future<bool> requestBluetoothPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      return statuses.values.every((status) => status.isGranted);
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting permissions: $e');
      }
      return false;
    }
  }

  /// Get paired/bonded Bluetooth devices
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      final isAvailable = await FlutterBluetoothSerial.instance.isAvailable;
      if (isAvailable == null || !isAvailable) {
        throw Exception('Bluetooth tidak tersedia pada perangkat ini');
      }

      final isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      if (isEnabled == null || !isEnabled) {
        throw Exception('Bluetooth tidak aktif. Silakan aktifkan Bluetooth.');
      }

      final hasPermission = await requestBluetoothPermissions();
      if (!hasPermission) {
        throw Exception('Izin Bluetooth ditolak.');
      }

      final bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();

      final printerDevices = bondedDevices.where((device) {
        final deviceName = device.name?.toLowerCase() ?? '';
        return deviceName.isNotEmpty && _isPrinterDevice(deviceName);
      }).toList();

      if (kDebugMode) {
        print('Found ${printerDevices.length} paired printer devices');
      }

      return printerDevices;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting paired devices: $e');
      }
      rethrow;
    }
  }

  /// Check if device name indicates it's a printer
  bool _isPrinterDevice(String deviceName) {
    return deviceName.contains('printer') ||
        deviceName.contains('pos') ||
        deviceName.contains('rpp') ||
        deviceName.contains('mpt') ||
        deviceName.contains('thermal') ||
        deviceName.contains('escpos') ||
        deviceName.contains('bluetooth');
  }

  /// Clear saved printer configuration
  Future<void> clearConfiguration() async {
    await _initPreferences();

    // Clear shared preferences
    await _prefs.remove(_printerConfigKey);
    await _prefs.remove(_autoPrintEnabledKey);

    // Reset local variables
    _printerIp = null;
    _bluetoothDevice = null;
    _connectionType = PrinterConnectionType.wifi;
    _autoPrintEnabled = true;
    _printedOrders.clear();
    _resetErrorTracking();

    if (kDebugMode) {
      print('🗑️ Printer configuration cleared');
    }
  }

  // GETTERS untuk mengakses nilai yang disimpan
  bool get autoPrintEnabled => _autoPrintEnabled;
  String? get printerIp => _printerIp;
  BluetoothDevice? get bluetoothDevice => _bluetoothDevice;

  Future<bool> autoPrintOrder(Order order) async {
    final workstation = _workstationName.toLowerCase().replaceAll(' ', '_');
    final printerConfig = {
      'type': _connectionType == PrinterConnectionType.wifi ? 'wifi' : 'bluetooth',
      'info': printerInfo,
      'health_status': printerHealthStatus,
      'consecutive_failures': _consecutiveFailures,
    };

    // Cek order sudah diprint sebelumnya
    if (_printedOrders.contains(order.orderId)) {
      if (kDebugMode) {
        print('🔄 Order ${order.orderId} sudah pernah diprint, skip');
      }
      return false;
    }

    if (!isConfigured) {
      final technicalReason = {
        'reason': 'printer_not_configured',
        'details': 'Printer belum dikonfigurasi untuk workstation ini',
        'workstation': workstation,
        'timestamp': DateTime.now().toIso8601String()
      };

      // Log semua items sebagai skipped karena printer tidak dikonfigurasi
      for (final item in order.items) {
        await PrintTrackingService().logSkippedItem(
            order.orderId!,
            _convertOrderItemToMap(item),
            workstation,
            'printer_not_configured',
            'Printer belum dikonfigurasi, tidak dapat melakukan auto print',
            technicalReason: technicalReason
        );
      }
      return false;
    }

    if (!_shouldAttemptPrint()) {
      final technicalReason = {
        'reason': 'too_many_failures',
        'details': 'Terlalu banyak kegagalan berturut-turut, sistem pause sementara',
        'consecutive_failures': _consecutiveFailures,
        'last_failure_time': _lastFailureTime?.toIso8601String(),
        'timestamp': DateTime.now().toIso8601String()
      };

      for (final item in order.items) {
        await PrintTrackingService().logSkippedItem(
            order.orderId!,
            _convertOrderItemToMap(item),
            workstation,
            'too_many_failures',
            'Sistem pause sementara karena terlalu banyak kegagalan print',
            technicalReason: technicalReason
        );
      }
      return false;
    }

    // Analisis items dengan enhanced problematic detection
    final validItems = <OrderItem>[];
    final problematicItems = <Map<String, dynamic>>[];

    for (final item in order.items) {
      final itemMap = _convertOrderItemToMap(item);
      final List<String> issues = [];
      Map<String, dynamic>? technicalIssue;

      // Cek workstation mismatch
      if (!_isItemForThisWorkstation(item, workstation)) {
        issues.add('workstation_mismatch');
      }

      // Cek stok dengan enhanced reporting
      final stockInfo = await _checkItemStock(item);
      if (!stockInfo['available'] || stockInfo['stock_status'] == 'out_of_stock') {
        issues.add('out_of_stock');
      } else if (stockInfo['stock_status'] == 'critical_stock') {
        issues.add('critical_stock');
      }

      // Cek technical issues printer
      if (_consecutiveFailures > 0) {
        issues.add('printer_health_warning');
        technicalIssue = {
          'consecutive_failures': _consecutiveFailures,
          'printer_health': printerHealthStatus,
          'connection_type': _connectionType.toString(),
        };
      }

      // Jika ada issues, log sebagai problematic item
      if (issues.isNotEmpty) {
        problematicItems.add({
          'item': itemMap,
          'issues': issues,
          'details': 'Item memiliki masalah: ${issues.join(", ")}',
          'stock_info': stockInfo,
          'technical_info': technicalIssue,
          'workstation_mismatch': issues.contains('workstation_mismatch'),
          'stock_problem': issues.any((issue) => issue.contains('stock')),
          'technical_problem': issues.any((issue) => issue.contains('printer') || issue.contains('technical')),
        });

        print('⚠️ PROBLEMATIC ITEM DETECTED: ${item.name} - Issues: ${issues.join(", ")} - Stock: ${stockInfo['effective_stock']}');
      }

      // TETAP MASUKKAN KE VALID ITEMS (print semua meskipun problematic)
      validItems.add(item);
    }

    // Log problematic items ke backend dengan enhanced details
    for (final problematic in problematicItems) {
      await PrintTrackingService().logProblematicItem(
          order.orderId!,
          problematic['item'],
          workstation,
          problematic['issues'],
          problematic['details'],
          problematic['stock_info']
      );
    }

    // Log print attempt untuk setiap item
    final List<String> logIds = [];
    for (final item in validItems) {
      final stockInfo = await _checkItemStock(item);
      final _ = problematicItems.any((p) => p['item']['id'] == item.itemId.toString());

      final logId = await PrintTrackingService().logPrintAttempt(
          order.orderId!,
          _convertOrderItemToMap(item),
          workstation,
          printerConfig,
          stockInfo
      );
      if (logId != null) {
        logIds.add(logId);
      }
    }

    final startTime = DateTime.now();
    try {
      final problematicCount = problematicItems.length;
      final totalCount = validItems.length;

      // Enhanced logging summary
      if (problematicCount > 0) {
        final stockProblems = problematicItems.where((p) => p['stock_problem'] == true).length;
        final technicalProblems = problematicItems.where((p) => p['technical_problem'] == true).length;
        final workstationProblems = problematicItems.where((p) => p['workstation_mismatch'] == true).length;

        print('🖨️ AUTO PRINT WITH ISSUES: Order ${order.orderId}');
        print('   📦 Total Items: $totalCount');
        print('   ⚠️ Problematic Items: $problematicCount');
        print('   📊 Breakdown:');
        print('     • Stock Issues: $stockProblems items');
        print('     • Technical Issues: $technicalProblems items');
        print('     • Workstation Mismatch: $workstationProblems items');
        print('   💡 Action: All items will be printed, kitchen should verify stock manually');
      } else {
        print('🖨️ AUTO PRINT: Order ${order.orderId} with $totalCount items (all OK)');
      }

      // Print order seperti biasa (semua item)
      final success = await _printOrderWithRetry(order, logIds: logIds);

      if (success) {
        _printedOrders.add(order.orderId ?? '');
        _recordSuccess();

        final duration = DateTime.now().difference(startTime).inMilliseconds;

        // Log success untuk setiap item dengan problematic context
        for (final logId in logIds) {
          final wasProblematic = problematicItems.any((p) =>
          p['item']['id'] == _findItemIdByLogId(logId, validItems));
          await PrintTrackingService().logPrintSuccess(
              logId,
              duration,
              wasProblematic: wasProblematic
          );
        }

        // Enhanced success reporting
        if (problematicCount > 0) {
          print('✅ PROBLEMATIC ORDER PRINTED: Order ${order.orderId} berhasil diprint');
          print('   📝 Catatan: $problematicCount items memiliki masalah, perlu verifikasi manual di dapur');
          print('   💡 Saran: Periksa stok fisik dan update sistem jika diperlukan');
        } else {
          print('✅ ORDER PRINTED: Order ${order.orderId} berhasil diprint secara otomatis');
        }
        return true;
      } else {
        _recordFailure();

        // Enhanced failure reporting dengan technical details
        final technicalDetails = {
          'connection_type': _connectionType.toString(),
          'printer_ip': _printerIp,
          'bluetooth_device': _bluetoothDevice?.name,
          'consecutive_failures': _consecutiveFailures,
          'printer_health': printerHealthStatus,
          'has_problematic_items': problematicCount > 0,
          'timestamp': DateTime.now().toIso8601String()
        };

        // Log failure untuk setiap item dengan technical details
        for (final logId in logIds) {
          await PrintTrackingService().logPrintFailure(
              logId,
              'auto_print_failed',
              'Auto print gagal setelah $_maxRetries percobaan',
              technicalDetails: technicalDetails
          );
        }

        print('❌ AUTO PRINT FAILED: Order ${order.orderId} gagal diprint');
        print('   🔧 Technical Details: ${technicalDetails.toString()}');
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ERROR IN AUTO PRINT: $e');
      }
      _recordFailure();

      // Enhanced error reporting
      final errorDetails = {
        'error_type': e.runtimeType.toString(),
        'error_message': e.toString(),
        'stack_trace': e is Error ? e.stackTrace.toString() : '',
        'has_problematic_items': problematicItems.isNotEmpty,
        'timestamp': DateTime.now().toIso8601String()
      };

      // Log failure untuk setiap item dengan error details
      for (final logId in logIds) {
        await PrintTrackingService().logPrintFailure(
            logId,
            'auto_print_error',
            'Error selama auto print: ${e.toString()}',
            technicalDetails: errorDetails
        );
      }

      print('❌ CRITICAL AUTO PRINT ERROR: Order ${order.orderId}');
      print('   🚨 Error: $e');
      print('   📋 Details: ${errorDetails.toString()}');
      return false;
    }
  }

  // Helper method untuk mencari item ID berdasarkan log ID
  String _findItemIdByLogId(String logId, List<OrderItem> items) {
    // Implementasi sederhana - dalam real implementation mungkin perlu mapping yang lebih baik
    return items.isNotEmpty ? items.first.itemId.toString() : '';
  }

  /// Helper method untuk convert OrderItem ke Map
  Map<String, dynamic> _convertOrderItemToMap(OrderItem item) {
    return {
      'id': item.itemId.toString(), // order item ID
      'menuItemId': item.menuItemId,
      'name': item.name,
      'quantity': item.qty,
      'notes': item.notes,
      'addons': item.addons,
      'toppings': item.toppings,
      'workstation': item.workstation,
      'mainCategory': item.mainCategory,
    };
  }

  /// Helper method untuk cek workstation item
  bool _isItemForThisWorkstation(OrderItem item, String currentWorkstation) {
    // Logic sederhana berdasarkan nama workstation
    // Bisa disesuaikan dengan struktur data yang lebih kompleks
    if (currentWorkstation == 'kitchen') {
      // Untuk kitchen, print semua item kecuali minuman tertentu
      return !_isBeverageItem(item);
    } else if (currentWorkstation.contains('bar')) {
      // Untuk bar, hanya print minuman
      return _isBeverageItem(item);
    }
    return true; // Fallback - print semua
  }

  /// Helper method untuk identifikasi item minuman
  bool _isBeverageItem(OrderItem item) {
    final beverageKeywords = [
      'minuman', 'drink', 'beverage', 'juice', 'soda', 'cola', 'tea', 'coffee',
      'kopi', 'teh', 'jus', 'susu', 'air', 'water', 'bir', 'beer', 'wine', 'cocktail'
    ];

    final itemName = item.name.toLowerCase();
    return beverageKeywords.any((keyword) => itemName.contains(keyword));
  }

  // Enhanced stock check
  Future<Map<String, dynamic>> _checkItemStock(OrderItem item) async {
    try {
      // Gunakan menuItemId untuk mencari stock, bukan itemId
      final menuItemId = item.menuItemId;
      if (menuItemId == null) {
        print('❌ No menuItemId found for item: ${item.name}');
        return _getFallbackStockInfo(item);
      }

      print('🔍 Checking stock for item: ${item.name} (Menu ID: $menuItemId)');

      final response = await http.get(
        Uri.parse('$baseUrl/api/menu-items/$menuItemId/stock-status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final stockData = json.decode(response.body);
        final data = stockData['data'] ?? {};

        print('✅ Stock data received: ${data['currentStock']} - Status: ${data['status']}');

        return {
          'available': data['available'] ?? true,
          'requiresPreparation': data['requiresPreparation'] ?? true,
          'stock_quantity': data['currentStock'] ?? 0,
          'stock_status': data['status'] ?? 'unknown',
          'calculated_stock': data['calculatedStock'] ?? 0,
          'manual_stock': data['manualStock'],
          'effective_stock': data['effectiveStock'] ?? 0,
          'menu_item_name': data['menuItemName'] ?? item.name
        };
      } else if (response.statusCode == 404) {
        print('⚠️ Menu item not found, using fallback stock data');
        return _getFallbackStockInfo(item);
      } else {
        print('❌ Stock API error: ${response.statusCode}');
        return _getFallbackStockInfo(item);
      }

    } catch (e) {
      print('❌ Error checking item stock: $e');
      return _getFallbackStockInfo(item);
    }
  }

// Fallback stock info untuk error handling
  Map<String, dynamic> _getFallbackStockInfo(OrderItem item) {
    return {
      'available': true,
      'requiresPreparation': true,
      'stock_quantity': 100,
      'stock_status': 'in_stock',
      'calculated_stock': 100,
      'manual_stock': null,
      'effective_stock': 100,
      'menu_item_name': item.name,
      'is_fallback': true
    };
  }

  /// Print with retry mechanism
  Future<bool> _printOrderWithRetry(Order order, {int attempt = 1, List<String>? logIds}) async {
    try {
      if (kDebugMode) {
        print('🔄 Print attempt $attempt for order ${order.orderId}');
      }

      bool success;
      if (_connectionType == PrinterConnectionType.wifi) {
        success = await _printViaWiFi(order);
      } else {
        success = await _printViaBluetooth(order);
      }

      if (!success && attempt < _maxRetries) {
        // Log retry attempt untuk setiap item
        if (logIds != null) {
          for (final logId in logIds) {
            await PrintTrackingService().logPrintFailure(
                logId,
                'retrying',
                'Retry attempt $attempt dari $_maxRetries'
            );
          }
        }

        if (kDebugMode) {
          print('⏳ Waiting ${_retryDelay.inSeconds}s before retry...');
        }
        await Future.delayed(_retryDelay);
        return await _printOrderWithRetry(order, attempt: attempt + 1, logIds: logIds);
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Print attempt $attempt failed: $e');
      }

      if (attempt < _maxRetries) {
        // Log retry attempt due to exception untuk setiap item
        if (logIds != null) {
          for (final logId in logIds) {
            await PrintTrackingService().logPrintFailure(
                logId,
                'retrying',
                'Retry attempt $attempt karena exception: ${e.toString()}'
            );
          }
        }

        if (kDebugMode) {
          print('⏳ Waiting ${_retryDelay.inSeconds}s before retry...');
        }
        await Future.delayed(_retryDelay);
        return await _printOrderWithRetry(order, attempt: attempt + 1, logIds: logIds);
      }

      if (kDebugMode) {
        print('❌ All print attempts failed for order ${order.orderId}');
      }
      return false;
    }
  }

  Future<bool> printOrder(Order order) async {
    if (!isConfigured) {
      if (kDebugMode) {
        print('Printer tidak dikonfigurasi');
      }
      return false;
    }

    try {
      print('Printing order ${order.orderId}');
      if (_connectionType == PrinterConnectionType.wifi) {
        return await _printViaWiFi(order);
      } else {
        return await _printViaBluetooth(order);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error printing: $e');
      }
      return false;
    }
  }

  /// Print via WiFi with enhanced error handling
  Future<bool> _printViaWiFi(Order order) async {
    if (_printerIp == null) return false;

    NetworkPrinter? printer;

    try {
      printer = NetworkPrinter(PaperSize.mm80, await CapabilityProfile.load());

      if (kDebugMode) {
        print('🔌 Connecting to WiFi printer at $_printerIp:$_printerPort...');
      }

      // Connect with timeout
      final result = await printer.connect(_printerIp!, port: _printerPort)
          .timeout(_connectionTimeout, onTimeout: () {
        throw Exception('Connection timeout - printer tidak merespons');
      });

      if (result != PosPrintResult.success) {
        throw Exception('Connection failed: $result');
      }

      if (kDebugMode) {
        print('✅ Connected to WiFi printer');
      }

      await _generateReceipt(printer, order);

      // Ensure print job is sent
      await Future.delayed(const Duration(milliseconds: 500));

      printer.disconnect();

      if (kDebugMode) {
        print('✅ Order ${order.orderId} berhasil diprint via WiFi');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ WiFi printing error: $e');
      }

      try {
        printer?.disconnect();
      } catch (_) {}

      return false;
    }
  }

  /// Print via Bluetooth with enhanced error handling
  Future<bool> _printViaBluetooth(Order order) async {
    if (_bluetoothDevice == null) return false;

    BluetoothConnection? connection;

    try {
      if (kDebugMode) {
        print('🔌 Connecting to Bluetooth printer ${_bluetoothDevice!.name}...');
      }

      // Connect with timeout
      connection = await BluetoothConnection.toAddress(_bluetoothDevice!.address)
          .timeout(_connectionTimeout, onTimeout: () {
        throw Exception('Bluetooth connection timeout');
      });

      if (!connection.isConnected) {
        throw Exception('Gagal terhubung ke printer');
      }

      if (kDebugMode) {
        print('✅ Connected to Bluetooth printer');
      }

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      final bytes = await _generateReceiptBytes(generator, order);

      // Send data with error handling
      connection.output.add(Uint8List.fromList(bytes));
      await connection.output.allSent.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Timeout sending data to printer');
        },
      );

      // Wait for print to complete
      await Future.delayed(const Duration(milliseconds: 800));

      await connection.close();

      if (kDebugMode) {
        print('✅ Order ${order.orderId} berhasil diprint via Bluetooth');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Bluetooth printing error: $e');
      }

      try {
        await connection?.close();
      } catch (_) {}

      return false;
    }
  }

  /// Generate receipt untuk NetworkPrinter
  Future<void> _generateReceipt(NetworkPrinter printer, Order order) async {
    if (kDebugMode) {
      print('🖨️ [GENERATING RECEIPT] _barType = $_barType');
      print('🖨️ [GENERATING RECEIPT] _workstationName = $_workstationName');
    }

    printer.text(
      'BARAJA AMPHI',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );
    printer.text(' ');

    printer.text(
      'ORDER $_workstationName',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
      ),
    );

    printer.hr(ch: '-');
    printer.text(' ');

    printer.row([
      PosColumn(text: 'Order ID:', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(text: order.orderId ?? 'N/A', width: 8),
    ]);
    printer.text(' ');

    printer.row([
      PosColumn(text: 'Nama:', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(text: order.name, width: 8),
    ]);
    printer.text(' ');

    printer.row([
      PosColumn(text: 'Meja:', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(text: order.table, width: 8),
    ]);
    printer.text(' ');

    printer.row([
      PosColumn(text: 'Tipe:', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(text: order.service, width: 8),
    ]);
    printer.text(' ');

    if (order.service.contains('Reservation') && order.reservationDate != null) {
      printer.row([
        PosColumn(text: 'Tanggal:', width: 4, styles: const PosStyles(bold: true)),
        PosColumn(text: order.reservationDate!, width: 8),
      ]);
      printer.text(' ');

      printer.row([
        PosColumn(text: 'Jam:', width: 4, styles: const PosStyles(bold: true)),
        PosColumn(text: order.reservationTime ?? '-', width: 8),
      ]);
      printer.text(' ');
    }

    printer.row([
      PosColumn(text: 'Waktu:', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(
        text: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
        width: 8,
      ),
    ]);
    printer.text(' ');

    printer.hr(ch: '-');
    printer.text(' ');

    printer.text(
      'PESANAN:',
      styles: const PosStyles(bold: true, underline: true),
    );
    printer.text(' ');

    for (var item in order.items) {
      final itemNameWithService = '${item.name} (${order.service}) x${item.qty}';
      printer.text(itemNameWithService, styles: const PosStyles(bold: true));

      if (item.addons != null && item.addons!.isNotEmpty) {
        for (var addon in item.addons!) {
          printer.text('  + ${addon['name']}',
              styles: const PosStyles(fontType: PosFontType.fontB));
        }
      }

      if (item.toppings != null && item.toppings!.isNotEmpty) {
        for (var topping in item.toppings!) {
          printer.text('  + ${topping['name']}',
              styles: const PosStyles(fontType: PosFontType.fontB));
        }
      }

      if (item.notes != null && item.notes!.isNotEmpty) {
        printer.text('  Catatan: ${item.notes}',
            styles: const PosStyles(fontType: PosFontType.fontB, bold: true));
      }

      printer.text(' ');
    }

    printer.hr(ch: '-');
    printer.text(' ');

    final totalItems = order.items.fold(0, (sum, item) => sum + item.qty);
    printer.row([
      PosColumn(text: 'TOTAL ITEM:', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: '$totalItems',
        width: 6,
        styles: const PosStyles(
          bold: true,
          align: PosAlign.right,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    ]);

    printer.text(' ');
    printer.hr(ch: '-');
    printer.text(' ');

    printer.text(' ');
    printer.cut();
  }

  /// Generate receipt bytes untuk Bluetooth
  Future<List<int>> _generateReceiptBytes(Generator generator, Order order) async {
    final List<int> bytes = [];

    bytes.addAll(generator.text('BARAJA AMPHI',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        )));

    bytes.addAll(generator.text('ORDER $_workstationName',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        )));

    bytes.addAll(generator.hr());
    bytes.addAll(generator.emptyLines(1));

    bytes.addAll(generator.row([
      PosColumn(text: 'Order ID:', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(text: order.orderId ?? 'N/A', width: 8),
    ]));

    bytes.addAll(generator.row([
      PosColumn(text: 'Nama:', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(text: order.name, width: 8),
    ]));

    bytes.addAll(generator.row([
      PosColumn(text: 'Meja:', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(text: order.table, width: 8),
    ]));

    bytes.addAll(generator.row([
      PosColumn(text: 'Tipe:', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(text: order.service, width: 8),
    ]));

    bytes.addAll(generator.row([
      PosColumn(text: 'Waktu:', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(text: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), width: 8),
    ]));

    bytes.addAll(generator.hr());
    bytes.addAll(generator.emptyLines(1));

    bytes.addAll(generator.text('PESANAN:',
        styles: const PosStyles(bold: true, underline: true)));
    bytes.addAll(generator.emptyLines(1));

    for (var item in order.items) {
      final itemNameWithService = '${item.name} (${order.service}) x${item.qty}';

      bytes.addAll(generator.text(itemNameWithService, styles: const PosStyles(bold: true)));

      if (item.addons != null && item.addons!.isNotEmpty) {
        for (var addon in item.addons!) {
          bytes.addAll(generator.text('  + ${addon['name']}'));
        }
      }

      if (item.toppings != null && item.toppings!.isNotEmpty) {
        for (var topping in item.toppings!) {
          bytes.addAll(generator.text('  + ${topping['name']}'));
        }
      }

      if (item.notes != null && item.notes!.isNotEmpty) {
        bytes.addAll(generator.text('  Catatan: ${item.notes}',
            styles: const PosStyles(bold: true)));
      }

      bytes.addAll(generator.emptyLines(1));
    }

    bytes.addAll(generator.hr());
    bytes.addAll(generator.emptyLines(1));

    final totalItems = order.items.fold(0, (sum, item) => sum + item.qty);
    bytes.addAll(generator.row([
      PosColumn(text: 'TOTAL ITEM:', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: '$totalItems', width: 6,
          styles: const PosStyles(
            bold: true,
            align: PosAlign.right,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          )),
    ]));

    bytes.addAll(generator.emptyLines(2));
    bytes.addAll(generator.cut());

    return bytes;
  }

  Future<bool> manualPrint(Order order) async {
    _printedOrders.remove(order.orderId);

    final workstation = _workstationName.toLowerCase().replaceAll(' ', '_');
    final printerConfig = {
      'type': _connectionType == PrinterConnectionType.wifi ? 'wifi' : 'bluetooth',
      'info': printerInfo,
    };

    // Log print attempt untuk setiap item
    final List<String> logIds = [];
    for (final item in order.items) {
      final stockInfo = await _checkItemStock(item);
      final logId = await PrintTrackingService().logPrintAttempt(
          order.orderId!,
          _convertOrderItemToMap(item),
          workstation,
          printerConfig,
          stockInfo
      );
      if (logId != null) {
        logIds.add(logId);
      }
    }

    final startTime = DateTime.now();

    try {
      final success = await printOrder(order);

      if (success) {
        final duration = DateTime.now().difference(startTime).inMilliseconds;
        for (final logId in logIds) {
          await PrintTrackingService().logPrintSuccess(
              logId,
              duration,
              wasProblematic: false
          );
        }
      } else {
        for (final logId in logIds) {
          await PrintTrackingService().logPrintFailure(
              logId,
              'printer_not_configured',
              'Manual print gagal - printer tidak terkonfigurasi'
          );
        }
      }

      return success;
    } catch (e) {
      for (final logId in logIds) {
        await PrintTrackingService().logPrintFailure(
            logId,
            'unknown_error',
            e.toString()
        );
      }
      rethrow;
    }
  }

  /// Test koneksi printer dengan retry
  Future<bool> testConnection() async {
    if (!isConfigured) return false;

    try {
      if (_connectionType == PrinterConnectionType.wifi) {
        return await _testWiFiConnection();
      } else {
        return await _testBluetoothConnection();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Test connection error: $e');
      }
      return false;
    }
  }

  Future<bool> _testWiFiConnection() async {
    if (_printerIp == null) return false;

    NetworkPrinter? printer;

    try {
      printer = NetworkPrinter(PaperSize.mm80, await CapabilityProfile.load());
      final result = await printer.connect(_printerIp!, port: _printerPort)
          .timeout(_connectionTimeout);

      if (result == PosPrintResult.success) {
        printer.text('TEST PRINTER',
            styles: const PosStyles(
              align: PosAlign.center,
              bold: true,
              height: PosTextSize.size2,
            ));
        printer.emptyLines(1);

        printer.text('Workstation: $_workstationName',
            styles: const PosStyles(align: PosAlign.center, bold: true));
        printer.emptyLines(1);

        printer.text('Koneksi WiFi berhasil!',
            styles: const PosStyles(align: PosAlign.center));
        printer.text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            styles: const PosStyles(align: PosAlign.center));
        printer.emptyLines(2);
        printer.cut();

        printer.disconnect();
        _recordSuccess();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('WiFi test failed: $e');
      }
      try {
        printer?.disconnect();
      } catch (_) {}
      return false;
    }
  }

  Future<bool> _testBluetoothConnection() async {
    if (_bluetoothDevice == null) return false;

    BluetoothConnection? connection;

    try {
      connection = await BluetoothConnection.toAddress(_bluetoothDevice!.address)
          .timeout(_connectionTimeout);

      if (!connection.isConnected) {
        return false;
      }

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);

      final bytes = <int>[];

      bytes.addAll(generator.text('TEST PRINTER',
          styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2)));
      bytes.addAll(generator.emptyLines(1));

      bytes.addAll(generator.text('Workstation: $_workstationName',
          styles: const PosStyles(align: PosAlign.center, bold: true)));
      bytes.addAll(generator.emptyLines(1));

      bytes.addAll(generator.text('Koneksi Bluetooth berhasil!',
          styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
          styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.emptyLines(2));
      bytes.addAll(generator.cut());

      connection.output.add(Uint8List.fromList(bytes));
      await connection.output.allSent;

      await Future.delayed(const Duration(milliseconds: 500));
      await connection.close();

      _recordSuccess();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Bluetooth test failed: $e');
      }
      try {
        await connection?.close();
      } catch (_) {}
      return false;
    }
  }

  /// Clear history print
  void clearPrintHistory() {
    _printedOrders.clear();
    if (kDebugMode) {
      print('Print history cleared');
    }
  }

  /// Getters
  int get printedCount => _printedOrders.length;

  bool isAlreadyPrinted(String? orderId) {
    return orderId != null && _printedOrders.contains(orderId);
  }

  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
}