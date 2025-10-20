import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/stock_menu.dart';

class StockmenuService {
  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'http://localhost:3000';

  // services/api_service.dart
  static Future<List<StockMenu>> getStockMenuByWorkstation(String workstation) async {
    try {
      // Fetch menu items untuk mendapatkan workstation info
      final menuItemsResponse = await http.get(
        Uri.parse('$baseUrl/api/menu/menu-items'),
        headers: {'Content-Type': 'application/json'},
      );

      if (menuItemsResponse.statusCode != 200) {
        throw Exception('Failed to load menu items: ${menuItemsResponse.statusCode}');
      }

      final Map<String, dynamic> menuItemsData = json.decode(menuItemsResponse.body);
      List<dynamic> allMenuItems = menuItemsData['data'] ?? [];

      // Filter menu items berdasarkan workstation
      Set<String> filteredMenuIds = allMenuItems
          .where((item) => item['workstation']?.toString().toLowerCase() == workstation.toLowerCase())
          .map((item) => item['id'].toString())
          .toSet();

      // Fetch stock menu
      final stockResponse = await http.get(
        Uri.parse('$baseUrl/api/product/menu-stock/manual-stock'),
        headers: {'Content-Type': 'application/json'},
      );

      if (stockResponse.statusCode != 200) {
        throw Exception('Failed to load stock menu: ${stockResponse.statusCode}');
      }

      final Map<String, dynamic> stockData = json.decode(stockResponse.body);

      if (stockData['success'] == true && stockData['data'] != null) {
        List<dynamic> menustockData = stockData['data'];

        // Filter stock menu berdasarkan menuItemId yang ada di workstation
        return menustockData
            .where((stock) => filteredMenuIds.contains(stock['menuItemId'].toString()))
            .map((menustockJson) => StockMenu.fromJson(menustockJson))
            .toList();
      } else {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      throw Exception('Error fetching menu stock: $e');
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
        headers: {'Content-Type': 'application/json'},
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
