// services/stock_menu_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/out_of_stock_model.dart';
import '../models/stock_menu.dart';
import '../models/category_model.dart';

class StockMenuService {
  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'http://localhost:3000';

  static Future<List<StockMenu>> getStockMenuByWorkstation(
    String workstation,
  ) async {
    try {
      // ⚡ OPTIMIZED: Add 5s timeout
      final menuItemsResponse = await http.get(
        Uri.parse('$baseUrl/api/menu/all-menu-items-backoffice'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 30));

      if (menuItemsResponse.statusCode != 200) {
        throw Exception(
          'Failed to load menu items: ${menuItemsResponse.statusCode}',
        );
      }

      final Map<String, dynamic> menuItemsData = json.decode(
        menuItemsResponse.body,
      );
      List<dynamic> allMenuItems = menuItemsData['data'] ?? [];

      // Filter menu items berdasarkan workstation
      Set<String> filteredMenuIds = allMenuItems
          .where(
            (item) =>
                item['workstation']?.toString().toLowerCase() ==
                workstation.toLowerCase(),
          )
          .map((item) => item['id'].toString())
          .toSet();

      // ⚡ OPTIMIZED: Add 5s timeout
      final stockResponse = await http.get(
        Uri.parse('$baseUrl/api/product/menu-stock/manual-stock'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 30));

      if (stockResponse.statusCode != 200) {
        throw Exception(
          'Failed to load stock menu: ${stockResponse.statusCode}',
        );
      }

      final Map<String, dynamic> stockData = json.decode(stockResponse.body);

      if (stockData['success'] == true && stockData['data'] != null) {
        List<dynamic> menustockData = stockData['data'];

        // Filter stock menu berdasarkan menuItemId yang ada di workstation
        return menustockData
            .where(
              (stock) =>
                  filteredMenuIds.contains(stock['menuItemId'].toString()),
            )
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
  static Future<List<Category>> getCategoriesByWorkstation(
    String workstation,
  ) async {
    try {
      // ⚡ OPTIMIZED: Add 5s timeout
      final menuItemsResponse = await http.get(
        Uri.parse('$baseUrl/api/menu/all-menu-items-backoffice'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 30));

      if (menuItemsResponse.statusCode != 200) {
        throw Exception(
          'Failed to load menu items: ${menuItemsResponse.statusCode}',
        );
      }

      final Map<String, dynamic> menuItemsData = json.decode(
        menuItemsResponse.body,
      );
      List<dynamic> allMenuItems = menuItemsData['data'] ?? [];

      // Filter menu items berdasarkan workstation dan ekstrak kategori
      final filteredItems = allMenuItems
          .where(
            (item) =>
                item['workstation']?.toString().toLowerCase() ==
                workstation.toLowerCase(),
          )
          .toList();

      // Group by category
      Map<String, List<dynamic>> categoryMap = {};
      for (var item in filteredItems) {
        String categoryId =
            item['category']?['id']?.toString() ?? 'uncategorized';
        // ignore: unused_local_variable
        String categoryName =
            item['category']?['name']?.toString() ?? 'Uncategorized';

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

      // ✅ Filter kategori yang tidak diinginkan
      // final excludedCategories = ['ruangan', 'sparkling', 'event'];
      // categories = categories.where((category) {
      //   return !excludedCategories.contains(category.name.toLowerCase());
      // }).toList();

      return categories;
    } catch (e) {
      throw Exception('Error fetching categories: $e');
    }
  }

  static Future<List<OutOfStockItem>> getOutOfStockItems(
    String workstation,
  ) async {
    try {
      // ⚡ OPTIMIZED: Add 5s timeout
      final menuItemsResponse = await http.get(
        Uri.parse('$baseUrl/api/menu/all-menu-items-backoffice'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (menuItemsResponse.statusCode != 200) {
        throw Exception(
          'Failed to load menu items: ${menuItemsResponse.statusCode}',
        );
      }

      final Map<String, dynamic> menuItemsData = json.decode(
        menuItemsResponse.body,
      );
      List<dynamic> allMenuItems = menuItemsData['data'] ?? [];

      // Filter berdasarkan workstation
      final filteredItems = allMenuItems
          .where(
            (item) =>
                item['workstation']?.toString().toLowerCase() ==
                workstation.toLowerCase(),
          )
          .toList();

      // ⚡ OPTIMIZED: Add 5s timeout
      final stockResponse = await http.get(
        Uri.parse('$baseUrl/api/product/menu-stock/manual-stock'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (stockResponse.statusCode != 200) {
        throw Exception('Failed to load stock: ${stockResponse.statusCode}');
      }

      final Map<String, dynamic> stockData = json.decode(stockResponse.body);
      List<dynamic> stockList = stockData['data'] ?? [];

      // Create map untuk lookup cepat
      Map<String, dynamic> stockMap = {};
      for (var stock in stockList) {
        stockMap[stock['menuItemId'].toString()] = stock;
      }

      // Filter items yang BENAR-BENAR habis (stok = 0)
      List<OutOfStockItem> outOfStockItems = [];

      for (var item in filteredItems) {
        final menuItemId = item['id'].toString();
        final stockInfo = stockMap[menuItemId];

        if (stockInfo != null) {
          final currentStock = stockInfo['effectiveStock'] ?? 0;

          // HANYA masukkan jika stok = 0 (habis total)
          if (currentStock <= 0) {
            outOfStockItems.add(
              OutOfStockItem(
                menuItemId: menuItemId,
                menuItemName: item['name'] ?? 'Unknown',
                categoryId:
                    item['category']?['id']?.toString() ?? 'uncategorized',
                categoryName: item['category']?['name'] ?? 'Uncategorized',
                currentStock: currentStock,
                stockStatus: 'out_of_stock',
                workstation: workstation,
                lastUpdated: DateTime.now(),
              ),
            );
          }
        }
      }

      return outOfStockItems;
    } catch (e) {
      throw Exception('Error fetching out of stock items: $e');
    }
  }

  /// Helper untuk determine stock status
  // static String _determineStockStatus(int stock) {
  //   if (stock <= 0) return 'out_of_stock';
  //   if (stock <= 5) return 'critical_stock';
  //   if (stock <= 10) return 'low_stock';
  //   return 'in_stock';
  // }

  // Get menu items by kategori dan workstation
  static Future<CategoryWithMenus> getMenusByCategoryAndWorkstation(
    String categoryId,
    String workstation,
  ) async {
    try {
      // ⚡ OPTIMIZED: Add 5s timeout
      final menuItemsResponse = await http.get(
        Uri.parse('$baseUrl/api/menu/all-menu-items-backoffice'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 30));

      if (menuItemsResponse.statusCode != 200) {
        throw Exception(
          'Failed to load menu items: ${menuItemsResponse.statusCode}',
        );
      }

      final Map<String, dynamic> menuItemsData = json.decode(
        menuItemsResponse.body,
      );
      List<dynamic> allMenuItems = menuItemsData['data'] ?? [];

      // Filter berdasarkan workstation dan kategori
      List<dynamic> filteredMenuItems = allMenuItems.where((item) {
        bool matchesWorkstation =
            item['workstation']?.toString().toLowerCase() ==
            workstation.toLowerCase();
        String itemCategoryId =
            item['category']?['id']?.toString() ?? 'uncategorized';
        bool matchesCategory = categoryId == 'uncategorized'
            ? (itemCategoryId == 'uncategorized' || item['category'] == null)
            : itemCategoryId == categoryId;

        return matchesWorkstation && matchesCategory;
      }).toList();

      // Get category info
      Category category;
      if (filteredMenuItems.isNotEmpty &&
          filteredMenuItems.first['category'] != null) {
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

      // ⚡ OPTIMIZED: Add 5s timeout
      final stockResponse = await http.get(
        Uri.parse('$baseUrl/api/product/menu-stock/manual-stock'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (stockResponse.statusCode != 200) {
        throw Exception(
          'Failed to load stock menu: ${stockResponse.statusCode}',
        );
      }

      final Map<String, dynamic> stockData = json.decode(stockResponse.body);
      List<StockMenu> stockMenus = [];

      if (stockData['success'] == true && stockData['data'] != null) {
        List<dynamic> menustockData = stockData['data'];

        stockMenus = menustockData
            .where(
              (stock) =>
                  filteredMenuIds.contains(stock['menuItemId'].toString()),
            )
            .map((menustockJson) => StockMenu.fromJson(menustockJson))
            .toList();
      }

      return CategoryWithMenus(category: category, menus: stockMenus);
    } catch (e) {
      throw Exception('Error fetching menus by category: $e');
    }
  }

  // Get semua menu dengan kategori untuk workstation (jika perlu semua sekaligus)
  static Future<List<CategoryWithMenus>> getAllMenusGroupedByCategory(
    String workstation,
  ) async {
    try {
      final categories = await getCategoriesByWorkstation(workstation);
      List<CategoryWithMenus> result = [];

      for (var category in categories) {
        final categoryWithMenus = await getMenusByCategoryAndWorkstation(
          category.id,
          workstation,
        );
        result.add(categoryWithMenus);
      }

      return result;
    } catch (e) {
      throw Exception('Error fetching all menus grouped by category: $e');
    }
  }

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
        print('✅ Success: $success');
        return success;
      } else {
        final jsonData = json.decode(response.body);
        final errorMessage = jsonData['message'] ?? 'Unknown error';
        final errorDetail = jsonData['error'] ?? '';
        print('❌ Error: $errorMessage - $errorDetail');
        throw Exception('Update failed: $errorMessage - $errorDetail');
      }
    } catch (e) {
      print('❌ Exception caught: $e');
      rethrow;
    }
  }

  // ⚡ OPTIMIZED: Single-call untuk semua data workstation
  // Menggantikan 20+ sequential calls dengan 1 call
  static Future<WorkstationData?> getAllWorkstationData(String workstation) async {
    try {
      print('⚡ [OPTIMIZED] Loading all data for $workstation in single call...');
      final startTime = DateTime.now();
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/menu/workstation-data?workstation=$workstation'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 30));  // 30s timeout for complete data

      if (response.statusCode != 200) {
        throw Exception('Failed to load workstation data: ${response.statusCode}');
      }

      final Map<String, dynamic> jsonData = json.decode(response.body);

      if (jsonData['success'] != true || jsonData['data'] == null) {
        throw Exception('Invalid response format');
      }

      final data = jsonData['data'];
      final List<dynamic> categoriesJson = data['categories'] ?? [];

      // Parse categories with menus
      List<CategoryWithMenus> categories = categoriesJson.map((catJson) {
        final List<dynamic> menusJson = catJson['menus'] ?? [];
        
        List<StockMenu> menus = menusJson.map((menuJson) => StockMenu(
          menuItemId: menuJson['menuItemId'] ?? '',
          name: menuJson['name'] ?? '',
          category: catJson['name'] ?? '',  // Use category name from parent
          calculatedStock: menuJson['calculatedStock'] ?? 0,
          manualStock: menuJson['manualStock'] ?? 0,
          effectiveStock: menuJson['effectiveStock'] ?? 0,
        )).toList();

        return CategoryWithMenus(
          category: Category(
            id: catJson['id'] ?? '',
            name: catJson['name'] ?? '',
            itemCount: catJson['itemCount'] ?? 0,
          ),
          menus: menus,
        );
      }).toList();

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      print('✅ [OPTIMIZED] Loaded ${data['totalMenus']} menus in ${data['totalCategories']} categories (${duration}ms)');

      return WorkstationData(
        workstation: data['workstation'] ?? workstation,
        categories: categories,
        totalMenus: data['totalMenus'] ?? 0,
        totalCategories: data['totalCategories'] ?? 0,
      );
    } catch (e) {
      print('❌ Error in getAllWorkstationData: $e');
      return null;  // Return null so caller can fallback to legacy method
    }
  }
}

// ⚡ Data class untuk hasil optimized endpoint
class WorkstationData {
  final String workstation;
  final List<CategoryWithMenus> categories;
  final int totalMenus;
  final int totalCategories;

  WorkstationData({
    required this.workstation,
    required this.categories,
    required this.totalMenus,
    required this.totalCategories,
  });
}
