// widgets/order_column.dart
import 'package:flutter/material.dart';
import '../models/order.dart';
import '../config/app_theme.dart';
import 'order_card.dart';

class OrderColumn extends StatelessWidget {
  final String title;
  final List<Order> orders;
  final Function(Order) onAction;
  final String searchQuery;
  final bool showTimer;
  final bool isFinished;

  final Function(Order, int)? onAddTime;

  const OrderColumn({
    super.key,
    required this.title,
    required this.orders,
    required this.onAction,
    required this.searchQuery,
    this.showTimer = false,
    this.isFinished = false,
    this.onAddTime,
  });

  @override
  Widget build(BuildContext context) {
    List<Order> filteredOrders = orders.where((order) =>
    order.name.toLowerCase().contains(searchQuery) ||
        order.items.any((item) => item.name.toLowerCase().contains(searchQuery))).toList();

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: filteredOrders.map((order) {
                  return OrderCard(
                    order: order,
                    onAction: () => onAction(order),
                    showTimer: showTimer,
                    isFinished: isFinished,
                    onAddTime: onAddTime ?? (order, minutes) {},
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}