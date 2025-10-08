import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/stock_menu.dart';

class StockmenuService {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://localhost:3000';

  // 📹 Ambil semua order untuk kitchen
  static Future<List<StockMenu>> getStockMenu() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/product/menu-stock/manual-stock'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          List<dynamic> menustockData = data['data'];
          return menustockData.map((menustockJson) => StockMenu.fromJson(menustockJson)).toList();
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('Failed to load orders: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching orders: $e');
    }
  }

  static Future<bool> updateManualStock(
      String menuItemId,
      int manualStock, {
        String? adjustmentNote,
        String? adjustedBy,
      }) async {
    try {

      // Body request sesuai backend
      final body = {
        'manualStock': manualStock,
        if (adjustmentNote != null) 'adjustmentNote': adjustmentNote,
        if (adjustedBy != null) 'adjustedBy': adjustedBy,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/api/product/menu/$menuItemId/adjust-stock'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final success = jsonData['success'] ?? false;

        return success;
      } else {

        final jsonData = json.decode(response.body);
        final errorMessage = jsonData['message'] ?? 'Unknown error';
        throw Exception('Update failed: $errorMessage');
      }
    } catch (e) {
      rethrow;
    }
  }
}