// widgets/order_card_compact.dart
import 'package:flutter/material.dart';
import '../models/order.dart';

class OrderCardCompact extends StatefulWidget {
  final Order order;
  final bool isExpanded;
  final bool showTimer;
  final bool isFinished;
  final int? queueNumber; // Nomor urut dalam antrian
  final VoidCallback onToggleExpand;
  final VoidCallback? onComplete;
  final Function(Order, int)? onAddTime;
  final VoidCallback? onReprint;

  const OrderCardCompact({
    super.key,
    required this.order,
    required this.isExpanded,
    required this.showTimer,
    required this.isFinished,
    this.queueNumber,
    required this.onToggleExpand,
    this.onComplete,
    this.onAddTime,
    this.onReprint,
  });

  @override
  State<OrderCardCompact> createState() => _OrderCardCompactState();
}

class _OrderCardCompactState extends State<OrderCardCompact> {
  static const Color brandColor = Color(0xFF077A4B);
  final Map<String, bool> _checkedItems = {};

  Color get _cardColor {
    if (widget.isFinished) return brandColor;
    if (widget.showTimer && widget.order.isHalfTimePassed) {
      return Colors.red.shade400;
    }
    return brandColor;
  }

  Color get _badgeColor {
    if (widget.isFinished) return brandColor.withOpacity(0.1);
    if (widget.showTimer && widget.order.isHalfTimePassed) {
      return Colors.red.shade50;
    }
    return brandColor.withOpacity(0.1);
  }

  String _formatTime(DateTime dateTime) {
    // Format: "08 Nov, 14:30"
    List<String> months = ['Januari', 'Febuari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

    String day = dateTime.day.toString().padLeft(2, '0');
    String month = months[dateTime.month - 1];
    String year = dateTime.year.toString();
    String hour = dateTime.hour.toString().padLeft(2, '0');
    String minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day $month $year, $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          // if (widget.isExpanded)
            _buildExpandedContent(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isExpanded
            ? const BorderRadius.vertical(top: Radius.circular(12))
            : BorderRadius.circular(12)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Nomor Urut (jika ada)
              if (widget.queueNumber != null && widget.showTimer && !widget.isFinished)
                Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _cardColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${widget.queueNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${widget.order.orderId ?? 'N/A'} -',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _badgeColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _cardColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_outline, size: 14, color: _cardColor),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    widget.order.name,
                                    style: TextStyle(
                                      color: _cardColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _badgeColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _cardColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.order.service,
                        style: TextStyle(
                          color: _cardColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (widget.order.table.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: brandColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: brandColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.table_restaurant, size: 16, color: brandColor),
                      const SizedBox(width: 4),
                      Text(
                        widget.order.table,
                        style: TextStyle(
                          color: brandColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(width: 16),

              // Tombol Print di header (selalu visible)
              if (widget.onReprint != null)
                Container(
                  decoration: BoxDecoration(
                    color: brandColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.print, color: brandColor, size: 20),
                    onPressed: widget.onReprint,
                    tooltip: 'Print Ulang',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          if (widget.order.service.contains('Reservation') &&
              widget.order.reservationDateTime != null &&
              !widget.showTimer) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.purple.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule,
                    color: Colors.purple.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.order.reservationCountdown(),
                    style: TextStyle(
                      color: Colors.purple.shade900,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (widget.order.service.contains('Reservation') && widget.showTimer) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.orange.shade300,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_available,
                    size: 14,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Reservasi - Siap dimasak',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          if (!widget.order.service.contains('Reservation')) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.yellow.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer,
                        size: 12,
                        color: Colors.yellow.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                          widget.order.updatedAtWIB != null
                          ? _formatTime(widget.order.updatedAtWIB!)
                              : '-',
                        style: TextStyle(
                          color: Colors.yellow.shade900,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Container(
      padding: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 8),

          Column(
            children: widget.order.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isChecked = _checkedItems['${widget.order.orderId}_$index'] ?? false;

              final List<String> extras = [];
              if (item.addons != null && item.addons!.isNotEmpty) {
                for (var addon in item.addons!) {
                  String addonName = addon['name'] ?? '';
                  if (addon['options'] != null) {
                    for (var option in addon['options']) {
                      extras.add('$addonName - ${option['label'] ?? ''}');
                    }
                  }
                }
              }
              if (item.toppings != null && item.toppings!.isNotEmpty) {
                for (var addon in item.toppings!) {
                  String addonName = addon['name'] ?? '';
                  if (addon['options'] != null) {
                    for (var option in addon['options']) {
                      extras.add('$addonName - ${option['label'] ?? ''}');
                    }
                  }
                }
              }

              return Container(
                margin: EdgeInsets.only(
                  bottom: index < widget.order.items.length - 1 ? 12 : 0,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isChecked ? brandColor.withOpacity(0.5) : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (widget.showTimer && !widget.isFinished)
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: Checkbox(
                              value: isChecked,
                              onChanged: (value) {
                                setState(() {
                                  _checkedItems['${widget.order.orderId}_$index'] = value ?? false;
                                });
                              },
                              fillColor: MaterialStateProperty.resolveWith((states) {
                                if (states.contains(MaterialState.selected)) {
                                  return brandColor;
                                }
                                return Colors.white;
                              }),
                              checkColor: Colors.white,
                              side: BorderSide(
                                color: Colors.grey.shade400,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            '${item.name} ${item.qty}x',
                            style: TextStyle(
                              color: isChecked ? Colors.grey.shade400 : Colors.black87,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration: isChecked ? TextDecoration.lineThrough : null,
                              decorationThickness: 2,
                            ),
                          ),
                        ),
                        if (isChecked)
                          Icon(
                            Icons.check_circle,
                            color: brandColor,
                            size: 18,
                          ),
                      ],
                    ),

                    if (extras.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: extras.map((extra) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: brandColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: brandColor.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              extra,
                              style: TextStyle(
                                color: brandColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    if (item.notes != null && item.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.orange.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 14,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.notes!,
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),

          if (widget.order.service.contains('Reservation') &&
              widget.order.reservationDate != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.purple.shade200,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.event,
                        size: 16,
                        color: Colors.purple.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Info Reservasi',
                        style: TextStyle(
                          color: Colors.purple.shade900,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Colors.purple.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.order.reservationDate!,
                        style: TextStyle(
                          color: Colors.purple.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.purple.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.order.reservationTime ?? '-',
                        style: TextStyle(
                          color: Colors.purple.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          if (widget.showTimer && !widget.isFinished) ...[
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _badgeColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _cardColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: _cardColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Waktu Masak',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _cardColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '30 menit (hitung mundur)',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.order.remainingText(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: widget.onComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Tandai Selesai',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  //
  // Widget _buildTimeButton(String label, int minutes) {
  //   return OutlinedButton(
  //     onPressed: () {
  //       if (widget.onAddTime != null) {
  //         widget.onAddTime!(widget.order, minutes);
  //       }
  //     },
  //     style: OutlinedButton.styleFrom(
  //       foregroundColor: brandColor,
  //       padding: const EdgeInsets.symmetric(vertical: 12),
  //       side: BorderSide(color: brandColor.withOpacity(0.3)),
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(8),
  //       ),
  //     ),
  //     child: Text(
  //       label,
  //       style: const TextStyle(
  //         fontSize: 13,
  //         fontWeight: FontWeight.w600,
  //       ),
  //     ),
  //   );
  // }
}