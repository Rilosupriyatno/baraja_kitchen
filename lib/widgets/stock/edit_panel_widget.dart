// widgets/stock/edit_panel_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/stock_menu.dart';

class EditPanelWidget extends StatelessWidget {
  final double width;
  final Set<String> selectedMenuIds;
  final Map<String, TextEditingController> stockControllers;
  final Map<String, int> pendingUpdates;
  final Map<String, Map<String, dynamic>> unsyncedChanges;
  final Map<String, List<StockMenu>> menuCache;
  final String? selectedCategoryId;
  final String workstation;
  final Color brandColor;
  final Function(String, int) onUpdateStock;
  final VoidCallback onClearSelection;
  final VoidCallback onSave;

  const EditPanelWidget({
    super.key,
    required this.width,
    required this.selectedMenuIds,
    required this.stockControllers,
    required this.pendingUpdates,
    required this.unsyncedChanges,
    required this.menuCache,
    required this.selectedCategoryId,
    required this.workstation,
    required this.brandColor,
    required this.onUpdateStock,
    required this.onClearSelection,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: _buildEditPanel(),
    );
  }

  Widget _buildEditPanel() {
    if (selectedMenuIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Pilih menu untuk\nmengedit stok',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Ambil SEMUA menu dari cache (tidak terpengaruh filter pencarian)
    final allMenus = selectedCategoryId != null
        ? (menuCache[selectedCategoryId!] ?? [])
        : <StockMenu>[];

    final selectedMenus = allMenus
        .where((menu) => selectedMenuIds.contains(menu.menuItemId))
        .toList();

    final bool hasButton = pendingUpdates.isNotEmpty || selectedMenuIds.isNotEmpty;
    final double bottomPadding = hasButton ? 80.0 : 12.0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: workstation == 'bar'
              ? Colors.blue[100]
              : brandColor.withOpacity(0.1),
          child: Row(
            children: [
              Icon(
                Icons.edit,
                size: 18,
                color: workstation == 'bar' ? Colors.blue[700] : brandColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Edit Stok (${selectedMenuIds.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: workstation == 'bar' ? Colors.blue[700] : brandColor,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onClearSelection,
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Batal', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 12,
              bottom: bottomPadding,
            ),
            itemExtent: 120,
            cacheExtent: 300,
            itemCount: selectedMenus.length,
            itemBuilder: (context, index) {
              final menu = selectedMenus[index];
              final controller = stockControllers[menu.menuItemId];

              if (controller == null) {
                return const SizedBox.shrink();
              }

              final hasUnsyncedChange = unsyncedChanges.containsKey(menu.menuItemId);
              final hasPendingUpdate = pendingUpdates.containsKey(menu.menuItemId);

              return _EditStockCard(
                key: ValueKey(menu.menuItemId),
                menu: menu,
                controller: controller,
                hasUnsyncedChange: hasUnsyncedChange,
                hasPendingUpdate: hasPendingUpdate,
                onUpdateStock: onUpdateStock,
              );
            },
          ),
        ),
        if (selectedMenuIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 48),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: pendingUpdates.isEmpty ? null : onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                icon: const Icon(Icons.save),
                label: Text(
                  pendingUpdates.isEmpty
                      ? 'Tidak Ada Perubahan'
                      : 'Simpan Sementara (${pendingUpdates.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EditStockCard extends StatefulWidget {
  final StockMenu menu;
  final TextEditingController controller;
  final bool hasUnsyncedChange;
  final bool hasPendingUpdate;
  final Function(String, int) onUpdateStock;

  const _EditStockCard({
    super.key,
    required this.menu,
    required this.controller,
    required this.hasUnsyncedChange,
    required this.hasPendingUpdate,
    required this.onUpdateStock,
  });

  @override
  State<_EditStockCard> createState() => _EditStockCardState();
}

class _EditStockCardState extends State<_EditStockCard> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.menu.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.hasUnsyncedChange)
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
            const SizedBox(height: 8),
            TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                labelText: 'Stok Baru',
                labelStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
                suffixIcon: widget.hasPendingUpdate
                    ? const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 18,
                )
                    : null,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: const TextStyle(fontSize: 14),
              onChanged: (value) {
                final newStock = int.tryParse(value);
                if (newStock != null) {
                  widget.onUpdateStock(widget.menu.menuItemId, newStock);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}