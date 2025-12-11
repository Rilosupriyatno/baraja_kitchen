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

                            // Hapus dari unsyncedChanges
                            setDialogState(() {
                              unsyncedChanges.remove(menuItemId);
                              editControllers.remove(menuItemId);
                            });

                            // Trigger update parent
                            onUpdate();

                            // Tampilkan snackbar
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Stok "${data['menuName']}" dikembalikan ke $oldStock'),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 2),
                              ),
                            );

                            // Jika tidak ada data lagi, tutup dialog
                            if (unsyncedChanges.isEmpty) {
                              Navigator.pop(context);
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
                  _syncToServer(
                    context,
                    unsyncedChanges,
                    onRefresh,
                    onUpdate,
                  );
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
    VoidCallback onUpdate,
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

  // Simpan BuildContext untuk loading dialog
  BuildContext? loadingDialogContext;

  // StateSetter untuk update dialog
  late void Function(void Function()) setDialogState;

  // Tampilkan loading dialog (TANPA AWAIT!)
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      loadingDialogContext = dialogContext;
      return StatefulBuilder(
        builder: (context, setState) {
          setDialogState = setState;
          return WillPopScope(
            onWillPop: () async => false,
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        'Uploading ${unsyncedChanges.length} perubahan ke server...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  print('✅ Loading dialog shown');

  // Fungsi untuk update dialog menjadi success/error
  void updateDialogToResult(List<Map<String, dynamic>> successList, List<Map<String, dynamic>> failList) {
    try {
      if (loadingDialogContext != null && loadingDialogContext!.mounted) {
        setDialogState(() {
          // State akan diupdate di builder StatefulBuilder
        });

        // Ganti isi dialog
        Navigator.of(loadingDialogContext!).pushReplacement(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (context, _, __) => WillPopScope(
              onWillPop: () async => true,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon sukses/error
                        Icon(
                          successList.isNotEmpty ? Icons.check_circle : Icons.error,
                          color: successList.isNotEmpty ? Colors.green : Colors.red,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        // Pesan utama
                        Text(
                          successList.isNotEmpty
                              ? 'Data Berhasil Disimpan!'
                              : 'Upload Gagal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: successList.isNotEmpty ? Colors.green : Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        // Detail
                        Text(
                          successList.length == (successList.length + failList.length)
                              ? '${successList.length} item berhasil diupload'
                              : '${successList.length} berhasil, ${failList.length} gagal',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (failList.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Item gagal:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...failList.take(3).map((f) => Text(
                            '• ${f['menuName']}',
                            style: const TextStyle(fontSize: 11),
                          )),
                          if (failList.length > 3)
                            Text(
                              '... dan ${failList.length - 3} lainnya',
                              style: const TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                        const SizedBox(height: 20),
                        // Tombol
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (successList.isEmpty || failList.isNotEmpty)
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('OK'),
                              ),
                            if (successList.isNotEmpty) ...[
                              if (failList.isNotEmpty) const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Tutup'),
                              ),
                              // const SizedBox(width: 8),
                              // ElevatedButton.icon(
                              //   onPressed: () async {
                              //     Navigator.of(context).pop();
                              //     await Future.delayed(const Duration(milliseconds: 200));
                              //     print('🔄 User memilih refresh data dari server...');
                              //     await onRefresh();
                              //   },
                              //   style: ElevatedButton.styleFrom(
                              //     backgroundColor: Colors.blue,
                              //     foregroundColor: Colors.white,
                              //   ),
                              //   icon: const Icon(Icons.refresh, size: 18),
                              //   label: const Text('Refresh Data'),
                              // ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            transitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
        print('✅ Dialog updated to result');
      }
    } catch (e) {
      print('❌ Error updating dialog: $e');
    }
  }

  List<Map<String, dynamic>> results = [];

  try {
    print('🚀 Starting upload process...');

    final saveFutures = unsyncedChanges.entries.map((entry) async {
      try {
        final menuItemId = entry.key;
        final newStock = entry.value['newStock'];

        print('📤 Uploading $menuItemId: ${entry.value['menuName']} = $newStock');

        final success = await StockMenuService.updateManualStock(
          menuItemId,
          newStock,
          adjustedBy: 'user',
          adjustmentNote: 'Stock sync from mobile app',
        );

        print('   📊 Raw success value: $success (type: ${success.runtimeType})');
        print('   ${success ? '✅' : '❌'} Upload result for $menuItemId: $success');

        return {
          'menuItemId': menuItemId,
          'success': success == true,
          'menuName': entry.value['menuName'],
        };
      } catch (e) {
        print('   ❌ Upload error for ${entry.key}: $e');
        return {
          'menuItemId': entry.key,
          'success': false,
          'error': e.toString(),
          'menuName': entry.value['menuName'],
        };
      }
    }).toList();

    print('⏳ Waiting for all uploads to complete...');
    results = await Future.wait(saveFutures);
    print('✅ All uploads completed');

  } catch (e) {
    print('❌ Error in upload process: $e');
    results = unsyncedChanges.entries.map((entry) => {
      'menuItemId': entry.key,
      'success': false,
      'error': e.toString(),
      'menuName': entry.value['menuName'],
    }).toList();
  }

  final successList = results.where((r) => r['success'] == true).toList();
  final failList = results.where((r) => r['success'] == false).toList();

  print('📊 Upload summary:');
  print('   ✅ Success: ${successList.length}');
  print('   ❌ Failed: ${failList.length}');

  // Hapus dari unsyncedChanges untuk item yang berhasil
  for (var result in successList) {
    final menuItemId = result['menuItemId'] as String;
    print('   🗑️ Removing $menuItemId from unsyncedChanges');
    unsyncedChanges.remove(menuItemId);
  }

  print('   📦 Remaining unsyncedChanges: ${unsyncedChanges.length}');

  // SELALU update dialog ke result, apapun yang terjadi
  updateDialogToResult(successList, failList);

  // Panggil onUpdate untuk trigger setState di parent
  onUpdate();
}