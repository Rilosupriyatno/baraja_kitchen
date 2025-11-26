// services/stock_cache_manager.dart
import '../models/category_model.dart';
import '../models/stock_menu.dart';

class StockCacheManager {
  static final StockCacheManager _instance = StockCacheManager._internal();
  factory StockCacheManager() => _instance;
  StockCacheManager._internal();

  // Cache storage
  final Map<String, List<Category>> _categoriesCache = {};
  final Map<String, Map<String, List<StockMenu>>> _menusCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // Flags
  final Map<String, bool> _isDataLoaded = {};

  /// Check if data is already loaded for a workstation
  bool isDataLoaded(String workstation) {
    return _isDataLoaded[workstation] ?? false;
  }

  /// Get cached categories
  List<Category>? getCachedCategories(String workstation) {
    return _categoriesCache[workstation];
  }

  /// Get cached menus for a specific category
  List<StockMenu>? getCachedMenus(String workstation, String categoryId) {
    return _menusCache[workstation]?[categoryId];
  }

  /// Get all cached menus for a workstation
  Map<String, List<StockMenu>>? getAllCachedMenus(String workstation) {
    return _menusCache[workstation];
  }

  /// Save categories to cache
  void saveCategories(String workstation, List<Category> categories) {
    _categoriesCache[workstation] = categories;
    _cacheTimestamps['${workstation}_categories'] = DateTime.now();
  }

  /// Save menus to cache
  void saveMenus(String workstation, String categoryId, List<StockMenu> menus) {
    _menusCache[workstation] ??= {};
    _menusCache[workstation]![categoryId] = menus;
    _cacheTimestamps['${workstation}_menus_$categoryId'] = DateTime.now();
  }

  /// Save all menus at once
  void saveAllMenus(String workstation, Map<String, List<StockMenu>> allMenus) {
    _menusCache[workstation] = allMenus;
    _cacheTimestamps['${workstation}_all_menus'] = DateTime.now();
  }

  /// Mark data as loaded
  void markAsLoaded(String workstation) {
    _isDataLoaded[workstation] = true;
  }

  /// Update a single menu item in cache
  void updateMenuItem(String workstation, String categoryId, StockMenu updatedMenu) {
    if (_menusCache[workstation]?[categoryId] != null) {
      final menuList = _menusCache[workstation]![categoryId]!;
      final index = menuList.indexWhere((m) => m.menuItemId == updatedMenu.menuItemId);
      if (index != -1) {
        menuList[index] = updatedMenu;
      }
    }
  }

  /// Update multiple menu items in cache
  void updateMultipleMenuItems(String workstation, Map<String, StockMenu> updates) {
    if (_menusCache[workstation] == null) return;

    for (var categoryMenus in _menusCache[workstation]!.values) {
      for (var i = 0; i < categoryMenus.length; i++) {
        final menuId = categoryMenus[i].menuItemId;
        if (updates.containsKey(menuId)) {
          categoryMenus[i] = updates[menuId]!;
        }
      }
    }
  }

  /// Clear cache for a specific workstation
  void clearCache(String workstation) {
    _categoriesCache.remove(workstation);
    _menusCache.remove(workstation);
    _isDataLoaded.remove(workstation);

    // Remove timestamps
    _cacheTimestamps.removeWhere((key, value) => key.startsWith(workstation));
  }

  /// Clear all cache
  void clearAllCache() {
    _categoriesCache.clear();
    _menusCache.clear();
    _cacheTimestamps.clear();
    _isDataLoaded.clear();
  }

  /// Get cache timestamp
  DateTime? getCacheTimestamp(String workstation, {String? key}) {
    final cacheKey = key ?? '${workstation}_all_menus';
    return _cacheTimestamps[cacheKey];
  }

  /// Get cache info for debugging
  Map<String, dynamic> getCacheInfo(String workstation) {
    final categories = _categoriesCache[workstation]?.length ?? 0;
    final menuCategories = _menusCache[workstation]?.length ?? 0;
    final totalMenus = _menusCache[workstation]?.values
        .fold<int>(0, (sum, list) => sum + list.length) ?? 0;
    final timestamp = _cacheTimestamps['${workstation}_all_menus'];

    return {
      'workstation': workstation,
      'isLoaded': _isDataLoaded[workstation] ?? false,
      'categoriesCount': categories,
      'menuCategoriesCount': menuCategories,
      'totalMenusCount': totalMenus,
      'lastCached': timestamp?.toString() ?? 'Never',
    };
  }
}