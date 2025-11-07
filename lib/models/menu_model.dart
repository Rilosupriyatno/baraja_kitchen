// models/menu_model.dart

class Topping {
  final String name;
  final double price;

  Topping({
    required this.name,
    required this.price,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
    };
  }

  factory Topping.fromJson(Map<String, dynamic> json) {
    return Topping(
      name: json['name'],
      price: (json['price'] as num).toDouble(),
    );
  }
}

class AddonOption {
  final String label;
  final double price;
  final bool isDefault;

  AddonOption({
    required this.label,
    required this.price,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'price': price,
      'isDefault': isDefault,
    };
  }

  factory AddonOption.fromJson(Map<String, dynamic> json) {
    return AddonOption(
      label: json['label'],
      price: (json['price'] as num).toDouble(),
      isDefault: json['isDefault'] ?? false,
    );
  }
}

class Addon {
  final String name;
  final List<AddonOption> options;

  Addon({
    required this.name,
    required this.options,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'options': options.map((opt) => opt.toJson()).toList(),
    };
  }

  factory Addon.fromJson(Map<String, dynamic> json) {
    return Addon(
      name: json['name'],
      options: (json['options'] as List)
          .map((opt) => AddonOption.fromJson(opt))
          .toList(),
    );
  }
}

class MenuItem {
  final String? id;
  final String name;
  final String description;
  final double price;
  final String imageURL;
  final String mainCat;
  final String category;
  final String? subCategory;
  final List<String> availableAt;
  final List<String> rawMaterials;
  final List<Topping> toppings;
  final List<Addon> addons;
  final String workstation;

  MenuItem({
    this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageURL = '',
    required this.mainCat,
    required this.category,
    this.subCategory,
    required this.availableAt,
    this.rawMaterials = const [],
    this.toppings = const [],
    this.addons = const [],
    required this.workstation,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'price': price,
      'imageURL': imageURL,
      'mainCat': mainCat,
      'category': category,
      'subCategory': subCategory,
      'availableAt': availableAt,
      'rawMaterials': rawMaterials,
      'toppings': toppings.map((t) => t.toJson()).toList(),
      'addons': addons.map((a) => a.toJson()).toList(),
      'workstation': workstation,
    };
  }

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: (json['price'] as num).toDouble(),
      imageURL: json['imageURL'] ?? '',
      mainCat: json['mainCat'],
      category: json['category'],
      subCategory: json['subCategory'],
      availableAt: json['availableAt'] is List
          ? List<String>.from(json['availableAt'])
          : [json['availableAt'].toString()], // Fallback jika string
      rawMaterials: List<String>.from(json['rawMaterials'] ?? []),
      toppings: (json['toppings'] as List?)
          ?.map((t) => Topping.fromJson(t))
          .toList() ??
          [],
      addons: (json['addons'] as List?)
          ?.map((a) => Addon.fromJson(a))
          .toList() ??
          [],
      workstation: json['workstation'],
    );
  }
}