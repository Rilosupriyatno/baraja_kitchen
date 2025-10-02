// models/order.dart
class OrderItem {
  final String name;
  final int qty;
  final List<Map<String, dynamic>>? addons;
  final List<Map<String, dynamic>>? toppings;
  final String? notes;
  final String itemId;

  OrderItem({
    required this.name,
    required this.qty,
    this.addons,
    this.toppings,
    this.notes,
    required this.itemId,
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
      itemId: json['_id'] ?? '',
    );
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
  DateTime? updatedAt;
  final String? reservationDate;
  final String? reservationTime;
  final DateTime? reservationDateTime; // ✅ Full datetime untuk perhitungan
  late final String status;
  final Map<String, dynamic>? reservationData; // ✅ Simpan full reservation data

  Order({
    this.orderId,
    required this.name,
    required this.table,
    required this.service,
    required this.source,
    required this.paymentMethod,
    required this.items,
    this.updatedAt,
    this.orderType,
    this.reservationDate,
    this.reservationTime,
    this.reservationDateTime,
    required this.status,
    this.reservationData,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List? ?? [])
        .map((item) => OrderItem.fromJson(item))
        .toList();

    String serviceType = json['orderType'] ?? 'Dine-In';

    if (json['orderType'] == 'Reservation') {
      serviceType = 'Reservation';
    }

    // Parse table number
    String tableNum = json['tableNumber'] ?? '';
    if (tableNum.isEmpty && json['orderType'] == 'Reservation') {
      try {
        final reservation = json['reservation'];
        if (reservation != null &&
            reservation['table_id'] is List &&
            (reservation['table_id'] as List).isNotEmpty) {
          final firstTable = reservation['table_id'][0];
          tableNum = firstTable['table_number'] ?? 'TBD';
        }
      } catch (e) {
        tableNum = 'TBD';
      }
    }

    // Parse reservation info
    String? reservationDate;
    String? reservationTime;
    DateTime? reservationDateTime;
    Map<String, dynamic>? reservationData;

    if (json['reservation'] != null) {
      final reservation = json['reservation'];
      reservationData = Map<String, dynamic>.from(reservation); // ✅ Simpan full data

      final rawDate = reservation['reservation_date'];
      reservationTime = reservation['reservation_time'];

      if (rawDate != null) {
        try {
          final date = DateTime.parse(rawDate);
          reservationDate = '${date.day}/${date.month}/${date.year}';

          // ✅ Combine date + time untuk DateTime lengkap
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
      orderType: json['orderType'],
      reservationDateTime: reservationDateTime,
      status: (json['status'] ?? 'Waiting').toString(),
      reservationData: reservationData,
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
    return '${diff.inMinutes} menit';
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
}