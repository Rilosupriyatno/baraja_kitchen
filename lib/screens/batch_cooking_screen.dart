// widgets/batch_cooking_view.dart
import 'package:flutter/material.dart';
import '../models/order.dart';

// CARA INTEGRASI KE KITCHEN DASHBOARD:
// 1. Import widget ini
// 2. Tambah tab baru di sidebar
// 3. Tambah view di IndexedStack

class BatchCookingView extends StatefulWidget {
  final List<Order> orders;
  final Function(List<String> orderIds) onBatchComplete;

  const BatchCookingView({
    super.key,
    required this.orders,
    required this.onBatchComplete,
  });

  @override
  State<BatchCookingView> createState() => _BatchCookingViewState();
}

class _BatchCookingViewState extends State<BatchCookingView> {
  static const Color brandColor = Color(0xFF077A4B);
  final Set<String> _completedBatches = {};

  // ✅ Fungsi untuk mengelompokkan menu yang identik
  Map<String, List<BatchItem>> _groupIdenticalItems() {
    final Map<String, List<BatchItem>> grouped = {};

    for (var order in widget.orders) {
      for (var item in order.items) {
        // Buat key unik berdasarkan nama menu + addons + toppings + notes
        final addonsKey = item.addons?.map((a) => a['name']).join(',') ?? '';
        final toppingsKey = item.toppings?.map((t) => t['name']).join(',') ?? '';
        final notesKey = item.notes ?? '';

        final key = '${item.name}|$addonsKey|$toppingsKey|$notesKey';

        if (!grouped.containsKey(key)) {
          grouped[key] = [];
        }

        grouped[key]!.add(BatchItem(
          orderId: order.orderId ?? '',
          orderName: order.name,
          tableNumber: order.table,
          menuName: item.name,
          quantity: item.qty,
          addons: item.addons,
          toppings: item.toppings,
          notes: item.notes,
        ));
      }
    }

    // Filter hanya yang qty total >= 2
    return Map.fromEntries(
      grouped.entries.where((entry) {
        final totalQty = entry.value.fold(0, (sum, item) => sum + item.quantity);
        return totalQty >= 2;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedItems = _groupIdenticalItems();

    if (groupedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada menu yang bisa dibuat batch',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Batch cooking hanya tersedia untuk pesanan identik',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: brandColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: brandColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: brandColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.group_work,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mode Batch Cooking',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Masak ${groupedItems.length} menu secara bersamaan untuk efisiensi maksimal',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Batch Items List
          ...groupedItems.entries.map((entry) {
            final items = entry.value;
            final totalQty = items.fold(0, (sum, item) => sum + item.quantity);
            final isCompleted = _completedBatches.contains(entry.key);

            return _buildBatchCard(
              items: items,
              totalQty: totalQty,
              isCompleted: isCompleted,
              onComplete: () {
                setState(() {
                  _completedBatches.add(entry.key);
                });

                // Trigger callback dengan list order IDs
                final orderIds = items.map((item) => item.orderId).toSet().toList();
                widget.onBatchComplete(orderIds);
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBatchCard({
    required List<BatchItem> items,
    required int totalQty,
    required bool isCompleted,
    required VoidCallback onComplete,
  }) {
    final firstItem = items.first;
    final _ = items.map((i) => '${i.orderName} (${i.tableNumber})').toSet().toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? brandColor : Colors.grey.shade200,
          width: isCompleted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - HAPUS InkWell/GestureDetector di sini
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isCompleted ? brandColor.withOpacity(0.1) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Checkbox dengan absorb pointer untuk isolasi
                AbsorbPointer(
                  absorbing: isCompleted,
                  child: Checkbox(
                    value: isCompleted,
                    onChanged: (_) => onComplete(),
                    // ... rest of checkbox properties
                  ),
                ),
                const SizedBox(width: 12),

                // Menu Info - buat non-clickable
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstItem.menuName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isCompleted ? Colors.grey : Colors.black87,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: brandColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Total: $totalQty porsi',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: brandColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),

          // Divider
          Divider(color: Colors.grey.shade200, height: 1),

          // Details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Addons & Toppings
                if (firstItem.addons != null && firstItem.addons!.isNotEmpty ||
                    firstItem.toppings != null && firstItem.toppings!.isNotEmpty) ...[
                  const Text(
                    'Modifikasi:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (firstItem.addons != null)
                        ...firstItem.addons!.map((addon) => _buildChip(addon['name'] ?? '')),
                      if (firstItem.toppings != null)
                        ...firstItem.toppings!.map((topping) => _buildChip(topping['name'] ?? '')),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Notes
                if (firstItem.notes != null && firstItem.notes!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            firstItem.notes!,
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Orders breakdown
                const Text(
                  'Untuk pesanan:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: brandColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item.orderName} (Meja ${item.tableNumber}) - ${item.quantity}x',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),

          // Complete Button
          if (!isCompleted)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onComplete,
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
                        'Selesai Masak Batch',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: brandColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: brandColor.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: brandColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Model helper untuk batch item
class BatchItem {
  final String orderId;
  final String orderName;
  final String tableNumber;
  final String menuName;
  final int quantity;
  final List<Map<String, dynamic>>? addons;
  final List<Map<String, dynamic>>? toppings;
  final String? notes;

  BatchItem({
    required this.orderId,
    required this.orderName,
    required this.tableNumber,
    required this.menuName,
    required this.quantity,
    this.addons,
    this.toppings,
    this.notes,
  });
}