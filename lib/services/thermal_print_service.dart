// services/thermal_print_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../models/order.dart';
import '../models/device.dart';
import 'package:intl/intl.dart';
import 'print_tracking_service.dart';

enum PrinterConnectionType { wifi, bluetooth }

class ThermalPrintService {
  static final ThermalPrintService _instance = ThermalPrintService._internal();
  factory ThermalPrintService() => _instance;
  ThermalPrintService._internal() {
    _loadPrinterConfig();
  }

  static const String _printerConfigKey = 'printer_config';
  static const String _autoPrintEnabledKey = 'auto_print_enabled';

  String? _printerIp;
  int _printerPort = 9100;
  BluetoothDevice? _bluetoothDevice;
  PrinterConnectionType _connectionType = PrinterConnectionType.wifi;
  bool _autoPrintEnabled = true;

  final Set<String> _printedItemIds = <String>{};
  final Map<String, Set<String>> _orderItemsHistory = {};

  int _consecutiveFailures = 0;
  DateTime? _lastFailureTime;
  static const int _maxRetries = 3;
  static const Duration _connectionTimeout = Duration(seconds: 10);

  Device? _currentDevice;
  late SharedPreferences _prefs;

  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }

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

  Future<void> _saveAutoPrintSetting() async {
    await _initPreferences();
    await _prefs.setBool(_autoPrintEnabledKey, _autoPrintEnabled);
  }

  Future<void> _autoConnect() async {
    if (!isConfigured) return;
    if (kDebugMode) {
      print('🔄 Attempting auto-connect to printer...');
    }
    final success = await testConnection();
    if (kDebugMode) {
      print(success ? '✅ Auto-connect successful' : '❌ Auto-connect failed');
    }
  }

  void setDevice(Device device) {
    _currentDevice = device;
    if (kDebugMode) {
      print('🖨️ [PRINT SERVICE] Device set:');
      print('   Device Name: ${device.deviceName}');
      print('   Workstation Type: ${device.workstationTypeString}');
      print('   Display Name: ${device.workstationName}');
      print('   Location: ${device.location}');
      print('   Header: "$_workstationName"');
    }
  }

  @Deprecated('Use setDevice(Device) instead')
  /// @deprecated Use setDevice() instead.
  /// This function is kept for backward compatibility only.
  @Deprecated('Use setDevice() instead')
  void setBarType(String? barType) {
    if (kDebugMode) {
      print('⚠️ setBarType is deprecated. Please use setDevice() instead.');
    }
  }

  String get _workstationName {
    if (_currentDevice != null) {
      return _currentDevice!.workstationName;
    }
    if (kDebugMode) {
      print('⚠️ No device set, using default KITCHEN');
    }
    return 'KITCHEN';
  }

  String get _workstationType {
    if (_currentDevice != null) {
      return _currentDevice!.workstationTypeString;
    }
    return 'kitchen';
  }

  void configurePrinter(String ip, {int port = 9100}) {
    _printerIp = ip;
    _printerPort = port;
    _connectionType = PrinterConnectionType.wifi;
    _resetErrorTracking();
    _savePrinterConfig();
    if (kDebugMode) {
      print('🖨️ Printer WiFi dikonfigurasi: $ip:$port');
    }
  }

  void configureBluetoothPrinter(BluetoothDevice device) {
    _bluetoothDevice = device;
    _connectionType = PrinterConnectionType.bluetooth;
    _resetErrorTracking();
    _savePrinterConfig();
    if (kDebugMode) {
      print('🖨️ Printer Bluetooth dikonfigurasi: ${device.name}');
    }
  }

  void setAutoPrintEnabled(bool enabled) {
    _autoPrintEnabled = enabled;
    _saveAutoPrintSetting();
    if (kDebugMode) {
      print('🖨️ Auto print ${enabled ? 'enabled' : 'disabled'}');
    }
  }

  void _resetErrorTracking() {
    _consecutiveFailures = 0;
    _lastFailureTime = null;
  }

  bool _shouldAttemptPrint() {
    if (_consecutiveFailures >= _maxRetries) {
      if (_lastFailureTime != null) {
        final timeSinceLastFailure = DateTime.now().difference(_lastFailureTime!);
        if (timeSinceLastFailure < const Duration(minutes: 5)) {
          if (kDebugMode) {
            print('⏸️ Print paused. Wait ${5 - timeSinceLastFailure.inMinutes} more minutes.');
          }
          return false;
        } else {
          _resetErrorTracking();
        }
      }
    }
    return true;
  }

  void _recordFailure() {
    _consecutiveFailures++;
    _lastFailureTime = DateTime.now();
    if (kDebugMode) {
      print('❌ Print failure recorded. Total: $_consecutiveFailures');
    }
  }

  void _recordSuccess() {
    if (_consecutiveFailures > 0) {
      if (kDebugMode) {
        print('✅ Print successful. Resetting error tracking.');
      }
      _resetErrorTracking();
    }
  }

  bool get isConfigured =>
      (_connectionType == PrinterConnectionType.wifi && _printerIp != null) ||
          (_connectionType == PrinterConnectionType.bluetooth && _bluetoothDevice != null);

  PrinterConnectionType get connectionType => _connectionType;

  String get printerInfo {
    if (_connectionType == PrinterConnectionType.wifi) {
      return 'WiFi: $_printerIp:$_printerPort';
    } else {
      return 'Bluetooth: ${_bluetoothDevice?.name ?? "Unknown"}';
    }
  }

  String get printerHealthStatus {
    if (!isConfigured) return 'Not Configured';
    if (_consecutiveFailures == 0) return 'healthy';
    if (_consecutiveFailures < _maxRetries) return 'Warning ($_consecutiveFailures failures)';
    return 'Offline';
  }

  int get consecutiveFailures => _consecutiveFailures;
  bool get autoPrintEnabled => _autoPrintEnabled;
  String? get printerIp => _printerIp;
  BluetoothDevice? get bluetoothDevice => _bluetoothDevice;

  Future<bool> requestBluetoothPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
      return statuses.values.every((status) => status.isGranted);
    } catch (e) {
      if (kDebugMode) print('Error requesting permissions: $e');
      return false;
    }
  }

  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      final isAvailable = await FlutterBluetoothSerial.instance.isAvailable;
      if (isAvailable == null || !isAvailable) {
        throw Exception('Bluetooth tidak tersedia');
      }

      final isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      if (isEnabled == null || !isEnabled) {
        throw Exception('Bluetooth tidak aktif');
      }

      final hasPermission = await requestBluetoothPermissions();
      if (!hasPermission) {
        throw Exception('Izin Bluetooth ditolak');
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
      if (kDebugMode) print('Error getting paired devices: $e');
      rethrow;
    }
  }

  bool _isPrinterDevice(String deviceName) {
    return deviceName.contains('printer') ||
        deviceName.contains('pos') ||
        deviceName.contains('rpp') ||
        deviceName.contains('thermal');
  }

  Future<void> clearConfiguration() async {
    await _initPreferences();
    await _prefs.remove(_printerConfigKey);
    await _prefs.remove(_autoPrintEnabledKey);

    _printerIp = null;
    _bluetoothDevice = null;
    _connectionType = PrinterConnectionType.wifi;
    _autoPrintEnabled = true;
    _printedItemIds.clear();
    _orderItemsHistory.clear();
    _resetErrorTracking();
    _currentDevice = null;

    if (kDebugMode) {
      print('🗑️ Printer configuration cleared');
    }
  }

  // ============================================
  // ✅ HELPER METHOD - SAFE ADDON/TOPPING PARSING
  // ============================================
  String _getSafeAddonText(dynamic addon) {
    try {
      final name = addon['name'] ?? 'Unknown';

      if (addon['options'] != null) {
        if (addon['options'] is Map) {
          final label = addon['options']['label'] ?? addon['options']['name'] ?? '';
          return label.isNotEmpty ? '  + $name - $label' : '  + $name';
        } else if (addon['options'] is String) {
          return '  + $name - ${addon['options']}';
        }
      }

      return '  + $name';
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error parsing addon: $e');
        print('   Addon data: $addon');
      }
      return '  + ${addon['name'] ?? 'Unknown Item'}';
    }
  }

  // ============================================
  // AUTO PRINT WITH ITEM TRACKING
  // ============================================
  Future<bool> autoPrintOrder(Order order, {bool isOpenBill = false}) async {
    final workstation = _workstationType;

    if (kDebugMode) {
      print('╔═══════════════════════════════════════╗');
      print('🖨️ [AUTO PRINT] Starting...');
      print('📝 Order ID: ${order.orderId}');
      print('📍 Device: ${_currentDevice?.deviceName ?? "Not Set"}');
      print('📍 Workstation Type: $workstation');
      print('📍 Workstation Name: $_workstationName');
      print('╚═══════════════════════════════════════╝');
    }

    final printerConfig = {
      'type': _connectionType == PrinterConnectionType.wifi ? 'wifi' : 'bluetooth',
      'info': printerInfo,
      'health_status': printerHealthStatus,
      'consecutive_failures': _consecutiveFailures,
    };

    if (!isConfigured) {
      if (kDebugMode) {
        print('⚠️ Printer not configured');
      }
      return false;
    }

    if (!_shouldAttemptPrint()) {
      if (kDebugMode) {
        print('⏸️ Print paused due to too many failures');
      }
      return false;
    }

    final itemsToPrint = order.items;

    if (itemsToPrint.isEmpty) {
      if (kDebugMode) {
        print('⚠️ No items to print for order ${order.orderId}');
      }
      return false;
    }

    if (kDebugMode) {
      print('🖨️ PRINTING ${itemsToPrint.length} items for order ${order.orderId}:');
      if (isOpenBill) {
        print('   📌 OPEN BILL - Pesanan Tambahan');
      }
      for (final item in itemsToPrint) {
        print('   📝 ${item.name} x${item.qty} (${item.itemId})');
      }
    }

    // ✅ OPTIMIZED: Process stock checks and logging in PARALLEL
    // This reduces delay significantly by not waiting for each item sequentially
    final logIdFutures = itemsToPrint.map((item) async {
      try {
        final stockInfo = await _checkItemStock(item);
        return await PrintTrackingService().logPrintAttempt(
            order.orderId!,
            _convertOrderItemToMap(item),
            workstation,
            printerConfig,
            stockInfo
        );
      } catch (e) {
        if (kDebugMode) print('⚠️ Failed to log print attempt: $e');
        return null;
      }
    }).toList();

    final results = await Future.wait(logIdFutures);
    final List<String> logIds = results.whereType<String>().toList();

    final startTime = DateTime.now();
    try {
      final success = await _printOrderItems(order, itemsToPrint, isOpenBill: isOpenBill, logIds: logIds);

      if (success) {
        for (final item in itemsToPrint) {
          _printedItemIds.add(item.itemId);
        }

        _recordSuccess();

        // PERFORMANCE: Fire-and-forget logging - don't block print completion
        for (final logId in logIds) {
          final duration = DateTime.now().difference(startTime).inMilliseconds;
          PrintTrackingService().logPrintSuccess(logId, duration, wasProblematic: false)
              .catchError((e) {
            if (kDebugMode) print('⚠️ Failed to log success: $e');
          });
        }

        if (kDebugMode) {
          print('✅ PRINT SUCCESS: ${itemsToPrint.length} items printed for ${order.orderId}');
        }
        return true;
      } else {
        _recordFailure();
        // PERFORMANCE: Fire-and-forget logging
        for (final logId in logIds) {
          PrintTrackingService().logPrintFailure(
              logId, 'auto_print_failed', 'Print gagal'
          ).catchError((e) {
            if (kDebugMode) print('⚠️ Failed to log failure: $e');
          });
        }
        if (kDebugMode) {
          print('❌ PRINT FAILED: ${order.orderId}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) print('❌ ERROR IN AUTO PRINT: $e');
      _recordFailure();
      // PERFORMANCE: Fire-and-forget logging
      for (final logId in logIds) {
        PrintTrackingService().logPrintFailure(
            logId, 'auto_print_error', e.toString()
        ).catchError((e2) {
          if (kDebugMode) print('⚠️ Failed to log error: $e2');
        });
      }
      return false;
    }
  }

  Future<bool> _printViaWiFiItems(Order order, List<OrderItem> itemsToPrint, {bool isOpenBill = false}) async {
    if (_printerIp == null) return false;
    NetworkPrinter? printer;

    try {
      printer = NetworkPrinter(PaperSize.mm80, await CapabilityProfile.load());

      if (kDebugMode) print('🔥 [INSTANT] Connecting to WiFi printer...');

      final result = await printer.connect(_printerIp!, port: _printerPort)
          .timeout(const Duration(seconds: 3), onTimeout: () {
        throw Exception('Connection timeout');
      });

      if (result != PosPrintResult.success) {
        throw Exception('Connection failed: $result');
      }

      if (kDebugMode) print('✅ [INSTANT] Connected - printing NOW');

      await _generateReceiptForItems(printer, order, itemsToPrint, isOpenBill: isOpenBill);

      printer.disconnect();

      if (kDebugMode) print('🔥 [INSTANT] ${itemsToPrint.length} items printed in record time');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ WiFi printing error: $e');
      try {
        printer?.disconnect();
      } catch (_) {}
      return false;
    }
  }

  Future<bool> _printViaBluetoothItems(Order order, List<OrderItem> itemsToPrint, {bool isOpenBill = false}) async {
    if (_bluetoothDevice == null) return false;
    BluetoothConnection? connection;

    try {
      if (kDebugMode) print('🔥 [INSTANT] Connecting to Bluetooth...');

      connection = await BluetoothConnection.toAddress(_bluetoothDevice!.address)
          .timeout(const Duration(seconds: 5), onTimeout: () {
        throw Exception('Bluetooth timeout');
      });

      if (!connection.isConnected) {
        throw Exception('Gagal terhubung ke printer');
      }

      if (kDebugMode) print('✅ [INSTANT] Connected - generating bytes');

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      final bytes = await _generateReceiptBytesForItems(generator, order, itemsToPrint, isOpenBill: isOpenBill);

      if (kDebugMode) print('🔥 [INSTANT] Sending ${bytes.length} bytes to printer');
      print('✅ ini nama kasir yang seharusnya muncul: ${order.cashierName} - PVBI');

      connection.output.add(Uint8List.fromList(bytes));

      await connection.output.allSent.timeout(const Duration(seconds: 10));

      await Future.delayed(const Duration(milliseconds: 200));

      await connection.close();

      if (kDebugMode) print('🔥 [INSTANT] ${itemsToPrint.length} items printed via Bluetooth');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Bluetooth printing error: $e');
      try {
        await connection?.close();
      } catch (_) {}
      return false;
    }
  }

  Future<bool> _printOrderItems(Order order, List<OrderItem> itemsToPrint, {bool isOpenBill = false, int attempt = 1, List<String>? logIds}) async {
    try {
      if (kDebugMode) {
        print('🔥 [INSTANT] Print attempt $attempt/$_maxRetries');
      }

      bool success;
      if (_connectionType == PrinterConnectionType.wifi) {
        success = await _printViaWiFiItems(order, itemsToPrint, isOpenBill: isOpenBill);
      } else {
        success = await _printViaBluetoothItems(order, itemsToPrint, isOpenBill: isOpenBill);
      }

      if (!success && attempt < _maxRetries) {
        if (kDebugMode) print('⏳ Quick retry in 1s...');

        await Future.delayed(const Duration(seconds: 1));
        return await _printOrderItems(order, itemsToPrint, isOpenBill: isOpenBill, attempt: attempt + 1, logIds: logIds);
      }

      return success;
    } catch (e) {
      if (kDebugMode) print('❌ Print attempt $attempt failed: $e');

      if (attempt < _maxRetries) {
        await Future.delayed(const Duration(seconds: 1));
        return await _printOrderItems(order, itemsToPrint, isOpenBill: isOpenBill, attempt: attempt + 1, logIds: logIds);
      }

      if (kDebugMode) print('❌ All print attempts failed');
      return false;
    }
  }

  Future<void> prewarmConnection() async {
    if (!isConfigured || !_autoPrintEnabled) return;

    try {
      print('🔥 [PREWARM] Quick printer check...');

      if (_connectionType == PrinterConnectionType.wifi && _printerIp != null) {
        final printer = NetworkPrinter(PaperSize.mm80, await CapabilityProfile.load());

        final result = await printer.connect(_printerIp!, port: _printerPort)
            .timeout(const Duration(seconds: 3));

        if (result == PosPrintResult.success) {
          print('✅ [PREWARM] Printer ready for instant printing');
          printer.disconnect();
          _resetErrorTracking();
        }
      } else if (_connectionType == PrinterConnectionType.bluetooth && _bluetoothDevice != null) {
        print('✅ [PREWARM] Bluetooth ready');
      }
    } catch (e) {
      print('⚠️ [PREWARM] Failed: $e (will retry on actual print)');
    }
  }

  // ============================================
  // ✅ FIXED: _generateReceiptForItems (WiFi) - Kitchen/Bar
  // ============================================
  Future<void> _generateReceiptForItems(NetworkPrinter printer, Order order, List<OrderItem> itemsToPrint, {bool isOpenBill = false}) async {
    if (kDebugMode) {
      print('🖨️ [GENERATE RECEIPT]');
      print('   Device: ${_currentDevice?.deviceName ?? "Not Set"}');
      print('   Workstation: "$_workstationName"');
      print('   Items: ${itemsToPrint.length}');
      print('   Order ID: ${order.orderId}');
      print('   Cashier Name: ${order.cashierName ?? "NULL"}');
    }

    // Header - Workstation Name (Dapur/Bar)
    printer.text(_workstationName.toUpperCase(),
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ));
    printer.feed(1);

    // Bill Header dengan status
    if (isOpenBill) {
      printer.text('PESANAN TAMBAHAN',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            underline: true,
          ));
    }
    printer.feed(1);

    // Order ID (kode struk)
    printer.row([
      PosColumn(text: 'Kode Struk', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: order.orderId ?? 'XXX-XXX-XXXX', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);

    // Tanggal
    printer.row([
      PosColumn(text: 'Tanggal', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: DateFormat('dd/MM/yy HH:mm').format(DateTime.now()), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);

    // Kasir
    printer.row([
      PosColumn(text: 'Kasir', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: order.cashierName ?? 'RFI', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);

    // Pelanggan
    printer.row([
      PosColumn(text: 'Pelanggan', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: order.name, width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);

    // No Meja (jika Dine In)
    if (order.service.toLowerCase() == 'dine-in' || order.service.toLowerCase() == 'dine in') {
      printer.row([
        PosColumn(text: 'No Meja', width: 4, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: order.table, width: 8, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    printer.feed(1);

    // Tipe Order
    printer.text(order.service,
        styles: const PosStyles(align: PosAlign.center, bold: true));

    printer.hr();

    // List Items
    for (var item in itemsToPrint) {
      // Nama item dengan penanda tipe order dan qty (gunakan item.dineType bukan order.service)
      final orderTypeShort = _getOrderTypeShort(item.dineType ?? order.service);
      printer.row([
        PosColumn(text: orderTypeShort, width: 1, styles: const PosStyles(align: PosAlign.left, bold: true, underline: true)),
        PosColumn(text: item.name, width: 8, styles: const PosStyles(align: PosAlign.left, bold: true)),
        PosColumn(text: 'x${item.qty}', width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]);

      // Addons
      if (item.addons != null && item.addons!.isNotEmpty) {
        for (var addon in item.addons!) {
          try {
            final name = addon['name'] ?? 'Unknown';
            String label = '';

            if (addon['options'] != null) {
              if (addon['options'] is Map) {
                label = addon['options']['label'] ?? addon['options']['name'] ?? '';
              } else if (addon['options'] is String) {
                label = addon['options'];
              }
            }

            final addonText = label.isNotEmpty ? '$name: $label' : name;
            printer.row([
              PosColumn(text: ' ', width: 2, styles: const PosStyles(align: PosAlign.left)),
              PosColumn(text: addonText, width: 10, styles: const PosStyles(align: PosAlign.left)),
            ]);
          } catch (e) {
            if (kDebugMode) print('⚠️ Error printing addon: $e');
          }
        }
      }

      // Toppings
      if (item.toppings != null && item.toppings!.isNotEmpty) {
        final toppingsList = item.toppings!.map((t) {
          final name = t['name'] ?? 'Unknown';
          final price = t['price'] ?? 0;
          return price != 0 ? '$name(+$price)' : name;
        }).join(', ');

        printer.row([
          PosColumn(text: ' ', width: 2, styles: const PosStyles(align: PosAlign.left)),
          PosColumn(text: '+$toppingsList', width: 10, styles: const PosStyles(align: PosAlign.left)),
        ]);
      }

      // Notes
      if (item.notes != null && item.notes!.isNotEmpty && item.notes!.trim().isNotEmpty) {
        printer.row([
          PosColumn(text: ' ', width: 2, styles: const PosStyles(align: PosAlign.left)),
          PosColumn(text: 'Catatan: ${item.notes}', width: 10, styles: const PosStyles(align: PosAlign.left)),
        ]);
      }

      printer.feed(1);
    }

    // ✅ Custom Amount Items
    if (order.customAmountItems != null && order.customAmountItems!.isNotEmpty) {
      for (var custom in order.customAmountItems!) {
        printer.row([
          PosColumn(text: 'CA', width: 1, styles: const PosStyles(align: PosAlign.left, bold: true, underline: true)),
          PosColumn(text: custom['name'] ?? 'Custom Amount', width: 8, styles: const PosStyles(align: PosAlign.left)),
          PosColumn(text: '', width: 3, styles: const PosStyles(align: PosAlign.right)),
        ]);
        printer.feed(1);
      }
    }

    printer.hr();

    // Footer - Selesai
    printer.text('Selesai',
        styles: const PosStyles(align: PosAlign.center));

    printer.feed(2);
    printer.cut();
  }

  // Helper method untuk mendapatkan singkatan tipe order
  String _getOrderTypeShort(String orderType) {
    final type = orderType.toLowerCase();
    
    // Dine-In
    if (type.contains('dine') && type.contains('in')) return 'DI';
    
    // Pickup
    if (type.contains('pickup') || type.contains('pick up')) return 'PU';
    
    // Delivery
    if (type.contains('delivery')) return 'DV';
    
    // Take Away
    if (type.contains('take') && type.contains('away')) return 'TA';
    
    // Reservation
    if (type.contains('reservation') || type.contains('reservasi')) return 'RSV';
    
    // Event
    if (type.contains('event')) return 'EV';
    
    // Default
    return 'N/A';
  }

  // ============================================
  // ✅ FIXED: _generateReceiptBytesForItems (Bluetooth) - Kitchen/Bar
  // ============================================
  Future<List<int>> _generateReceiptBytesForItems(Generator generator, Order order, List<OrderItem> itemsToPrint, {bool isOpenBill = false}) async {
    final List<int> bytes = [];

    // Header - Workstation Name (Dapur/Bar)
    bytes.addAll(generator.text(_workstationName.toUpperCase(),
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        )));
    bytes.addAll(generator.feed(1));

    // Bill Header dengan status
    if (isOpenBill) {
      bytes.addAll(generator.text('PESANAN TAMBAHAN',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            underline: true,
          )));
    }
    print('✅ ini nama kasir yang seharusnya muncul: ${order.cashierName} - GRBFI');
    bytes.addAll(generator.feed(1));

    // Order ID (kode struk)
    bytes.addAll(generator.row([
      PosColumn(text: 'Kode Struk', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: order.orderId ?? 'XXX-XXX-XXXX', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]));

    // Tanggal
    bytes.addAll(generator.row([
      PosColumn(text: 'Tanggal', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: DateFormat('dd/MM/yy HH:mm').format(DateTime.now()), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]));

    // Kasir
    bytes.addAll(generator.row([
      PosColumn(text: 'Kasir', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: order.cashierName ?? 'BFI', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]));

    // Pelanggan
    bytes.addAll(generator.row([
      PosColumn(text: 'Pelanggan', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: order.name, width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]));

    // No Meja (jika Dine In)
    if (order.service.toLowerCase() == 'dine-in' || order.service.toLowerCase() == 'dine in') {
      bytes.addAll(generator.row([
        PosColumn(text: 'No Meja', width: 4, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: order.table, width: 8, styles: const PosStyles(align: PosAlign.right)),
      ]));
    }

    bytes.addAll(generator.feed(1));

    // Tipe Order
    bytes.addAll(generator.text(order.service,
        styles: const PosStyles(align: PosAlign.center, bold: true)));

    bytes.addAll(generator.hr());

    // List Items
    for (var item in itemsToPrint) {
      // Nama item dengan penanda tipe order dan qty (gunakan item.dineType bukan order.service)
      final orderTypeShort = _getOrderTypeShort(item.dineType ?? order.service);
      bytes.addAll(generator.row([
        PosColumn(text: orderTypeShort, width: 1, styles: const PosStyles(align: PosAlign.left, bold: true, underline: true)),
        PosColumn(text: item.name, width: 8, styles: const PosStyles(align: PosAlign.left, bold: true)),
        PosColumn(text: 'x${item.qty}', width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]));

      // Addons
      if (item.addons != null && item.addons!.isNotEmpty) {
        for (var addon in item.addons!) {
          final name = addon['name'] ?? 'Unknown';
          String label = '';

          if (addon['options'] != null) {
            if (addon['options'] is Map) {
              label = addon['options']['label'] ?? addon['options']['name'] ?? '';
            } else if (addon['options'] is String) {
              label = addon['options'];
            }
          }

          final addonText = label.isNotEmpty ? '$name: $label' : name;
          bytes.addAll(generator.row([
            PosColumn(text: ' ', width: 2, styles: const PosStyles(align: PosAlign.left)),
            PosColumn(text: addonText, width: 10, styles: const PosStyles(align: PosAlign.left)),
          ]));
        }
      }

      // Toppings
      if (item.toppings != null && item.toppings!.isNotEmpty) {
        final toppingsList = item.toppings!.map((t) {
          final name = t['name'] ?? 'Unknown';
          final price = t['price'] ?? 0;
          return price != 0 ? '$name(+$price)' : name;
        }).join(', ');

        bytes.addAll(generator.row([
          PosColumn(text: ' ', width: 2, styles: const PosStyles(align: PosAlign.left)),
          PosColumn(text: '+$toppingsList', width: 10, styles: const PosStyles(align: PosAlign.left)),
        ]));
      }

      // Notes
      if (item.notes != null && item.notes!.isNotEmpty && item.notes!.trim().isNotEmpty) {
        bytes.addAll(generator.row([
          PosColumn(text: ' ', width: 2, styles: const PosStyles(align: PosAlign.left)),
          PosColumn(text: 'Catatan: ${item.notes}', width: 10, styles: const PosStyles(align: PosAlign.left)),
        ]));
      }

      bytes.addAll(generator.feed(1));
    }

    // ✅ Custom Amount Items
    if (order.customAmountItems != null && order.customAmountItems!.isNotEmpty) {
      for (var custom in order.customAmountItems!) {
        bytes.addAll(generator.row([
          PosColumn(text: 'CA', width: 1, styles: const PosStyles(align: PosAlign.left, bold: true, underline: true)),
          PosColumn(text: custom['name'] ?? 'Custom Amount', width: 8, styles: const PosStyles(align: PosAlign.left)),
          PosColumn(text: '', width: 3, styles: const PosStyles(align: PosAlign.right)),
        ]));
        bytes.addAll(generator.feed(1));
      }
    }

    bytes.addAll(generator.hr());

    // Footer - Selesai
    bytes.addAll(generator.text('Selesai',
        styles: const PosStyles(align: PosAlign.center)));

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }

  // ============================================
  // MANUAL PRINT (ALL ITEMS)
  // ============================================
  Future<bool> manualPrint(Order order) async {
    final workstation = _workstationType;
    final printerConfig = {
      'type': _connectionType == PrinterConnectionType.wifi ? 'wifi' : 'bluetooth',
      'info': printerInfo,
    };

    // ✅ OPTIMIZED: Process stock checks and logging in PARALLEL
    final logIdFutures = order.items.map((item) async {
      try {
        final stockInfo = await _checkItemStock(item);
        return await PrintTrackingService().logPrintAttempt(
            order.orderId!,
            _convertOrderItemToMap(item),
            workstation,
            printerConfig,
            stockInfo
        );
      } catch (e) {
        if (kDebugMode) print('⚠️ Failed to log print attempt: $e');
        return null;
      }
    }).toList();

    final results = await Future.wait(logIdFutures);
    final List<String> logIds = results.whereType<String>().toList();

    final startTime = DateTime.now();

    try {
      final success = await printOrder(order);

      if (success) {
        try {
          final duration = DateTime.now().difference(startTime).inMilliseconds;
          for (final logId in logIds) {
            await PrintTrackingService().logPrintSuccess(logId, duration, wasProblematic: false);
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ Failed to log success: $e');
        }
      } else {
        try {
          for (final logId in logIds) {
            await PrintTrackingService().logPrintFailure(
                logId, 'printer_not_configured', 'Manual print gagal'
            );
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ Failed to log failure: $e');
        }
      }

      return success;
    } catch (e) {
      try {
        for (final logId in logIds) {
          await PrintTrackingService().logPrintFailure(logId, 'unknown_error', e.toString());
        }
      } catch (e2) {
        if (kDebugMode) print('⚠️ Failed to log error: $e2');
      }
      rethrow;
    }
  }

  /// @deprecated This function prints the ENTIRE order.
  /// Use autoPrintOrder() for auto-printing new items only.
  /// Kept for manual print from UI.
  @Deprecated('Use autoPrintOrder() for auto-printing')
  Future<bool> printOrder(Order order) async {
    if (!isConfigured) {
      if (kDebugMode) print('Printer tidak dikonfigurasi');
      return false;
    }

    try {
      print('[DEPRECATED] Printing order ${order.orderId}');
      if (_connectionType == PrinterConnectionType.wifi) {
        return await _printViaWiFi(order);
      } else {
        return await _printViaBluetooth(order);
      }
    } catch (e) {
      if (kDebugMode) print('Error printing: $e');
      return false;
    }
  }

  /// @deprecated This function prints entire order, not items.
  /// Use _printViaWiFiItems() for new items printing.
  @Deprecated('Use _printViaWiFiItems() instead')
  Future<bool> _printViaWiFi(Order order) async {
    if (_printerIp == null) return false;
    NetworkPrinter? printer;

    try {
      printer = NetworkPrinter(PaperSize.mm80, await CapabilityProfile.load());
      if (kDebugMode) print('🔌 Connecting to WiFi printer...');

      final result = await printer.connect(_printerIp!, port: _printerPort)
          .timeout(_connectionTimeout, onTimeout: () {
        throw Exception('Connection timeout');
      });

      if (result != PosPrintResult.success) {
        throw Exception('Connection failed: $result');
      }

      if (kDebugMode) print('✅ Connected to WiFi printer');

      await _generateReceipt(printer, order);
      await Future.delayed(const Duration(milliseconds: 500));
      printer.disconnect();

      if (kDebugMode) print('✅ Order ${order.orderId} printed via WiFi');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ WiFi printing error: $e');
      try {
        printer?.disconnect();
      } catch (_) {}
      return false;
    }
  }

  /// @deprecated This function prints entire order, not items.
  /// Use _printViaBluetoothItems() for new items printing.
  @Deprecated('Use _printViaBluetoothItems() instead')
  Future<bool> _printViaBluetooth(Order order) async {
    if (_bluetoothDevice == null) return false;
    BluetoothConnection? connection;

    try {
      if (kDebugMode) print('🔌 Connecting to Bluetooth printer...');

      connection = await BluetoothConnection.toAddress(_bluetoothDevice!.address)
          .timeout(_connectionTimeout, onTimeout: () {
        throw Exception('Bluetooth connection timeout');
      });

      if (!connection.isConnected) {
        throw Exception('Gagal terhubung ke printer');
      }

      if (kDebugMode) print('✅ Connected to Bluetooth printer');

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      final bytes = await _generateReceiptBytes(generator, order);

      connection.output.add(Uint8List.fromList(bytes));
      await connection.output.allSent.timeout(const Duration(seconds: 15));
      await Future.delayed(const Duration(milliseconds: 800));
      await connection.close();

      if (kDebugMode) print('✅ Order ${order.orderId} printed via Bluetooth');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Bluetooth printing error: $e');
      try {
        await connection?.close();
      } catch (_) {}
      return false;
    }
  }

  // ============================================
  // @deprecated - Use _generateReceiptForItems instead
  // ============================================
  /// @deprecated This generates receipt for ENTIRE order.
  /// Use _generateReceiptForItems() for printing specific items.
  @Deprecated('Use _generateReceiptForItems() instead')
  Future<void> _generateReceipt(NetworkPrinter printer, Order order) async {
    if (kDebugMode) print('🖨️ [DEPRECATED] Generating full receipt');

    // Header - Workstation Name
    printer.text(_workstationName.toUpperCase(),
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ));
    printer.feed(1);

    // Order ID (kode struk)
    printer.row([
      PosColumn(text: 'Kode Struk', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: order.orderId ?? 'XXX-XXX-XXXX', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);

    // Tanggal
    printer.row([
      PosColumn(text: 'Tanggal', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: DateFormat('dd/MM/yy HH:mm').format(DateTime.now()), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);

    // Kasir
    printer.row([
      PosColumn(text: 'Kasir', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: order.cashierName ?? 'GR', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);

    // Pelanggan
    printer.row([
      PosColumn(text: 'Pelanggan', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: order.name, width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);

    // No Meja (jika Dine In)
    if (order.service.toLowerCase() == 'dine-in' || order.service.toLowerCase() == 'dine in') {
      printer.row([
        PosColumn(text: 'No Meja', width: 4, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: order.table, width: 8, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    // Info reservasi jika ada
    if (order.service.contains('Reservation') && order.reservationDate != null) {
      printer.row([
        PosColumn(text: 'Tgl Reservasi', width: 4, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: order.reservationDate!, width: 8, styles: const PosStyles(align: PosAlign.right)),
      ]);

      printer.row([
        PosColumn(text: 'Jam', width: 4, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: order.reservationTime ?? '-', width: 8, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    printer.feed(1);

    // Tipe Order
    printer.text(order.service,
        styles: const PosStyles(align: PosAlign.center, bold: true));

    printer.hr();

    // List Items
    for (var item in order.items) {
      // Nama item dengan penanda tipe order dan qty (gunakan item.dineType bukan order.service)
      final orderTypeShort = _getOrderTypeShort(item.dineType ?? order.service);
      printer.row([
        PosColumn(text: orderTypeShort, width: 1, styles: const PosStyles(align: PosAlign.left, bold: true, underline: true)),
        PosColumn(text: item.name, width: 8, styles: const PosStyles(align: PosAlign.left, bold: true)),
        PosColumn(text: 'x${item.qty}', width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]);

      // Addons
      if (item.addons != null && item.addons!.isNotEmpty) {
        for (var addon in item.addons!) {
          try {
            final name = addon['name'] ?? 'Unknown';
            String label = '';

            if (addon['options'] != null) {
              if (addon['options'] is Map) {
                label = addon['options']['label'] ?? addon['options']['name'] ?? '';
              } else if (addon['options'] is String) {
                label = addon['options'];
              }
            }

            final addonText = label.isNotEmpty ? '$name: $label' : name;
            printer.row([
              PosColumn(text: ' ', width: 2, styles: const PosStyles(align: PosAlign.left)),
              PosColumn(text: addonText, width: 10, styles: const PosStyles(align: PosAlign.left)),
            ]);
          } catch (e) {
            if (kDebugMode) print('⚠️ Error printing addon: $e');
          }
        }
      }

      // Toppings
      if (item.toppings != null && item.toppings!.isNotEmpty) {
        final toppingsList = item.toppings!.map((t) {
          final name = t['name'] ?? 'Unknown';
          final price = t['price'] ?? 0;
          return price != 0 ? '$name(+$price)' : name;
        }).join(', ');

        printer.row([
          PosColumn(text: ' ', width: 2, styles: const PosStyles(align: PosAlign.left)),
          PosColumn(text: '+$toppingsList', width: 10, styles: const PosStyles(align: PosAlign.left)),
        ]);
      }

      // Notes
      if (item.notes != null && item.notes!.isNotEmpty && item.notes!.trim().isNotEmpty) {
        printer.row([
          PosColumn(text: ' ', width: 2, styles: const PosStyles(align: PosAlign.left)),
          PosColumn(text: 'Catatan: ${item.notes}', width: 10, styles: const PosStyles(align: PosAlign.left)),
        ]);
      }

      printer.feed(1);
    }

    printer.hr();

    // Footer - Selesai
    printer.text('Selesai',
        styles: const PosStyles(align: PosAlign.center));

    printer.feed(2);
    printer.cut();
  }

  // ============================================
  // @deprecated - Use _generateReceiptBytesForItems instead
  // ============================================
  /// @deprecated This generates receipt bytes for ENTIRE order.
  /// Use _generateReceiptBytesForItems() for printing specific items.
  @Deprecated('Use _generateReceiptBytesForItems() instead')
  Future<List<int>> _generateReceiptBytes(Generator generator, Order order) async {
    final List<int> bytes = [];

    // Header - Workstation Name
    bytes.addAll(generator.text(_workstationName.toUpperCase(),
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        )));
    bytes.addAll(generator.feed(1));

    // Order ID (kode struk)
    bytes.addAll(generator.row([
      PosColumn(text: 'Kode Struk', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: order.orderId ?? 'XXX-XXX-XXXX', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]));

    // Tanggal
    bytes.addAll(generator.row([
      PosColumn(text: 'Tanggal', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: DateFormat('dd/MM/yy HH:mm').format(DateTime.now()), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]));

    // Kasir
    bytes.addAll(generator.row([
      PosColumn(text: 'Kasir', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: order.cashierName ?? 'GRB', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]));

    // Pelanggan
    bytes.addAll(generator.row([
      PosColumn(text: 'Pelanggan', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: order.name, width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]));

    // No Meja (jika Dine In)
    if (order.service.toLowerCase() == 'dine-in' || order.service.toLowerCase() == 'dine in') {
      bytes.addAll(generator.row([
        PosColumn(text: 'No Meja', width: 4, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: order.table, width: 8, styles: const PosStyles(align: PosAlign.right)),
      ]));
    }

    // Info reservasi jika ada
    if (order.service.contains('Reservation') && order.reservationDate != null) {
      bytes.addAll(generator.row([
        PosColumn(text: 'Tgl Reservasi', width: 4, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: order.reservationDate!, width: 8, styles: const PosStyles(align: PosAlign.right)),
      ]));

      bytes.addAll(generator.row([
        PosColumn(text: 'Jam', width: 4, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: order.reservationTime ?? '-', width: 8, styles: const PosStyles(align: PosAlign.right)),
      ]));
    }

    bytes.addAll(generator.feed(1));

    // Tipe Order
    bytes.addAll(generator.text(order.service,
        styles: const PosStyles(align: PosAlign.center, bold: true)));

    bytes.addAll(generator.hr());

    // List Items
    for (var item in order.items) {
      // Nama item dengan penanda tipe order dan qty (gunakan item.dineType bukan order.service)
      final orderTypeShort = _getOrderTypeShort(item.dineType ?? order.service);
      bytes.addAll(generator.row([
        PosColumn(text: orderTypeShort, width: 1, styles: const PosStyles(align: PosAlign.left, bold: true, underline: true)),
        PosColumn(text: item.name, width: 8, styles: const PosStyles(align: PosAlign.left, bold: true)),
        PosColumn(text: 'x${item.qty}', width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]));

      // Addons
      if (item.addons != null && item.addons!.isNotEmpty) {
        for (var addon in item.addons!) {
          final name = addon['name'] ?? 'Unknown';
          String label = '';

          if (addon['options'] != null) {
            if (addon['options'] is Map) {
              label = addon['options']['label'] ?? addon['options']['name'] ?? '';
            } else if (addon['options'] is String) {
              label = addon['options'];
            }
          }

          final addonText = label.isNotEmpty ? '$name: $label' : name;
          bytes.addAll(generator.row([
            PosColumn(text: ' ', width: 2, styles: const PosStyles(align: PosAlign.left)),
            PosColumn(text: addonText, width: 10, styles: const PosStyles(align: PosAlign.left)),
          ]));
        }
      }

      // Toppings
      if (item.toppings != null && item.toppings!.isNotEmpty) {
        final toppingsList = item.toppings!.map((t) {
          final name = t['name'] ?? 'Unknown';
          final price = t['price'] ?? 0;
          return price != 0 ? '$name(+$price)' : name;
        }).join(', ');

        bytes.addAll(generator.row([
          PosColumn(text: ' ', width: 2, styles: const PosStyles(align: PosAlign.left)),
          PosColumn(text: '+$toppingsList', width: 10, styles: const PosStyles(align: PosAlign.left)),
        ]));
      }

      // Notes
      if (item.notes != null && item.notes!.isNotEmpty && item.notes!.trim().isNotEmpty) {
        bytes.addAll(generator.row([
          PosColumn(text: ' ', width: 2, styles: const PosStyles(align: PosAlign.left)),
          PosColumn(text: 'Catatan: ${item.notes}', width: 10, styles: const PosStyles(align: PosAlign.left)),
        ]));
      }

      bytes.addAll(generator.feed(1));
    }

    bytes.addAll(generator.hr());

    // Footer - Selesai
    bytes.addAll(generator.text('Selesai',
        styles: const PosStyles(align: PosAlign.center)));

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }

  // ============================================
  // TEST CONNECTION
  // ============================================
  Future<bool> testConnection() async {
    if (!isConfigured) return false;

    try {
      if (_connectionType == PrinterConnectionType.wifi) {
        return await _testWiFiConnection();
      } else {
        return await _testBluetoothConnection();
      }
    } catch (e) {
      if (kDebugMode) print('Test connection error: $e');
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
            styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
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
      if (kDebugMode) print('WiFi test failed: $e');
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
      if (kDebugMode) print('🔵 Starting Bluetooth test connection...');
      
      connection = await BluetoothConnection.toAddress(_bluetoothDevice!.address)
          .timeout(_connectionTimeout);

      if (!connection.isConnected) {
        if (kDebugMode) print('❌ Bluetooth not connected');
        return false;
      }

      if (kDebugMode) print('✅ Bluetooth connected, generating test receipt...');

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

      if (kDebugMode) print('📤 Sending ${bytes.length} bytes to printer...');
      connection.output.add(Uint8List.fromList(bytes));
      
      // Add timeout to allSent to prevent hanging
      try {
        await connection.output.allSent.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            if (kDebugMode) print('⚠️ allSent timeout, but data likely sent');
          },
        );
        if (kDebugMode) print('✅ All data sent successfully');
      } catch (e) {
        if (kDebugMode) print('⚠️ allSent error (but continuing): $e');
        // Continue anyway, data is likely sent
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (kDebugMode) print('🔌 Closing Bluetooth connection...');
      try {
        // Just call close without awaiting indefinitely, but catch any errors
        connection.close().catchError((e) {
          if (kDebugMode) print('⚠️ Error inside close (ignoring): $e');
        });
        
        // Wait a short moment to allow close frame to be sent, but don't block return
        await Future.delayed(const Duration(milliseconds: 500));
        
      } catch (e) {
        if (kDebugMode) print('⚠️ Error triggering close (ignoring): $e');
      }
      
      if (kDebugMode) print('✅ Bluetooth test completed successfully');

      _recordSuccess();
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Bluetooth test failed: $e');
      try {
        await connection?.close();
      } catch (_) {}
      return false;
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================
  Map<String, dynamic> _convertOrderItemToMap(OrderItem item) {
    return {
      'id': item.itemId.toString(),
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

  Future<Map<String, dynamic>> _checkItemStock(OrderItem item) async {
    try {
      final menuItemId = item.menuItemId;
      if (menuItemId == null) {
        return _getFallbackStockInfo(item);
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/menu-items/$menuItemId/stock-status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final stockData = json.decode(response.body);
        final data = stockData['data'] ?? {};

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
      } else {
        return _getFallbackStockInfo(item);
      }
    } catch (e) {
      return _getFallbackStockInfo(item);
    }
  }

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

  // ============================================
  // PUBLIC HELPER METHODS
  // ============================================
  void clearPrintHistory() {
    _printedItemIds.clear();
    _orderItemsHistory.clear();
    if (kDebugMode) {
      print('🗑️ Print history cleared - all items can be printed again');
    }
  }

  int get printedCount => _printedItemIds.length;

  bool isAlreadyPrinted(String? orderId) {
    return _orderItemsHistory.containsKey(orderId);
  }

  bool isItemAlreadyPrinted(String itemId) {
    return _printedItemIds.contains(itemId);
  }

  int getPrintedItemsCount(String orderId) {
    return _orderItemsHistory[orderId]?.length ?? 0;
  }

  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
}