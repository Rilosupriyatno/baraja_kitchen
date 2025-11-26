// dialogs/clear_cache_dialog.dart
import 'package:flutter/material.dart';
import '../services/stock_cache_manager.dart';

void showClearCacheDialog({
  required BuildContext context,
  required StockCacheManager cacheManager,
  required String workstation,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Text('Hapus Cache?'),
        ],
      ),
      content: const Text(
        'Data akan dimuat ulang dari server saat Anda membuka halaman ini lagi. Lanjutkan?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            cacheManager.clearCache(workstation);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Cache berhasil dihapus'),
                  ],
                ),
                backgroundColor: Colors.green,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
}