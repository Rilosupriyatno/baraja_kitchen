import 'package:flutter/material.dart';
import '../models/order.dart';

class OrderDetailPanel extends StatefulWidget {
  final Order? order;
  final int? queueNumber;
  final Color brandColor;
  final VoidCallback? onComplete;
  final VoidCallback? onReprint;
  final bool showTimer;

  const OrderDetailPanel({
    super.key,
    required this.order,
    this.queueNumber,
    required this.brandColor,
    this.onComplete,
    this.onReprint,
    this.showTimer = true,
  });

  @override
  State<OrderDetailPanel> createState() => _OrderDetailPanelState();
}

class _OrderDetailPanelState extends State<OrderDetailPanel> {
  final Map<String, bool> _checkedItems = {};

  Color get _cardColor {
    if (widget.order == null) return widget.brandColor;
    if (widget.showTimer && widget.order!.isHalfTimePassed) {
      return Colors.red.shade400;
    }
    return widget.brandColor;
  }

  String _formatTime(DateTime dateTime) {
    List<String> months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
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
    if (widget.order == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: const Text(
              'Order Detail',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          // Empty state
          Expanded(
            child: Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Pilih order untuk melihat detail',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with print button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
              children: [
                if (widget.queueNumber != null) ...[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(12),
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
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.order!.orderId ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person, size: 16, color: _cardColor),
                          const SizedBox(width: 4),
                          Text(
                            widget.order!.name,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (widget.order!.table.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.table_restaurant, size: 16, color: _cardColor),
                            const SizedBox(width: 4),
                            Text(
                              widget.order!.table,
                              style: TextStyle(
                                fontSize: 14,
                                color: _cardColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Print button in header
                if (widget.onReprint != null)
                  Container(
                    decoration: BoxDecoration(
                      color: widget.brandColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.print, color: widget.brandColor, size: 20),
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
          ),

        // Order entry time
        if (widget.order!.createdAtWIB != null || widget.order!.createdAt != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border(bottom: BorderSide(color: Colors.orange.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Order masuk: ${_formatTime(widget.order!.createdAtWIB ?? widget.order!.createdAt!)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        // Content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Order info badges
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoBadge(
                    icon: Icons.restaurant_menu,
                    label: widget.order!.service,
                    color: widget.brandColor,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Timer section
              if (widget.showTimer) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardColor.withOpacity(0.1),
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
                          Icon(Icons.timer_outlined, color: _cardColor, size: 18),
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
                              widget.order!.remainingText(),
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
                const SizedBox(height: 20),
              ],

              // Items section
              Text(
                'Items (${widget.order!.items.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              ...widget.order!.items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isChecked = _checkedItems['${widget.order!.orderId}_$index'] ?? false;

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
                  for (var topping in item.toppings!) {
                    String toppingName = topping['name'] ?? '';
                    if (topping['options'] != null) {
                      for (var option in topping['options']) {
                        extras.add('$toppingName - ${option['label'] ?? ''}');
                      }
                    }
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isChecked ? widget.brandColor.withOpacity(0.5) : Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (widget.showTimer)
                            Container(
                              margin: const EdgeInsets.only(right: 12),
                              child: Checkbox(
                                value: isChecked,
                                onChanged: (value) {
                                  setState(() {
                                    _checkedItems['${widget.order!.orderId}_$index'] = value ?? false;
                                  });
                                },
                                fillColor: MaterialStateProperty.resolveWith((states) {
                                  if (states.contains(MaterialState.selected)) {
                                    return widget.brandColor;
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
                              color: widget.brandColor,
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
                                color: widget.brandColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: widget.brandColor.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                extra,
                                style: TextStyle(
                                  color: widget.brandColor,
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
              }),
            ],
          ),
        ),

        // Action button (only Complete)
        if (widget.showTimer) ...[ 
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: widget.onComplete,
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text('Tandai Selesai'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.brandColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
