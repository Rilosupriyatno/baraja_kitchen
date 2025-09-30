import 'item.dart';

class Order {
  final String name;
  final String table;
  final String service;
  final List<Item> items;
  final DateTime start;        // createdAt dari backend
  late final DateTime? updatedAt;   // updatedAt dari backend (untuk OnProcess)

  bool alertPlayed = false;

  String? originalStatus;
  String? orderId;

  Order(
      this.name,
      this.table,
      this.service,
      this.items, {
        DateTime? start,
        this.updatedAt,
      }) : start = start ?? DateTime.now();

  // dianggap telat kalau sudah lewat 30 menit dari Waiting
  bool get isLate => DateTime.now().difference(start).inMinutes >= 30;

  /// Hitung mundur dari 30:00 → 00:00 untuk konfirmasi (Waiting)
  String confirmationText() {
    const maxConfirmation = Duration(minutes: 30);
    final diff = DateTime.now().difference(start);
    final remainingConfirm = maxConfirmation - diff;

    if (remainingConfirm.isNegative) return "00:00";

    return '${remainingConfirm.inMinutes}:${(remainingConfirm.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  /// Hitung mundur saat status Penyiapan (OnProcess → dari updatedAt)
  String remainingText() {
    if (updatedAt == null) return "00:00";

    final endTime = updatedAt!.add(const Duration(minutes: 30));
    final diff = endTime.difference(DateTime.now());

    if (diff.isNegative) return "00:00";

    return '${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  /// True kalau sudah lewat 15 menit sejak OnProcess
  bool get isHalfTimePassed {
    if (updatedAt == null) return false;
    return DateTime.now().difference(updatedAt!).inMinutes >= 15;
  }

  /// Total waktu memasak (sejak OnProcess)
  String totalCookTime() {
    if (updatedAt == null) return "00:00";

    final cooked = DateTime.now().difference(updatedAt!);
    return '${cooked.inMinutes}:${(cooked.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
