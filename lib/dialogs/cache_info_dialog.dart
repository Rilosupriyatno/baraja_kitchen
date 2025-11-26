// dialogs/cache_info_dialog.dart
import 'package:flutter/material.dart';
import '../services/stock_cache_manager.dart';

void showCacheInfoDialog({
  required BuildContext context,
  required StockCacheManager cacheManager,
  required String workstation,
}) {
  final cacheInfo = cacheManager.getCacheInfo(workstation);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue),
          SizedBox(width: 8),
          Text('Informasi Cache'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Workstation', cacheInfo['workstation']),
          _buildInfoRow('Status', cacheInfo['isLoaded'] ? 'Loaded ✅' : 'Not Loaded'),
          _buildInfoRow('Kategori', '${cacheInfo['categoriesCount']}'),
          _buildInfoRow('Total Menu', '${cacheInfo['totalMenusCount']}'),
          _buildInfoRow('Terakhir Cached', cacheInfo['lastCached']),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    ),
  );
}

Widget _buildInfoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(color: Colors.grey.shade700),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );
}