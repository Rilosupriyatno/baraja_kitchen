// models/order.dart
class OrderItem {
  final String name;
  final int qty;
  final List<Map<String, dynamic>>? addons;
  final List<Map<String, dynamic>>? toppings;
  final String? notes;
  final String itemId;
  final String? menuItemId;
  final double? subtotal;
  final String? kitchenStatus;
  final bool? isPrinted;
  final String? dineType;
  final String? workstation; // ✅ Added workstation field
  final String? mainCategory; // ✅ Added mainCategory field

  OrderItem({
    required this.name,
    required this.qty,
    this.addons,
    this.toppings,
    this.notes,
    required this.itemId,
    this.menuItemId,
    this.subtotal,
    this.kitchenStatus,
    this.isPrinted,
    this.dineType,
    this.workstation,
    this.mainCategory,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Handle menuItem data structure
    String itemName = '';
    String? menuItemId;
    String? workstation;
    String? mainCategory;

    if (json['menuItem'] != null) {
      if (json['menuItem'] is Map) {
        itemName = json['menuItem']['name'] ?? '';
        menuItemId = json['menuItem']['_id']?.toString();
        workstation = json['menuItem']['workstation']?.toString();
        mainCategory = json['menuItem']['mainCategory']?.toString();
      } else if (json['menuItem'] is String) {
        itemName = json['menuItem'];
      }
    }

    // Fallback to name field if menuItem is not available
    if (itemName.isEmpty) {
      itemName = json['name'] ?? '';
    }

    return OrderItem(
      name: itemName,
      qty: json['quantity'] ?? 1,
      addons: json['addons'] != null
          ? List<Map<String, dynamic>>.from(json['addons'])
          : null,
      toppings: json['toppings'] != null
          ? List<Map<String, dynamic>>.from(json['toppings'])
          : null,
      notes: json['notes'],
      itemId: json['_id']?.toString() ?? '',
      menuItemId: menuItemId,
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      kitchenStatus: json['kitchenStatus'],
      isPrinted: json['isPrinted'] ?? false,
      dineType: json['dineType'],
      workstation: workstation,
      mainCategory: mainCategory,
    );
  }

  // ✅ Helper method to check if this is a kitchen item (makanan)
  bool get isKitchenItem {
    // Priority 1: Check workstation
    if (workstation != null) {
      return workstation == 'kitchen';
    }
    
    // Priority 2: Check mainCategory
    if (mainCategory != null) {
      return mainCategory == 'makanan';
    }
    
    // Priority 3: Check by name as fallback
    final nameLower = name.toLowerCase();
    return !nameLower.contains('jus') &&
        !nameLower.contains('soda') &&
        !nameLower.contains('kopi') &&
        !nameLower.contains('teh') &&
        !nameLower.contains('air') &&
        !nameLower.contains('mocktail') &&
        !nameLower.contains('cocktail') &&
        !nameLower.contains('bir') &&
        !nameLower.contains('wine') &&
        !nameLower.contains('minuman') &&
        !nameLower.contains('soft drink') &&
        !nameLower.contains('es') &&
        !nameLower.contains('ice');
  }

  // ✅ Helper method to check if this is a bar item (minuman)
  bool get isBarItem {
    // Priority 1: Check workstation
    if (workstation != null) {
      return workstation == 'bar';
    }
    
    // Priority 2: Check mainCategory
    if (mainCategory != null) {
      return mainCategory == 'minuman';
    }
    
    // Priority 3: Check by name as fallback
    final nameLower = name.toLowerCase();
    return nameLower.contains('jus') ||
        nameLower.contains('soda') ||
        nameLower.contains('kopi') ||
        nameLower.contains('teh') ||
        nameLower.contains('air') ||
        nameLower.contains('mocktail') ||
        nameLower.contains('cocktail') ||
        nameLower.contains('bir') ||
        nameLower.contains('wine') ||
        nameLower.contains('minuman') ||
        nameLower.contains('soft drink') ||
        nameLower.contains('es') ||
        nameLower.contains('ice');
  }

  // ✅ Get workstation with priority
  String get resolvedWorkstation {
    if (workstation != null) {
      return workstation!;
    }
    if (mainCategory != null) {
      return mainCategory == 'makanan' ? 'kitchen' : 'bar';
    }
    return isKitchenItem ? 'kitchen' : 'bar';
  }
}

class Order {
  final String? orderId;
  final String name;
  final String table;
  final String service;
  final String source;
  final String paymentMethod;
  final List<OrderItem> items;
  final String? orderType;
  DateTime? createdAt;
  DateTime? updatedAt;
  final String? reservationDate;
  final String? reservationTime;
  final DateTime? reservationDateTime;
  late final String status;
  final Map<String, dynamic>? reservationData;
  final double? totalPrice;
  final String? outletId;
  final String? cashierId;
  final String? userId;

  Order({
    this.orderId,
    required this.name,
    required this.table,
    required this.service,
    required this.source,
    required this.paymentMethod,
    required this.items,
    this.createdAt,
    this.updatedAt,
    this.orderType,
    this.reservationDate,
    this.reservationTime,
    this.reservationDateTime,
    required this.status,
    this.reservationData,
    this.totalPrice,
    this.outletId,
    this.cashierId,
    this.userId,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // Parse items
    final itemsList = (json['items'] as List? ?? [])
        .map((item) => OrderItem.fromJson(item))
        .toList();

    // Determine service type
    String serviceType = json['orderType'] ?? 'Dine-In';
    if (json['orderType'] == 'Reservation') {
      serviceType = 'Reservation';
    }

    // Parse table number
    String tableNum = json['tableNumber'] ?? '';
    
    // Handle reservation table number
    if (tableNum.isEmpty && serviceType == 'Reservation') {
      try {
        final reservation = json['reservation'];
        if (reservation != null) {
          if (reservation['table_id'] is List && (reservation['table_id'] as List).isNotEmpty) {
            final firstTable = reservation['table_id'][0];
            tableNum = firstTable['table_number']?.toString() ?? 'TBD';
          } else if (reservation['table_id'] is Map) {
            tableNum = reservation['table_id']['table_number']?.toString() ?? 'TBD';
          } else if (reservation['tableNumber'] != null) {
            tableNum = reservation['tableNumber'].toString();
          }
        }
      } catch (e) {
        tableNum = 'TBD';
      }
    }

    // Parse dates
    DateTime? createdAt;
    DateTime? updatedAt;
    
    try {
      if (json['createdAt'] != null) {
        createdAt = DateTime.parse(json['createdAt']);
      }
      if (json['updatedAt'] != null) {
        updatedAt = DateTime.parse(json['updatedAt']);
      }
      // Fallback to WIB fields
      if (createdAt == null && json['createdAtWIB'] != null) {
        createdAt = DateTime.parse(json['createdAtWIB']);
      }
      if (updatedAt == null && json['updatedAtWIB'] != null) {
        updatedAt = DateTime.parse(json['updatedAtWIB']);
      }
    } catch (e) {
      // Use current time as fallback
      createdAt = DateTime.now();
      updatedAt = DateTime.now();
    }

    // Parse reservation info
    String? reservationDate;
    String? reservationTime;
    DateTime? reservationDateTime;
    Map<String, dynamic>? reservationData;

    if (json['reservation'] != null) {
      final reservation = json['reservation'];
      reservationData = reservation is Map ? Map<String, dynamic>.from(reservation) : null;

      // Handle reservation date and time
      if (reservation is Map) {
        final rawDate = reservation['reservation_date'];
        reservationTime = reservation['reservation_time'];

        if (rawDate != null) {
          try {
            final date = DateTime.parse(rawDate);
            reservationDate = '${date.day}/${date.month}/${date.year}';

            // Combine date + time for complete DateTime
            if (reservationTime != null) {
              final timeParts = reservationTime.split(':');
              if (timeParts.length >= 2) {
                final hour = int.tryParse(timeParts[0]) ?? 0;
                final minute = int.tryParse(timeParts[1]) ?? 0;

                reservationDateTime = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  hour,
                  minute,
                );
              }
            }
          } catch (e) {
            // ignore parsing error
          }
        }
      }
    }

    // Calculate total price
    double? totalPrice;
    if (json['grandTotal'] != null) {
      totalPrice = (json['grandTotal'] as num).toDouble();
    } else if (json['totalPrice'] != null) {
      totalPrice = (json['totalPrice'] as num).toDouble();
    } else {
      // Calculate from items as fallback
      totalPrice = itemsList.fold<double>(
        0.0,
        (double sum, OrderItem item) => sum + (item.subtotal ?? 0.0),
      );
    }

    return Order(
      orderId: json['order_id']?.toString() ?? json['_id']?.toString(),
      name: json['user']?.toString() ?? 'Guest',
      table: tableNum,
      service: serviceType,
      source: json['source']?.toString() ?? 'Unknown',
      paymentMethod: json['paymentMethod']?.toString() ?? 'Cash',
      items: itemsList,
      createdAt: createdAt,
      updatedAt: updatedAt,
      orderType: json['orderType']?.toString(),
      reservationDate: reservationDate,
      reservationTime: reservationTime,
      reservationDateTime: reservationDateTime,
      status: (json['status'] ?? 'Waiting').toString(),
      reservationData: reservationData,
      totalPrice: totalPrice,
      outletId: json['outlet']?.toString(),
      cashierId: json['cashierId']?.toString(),
      userId: json['user_id']?.toString(),
    );
  }

  // ✅ Helper untuk waktu
  bool get isLate {
    if (updatedAt == null) return false;
    final now = DateTime.now();
    final diff = now.difference(updatedAt!);
    return diff.inMinutes > 30;
  }

  bool get isHalfTimePassed {
    if (updatedAt == null) return false;
    final now = DateTime.now();
    final diff = now.difference(updatedAt!);
    return diff.inMinutes > 15;
  }

  String remainingText() {
    if (updatedAt == null) return '30:00';
    final now = DateTime.now();
    final diff = now.difference(updatedAt!);
    final remaining = 30 * 60 - diff.inSeconds;

    if (remaining <= 0) {
      return '00:00';
    }

    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String totalCookTime() {
    if (updatedAt == null) return '0 menit';
    final now = DateTime.now();
    final diff = now.difference(updatedAt!);
    
    if (diff.inHours > 0) {
      return '${diff.inHours} jam ${diff.inMinutes.remainder(60)} menit';
    } else {
      return '${diff.inMinutes} menit';
    }
  }

  // ✅ Helper untuk tampilan countdown reservasi
  String reservationCountdown() {
    if (reservationDateTime == null) return '-';

    final now = DateTime.now();
    final diff = reservationDateTime!.difference(now);

    if (diff.isNegative) {
      return 'Sudah lewat';
    }

    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours jam $minutes menit lagi';
    } else {
      return '$minutes menit lagi';
    }
  }

  // ✅ Helper untuk cek apakah order ini untuk kitchen (berdasarkan workstation)
  bool get isKitchenOrder {
    return items.any((item) => item.isKitchenItem);
  }

  // ✅ Helper untuk cek apakah order ini untuk bar (berdasarkan workstation)
  bool get isBarOrder {
    return items.any((item) => item.isBarItem);
  }

  // ✅ Get only kitchen items (makanan)
  List<OrderItem> get kitchenItems {
    return items.where((item) => item.isKitchenItem).toList();
  }

  // ✅ Get only bar items (minuman)
  List<OrderItem> get barItems {
    return items.where((item) => item.isBarItem).toList();
  }

  // ✅ Check if order has mixed items (both kitchen and bar)
  bool get hasMixedItems {
    return isKitchenOrder && isBarOrder;
  }

  // ✅ Helper untuk menentukan bar type berdasarkan table number
  String? get barType {
    if (table.isEmpty) return null;
    
    final firstChar = table[0].toUpperCase();
    if (firstChar.compareTo('A') >= 0 && firstChar.compareTo('I') <= 0) {
      return 'depan';
    } else if (firstChar.compareTo('J') >= 0 && firstChar.compareTo('Z') <= 0) {
      return 'belakang';
    }
    return null;
  }

  // ✅ Get workstation distribution summary
  Map<String, int> get workstationSummary {
    final summary = <String, int>{};
    
    for (final item in items) {
      final workstation = item.resolvedWorkstation;
      summary[workstation] = (summary[workstation] ?? 0) + item.qty;
    }
    
    return summary;
  }

  // ✅ Format waktu yang user-friendly
  String get formattedCreatedTime {
    if (createdAt == null) return '-';
    return '${createdAt!.hour.toString().padLeft(2, '0')}:${createdAt!.minute.toString().padLeft(2, '0')}';
  }

  String get formattedUpdatedTime {
    if (updatedAt == null) return '-';
    return '${updatedAt!.hour.toString().padLeft(2, '0')}:${updatedAt!.minute.toString().padLeft(2, '0')}';
  }

  // ✅ Helper untuk status display
  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'waiting':
      case 'pending':
        return 'Menunggu';
      case 'onprocess':
      case 'preparing':
        return 'Diproses';
      case 'ready':
        return 'Siap';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
      case 'canceled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  // ✅ Helper untuk warna status
  String get statusColor {
    switch (status.toLowerCase()) {
      case 'waiting':
      case 'pending':
        return '#FFA500'; // Orange
      case 'onprocess':
      case 'preparing':
        return '#007BFF'; // Blue
      case 'ready':
        return '#28A745'; // Green
      case 'completed':
        return '#6C757D'; // Gray
      case 'cancelled':
      case 'canceled':
        return '#DC3545'; // Red
      default:
        return '#6C757D'; // Gray
    }
  }

  // ✅ Copy with method untuk immutability
  Order copyWith({
    String? orderId,
    String? name,
    String? table,
    String? service,
    String? source,
    String? paymentMethod,
    List<OrderItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? orderType,
    String? reservationDate,
    String? reservationTime,
    DateTime? reservationDateTime,
    String? status,
    Map<String, dynamic>? reservationData,
    double? totalPrice,
    String? outletId,
    String? cashierId,
    String? userId,
  }) {
    return Order(
      orderId: orderId ?? this.orderId,
      name: name ?? this.name,
      table: table ?? this.table,
      service: service ?? this.service,
      source: source ?? this.source,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      orderType: orderType ?? this.orderType,
      reservationDate: reservationDate ?? this.reservationDate,
      reservationTime: reservationTime ?? this.reservationTime,
      reservationDateTime: reservationDateTime ?? this.reservationDateTime,
      status: status ?? this.status,
      reservationData: reservationData ?? this.reservationData,
      totalPrice: totalPrice ?? this.totalPrice,
      outletId: outletId ?? this.outletId,
      cashierId: cashierId ?? this.cashierId,
      userId: userId ?? this.userId,
    );
  }
}