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

  // ✅ Track printed items per itemId (bukan orderId)
  final Set<String> _printedItemIds = <String>{};

  // ✅ Track order yang sudah pernah diproses (untuk deteksi open bill)
  final Map<String, Set<String>> _orderItemsHistory = {};

  int _consecutiveFailures = 0;
  DateTime? _lastFailureTime;
  static const int _maxRetries = 3;
  // static const Duration _retryDelay = Duration(seconds: 2);
  static const Duration _connectionTimeout = Duration(seconds: 10);

  String? _barType;
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

  void setBarType(String? barType) {
    _barType = barType;
    if (kDebugMode) {
      print('🖨️ [PRINT SERVICE] Bar Type set to: ${barType ?? "null (KITCHEN)"}');
      print('🖨️ [PRINT SERVICE] Header: "$_workstationName"');
    }
  }

  String get _workstationName {
    if (kDebugMode) {
      print('🖨️ [GET WORKSTATION] _barType = $_barType');
    }

    switch (_barType) {
      case 'kitchen':
        return 'KITCHEN';
      case 'depan':
        return 'BAR DEPAN';
      case 'belakang':
        return 'BAR BELAKANG';
      case null:
        return 'KITCHEN';
      default:
        return 'BAR';
    }
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

    if (kDebugMode) {
      print('🗑️ Printer configuration cleared');
    }
  }

// ============================================
// AUTO PRINT WITH ITEM TRACKING
// ============================================
  Future<bool> autoPrintOrder(Order order, {bool isOpenBill = false}) async {
    final workstation = _workstationName.toLowerCase().replaceAll(' ', '_');

    if (kDebugMode) {
      print('╔═══════════════════════════════════════╗');
      print('🖨️ [AUTO PRINT] Starting...');
      print('📝 Order ID: ${order.orderId}');
      print('📍 _barType: $_barType');
      print('📍 Workstation Name: $_workstationName');
      print('📍 Workstation Key: $workstation');
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

    // ✅ SIMPLIFIED: Dashboard sudah filter items yang perlu diprint
    // Jadi kita tinggal print semua items yang ada di order ini
    final itemsToPrint = order.items;

    if (itemsToPrint.isEmpty) {
      if (kDebugMode) {
        print('⚠️ No items to print for order ${order.orderId}');
      }
      return false;
    }

    if (kDebugMode) {
      print('🖨️ PRINTING ${itemsToPrint.length} items for order ${order.orderId}:');
      if (isOpenBill) {  // ✅ TAMBAH LOG
        print('   📌 OPEN BILL - Pesanan Tambahan');
      }
      for (final item in itemsToPrint) {
        print('   📝 ${item.name} x${item.qty} (${item.itemId})');
      }
    }

    // Log print attempt
    final List<String> logIds = [];
    for (final item in itemsToPrint) {
      final stockInfo = await _checkItemStock(item);
      final logId = await PrintTrackingService().logPrintAttempt(
          order.orderId!,
          _convertOrderItemToMap(item),
          workstation,
          printerConfig,
          stockInfo
      );
      if (logId != null) logIds.add(logId);
    }

    final startTime = DateTime.now();
    try {
      // ✅ Pass isOpenBill flag ke method print
      final success = await _printOrderItems(order, itemsToPrint, isOpenBill: isOpenBill, logIds: logIds);

      if (success) {
        // ✅ Mark items sebagai sudah diprint di internal tracking
        for (final item in itemsToPrint) {
          _printedItemIds.add(item.itemId);
        }

        _recordSuccess();

        final duration = DateTime.now().difference(startTime).inMilliseconds;
        for (final logId in logIds) {
          await PrintTrackingService().logPrintSuccess(logId, duration, wasProblematic: false);
        }

        if (kDebugMode) {
          print('✅ PRINT SUCCESS: ${itemsToPrint.length} items printed for ${order.orderId}');
        }
        return true;
      } else {
        _recordFailure();
        for (final logId in logIds) {
          await PrintTrackingService().logPrintFailure(
              logId, 'auto_print_failed', 'Print gagal'
          );
        }
        if (kDebugMode) {
          print('❌ PRINT FAILED: ${order.orderId}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) print('❌ ERROR IN AUTO PRINT: $e');
      _recordFailure();
      for (final logId in logIds) {
        await PrintTrackingService().logPrintFailure(
            logId, 'auto_print_error', e.toString()
        );
      }
      return false;
    }
  }

// 🔥 INSTANT PRINT: Zero delay, maximum speed
  Future<bool> _printViaWiFiItems(Order order, List<OrderItem> itemsToPrint, {bool isOpenBill = false}) async {
    if (_printerIp == null) return false;
    NetworkPrinter? printer;

    try {
      printer = NetworkPrinter(PaperSize.mm80, await CapabilityProfile.load());

      if (kDebugMode) print('🔥 [INSTANT] Connecting to WiFi printer...');

      // ✅ Reduced timeout: 3 seconds max
      final result = await printer.connect(_printerIp!, port: _printerPort)
          .timeout(const Duration(seconds: 3), onTimeout: () {
        throw Exception('Connection timeout');
      });

      if (result != PosPrintResult.success) {
        throw Exception('Connection failed: $result');
      }

      if (kDebugMode) print('✅ [INSTANT] Connected - printing NOW');

      // ✅ Generate receipt synchronously (no await)
      await _generateReceiptForItems(printer, order, itemsToPrint, isOpenBill: isOpenBill);

      // ❌ REMOVED: Unnecessary delay
      // await Future.delayed(const Duration(milliseconds: 500));

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

      // ✅ Reduced timeout: 5 seconds max
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

      // ✅ Send data immediately
      connection.output.add(Uint8List.fromList(bytes));

      // ✅ Reduced wait time: 10 seconds max
      await connection.output.allSent.timeout(const Duration(seconds: 10));

      // ✅ Reduced post-print delay: 200ms instead of 800ms
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

// ✅ OPTIMIZED: Faster retry strategy
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

        // ✅ Reduced retry delay: 1 second instead of 2
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

// ✅ OPTIMIZED: Prewarm with faster timeout
  Future<void> prewarmConnection() async {
    if (!isConfigured || !_autoPrintEnabled) return;

    try {
      print('🔥 [PREWARM] Quick printer check...');

      if (_connectionType == PrinterConnectionType.wifi && _printerIp != null) {
        final printer = NetworkPrinter(PaperSize.mm80, await CapabilityProfile.load());

        // ✅ Reduced prewarm timeout: 3 seconds
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
  // GENERATE RECEIPT FOR SPECIFIC ITEMS
  // ============================================
  Future<void> _generateReceiptForItems(NetworkPrinter printer, Order order, List<OrderItem> itemsToPrint, {bool isOpenBill = false}) async {
    if (kDebugMode) {
      print('🖨️ [GENERATE RECEIPT]');
      print('   _barType: ${_barType ?? "null"}');
      print('   Workstation: "$_workstationName"');
      print('   Items: ${itemsToPrint.length}');
    }

    printer.text('BARAJA AMPHI',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ));
    printer.text(' ');

    printer.text('ORDER $_workstationName',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ));

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

    printer.row([
      PosColumn(text: 'Waktu:', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(text: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), width: 8),
    ]);
    printer.text(' ');

    printer.hr(ch: '-');
    printer.text(' ');

    if (isOpenBill) {
      printer.text('** PESANAN TAMBAHAN **',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          ));
      printer.hr(ch: '-');
    }



    if (isOpenBill) {
      printer.text('ITEM TAMBAHAN:', styles: const PosStyles(bold: true, underline: true));
    } else {
      printer.text('PESANAN:', styles: const PosStyles(bold: true, underline: true));
    }


    // ✅ PRINT ONLY SPECIFIC ITEMS
    for (var item in itemsToPrint) {
      final itemNameWithService = '${item.name} (${order.service}) x${item.qty}';
      printer.text(itemNameWithService, styles: const PosStyles(bold: true));

      if (item.addons != null && item.addons!.isNotEmpty) {
        for (var addon in item.addons!) {
          printer.text('  + ${addon['name']} - ${addon['options']['label']}',
              styles: const PosStyles(fontType: PosFontType.fontB));
        }
      }

      if (item.toppings != null && item.toppings!.isNotEmpty) {
        for (var topping in item.toppings!) {
          printer.text('  + ${topping['name']} - ${topping['options']['label']}',
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

    final totalItems = itemsToPrint.fold(0, (sum, item) => sum + item.qty);
    printer.row([
      PosColumn(text: 'TOTAL ITEM:', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: '$totalItems', width: 6,
          styles: const PosStyles(
            bold: true,
            align: PosAlign.right,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          )),
    ]);

    printer.text(' ');
    printer.hr(ch: '-');
    printer.text(' ');
    printer.text(' ');
    printer.cut();
  }

  Future<List<int>> _generateReceiptBytesForItems(Generator generator, Order order, List<OrderItem> itemsToPrint, {bool isOpenBill = false}) async {
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
    if (isOpenBill) {
      bytes.addAll(generator.text('** PESANAN TAMBAHAN **',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          )));
      bytes.addAll(generator.hr());
    }


    if (isOpenBill) {
      bytes.addAll(generator.text('ITEM TAMBAHAN:',
          styles: const PosStyles(bold: true, underline: true)));
    } else {
      bytes.addAll(generator.text('PESANAN:',
          styles: const PosStyles(bold: true, underline: true)));
    }
    bytes.addAll(generator.emptyLines(1));

    // ✅ PRINT ONLY SPECIFIC ITEMS
    for (var item in itemsToPrint) {
      final itemNameWithService = '${item.name} (${order.service}) x${item.qty}';
      bytes.addAll(generator.text(itemNameWithService, styles: const PosStyles(bold: true)));

      if (item.addons != null && item.addons!.isNotEmpty) {
        for (var addon in item.addons!) {
          bytes.addAll(generator.text('  + ${addon['name']} - ${addon['options']['label']}'));
        }
      }

      if (item.toppings != null && item.toppings!.isNotEmpty) {
        for (var topping in item.toppings!) {
          bytes.addAll(generator.text('  + ${topping['name']} - ${topping['options']['label']}'));
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

    final totalItems = itemsToPrint.fold(0, (sum, item) => sum + item.qty);
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

  // ============================================
  // MANUAL PRINT (ALL ITEMS)
  // ============================================
  Future<bool> manualPrint(Order order) async {
    final workstation = _workstationName.toLowerCase().replaceAll(' ', '_');
    final printerConfig = {
      'type': _connectionType == PrinterConnectionType.wifi ? 'wifi' : 'bluetooth',
      'info': printerInfo,
    };

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
      if (logId != null) logIds.add(logId);
    }

    final startTime = DateTime.now();

    try {
      final success = await printOrder(order);

      if (success) {
        final duration = DateTime.now().difference(startTime).inMilliseconds;
        for (final logId in logIds) {
          await PrintTrackingService().logPrintSuccess(logId, duration, wasProblematic: false);
        }
      } else {
        for (final logId in logIds) {
          await PrintTrackingService().logPrintFailure(
              logId, 'printer_not_configured', 'Manual print gagal'
          );
        }
      }

      return success;
    } catch (e) {
      for (final logId in logIds) {
        await PrintTrackingService().logPrintFailure(logId, 'unknown_error', e.toString());
      }
      rethrow;
    }
  }

  Future<bool> printOrder(Order order) async {
    if (!isConfigured) {
      if (kDebugMode) print('Printer tidak dikonfigurasi');
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
      if (kDebugMode) print('Error printing: $e');
      return false;
    }
  }

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

  Future<void> _generateReceipt(NetworkPrinter printer, Order order) async {
    if (kDebugMode) print('🖨️ Generating full receipt');

    printer.text('BARAJA AMPHI',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ));
    printer.text(' ');

    printer.text('ORDER $_workstationName',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ));

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
      PosColumn(text: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), width: 8),
    ]);
    printer.text(' ');

    printer.hr(ch: '-');
    printer.text(' ');

    printer.text('PESANAN:', styles: const PosStyles(bold: true, underline: true));
    printer.text(' ');

    for (var item in order.items) {
      final itemNameWithService = '${item.name} (${order.service}) x${item.qty}';
      printer.text(itemNameWithService, styles: const PosStyles(bold: true));

      if (item.addons != null && item.addons!.isNotEmpty) {
        for (var addon in item.addons!) {
          printer.text('  + ${addon['name']} - ${addon['options']['label']}',
              styles: const PosStyles(fontType: PosFontType.fontB));
        }
      }

      if (item.toppings != null && item.toppings!.isNotEmpty) {
        for (var topping in item.toppings!) {
          printer.text('  + ${topping['name']} - ${topping['options']['label']}',
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
      PosColumn(text: '$totalItems', width: 6,
          styles: const PosStyles(
            bold: true,
            align: PosAlign.right,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          )),
    ]);

    printer.text(' ');
    printer.hr(ch: '-');
    printer.text(' ');
    printer.text(' ');
    printer.cut();
  }

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
          bytes.addAll(generator.text('  + ${addon['name']} - ${addon['options']['label']}'));
        }
      }

      if (item.toppings != null && item.toppings!.isNotEmpty) {
        for (var topping in item.toppings!) {
          bytes.addAll(generator.text('  + ${topping['name']} - ${topping['options']['label']}'));
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
      connection = await BluetoothConnection.toAddress(_bluetoothDevice!.address)
          .timeout(_connectionTimeout);

      if (!connection.isConnected) return false;

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
      if (kDebugMode) print('Bluetooth test failed: $e');
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

  // bool _isItemForThisWorkstation(OrderItem item, String currentWorkstation) {
  //   if (currentWorkstation == 'kitchen') {
  //     return !_isBeverageItem(item);
  //   } else if (currentWorkstation.contains('bar')) {
  //     return _isBeverageItem(item);
  //   }
  //   return true;
  // }

  // bool _isBeverageItem(OrderItem item) {
  //   final beverageKeywords = [
  //     'minuman', 'drink', 'beverage', 'juice', 'soda', 'cola', 'tea', 'coffee',
  //     'kopi', 'teh', 'jus', 'susu', 'air', 'water', 'bir', 'beer', 'wine', 'cocktail'
  //   ];
  //   final itemName = item.name.toLowerCase();
  //   return beverageKeywords.any((keyword) => itemName.contains(keyword));
  // }

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