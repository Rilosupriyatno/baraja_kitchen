// ignore: file_names
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/stock_menu.dart';
import '../services/stockmenu_service.dart';

class Updatestock {
  static void show({
    required BuildContext context,
    required StockMenu stock,
    required VoidCallback onSuccess,
    Color brandColor = Colors.blue,
    String? adjustedBy,
  }) {
    // Gunakan calculatedStock sebagai default value
    final TextEditingController manualStockController = TextEditingController(
      text: (stock.manualStock != 0
          ? stock.manualStock
          : stock.calculatedStock).toString(),
    );
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: brandColor.withOpacity(0.1),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: brandColor),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Edit Stok Manual',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content (Scrollable)
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nama Produk
                        Text(
                          stock.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),

                        // Kategori
                        Text(
                          'Kategori: ${stock.category}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 16),

                        // Input Stok Manual
                        TextField(
                          controller: manualStockController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Stok Manual',
                            hintText: 'Masukkan jumlah stok',
                            helperText: 'Default: Kalkulasi Stok (${stock.calculatedStock})',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: Icon(
                              Icons.inventory,
                              color: brandColor,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: brandColor,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            if (kDebugMode) {
                              print('User mengetik: $value');
                            }
                          },
                        ),
                        SizedBox(height: 12),

                        // Input Catatan
                        TextField(
                          controller: noteController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Catatan (Opsional)',
                            hintText: 'Alasan penyesuaian stok...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: Icon(
                              Icons.notes,
                              color: Colors.grey.shade600,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: brandColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),

                        // Info Stok
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            children: [
                              _buildInfoRow(
                                'Kalkulasi Stok:',
                                stock.calculatedStock.toString(),
                                Colors.black87,
                              ),
                              SizedBox(height: 8),
                              _buildInfoRow(
                                'Stok Efektif:',
                                stock.effectiveStock.toString(),
                                stock.effectiveStock > 10
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Actions
                Container(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          if (kDebugMode) {
                            print('[CANCEL] User membatalkan update');
                          }
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Batal',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final inputText = manualStockController.text;
                          final note = noteController.text.trim();
                          final newStock = int.tryParse(inputText);

                          if (newStock == null) {
                            if (kDebugMode) {
                              print(
                                '[VALIDATION] Input bukan angka valid: "$inputText"',
                              );
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Masukkan angka yang valid'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (newStock < 0) {
                            if (kDebugMode) {
                              print('[VALIDATION] Stok negatif: $newStock');
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Stok tidak boleh negatif'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (kDebugMode) {
                            print('[VALIDATION] Valid - New stock: $newStock');
                          }

                          // Show loading
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) =>
                                Center(child: CircularProgressIndicator()),
                          );

                          try {
                            final success =
                            await StockmenuService.updateManualStock(
                              stock.menuItemId,
                              newStock,
                              adjustmentNote: note.isEmpty ? null : note,
                              adjustedBy: adjustedBy,
                            );

                            // Close loading dialog
                            Navigator.pop(context);

                            if (success) {
                              if (kDebugMode) {
                                print('[SUCCESS] Stock updated successfully');
                              }

                              // Close edit dialog
                              Navigator.pop(context);

                              // Callback untuk refresh data
                              onSuccess();

                              // Show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Stok berhasil diupdate'),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              if (kDebugMode) {
                                print('[FAILED] API returned false');
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.error, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text('Gagal update stok'),
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (kDebugMode) {
                              print('[ERROR] Exception: $e');
                            }

                            // Close loading dialog
                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.toString()}'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Simpan',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}