// services/print_tracking_service.dart - FIXED
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class PrintTrackingService {
  static final PrintTrackingService _instance = PrintTrackingService._internal();
  factory PrintTrackingService() => _instance;
  PrintTrackingService._internal();

  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://localhost:3000';

  // Method untuk log print attempt per ITEM - FIXED PARAMETERS
  Future<String?> logPrintAttempt(
      String orderId,
      Map<String, dynamic> item,
      String workstation,
      Map<String, dynamic> printerConfig,
      Map<String, dynamic> stockInfo,
      ) async {
    try {
      final requestBody = {
        'order_id': orderId,
        'item': item,
        'workstation': workstation,
        'printer_config': printerConfig,
        'stock_info': stockInfo,
        'timestamp': DateTime.now().toIso8601String()
      };

      // 🟢 Tampilkan ke console semua data yang akan dikirim
      print('====================== 🌐 PRINT ATTEMPT REQUEST ======================');
      print('🔗 Endpoint: $baseUrl/api/print/log-attempt');
      print('📦 Data yang dikirim (requestBody):');
      print(const JsonEncoder.withIndent('  ').convert(requestBody));
      print('======================================================================\n');

      final response = await http.post(
          Uri.parse('$baseUrl/api/print/log-attempt'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody)
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data']['log_id'];
      } else {
        print('❌ Failed to log print attempt: ${response.statusCode}');
        print('   Response: ${response.body}');
      }
      return null;
    } catch (e) {
      print('❌ Error logging print attempt: $e');
      return null;
    }
  }

  // Method untuk log problematic item - FIXED
  Future<void> logProblematicItem(
      String orderId,
      Map<String, dynamic> item,
      String workstation,
      List<String> issues,
      String details,
      Map<String, dynamic> stockInfo
      ) async {
    try {
      final response = await http.post(
          Uri.parse('$baseUrl/api/print/log-problematic'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'order_id': orderId,
            'item': item,
            'workstation': workstation,
            'issues': issues,
            'details': details,
            'stock_info': stockInfo,
            'timestamp': DateTime.now().toIso8601String()
          })
      );

      if (response.statusCode != 200) {
        print('❌ Failed to log problematic item: ${response.statusCode}');
      } else {
        print('📝 Logged problematic item: ${item['name']} - Issues: ${issues.join(", ")}');
      }
    } catch (e) {
      print('❌ Error logging problematic item: $e');
    }
  }

  // Method untuk log print success - FIXED (tambahkan parameter wasProblematic)
  Future<void> logPrintSuccess(String logId, int duration, {bool wasProblematic = false}) async {
    try {
      final response = await http.post(
          Uri.parse('$baseUrl/api/print/log-success'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'log_id': logId,
            'duration': duration,
            'was_problematic': wasProblematic
          })
      );

      if (response.statusCode != 200) {
        print('❌ Failed to log print success: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error logging print success: $e');
    }
  }

  // Method untuk log print failure - FIXED (tambahkan parameter technicalDetails)
  Future<void> logPrintFailure(
      String logId,
      String reason,
      String details,
      {Map<String, dynamic>? technicalDetails}
      ) async {
    try {
      final requestBody = {
        'log_id': logId,
        'reason': reason,
        'details': details,
      };

      // Tambahkan technical details jika ada
      if (technicalDetails != null) {
        requestBody['technical_details'] = technicalDetails as String;
      }

      final response = await http.post(
          Uri.parse('$baseUrl/api/print/log-failure'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody)
      );

      if (response.statusCode != 200) {
        print('❌ Failed to log print failure: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error logging print failure: $e');
    }
  }

  // Method untuk log skipped item - FIXED (tambahkan parameter technicalReason)
  Future<void> logSkippedItem(
      String orderId,
      Map<String, dynamic> item,
      String workstation,
      String reason,
      String details,
      {Map<String, dynamic>? technicalReason}
      ) async {
    try {
      final requestBody = {
        'order_id': orderId,
        'item': item,
        'workstation': workstation,
        'reason': reason,
        'details': details,
      };

      // Tambahkan technical reason jika ada
      if (technicalReason != null) {
        requestBody['technical_reason'] = technicalReason;
      }

      final response = await http.post(
          Uri.parse('$baseUrl/api/print/log-skipped'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody)
      );

      if (response.statusCode != 200) {
        print('❌ Failed to log skipped item: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error logging skipped item: $e');
    }
  }
}