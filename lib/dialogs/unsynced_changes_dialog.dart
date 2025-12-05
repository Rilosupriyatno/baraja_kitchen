// dialogs/unsynced_changes_dialog.dart
import 'package:flutter/material.dart';
import '../services/stockmenu_service.dart';
import '../services/stock_cache_manager.dart';

void showUnsyncedChangesDialog({
  required BuildContext context,
  required Map<String, Map<String, dynamic>> unsyncedChanges,
  required VoidCallback onUpdate,
  required Future<void> Function() onRefresh,
  required StockCacheManager cacheManager,
  required String workstation,
  required String? currentCategoryId,
}) {
  final Set<String> editingItems = {};
  final Map<String, TextEditingController> editControllers = {};

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.storage, color: Colors.orange),
              SizedBox(width: 8),
              Text('Data Sementara'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: unsyncedChanges.isEmpty
                ? const Center(
              child: Text(
                'Tidak ada perubahan data',
                textAlign: TextAlign.center,
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              itemCount: unsyncedChanges.length,
              itemBuilder: (context, index) {
                final entry = unsyncedChanges.entries.elementAt(index);
                final menuItemId = entry.key;
                final data = entry.value;
                final isEditing = editingItems.contains(menuItemId);

                if (!editControllers.containsKey(menuItemId)) {
                  editControllers[menuItemId] = TextEditingController(
                    text: data['newStock'].toString(),
                  );
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child: Icon(
                        Icons.edit,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      data['menuName'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: isEditing
                        ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: editControllers[menuItemId],
                              keyboardType: TextInputType.number,
                              autofocus: true,
                              decoration: InputDecoration(
                                labelText: 'Stok Baru',
                                labelStyle: const TextStyle(fontSize: 11),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                isDense: true,
                                suffixText: 'dari ${data['oldStock']}',
                                suffixStyle: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.check,
                              color: Colors.green,
                              size: 20,
                            ),
                            onPressed: () {
                              final newStock = int.tryParse(
                                editControllers[menuItemId]!.text,
                              );
                              if (newStock != null) {
                                setDialogState(() {
                                  unsyncedChanges[menuItemId]!['newStock'] = newStock;
                                  editingItems.remove(menuItemId);
                                });

                                // Update stok di cache juga
                                _updateStockInCache(
                                  cacheManager,
                                  workstation,
                                  currentCategoryId,
                                  menuItemId,
                                  newStock,
                                );

                                onUpdate();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Stok sementara berhasil diperbarui'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                            tooltip: 'Simpan',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                editingItems.remove(menuItemId);
                                editControllers[menuItemId]!.text = data['newStock'].toString();
                              });
                            },
                            tooltip: 'Batal',
                          ),
                        ],
                      ),
                    )
                        : Text(
                      'Stok: ${data['oldStock']} → ${data['newStock']}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                    trailing: isEditing
                        ? null
                        : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.blue,
                            size: 20,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              editingItems.add(menuItemId);
                            });
                          },
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () {
                            // Kembalikan stok ke nilai awal sebelum dihapus
                            final oldStock = data['oldStock'];
                            _updateStockInCache(
                              cacheManager,
                              workstation,
                              currentCategoryId,
                              menuItemId,
                              oldStock,
                            );

                            unsyncedChanges.remove(menuItemId);
                            editControllers.remove(menuItemId);

                            // Trigger update dengan refresh controllers
                            onUpdate();

                            Navigator.pop(context);

                            // Tampilkan snackbar
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Stok "${data['menuName']}" dikembalikan ke $oldStock'),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 2),
                              ),
                            );

                            if (unsyncedChanges.isNotEmpty) {
                              showUnsyncedChangesDialog(
                                context: context,
                                unsyncedChanges: unsyncedChanges,
                                onUpdate: onUpdate,
                                onRefresh: onRefresh,
                                cacheManager: cacheManager,
                                workstation: workstation,
                                currentCategoryId: currentCategoryId,
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Semua data sementara telah dihapus'),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          tooltip: 'Hapus',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
            if (unsyncedChanges.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _syncToServer(context, unsyncedChanges, onRefresh);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.upload),
                label: const Text('Upload'),
              ),
          ],
        );
      },
    ),
  );
}

// Helper function untuk update stok di cache
void _updateStockInCache(
    StockCacheManager cacheManager,
    String workstation,
    String? categoryId,
    String menuItemId,
    int newStock,
    ) {
  if (categoryId == null) {
    print('❌ categoryId is null, cannot update cache');
    return;
  }

  final cachedMenus = cacheManager.getAllCachedMenus(workstation);
  if (cachedMenus == null) {
    print('❌ No cached menus for $workstation');
    return;
  }

  final categoryMenus = cachedMenus[categoryId];
  if (categoryMenus == null) {
    print('❌ No menus for category $categoryId');
    return;
  }

  // Cari menu yang akan diupdate
  bool updated = false;
  for (var menu in categoryMenus) {
    if (menu.menuItemId == menuItemId) {
      print('✅ Updating $menuItemId stock from ${menu.manualStock} to $newStock');
      menu.manualStock = newStock;
      // Update ke cache manager
      cacheManager.updateMenuItem(workstation, categoryId, menu);
      updated = true;
      break;
    }
  }

  if (!updated) {
    print('❌ Menu $menuItemId not found in category');
  }
}

Future<void> _syncToServer(
    BuildContext context,
    Map<String, Map<String, dynamic>> unsyncedChanges,
    Future<void> Function() onRefresh,
    ) async {
  if (unsyncedChanges.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tidak ada perubahan data'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Uploading ${unsyncedChanges.length} perubahan ke server...'),
            ],
          ),
        ),
      ),
    ),
  );

  final saveFutures = unsyncedChanges.entries.map((entry) async {
    try {
      final menuItemId = entry.key;
      final newStock = entry.value['newStock'];

      final success = await StockMenuService.updateManualStock(
        menuItemId,
        newStock,
        adjustedBy: 'user',
        adjustmentNote: 'Stock sync from mobile app',
      );

      return {
        'menuItemId': menuItemId,
        'success': success,
        'menuName': entry.value['menuName'],
      };
    } catch (e) {
      return {
        'menuItemId': entry.key,
        'success': false,
        'error': e.toString(),
        'menuName': entry.value['menuName'],
      };
    }
  }).toList();

  final results = await Future.wait(saveFutures);

  final successList = results.where((r) => r['success'] == true).toList();
  final failList = results.where((r) => r['success'] == false).toList();

  for (var result in successList) {
    unsyncedChanges.remove(result['menuItemId']);
  }

  if (context.mounted) {
    Navigator.of(context).pop();
  }

  if (context.mounted) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hasil Upload'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '✅ Berhasil: ${successList.length}',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (failList.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '❌ Gagal: ${failList.length}',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Item gagal:'),
              ...failList.map((f) => Text('• ${f['menuName']}')),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (successList.isNotEmpty) {
      await onRefresh();
    }
  }
}