// services/stock_menu_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/stock_menu.dart';
import '../models/category_model.dart';

class StockMenuService {
  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'http://localhost:3000';


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
  
  // Get semua kategori untuk workstation tertentu
  static Future<List<Category>> getCategoriesByWorkstation(String workstation) async {
    try {
      // Fetch menu items untuk mendapatkan kategori
      final menuItemsResponse = await http.get(
        Uri.parse('$baseUrl/api/menu/menu-items'),
        headers: {'Content-Type': 'application/json'},
      );

      if (menuItemsResponse.statusCode != 200) {
        throw Exception('Failed to load menu items: ${menuItemsResponse.statusCode}');
      }

      final Map<String, dynamic> menuItemsData = json.decode(menuItemsResponse.body);
      List<dynamic> allMenuItems = menuItemsData['data'] ?? [];

      // Filter menu items berdasarkan workstation dan ekstrak kategori
      final filteredItems = allMenuItems
          .where((item) => item['workstation']?.toString().toLowerCase() == workstation.toLowerCase())
          .toList();

      // Group by category
      Map<String, List<dynamic>> categoryMap = {};
      for (var item in filteredItems) {
        String categoryId = item['category']?['id']?.toString() ?? 'uncategorized';
        String categoryName = item['category']?['name']?.toString() ?? 'Uncategorized';
        
        if (!categoryMap.containsKey(categoryId)) {
          categoryMap[categoryId] = [];
        }
        categoryMap[categoryId]!.add(item);
      }

      // Convert to Category list
      List<Category> categories = categoryMap.entries.map((entry) {
        return Category(
          id: entry.key,
          name: entry.value.first['category']?['name'] ?? 'Uncategorized',
          itemCount: entry.value.length,
        );
      }).toList();

      return categories;
    } catch (e) {
      throw Exception('Error fetching categories: $e');
    }
  }

  // Get menu items by kategori dan workstation
  static Future<CategoryWithMenus> getMenusByCategoryAndWorkstation(
    String categoryId, 
    String workstation
  ) async {
    try {
      // Fetch menu items
      final menuItemsResponse = await http.get(
        Uri.parse('$baseUrl/api/menu/menu-items'),
        headers: {'Content-Type': 'application/json'},
      );

      if (menuItemsResponse.statusCode != 200) {
        throw Exception('Failed to load menu items: ${menuItemsResponse.statusCode}');
      }

      final Map<String, dynamic> menuItemsData = json.decode(menuItemsResponse.body);
      List<dynamic> allMenuItems = menuItemsData['data'] ?? [];

      // Filter berdasarkan workstation dan kategori
      List<dynamic> filteredMenuItems = allMenuItems.where((item) {
        bool matchesWorkstation = item['workstation']?.toString().toLowerCase() == workstation.toLowerCase();
        String itemCategoryId = item['category']?['id']?.toString() ?? 'uncategorized';
        bool matchesCategory = categoryId == 'uncategorized' 
            ? (itemCategoryId == 'uncategorized' || item['category'] == null)
            : itemCategoryId == categoryId;
        
        return matchesWorkstation && matchesCategory;
      }).toList();

      // Get category info
      Category category;
      if (filteredMenuItems.isNotEmpty && filteredMenuItems.first['category'] != null) {
        category = Category.fromJson(filteredMenuItems.first['category']);
      } else {
        category = Category(
          id: 'uncategorized',
          name: 'Uncategorized',
          itemCount: filteredMenuItems.length,
        );
      }

      // Fetch stock data untuk menu items yang difilter
      Set<String> filteredMenuIds = filteredMenuItems
          .map((item) => item['id'].toString())
          .toSet();

      final stockResponse = await http.get(
        Uri.parse('$baseUrl/api/product/menu-stock/manual-stock'),
        headers: {'Content-Type': 'application/json'},
      );

      if (stockResponse.statusCode != 200) {
        throw Exception('Failed to load stock menu: ${stockResponse.statusCode}');
      }

      final Map<String, dynamic> stockData = json.decode(stockResponse.body);
      List<StockMenu> stockMenus = [];

      if (stockData['success'] == true && stockData['data'] != null) {
        List<dynamic> menustockData = stockData['data'];

        stockMenus = menustockData
            .where((stock) => filteredMenuIds.contains(stock['menuItemId'].toString()))
            .map((menustockJson) => StockMenu.fromJson(menustockJson))
            .toList();
      }

      return CategoryWithMenus(
        category: category,
        menus: stockMenus,
      );
    } catch (e) {
      throw Exception('Error fetching menus by category: $e');
    }
  }

  // Get semua menu dengan kategori untuk workstation (jika perlu semua sekaligus)
  static Future<List<CategoryWithMenus>> getAllMenusGroupedByCategory(String workstation) async {
    try {
      final categories = await getCategoriesByWorkstation(workstation);
      List<CategoryWithMenus> result = [];

      for (var category in categories) {
        final categoryWithMenus = await getMenusByCategoryAndWorkstation(
          category.id, 
          workstation
        );
        result.add(categoryWithMenus);
      }

      return result;
    } catch (e) {
      throw Exception('Error fetching all menus grouped by category: $e');
    }
  }

  // Update stock method (tetap sama)
  static Future<bool> updateManualStock(
    String menuItemId,
    int manualStock, {
    String? adjustmentNote,
    String? adjustedBy,
  }) async {
    try {
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