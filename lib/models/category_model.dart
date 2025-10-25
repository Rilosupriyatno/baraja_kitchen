// models/category_model.dart
import 'package:baraja_bar/models/stock_menu.dart';

class Category {
  final String id;
  final String name;
  final String? description;
  final int itemCount;

  Category({
    required this.id,
    required this.name,
    this.description,
    this.itemCount = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      itemCount: json['itemCount'] ?? 0,
    );
  }
}

class CategoryWithMenus {
  final Category category;
  final List<StockMenu> menus;

  CategoryWithMenus({
    required this.category,
    required this.menus,
  });
}