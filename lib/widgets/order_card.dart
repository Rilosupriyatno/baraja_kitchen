import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart'; // ✅ Import untuk format tanggal
import '../models/order.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onAction;
  final bool showTimer;
  final bool isFinished;
  final bool isReservation; // ✅ Flag reservasi
  final Function(Order, int) onAddTime;

  const OrderCard({
    super.key,
    required this.order,
    required this.onAction,
    this.showTimer = false,
    this.isFinished = false,
    this.isReservation = false, // ✅ Default false
    required this.onAddTime,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      // ✅ Border khusus untuk reservasi
      color: isReservation ? Colors.orange.shade50 : Colors.white,
      child: Container(
        decoration: isReservation
            ? BoxDecoration(
          border: Border.all(color: Colors.orange, width: 2),
          borderRadius: BorderRadius.circular(8),
        )
            : null,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Badge RESERVASI jika perlu
              if (isReservation)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'RESERVASI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
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

              // ✅ Info waktu reservasi jika ada
              if (isReservation)
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.orange),
                      SizedBox(width: 4),
                      Text(
                        'Waktu: ${DateFormat('dd MMM yyyy, HH:mm').format(order.start)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              Divider(),
              ...order.items.map((item) => Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('${item.name} x${item.qty}'),
              )),
              SizedBox(height: 6),

              // ✅ Tidak tampilkan timer/konfirmasi untuk reservasi
              if (!isFinished && !isReservation)
                Text(
                  showTimer
                      ? 'Sisa waktu: ${order.remainingText()}'
                      : 'Konfirmasi: ${order.confirmationText()}',
                  style: TextStyle(
                    color: showTimer
                        ? (order.isHalfTimePassed ? Colors.red : Colors.green)
                        : (order.isLate ? Colors.red : Colors.green),
                    fontWeight: FontWeight.bold,
                  ),
                ),

              if (showTimer && !isFinished && !isReservation)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [5, 10, 15]
                      .map((minutes) => Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: OutlinedButton.icon(
                      onPressed: () => onAddTime(order, minutes),
                      icon: Icon(FontAwesomeIcons.clock, size: 14),
                      label: Text('+${minutes}m'),
                    ),
                  ))
                      .toList(),
                ),

              SizedBox(height: 8),

              // ✅ Tombol berbeda untuk reservasi
              Center(
                child: ElevatedButton.icon(
                  onPressed: isReservation ? null : onAction, // Disable untuk reservasi
                  icon: Icon(
                    isReservation
                        ? Icons.event
                        : (isFinished
                        ? FontAwesomeIcons.eye
                        : FontAwesomeIcons.check),
                  ),
                  label: Text(
                    isReservation
                        ? 'RESERVASI - TUNGGU WAKTU'
                        : (isFinished
                        ? 'LIHAT DETAIL'
                        : (showTimer ? 'SELESAIKAN' : 'KONFIRMASI')),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReservation ? Colors.grey : null,
                  ),
                ),
              ),

              if (isFinished)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Waktu Memasak: ${order.totalCookTime()}',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}