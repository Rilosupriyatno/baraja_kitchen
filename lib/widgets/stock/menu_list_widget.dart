// widgets/stock/menu_list_widget.dart
import 'package:flutter/material.dart';
import '../../models/stock_menu.dart';

class MenuListWidget extends StatelessWidget {
  final List<StockMenu> filteredMenus;
  final Set<String> selectedMenuIds;
  final Map<String, Map<String, dynamic>> unsyncedChanges;
  final String searchText;
  final String workstation;
  final Color brandColor;
  final ScrollController scrollController;
  final Function(String) onToggleSelection;

  const MenuListWidget({
    super.key,
    required this.filteredMenus,
    required this.selectedMenuIds,
    required this.unsyncedChanges,
    required this.searchText,
    required this.workstation,
    required this.brandColor,
    required this.scrollController,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    if (filteredMenus.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              searchText.isNotEmpty ? 'Menu tidak ditemukan' : 'Tidak ada menu',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: filteredMenus.length,
      itemBuilder: (context, index) {
        final menu = filteredMenus[index];
        final isSelected = selectedMenuIds.contains(menu.menuItemId);
        final isLowStock = menu.manualStock <= 10;
        final hasUnsyncedChange = unsyncedChanges.containsKey(menu.menuItemId);

        return Card(
          elevation: isSelected ? 3 : 1,
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected
                  ? (workstation == 'bar' ? Colors.blue[700]! : brandColor)
                  : (hasUnsyncedChange ? Colors.orange : Colors.transparent),
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: () => onToggleSelection(menu.menuItemId),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onToggleSelection(menu.menuItemId),
                    activeColor: workstation == 'bar' ? Colors.blue[700] : brandColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                menu.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasUnsyncedChange)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'SEMENTARA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildStockBadge(
                              'Manual',
                              menu.manualStock,
                              isLowStock
                                  ? Colors.red.shade600
                                  : Colors.green.shade600,
                            ),
                            const SizedBox(width: 4),
                            _buildStockBadge(
                              'Kalkulasi',
                              menu.calculatedStock,
                              Colors.orange.shade600,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStockBadge(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}