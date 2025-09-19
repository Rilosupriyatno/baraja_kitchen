// models/order.dart
import 'dart:async';
import 'item.dart';

class Order {
  final String name;
  final String table;
  final String service;
  final List<Item> items;
  final DateTime start;
  Duration remaining = Duration(minutes: 3);
  Timer? _timer;
  bool alertPlayed = false;

  // Additional fields for API integration
  String? originalStatus;
  String? orderId;

  Order(this.name, this.table, this.service, this.items, {DateTime? start})
      : start = start ?? DateTime.now();

  void startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      remaining -= Duration(seconds: 1);
    });
  }

  void stopTimer() => _timer?.cancel();

  bool get isLate => DateTime.now().difference(start).inSeconds > 30;

  String confirmationText() {
    final diff = DateTime.now().difference(start);
    return '${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  String remainingText() {
    if (remaining.inSeconds >= 0) {
      return '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
    } else {
      return '-${remaining.inSeconds.abs()}s';
    }
  }

  String totalCookTime() {
    final cookedDuration = Duration(minutes: 3) - remaining;
    return '${cookedDuration.inMinutes}:${(cookedDuration.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}