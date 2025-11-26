// widgets/stock/edit_panel_widget.dart
import 'package:flutter/material.dart';
import '../../models/stock_menu.dart';

class EditPanelWidget extends StatelessWidget {
  final double width;
  final Set<String> selectedMenuIds;
  final List<StockMenu> filteredMenus;
  final Map<String, TextEditingController> stockControllers;
  final Map<String, int> pendingUpdates;
  final Map<String, Map<String, dynamic>> unsyncedChanges; // TAMBAHKAN INI
  final String workstation;
  final Color brandColor;
  final Function(String, int) onUpdateStock;
  final VoidCallback onClearSelection;
  final VoidCallback onSave;

  const EditPanelWidget({
    super.key,
    required this.width,
    required this.selectedMenuIds,
    required this.filteredMenus,
    required this.stockControllers,
    required this.pendingUpdates,
    required this.unsyncedChanges, // TAMBAHKAN INI
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

    final selectedMenus = filteredMenus
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
            itemCount: selectedMenus.length,
            itemBuilder: (context, index) {
              final menu = selectedMenus[index];
              final controller = stockControllers[menu.menuItemId]!;

              // Cek apakah menu ini punya perubahan yang belum di-sync
              final hasUnsyncedChange = unsyncedChanges.containsKey(menu.menuItemId);

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
                              menu.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
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
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller,
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
                          suffixIcon: pendingUpdates.containsKey(menu.menuItemId)
                              ? const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          )
                              : null,
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14),
                        onChanged: (value) {
                          final newStock = int.tryParse(value);
                          if (newStock != null) {
                            onUpdateStock(menu.menuItemId, newStock);
                          }
                        },
                      ),
                    ],
                  ),
                ),
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