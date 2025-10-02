// services/thermal_print_service.dart
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/foundation.dart';
import '../models/order.dart';
import 'package:intl/intl.dart';

class ThermalPrintService {
  static final ThermalPrintService _instance = ThermalPrintService._internal();
  factory ThermalPrintService() => _instance;
  ThermalPrintService._internal();

  // Konfigurasi printer (bisa disimpan di SharedPreferences)
  String? _printerIp;
  int _printerPort = 9100; // Port default untuk thermal printer

  // Track order yang sudah pernah diprint
  final Set<String> _printedOrders = <String>{};

  /// Set konfigurasi printer
  void configurePrinter(String ip, {int port = 9100}) {
    _printerIp = ip;
    _printerPort = port;
    if (kDebugMode) {
      print('🖨️ Printer configured: $ip:$port');
    }
  }

  /// Cek apakah printer sudah dikonfigurasi
  bool get isConfigured => _printerIp != null;

  /// Print order baru secara otomatis
  Future<bool> autoPrintOrder(Order order) async {
    // Skip jika sudah pernah diprint
    if (_printedOrders.contains(order.orderId)) {
      if (kDebugMode) {
        print('🔇 Order ${order.orderId} sudah pernah diprint, skip');
      }
      return false;
    }

    // Skip jika printer belum dikonfigurasi
    if (!isConfigured) {
      if (kDebugMode) {
        print('⚠️ Printer belum dikonfigurasi');
      }
      return false;
    }

    try {
      final success = await printOrder(order);
      if (success) {
        _printedOrders.add(order.orderId ?? '');
      }
      return success;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error auto print: $e');
      }
      return false;
    }
  }

  /// Print order ke thermal printer
  Future<bool> printOrder(Order order) async {
    if (_printerIp == null) {
      if (kDebugMode) {
        print('❌ Printer IP tidak ditemukan');
      }
      return false;
    }

    try {
      // Connect ke printer
      final printer = NetworkPrinter(PaperSize.mm80, await CapabilityProfile.load());
      final result = await printer.connect(_printerIp!, port: _printerPort);

      if (result != PosPrintResult.success) {
        if (kDebugMode) {
          print('❌ Gagal connect ke printer: $result');
        }
        return false;
      }

      // Generate receipt
      await _generateReceipt(printer, order);

      // Disconnect
      printer.disconnect();

      if (kDebugMode) {
        print('✅ Order ${order.orderId} berhasil diprint');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error printing: $e');
      }
      return false;
    }
  }

  /// Generate konten receipt
  Future<void> _generateReceipt(NetworkPrinter printer, Order order) async {
    // Header
    printer.text(
      'BARAJA KITCHEN',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );

    printer.text(
      'ORDER DAPUR',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );

    printer.hr();
    printer.emptyLines(1);

    // Order Info
    printer.row([
      PosColumn(
        text: 'Order ID:',
        width: 4,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: order.orderId ?? 'N/A',
        width: 8,
      ),
    ]);

    printer.row([
      PosColumn(
        text: 'Nama:',
        width: 4,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: order.name,
        width: 8,
      ),
    ]);

    printer.row([
      PosColumn(
        text: 'Meja:',
        width: 4,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: order.table,
        width: 8,
      ),
    ]);

    printer.row([
      PosColumn(
        text: 'Tipe:',
        width: 4,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: order.service,
        width: 8,
      ),
    ]);

    // Jika reservasi, tampilkan info waktu
    if (order.service.contains('Reservation') &&
        order.reservationDate != null) {
      printer.row([
        PosColumn(
          text: 'Tanggal:',
          width: 4,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: order.reservationDate!,
          width: 8,
        ),
      ]);

      printer.row([
        PosColumn(
          text: 'Jam:',
          width: 4,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: order.reservationTime ?? '-',
          width: 8,
        ),
      ]);
    }

    printer.row([
      PosColumn(
        text: 'Waktu:',
        width: 4,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
        width: 8,
      ),
    ]);

    printer.hr();
    printer.emptyLines(1);

    // Items
    printer.text(
      'PESANAN:',
      styles: const PosStyles(
        bold: true,
        underline: true,
      ),
    );
    printer.emptyLines(1);

    for (var item in order.items) {
      // Item name and quantity
      printer.row([
        PosColumn(
          text: item.name,
          width: 8,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: '${item.qty}x',
          width: 4,
          styles: const PosStyles(
            bold: true,
            align: PosAlign.right,
          ),
        ),
      ]);

      // Addons
      if (item.addons != null && item.addons!.isNotEmpty) {
        for (var addon in item.addons!) {
          printer.text(
            '  + ${addon['name']}',
            styles: const PosStyles(fontType: PosFontType.fontB),
          );
        }
      }

      // Toppings
      if (item.toppings != null && item.toppings!.isNotEmpty) {
        for (var topping in item.toppings!) {
          printer.text(
            '  + ${topping['name']}',
            styles: const PosStyles(fontType: PosFontType.fontB),
          );
        }
      }

      // Notes
      if (item.notes != null && item.notes!.isNotEmpty) {
        printer.text(
          '  Catatan: ${item.notes}',
          styles: const PosStyles(
            fontType: PosFontType.fontB,
            bold: true,
          ),
        );
      }

      printer.emptyLines(1);
    }

    printer.hr();
    printer.emptyLines(1);

    // Total items
    final totalItems = order.items.fold(0, (sum, item) => sum + item.qty);
    printer.row([
      PosColumn(
        text: 'TOTAL ITEM:',
        width: 6,
        styles: const PosStyles(bold: true),
      ),
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

    printer.emptyLines(1);
    printer.hr();
    printer.emptyLines(2);

    // Footer
    printer.text(
      'SIAPKAN DENGAN CERMAT',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );

    printer.text(
      'TARGET: 30 MENIT',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
      ),
    );

    printer.emptyLines(2);

    // Cut paper
    printer.cut();
  }

  /// Manual print (untuk reprint)
  Future<bool> manualPrint(Order order) async {
    // Hapus dari history agar bisa diprint ulang
    _printedOrders.remove(order.orderId);
    return await printOrder(order);
  }

  /// Test koneksi printer
  Future<bool> testConnection() async {
    if (_printerIp == null) return false;

    try {
      final printer = NetworkPrinter(PaperSize.mm80, await CapabilityProfile.load());
      final result = await printer.connect(_printerIp!, port: _printerPort);

      if (result == PosPrintResult.success) {
        // Print test page
        printer.text(
          'TEST PRINTER',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
          ),
        );
        printer.emptyLines(1);
        printer.text(
          'Koneksi berhasil!',
          styles: const PosStyles(align: PosAlign.center),
        );
        printer.text(
          DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
          styles: const PosStyles(align: PosAlign.center),
        );
        printer.emptyLines(2);
        printer.cut();

        printer.disconnect();
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Test connection failed: $e');
      }
      return false;
    }
  }

  /// Clear history print
  void clearPrintHistory() {
    _printedOrders.clear();
    if (kDebugMode) {
      print('🗑️ Print history cleared');
    }
  }

  /// Getter untuk debugging
  int get printedCount => _printedOrders.length;
  String? get printerIp => _printerIp;
}