class StockMenu {
  final String menuItemId;
  final String name;
  final String category;
  final int calculatedStock;
  final int manualStock;
  final int effectiveStock;

  StockMenu ({
    required this.menuItemId,
    required this.name,
    required this.category,
    required this.calculatedStock,
    required this.manualStock,
    required this.effectiveStock
});

  factory StockMenu.fromJson(Map<String, dynamic> json) {
    return StockMenu(
      menuItemId: json['menuItemId'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      calculatedStock: json['calculatedStock'] ?? 0,
      manualStock: json['manualStock'] ?? 0,
      effectiveStock: json['effectiveStock'] ?? 0,
    );
  }
}