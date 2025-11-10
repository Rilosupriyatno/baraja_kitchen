// widgets/out_of_stock_dialog.dart
import 'package:flutter/material.dart';
import '../models/out_of_stock_model.dart';
import '../widgets/category_selection_screen.dart';

class OutOfStockDialog extends StatefulWidget {
  final List<OutOfStockItem> outOfStockItems;
  final String workstation;
  final Color brandColor;
  final VoidCallback? onRefresh; // 🔥 TAMBAHAN: Callback untuk refresh

  const OutOfStockDialog({
    super.key,
    required this.outOfStockItems,
    required this.workstation,
    required this.brandColor,
    this.onRefresh,
  });

  @override
  State<OutOfStockDialog> createState() => _OutOfStockDialogState();
}

class _OutOfStockDialogState extends State<OutOfStockDialog> {
  // Group items by category
  Map<String, List<OutOfStockItem>> _groupByCategory() {
    final Map<String, List<OutOfStockItem>> grouped = {};

    for (var item in widget.outOfStockItems) {
      if (!grouped.containsKey(item.categoryId)) {
        grouped[item.categoryId] = [];
      }
      grouped[item.categoryId]!.add(item);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedItems = _groupByCategory();
    final outOfStockCount = widget.outOfStockItems.where((i) => i.isOutOfStock).length;
    final criticalCount = widget.outOfStockItems.where((i) => i.isCriticalStock).length;

    // 🔥 TAMBAHAN: Auto-close jika tidak ada lagi item
    if (widget.outOfStockItems.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 600,
          maxHeight: 700,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(color: Colors.red.shade200, width: 2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.warning_rounded,
                      color: Colors.red.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Peringatan Stok',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$outOfStockCount habis • $criticalCount kritis',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 🔥 TAMBAHAN: Tombol refresh manual
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.red.shade700),
                    onPressed: widget.onRefresh,
                    tooltip: 'Refresh',
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.red.shade700),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: groupedItems.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.green.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Semua Stok Aman',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tidak ada menu yang habis atau kritis',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: groupedItems.length,
                itemBuilder: (context, index) {
                  final categoryId = groupedItems.keys.elementAt(index);
                  final categoryItems = groupedItems[categoryId]!;
                  final categoryName = categoryItems.first.categoryName;

                  return _buildCategoryCard(
                    context,
                    categoryId,
                    categoryName,
                    categoryItems,
                  );
                },
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Klik kategori untuk update stok',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
      BuildContext context,
      String categoryId,
      String categoryName,
      List<OutOfStockItem> items,
      ) {
    final outOfStockInCategory = items.where((i) => i.isOutOfStock).length;
    final criticalInCategory = items.where((i) => i.isCriticalStock).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          // Close dialog
          Navigator.pop(context);

          // Navigate to category selection screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategorySelectionScreen(
                workstation: widget.workstation,
                preSelectedCategoryId: categoryId,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: widget.brandColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      categoryName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.brandColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${items.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Summary
              Row(
                children: [
                  if (outOfStockInCategory > 0) ...[
                    Icon(
                      Icons.block,
                      size: 14,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$outOfStockInCategory Habis',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (criticalInCategory > 0) ...[
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$criticalInCategory Kritis',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),

              // Items List
              ...items.take(3).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: item.isOutOfStock
                            ? Colors.red.shade400
                            : Colors.orange.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.menuItemName,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: item.isOutOfStock
                            ? Colors.red.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: item.isOutOfStock
                              ? Colors.red.shade200
                              : Colors.orange.shade200,
                        ),
                      ),
                      child: Text(
                        '${item.currentStock}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: item.isOutOfStock
                              ? Colors.red.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              )),

              if (items.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+${items.length - 3} lainnya',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
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