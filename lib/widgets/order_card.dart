// widgets/order_card.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/order.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onAction;
  final bool showTimer;
  final bool isFinished;
  final Function(Order, int) onAddTime;

  const OrderCard({
    super.key,
    required this.order,
    required this.onAction,
    this.showTimer = false,
    this.isFinished = false,
    required this.onAddTime,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${order.name} - (Table ${order.table})',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  order.service,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            Divider(),
            ...order.items.map((item) => Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('${item.name} x${item.qty}'),
            )),
            SizedBox(height: 6),
            if (!isFinished)
              Text(
                showTimer ? 'Sisa waktu: ${order.remainingText()}' : 'Konfirmasi: ${order.confirmationText()}',
                style: TextStyle(
                  color: order.isLate ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (showTimer && !isFinished)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [5, 10, 15].map((minutes) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: OutlinedButton.icon(
                    onPressed: () => onAddTime(order, minutes),
                    icon: Icon(FontAwesomeIcons.clock, size: 14),
                    label: Text('+${minutes}m'),
                  ),
                )).toList(),
              ),
            SizedBox(height: 8),
            Center(
              child: ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(isFinished ? FontAwesomeIcons.eye : FontAwesomeIcons.check),
                label: Text(isFinished ? 'LIHAT DETAIL' : (showTimer ? 'SELESAIKAN' : 'KONFIRMASI')),
              ),
            ),
            if (isFinished)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Waktu Memasak: ${order.totalCookTime()}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}