// models/recipe_model.dart

class BaseIngredient {
  final String productId;
  final String productName;
  final String productSku;
  final double quantity;
  final String unit;
  final bool isDefault;

  BaseIngredient({
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.quantity,
    required this.unit,
    this.isDefault = true,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'productSku': productSku,
    'quantity': quantity,
    'unit': unit,
    'isDefault': isDefault,
  };

  factory BaseIngredient.fromJson(Map<String, dynamic> json) => BaseIngredient(
    productId: json['productId'],
    productName: json['productName'],
    productSku: json['productSku'],
    quantity: (json['quantity'] as num).toDouble(),
    unit: json['unit'],
    isDefault: json['isDefault'] ?? true,
  );
}

class ToppingOption {
  final String toppingName;
  final List<BaseIngredient> ingredients;

  ToppingOption({
    required this.toppingName,
    required this.ingredients,
  });

  Map<String, dynamic> toJson() => {
    'toppingName': toppingName,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
  };

  factory ToppingOption.fromJson(Map<String, dynamic> json) => ToppingOption(
    toppingName: json['toppingName'],
    ingredients: (json['ingredients'] as List)
        .map((i) => BaseIngredient.fromJson(i))
        .toList(),
  );
}

class AddonOption {
  final String addonName;
  final String optionLabel;
  final List<BaseIngredient> ingredients;

  AddonOption({
    required this.addonName,
    required this.optionLabel,
    required this.ingredients,
  });

  Map<String, dynamic> toJson() => {
    'addonName': addonName,
    'optionLabel': optionLabel,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
  };

  factory AddonOption.fromJson(Map<String, dynamic> json) => AddonOption(
    addonName: json['addonName'],
    optionLabel: json['optionLabel'],
    ingredients: (json['ingredients'] as List)
        .map((i) => BaseIngredient.fromJson(i))
        .toList(),
  );
}

class Recipe {
  final String? id;
  final String menuItemId;
  final List<BaseIngredient> baseIngredients;
  final List<ToppingOption> toppingOptions;
  final List<AddonOption> addonOptions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Recipe({
    this.id,
    required this.menuItemId,
    required this.baseIngredients,
    this.toppingOptions = const [],
    this.addonOptions = const [],
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'menuItemId': menuItemId,
    'baseIngredients': baseIngredients.map((i) => i.toJson()).toList(),
    'toppingOptions': toppingOptions.map((t) => t.toJson()).toList(),
    'addonOptions': addonOptions.map((a) => a.toJson()).toList(),
  };

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    id: json['_id'],
    menuItemId: json['menuItemId'],
    baseIngredients: (json['baseIngredients'] as List)
        .map((i) => BaseIngredient.fromJson(i))
        .toList(),
    toppingOptions: (json['toppingOptions'] as List?)
        ?.map((t) => ToppingOption.fromJson(t))
        .toList() ?? [],
    addonOptions: (json['addonOptions'] as List?)
        ?.map((a) => AddonOption.fromJson(a))
        .toList() ?? [],
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
  );
}