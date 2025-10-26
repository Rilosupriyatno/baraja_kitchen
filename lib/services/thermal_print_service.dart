// services/thermal_print_service.dart
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/order.dart';
import 'package:intl/intl.dart';

enum PrinterConnectionType { wifi, bluetooth }

class ThermalPrintService {
  static final ThermalPrintService _instance = ThermalPrintService._internal();
  factory ThermalPrintService() => _instance;
  ThermalPrintService._internal();

  // Konfigurasi printer WiFi
  String? _printerIp;
  int _printerPort = 9100;

  // Konfigurasi printer Bluetooth
  BluetoothDevice? _bluetoothDevice;
  PrinterConnectionType _connectionType = PrinterConnectionType.wifi;

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
    if (kDebugMode) {
      print('Printer WiFi dikonfigurasi: $ip:$port');
    }
  }

  /// Set konfigurasi printer Bluetooth
  void configureBluetoothPrinter(BluetoothDevice device) {
    _bluetoothDevice = device;
    _connectionType = PrinterConnectionType.bluetooth;
    _resetErrorTracking();
    if (kDebugMode) {
      print('Printer Bluetooth dikonfigurasi: ${device.name}');
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
    if (_consecutiveFailures == 0) return 'Healthy';
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

  /// Auto print with retry mechanism
  Future<bool> autoPrintOrder(Order order) async {
    if (_printedOrders.contains(order.orderId)) {
      if (kDebugMode) {
        print('Order ${order.orderId} sudah pernah diprint, skip');
      }
      return false;
    }

    if (!isConfigured) {
      if (kDebugMode) {
        print('Printer belum dikonfigurasi');
      }
      return false;
    }

    if (!_shouldAttemptPrint()) {
      if (kDebugMode) {
        print('⏸️ Skipping print attempt due to consecutive failures');
      }
      return false;
    }

    try {
      print('🖨️ Auto printing order ${order.orderId}');
      final success = await _printOrderWithRetry(order);

      if (success) {
        _printedOrders.add(order.orderId ?? '');
        _recordSuccess();
        print('✅ Order ${order.orderId} berhasil diprint secara otomatis');
      } else {
        _recordFailure();
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error auto print: $e');
      }
      _recordFailure();
      return false;
    }
  }

  /// Print with retry mechanism
  Future<bool> _printOrderWithRetry(Order order, {int attempt = 1}) async {
    try {
      if (kDebugMode) {
        print('🔄 Print attempt $attempt for order ${order.orderId}');
      }

      if (_connectionType == PrinterConnectionType.wifi) {
        return await _printViaWiFi(order);
      } else {
        return await _printViaBluetooth(order);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Print attempt $attempt failed: $e');
      }

      if (attempt < _maxRetries) {
        if (kDebugMode) {
          print('⏳ Waiting ${_retryDelay.inSeconds}s before retry...');
        }
        await Future.delayed(_retryDelay);
        return await _printOrderWithRetry(order, attempt: attempt + 1);
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

  /// Manual print (untuk reprint)
  Future<bool> manualPrint(Order order) async {
    _printedOrders.remove(order.orderId);
    return await printOrder(order);
  }

  /// Test koneksi printer dengan retry
  Future<bool> testConnection() async {
    if (!isConfigured) return false;

    if (_connectionType == PrinterConnectionType.wifi) {
      return await _testWiFiConnection();
    } else {
      return await _testBluetoothConnection();
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
  String? get printerIp => _printerIp;
  BluetoothDevice? get bluetoothDevice => _bluetoothDevice;

  bool isAlreadyPrinted(String? orderId) {
    return orderId != null && _printedOrders.contains(orderId);
  }
}



// import 'package:esc_pos_printer/esc_pos_printer.dart';
// import 'package:esc_pos_utils/esc_pos_utils.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:image/image.dart' as img;
// import '../models/order.dart';
// import 'package:intl/intl.dart';
//
// enum PrinterConnectionType { wifi, bluetooth }
//
// class ThermalPrintService {
//   static final ThermalPrintService _instance = ThermalPrintService._internal();
//   factory ThermalPrintService() => _instance;
//   ThermalPrintService._internal();
//
//   // Konfigurasi printer WiFi
//   String? _printerIp;
//   int _printerPort = 9100;
//
//   // Konfigurasi printer Bluetooth
//   BluetoothDevice? _bluetoothDevice;
//   PrinterConnectionType _connectionType = PrinterConnectionType.wifi;
//
//   // Track order yang sudah pernah diprint
//   final Set<String> _printedOrders = <String>{};
//
//   // Cache logo image
//   img.Image? _logoImage;
//
//   /// Load logo image dari assets
//   Future<img.Image?> _loadLogo() async {
//     if (_logoImage != null) return _logoImage;
//
//     try {
//       final ByteData data = await rootBundle.load('assets/images/logo_print.webp');
//       final Uint8List bytes = data.buffer.asUint8List();
//
//       // Decode image
//       img.Image? image = img.decodeImage(bytes);
//
//       if (image != null) {
//         // Resize logo agar sesuai dengan lebar printer (max 384 pixels untuk 80mm)
//         // Sesuaikan size sesuai kebutuhan
//         if (image.width > 300) {
//           image = img.copyResize(image, width: 300);
//         }
//
//         _logoImage = image;
//         if (kDebugMode) {
//           print('Logo loaded successfully: ${image.width}x${image.height}');
//         }
//         return image;
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error loading logo: $e');
//       }
//     }
//     return null;
//   }
//
//   /// Set konfigurasi printer WiFi
//   void configurePrinter(String ip, {int port = 9100}) {
//     _printerIp = ip;
//     _printerPort = port;
//     _connectionType = PrinterConnectionType.wifi;
//     if (kDebugMode) {
//       print('Printer WiFi dikonfigurasi: $ip:$port');
//     }
//   }
//
//   /// Set konfigurasi printer Bluetooth
//   void configureBluetoothPrinter(BluetoothDevice device) {
//     _bluetoothDevice = device;
//     _connectionType = PrinterConnectionType.bluetooth;
//     if (kDebugMode) {
//       print('Printer Bluetooth dikonfigurasi: ${device.name}');
//     }
//   }
//
//   /// Cek apakah printer sudah dikonfigurasi
//   bool get isConfigured =>
//       (_connectionType == PrinterConnectionType.wifi && _printerIp != null) ||
//           (_connectionType == PrinterConnectionType.bluetooth && _bluetoothDevice != null);
//
//   /// Get connection type
//   PrinterConnectionType get connectionType => _connectionType;
//
//   /// Get printer info
//   String get printerInfo {
//     if (_connectionType == PrinterConnectionType.wifi) {
//       return 'WiFi: $_printerIp:$_printerPort';
//     } else {
//       return 'Bluetooth: ${_bluetoothDevice?.name ?? "Unknown"}';
//     }
//   }
//
//   /// Request Bluetooth permissions
//   Future<bool> requestBluetoothPermissions() async {
//     try {
//       Map<Permission, PermissionStatus> statuses = await [
//         Permission.bluetoothScan,
//         Permission.bluetoothConnect,
//         Permission.location,
//       ].request();
//
//       return statuses.values.every((status) => status.isGranted);
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error requesting permissions: $e');
//       }
//       return false;
//     }
//   }
//
//   /// Get paired/bonded Bluetooth devices
//   Future<List<BluetoothDevice>> getPairedDevices() async {
//     try {
//       // Check if Bluetooth is available
//       final isAvailable = await FlutterBluetoothSerial.instance.isAvailable;
//       if (isAvailable == null || !isAvailable) {
//         throw Exception('Bluetooth tidak tersedia pada perangkat ini');
//       }
//
//       // Check if Bluetooth is enabled
//       final isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
//       if (isEnabled == null || !isEnabled) {
//         throw Exception('Bluetooth tidak aktif. Silakan aktifkan Bluetooth.');
//       }
//
//       // Request permissions
//       final hasPermission = await requestBluetoothPermissions();
//       if (!hasPermission) {
//         throw Exception('Izin Bluetooth ditolak.');
//       }
//
//       // Get bonded devices
//       final bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
//
//       // Filter only printer devices
//       final printerDevices = bondedDevices.where((device) {
//         final deviceName = device.name?.toLowerCase() ?? '';
//         return deviceName.isNotEmpty && _isPrinterDevice(deviceName);
//       }).toList();
//
//       if (kDebugMode) {
//         print('Found ${printerDevices.length} paired printer devices');
//       }
//
//       return printerDevices;
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error getting paired devices: $e');
//       }
//       rethrow;
//     }
//   }
//
//   /// Check if device name indicates it's a printer
//   bool _isPrinterDevice(String deviceName) {
//     return deviceName.contains('printer') ||
//         deviceName.contains('pos') ||
//         deviceName.contains('rpp') ||
//         deviceName.contains('mpt') ||
//         deviceName.contains('thermal') ||
//         deviceName.contains('escpos') ||
//         deviceName.contains('bluetooth');
//   }
//
//   Future<bool> autoPrintOrder(Order order) async {
//     if (_printedOrders.contains(order.orderId)) {
//       if (kDebugMode) {
//         print('Order ${order.orderId} sudah pernah diprint, skip');
//       }
//       return false;
//     }
//
//     if (!isConfigured) {
//       if (kDebugMode) {
//         print('Printer belum dikonfigurasi');
//       }
//       return false;
//     }
//
//     try {
//       print('Auto printing order ${order.orderId}');
//       final success = await printOrder(order);
//       if (success) {
//         _printedOrders.add(order.orderId ?? '');
//         print('Order ${order.orderId} berhasil diprint secara otomatis');
//       }
//       return success;
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error auto print: $e');
//       }
//       return false;
//     }
//   }
//
//   Future<bool> printOrder(Order order) async {
//     if (!isConfigured) {
//       if (kDebugMode) {
//         print('Printer tidak dikonfigurasi');
//       }
//       return false;
//     }
//
//     try {
//       print('Printing order ${order.orderId}');
//       if (_connectionType == PrinterConnectionType.wifi) {
//         return await _printViaWiFi(order);
//       } else {
//         return await _printViaBluetooth(order);
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error printing: $e');
//       }
//       return false;
//     }
//   }
//
//   /// Print via WiFi
//   Future<bool> _printViaWiFi(Order order) async {
//     if (_printerIp == null) return false;
//
//     try {
//       final printer = NetworkPrinter(PaperSize.mm80, await CapabilityProfile.load());
//       final result = await printer.connect(_printerIp!, port: _printerPort);
//
//       if (result != PosPrintResult.success) {
//         if (kDebugMode) {
//           print('Gagal connect ke WiFi printer: $result');
//         }
//         return false;
//       }
//
//       await _generateReceipt(printer, order);
//       printer.disconnect();
//
//       if (kDebugMode) {
//         print('Order ${order.orderId} berhasil diprint via WiFi');
//       }
//
//       return true;
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error WiFi printing: $e');
//       }
//       return false;
//     }
//   }
//
//   /// Print via Bluetooth
//   Future<bool> _printViaBluetooth(Order order) async {
//     if (_bluetoothDevice == null) return false;
//
//     BluetoothConnection? connection;
//
//     try {
//       // Connect to Bluetooth device
//       connection = await BluetoothConnection.toAddress(_bluetoothDevice!.address);
//
//       if (!connection.isConnected) {
//         throw Exception('Gagal terhubung ke printer');
//       }
//
//       // Generate receipt bytes
//       final profile = await CapabilityProfile.load();
//       final generator = Generator(PaperSize.mm80, profile);
//       final bytes = await _generateReceiptBytes(generator, order);
//
//       // Send data
//       connection.output.add(Uint8List.fromList(bytes));
//       await connection.output.allSent;
//
//       // Wait a bit for printing to complete
//       await Future.delayed(const Duration(milliseconds: 500));
//
//       // Close connection
//       await connection.close();
//
//       if (kDebugMode) {
//         print('Order ${order.orderId} berhasil diprint via Bluetooth');
//       }
//
//       return true;
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error Bluetooth printing: $e');
//       }
//       try {
//         await connection?.close();
//       } catch (_) {}
//       return false;
//     }
//   }
//
//   /// Generate receipt untuk NetworkPrinter
//   /// Generate receipt untuk NetworkPrinter
//   Future<void> _generateReceipt(NetworkPrinter printer, Order order) async {
//     // ===== HEADER =====
//     printer.text(
//       'BARAJA AMPHI',
//       styles: const PosStyles(
//         align: PosAlign.center,
//         height: PosTextSize.size2,
//         width: PosTextSize.size2,
//         bold: true,
//       ),
//     );
//     printer.text(' ');
//     printer.text(
//       'ORDER DAPUR',
//       styles: const PosStyles(align: PosAlign.center, bold: true),
//     );
//
//     printer.hr(ch: '-');
//     printer.text(' ');
//
//     // ===== DETAIL ORDER =====
//     printer.row([
//       PosColumn(text: 'Order ID:', width: 4, styles: const PosStyles(bold: true)),
//       PosColumn(text: order.orderId ?? 'N/A', width: 8),
//     ]);
//     printer.text(' ');
//
//     printer.row([
//       PosColumn(text: 'Nama:', width: 4, styles: const PosStyles(bold: true)),
//       PosColumn(text: order.name, width: 8),
//     ]);
//     printer.text(' ');
//
//     printer.row([
//       PosColumn(text: 'Meja:', width: 4, styles: const PosStyles(bold: true)),
//       PosColumn(text: order.table, width: 8),
//     ]);
//     printer.text(' ');
//
//     printer.row([
//       PosColumn(text: 'Tipe:', width: 4, styles: const PosStyles(bold: true)),
//       PosColumn(text: order.service, width: 8),
//     ]);
//     printer.text(' ');
//
//     if (order.service.contains('Reservation') && order.reservationDate != null) {
//       printer.row([
//         PosColumn(text: 'Tanggal:', width: 4, styles: const PosStyles(bold: true)),
//         PosColumn(text: order.reservationDate!, width: 8),
//       ]);
//       printer.text(' ');
//
//       printer.row([
//         PosColumn(text: 'Jam:', width: 4, styles: const PosStyles(bold: true)),
//         PosColumn(text: order.reservationTime ?? '-', width: 8),
//       ]);
//       printer.text(' ');
//     }
//
//     printer.row([
//       PosColumn(text: 'Waktu:', width: 4, styles: const PosStyles(bold: true)),
//       PosColumn(
//         text: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
//         width: 8,
//       ),
//     ]);
//     printer.text(' ');
//
//     printer.hr(ch: '-');
//     printer.text(' ');
//
//     // ===== DAFTAR PESANAN =====
//     printer.text(
//       'PESANAN:',
//       styles: const PosStyles(bold: true, underline: true),
//     );
//     printer.text(' ');
//
//     for (var item in order.items) {
//       final itemNameWithService = '${item.name} (${order.service}) x${item.qty}';
//       printer.text(itemNameWithService, styles: const PosStyles(bold: true));
//
//       if (item.addons != null && item.addons!.isNotEmpty) {
//         for (var addon in item.addons!) {
//           printer.text('  + ${addon['name']}',
//               styles: const PosStyles(fontType: PosFontType.fontB));
//         }
//       }
//
//       if (item.toppings != null && item.toppings!.isNotEmpty) {
//         for (var topping in item.toppings!) {
//           printer.text('  + ${topping['name']}',
//               styles: const PosStyles(fontType: PosFontType.fontB));
//         }
//       }
//
//       if (item.notes != null && item.notes!.isNotEmpty) {
//         printer.text('  Catatan: ${item.notes}',
//             styles: const PosStyles(fontType: PosFontType.fontB, bold: true));
//       }
//
//       printer.text(' '); // jarak halus antar item
//     }
//
//     printer.hr(ch: '-');
//     printer.text(' ');
//
//     // ===== TOTAL =====
//     final totalItems = order.items.fold(0, (sum, item) => sum + item.qty);
//     printer.row([
//       PosColumn(text: 'TOTAL ITEM:', width: 6, styles: const PosStyles(bold: true)),
//       PosColumn(
//         text: '$totalItems',
//         width: 6,
//         styles: const PosStyles(
//           bold: true,
//           align: PosAlign.right,
//           height: PosTextSize.size2,
//           width: PosTextSize.size2,
//         ),
//       ),
//     ]);
//
//     printer.text(' ');
//     printer.hr(ch: '-');
//     printer.text(' ');
//
//     // ===== FOOTER =====
//     // printer.text(
//     //   'SIAPKAN DENGAN CERMAT',
//     //   styles: const PosStyles(align: PosAlign.center, bold: true),
//     // );
//     // printer.text(
//     //   'TARGET: 30 MENIT',
//     //   styles: const PosStyles(
//     //     align: PosAlign.center,
//     //     bold: true,
//     //     height: PosTextSize.size2,
//     //   ),
//     // );
//
//     printer.text(' ');
//     printer.cut();
//   }
//
//
//   /// Generate receipt bytes untuk Bluetooth
//   Future<List<int>> _generateReceiptBytes(Generator generator, Order order) async {
//     final List<int> bytes = [];
//
//     // Print logo jika ada
//     // final logo = await _loadLogo();
//     // if (logo != null) {
//     //   bytes.addAll(generator.image(logo, align: PosAlign.center));
//     //   bytes.addAll(generator.emptyLines(1));
//     // }
//
//     bytes.addAll(generator.text('BARAJA AMPHI',
//         styles: const PosStyles(
//           align: PosAlign.center,
//           height: PosTextSize.size2,
//           width: PosTextSize.size2,
//           bold: true,
//         )));
//
//     bytes.addAll(generator.text('ORDER DAPUR',
//         styles: const PosStyles(align: PosAlign.center, bold: true)));
//
//     bytes.addAll(generator.hr());
//     bytes.addAll(generator.emptyLines(1));
//
//     bytes.addAll(generator.row([
//       PosColumn(text: 'Order ID:', width: 4, styles: const PosStyles(bold: true)),
//       PosColumn(text: order.orderId ?? 'N/A', width: 8),
//     ]));
//
//     bytes.addAll(generator.row([
//       PosColumn(text: 'Nama:', width: 4, styles: const PosStyles(bold: true)),
//       PosColumn(text: order.name, width: 8),
//     ]));
//
//     bytes.addAll(generator.row([
//       PosColumn(text: 'Meja:', width: 4, styles: const PosStyles(bold: true)),
//       PosColumn(text: order.table, width: 8),
//     ]));
//
//     bytes.addAll(generator.row([
//       PosColumn(text: 'Tipe:', width: 4, styles: const PosStyles(bold: true)),
//       PosColumn(text: order.service, width: 8),
//     ]));
//
//     bytes.addAll(generator.row([
//       PosColumn(text: 'Waktu:', width: 4, styles: const PosStyles(bold: true)),
//       PosColumn(text: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), width: 8),
//     ]));
//
//     bytes.addAll(generator.hr());
//     bytes.addAll(generator.emptyLines(1));
//
//     bytes.addAll(generator.text('PESANAN:',
//         styles: const PosStyles(bold: true, underline: true)));
//     bytes.addAll(generator.emptyLines(1));
//
//     for (var item in order.items) {
//       // Modifikasi: Tambahkan service type di samping nama menu
//       final itemNameWithService = '${item.name} (${order.service}) x${item.qty}';
//
//       bytes.addAll(generator.text(itemNameWithService, styles: const PosStyles(bold: true)));
//
//       if (item.addons != null && item.addons!.isNotEmpty) {
//         for (var addon in item.addons!) {
//           bytes.addAll(generator.text('  + ${addon['name']}'));
//         }
//       }
//
//       if (item.toppings != null && item.toppings!.isNotEmpty) {
//         for (var topping in item.toppings!) {
//           bytes.addAll(generator.text('  + ${topping['name']}'));
//         }
//       }
//
//       if (item.notes != null && item.notes!.isNotEmpty) {
//         bytes.addAll(generator.text('  Catatan: ${item.notes}',
//             styles: const PosStyles(bold: true)));
//       }
//
//       bytes.addAll(generator.emptyLines(1));
//     }
//
//     bytes.addAll(generator.hr());
//     bytes.addAll(generator.emptyLines(1));
//
//     final totalItems = order.items.fold(0, (sum, item) => sum + item.qty);
//     bytes.addAll(generator.row([
//       PosColumn(text: 'TOTAL ITEM:', width: 6, styles: const PosStyles(bold: true)),
//       PosColumn(text: '$totalItems', width: 6,
//           styles: const PosStyles(
//             bold: true,
//             align: PosAlign.right,
//             height: PosTextSize.size2,
//             width: PosTextSize.size2,
//           )),
//     ]));
//
//     // bytes.addAll(generator.emptyLines(2));
//     // bytes.addAll(generator.text('SIAPKAN DENGAN CERMAT',
//     //     styles: const PosStyles(align: PosAlign.center, bold: true)));
//     // bytes.addAll(generator.text('TARGET: 30 MENIT',
//     //     styles: const PosStyles(
//     //       align: PosAlign.center,
//     //       bold: true,
//     //       height: PosTextSize.size2,
//     //     )));
//
//     bytes.addAll(generator.emptyLines(2));
//     bytes.addAll(generator.cut());
//
//     return bytes;
//   }
//
//   /// Manual print (untuk reprint)
//   Future<bool> manualPrint(Order order) async {
//     _printedOrders.remove(order.orderId);
//     return await printOrder(order);
//   }
//
//   /// Test koneksi printer
//   Future<bool> testConnection() async {
//     if (!isConfigured) return false;
//
//     if (_connectionType == PrinterConnectionType.wifi) {
//       return await _testWiFiConnection();
//     } else {
//       return await _testBluetoothConnection();
//     }
//   }
//
//   Future<bool> _testWiFiConnection() async {
//     if (_printerIp == null) return false;
//
//     try {
//       final printer = NetworkPrinter(PaperSize.mm80, await CapabilityProfile.load());
//       final result = await printer.connect(_printerIp!, port: _printerPort);
//
//       if (result == PosPrintResult.success) {
//         // Print logo untuk test
//         // final logo = await _loadLogo();
//         // if (logo != null) {
//         //   printer.image(logo, align: PosAlign.center);
//         //   printer.emptyLines(1);
//         // }
//
//         printer.text('TEST PRINTER',
//             styles: const PosStyles(
//               align: PosAlign.center,
//               bold: true,
//               height: PosTextSize.size2,
//             ));
//         printer.emptyLines(1);
//         printer.text('Koneksi WiFi berhasil!',
//             styles: const PosStyles(align: PosAlign.center));
//         printer.text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
//             styles: const PosStyles(align: PosAlign.center));
//         printer.emptyLines(2);
//         printer.cut();
//
//         printer.disconnect();
//         return true;
//       }
//       return false;
//     } catch (e) {
//       if (kDebugMode) {
//         print('WiFi test failed: $e');
//       }
//       return false;
//     }
//   }
//
//   Future<bool> _testBluetoothConnection() async {
//     if (_bluetoothDevice == null) return false;
//
//     BluetoothConnection? connection;
//
//     try {
//       connection = await BluetoothConnection.toAddress(_bluetoothDevice!.address);
//
//       if (!connection.isConnected) {
//         return false;
//       }
//
//       final profile = await CapabilityProfile.load();
//       final generator = Generator(PaperSize.mm80, profile);
//
//       final bytes = <int>[];
//
//       // Print logo untuk test
//       // final logo = await _loadLogo();
//       // if (logo != null) {
//       //   bytes.addAll(generator.image(logo, align: PosAlign.center));
//       //   bytes.addAll(generator.emptyLines(1));
//       // }
//
//       bytes.addAll(generator.text('TEST PRINTER',
//           styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2)));
//       bytes.addAll(generator.emptyLines(1));
//       bytes.addAll(generator.text('Koneksi Bluetooth berhasil!',
//           styles: const PosStyles(align: PosAlign.center)));
//       bytes.addAll(generator.text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
//           styles: const PosStyles(align: PosAlign.center)));
//       bytes.addAll(generator.emptyLines(2));
//       bytes.addAll(generator.cut());
//
//       connection.output.add(Uint8List.fromList(bytes));
//       await connection.output.allSent;
//
//       await Future.delayed(const Duration(milliseconds: 500));
//       await connection.close();
//
//       return true;
//     } catch (e) {
//       if (kDebugMode) {
//         print('Bluetooth test failed: $e');
//       }
//       try {
//         await connection?.close();
//       } catch (_) {}
//       return false;
//     }
//   }
//
//   /// Clear history print
//   void clearPrintHistory() {
//     _printedOrders.clear();
//     if (kDebugMode) {
//       print('Print history cleared');
//     }
//   }
//
//   /// Getters
//   int get printedCount => _printedOrders.length;
//   String? get printerIp => _printerIp;
//   BluetoothDevice? get bluetoothDevice => _bluetoothDevice;
//
//   bool isAlreadyPrinted(String? orderId) {
//     return orderId != null && _printedOrders.contains(orderId);
//   }
// }