// models/order.dart
class OrderItem {
  final String name;
  final int qty;
  final List<Map<String, dynamic>>? addons;
  final List<Map<String, dynamic>>? toppings;
  final String? notes;
  final String itemId; // ✅ Tambahkan untuk tracking batch

  OrderItem({
    required this.name,
    required this.qty,
    this.addons,
    this.toppings,
    this.notes,
    required this.itemId, // ✅ Required
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: json['menuItem']?['name'] ?? '',
      qty: json['quantity'] ?? 1,
      addons: json['addons'] != null
          ? List<Map<String, dynamic>>.from(json['addons'])
          : null,
      toppings: json['toppings'] != null
          ? List<Map<String, dynamic>>.from(json['toppings'])
          : null,
      notes: json['notes'],
      itemId: json['_id'] ?? '', // ✅ Ambil dari JSON response
    );
  }
}

class Order {
  final String? orderId;
  final String name;
  final String table;
  final String service;
  final String source; // Web, App, Cashier
  final String paymentMethod; // Cash, Card, etc
  final List<OrderItem> items;
  DateTime? updatedAt;
  final String? reservationDate;
  final String? reservationTime;
  final String status; // 👈 status order

  Order({
    this.orderId,
    required this.name,
    required this.table,
    required this.service,
    required this.source,
    required this.paymentMethod,
    required this.items,
    this.updatedAt,
    this.reservationDate,
    this.reservationTime,
    required this.status,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // Parse items
    final itemsList = (json['items'] as List? ?? [])
        .map((item) => OrderItem.fromJson(item))
        .toList();

// models/order.dart
// Parse service type
    String serviceType = json['orderType'] ?? 'Dine-In';

// Tetap tampil "Reservation" kalau reservation
    if (json['orderType'] == 'Reservation') {
      serviceType = 'Reservation';
    }

// Hapus bagian yang override dengan type


    // Parse table number
    String tableNum = json['tableNumber'] ?? '';
    if (tableNum.isEmpty && json['orderType'] == 'Reservation') {
      if (json['reservation'] != null &&
          json['reservation']['table_id'] != null &&
          json['reservation']['table_id'].isNotEmpty) {
        tableNum = 'TBD';
      }
    }

    // Parse reservation info
    String? reservationDate;
    String? reservationTime;
    if (json['reservation'] != null) {
      final reservation = json['reservation'];
      reservationDate = reservation['reservation_date'];
      reservationTime = reservation['reservation_time'];

      if (reservationDate != null) {
        try {
          final date = DateTime.parse(reservationDate);
          reservationDate = '${date.day}/${date.month}/${date.year}';
        } catch (_) {}
      }
    }

    return Order(
      orderId: json['order_id'],
      name: json['user'] ?? 'Guest',
      table: tableNum,
      service: serviceType,
      source: json['source'] ?? 'Unknown',
      paymentMethod: json['paymentMethod'] ?? 'Cash',
      items: itemsList,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      reservationDate: reservationDate,
      reservationTime: reservationTime,
      status: (json['status'] ?? 'Waiting').toString(),
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
    final remaining = 30 * 60 - diff.inSeconds; // total detik sisa

    if (remaining <= 0) {
      // ✅ Kalau sudah lewat 30 menit tampilkan "00:00"
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
    return '${diff.inMinutes} menit';
  }
}
