  // widgets/stock_menu_table.dart
  import 'package:flutter/material.dart';
  import '../models/stock_menu.dart';
  import 'updateStock.dart';

  class TableStockmenu extends StatelessWidget {
    final List<StockMenu> stockMenu;
    final VoidCallback onRefresh;
    final Color brandColor;

    const TableStockmenu({
      super.key,
      required this.stockMenu,
      required this.onRefresh,
      required this.brandColor,
    });

    @override
    Widget build(BuildContext context) {
      if (stockMenu.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Tidak ada data stok',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      }

      // Sort berdasarkan effectiveStock ascending (stok paling sedikit di atas)
      final sortedStock = List<StockMenu>.from(stockMenu)
        ..sort((a, b) => b.effectiveStock.compareTo(a.effectiveStock));

      return LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
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
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2, color: brandColor, size: 24),
                        const SizedBox(width: 12),
                        const Text(
                          'Daftar Stok Menu',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: brandColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${sortedStock.length} Item',
                            style: TextStyle(
                              color: brandColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Table Content
                  SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(
                          Colors.grey.shade50,
                        ),
                        columnSpacing: isDesktop ? 40 : 20,
                        horizontalMargin: 20,
                        headingRowHeight: 56,
                        dataRowHeight: 60,
                        columns: [
                          DataColumn(
                            label: Text(
                              'Produk',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Kategori',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Kalkulasi',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              'Manual',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              'Stok',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            numeric: true,
                          ),
                          const DataColumn(
                            label: Text(
                              'Aksi',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        rows: sortedStock.map((stock) {
                          final isLowStock = stock.effectiveStock <= 10;

                          return DataRow(
                            cells: [
                              DataCell(
                                Container(
                                  constraints: BoxConstraints(
                                    maxWidth: isDesktop ? 200 : 150,
                                  ),
                                  child: Text(
                                    stock.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: brandColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    stock.category,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: brandColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  stock.calculatedStock.toString(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  stock.manualStock.toString(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isLowStock
                                        ? Colors.orange.shade50
                                        : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isLowStock
                                          ? Colors.orange.shade300
                                          : Colors.green.shade300,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isLowStock
                                            ? Icons.warning_amber_rounded
                                            : Icons.check_circle_outline,
                                        size: 16,
                                        color: isLowStock
                                            ? Colors.orange.shade700
                                            : Colors.green.shade700,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        stock.effectiveStock.toString(),
                                        style: TextStyle(
                                          color: isLowStock
                                              ? Colors.orange.shade900
                                              : Colors.green.shade900,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    color: brandColor,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    Updatestock.show(
                                      context: context,
                                      stock: stock,
                                      onSuccess: onRefresh,
                                      brandColor: brandColor,
                                    );
                                  },
                                  tooltip: 'Edit Stok',
                                  style: IconButton.styleFrom(
                                    backgroundColor: brandColor.withOpacity(0.1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }