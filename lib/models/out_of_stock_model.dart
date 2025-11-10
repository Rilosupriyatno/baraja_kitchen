// models/out_of_stock_model.dart
class OutOfStockItem {
  final String menuItemId;
  final String menuItemName;
  final String categoryId;
  final String categoryName;
  final int currentStock;
  final String stockStatus;
  final String workstation;
  final DateTime lastUpdated;

  OutOfStockItem({
    required this.menuItemId,
    required this.menuItemName,
    required this.categoryId,
    required this.categoryName,
    required this.currentStock,
    required this.stockStatus,
    required this.workstation,
    required this.lastUpdated,
  });

  factory OutOfStockItem.fromJson(Map<String, dynamic> json) {
    return OutOfStockItem(
      menuItemId: json['menuItemId']?.toString() ?? '',
      menuItemName: json['menuItemName'] ?? '',
      categoryId: json['categoryId']?.toString() ?? '',
      categoryName: json['categoryName'] ?? 'Uncategorized',
      currentStock: json['currentStock'] ?? 0,
      stockStatus: json['stockStatus'] ?? 'unknown',
      workstation: json['workstation'] ?? '',
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
    );
  }

  bool get isOutOfStock => currentStock <= 0 || stockStatus == 'out_of_stock';
  bool get isCriticalStock => stockStatus == 'critical_stock' && currentStock > 0;
}