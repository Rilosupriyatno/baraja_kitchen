// screens/menu_list_screen.dart
import 'package:flutter/material.dart';
import '../services/stockmenu_service.dart';
import '../models/stock_menu.dart';

class MenuListScreen extends StatefulWidget {
  final String workstation;
  final String categoryId;
  final String categoryName;

  const MenuListScreen({
    super.key,
    required this.workstation,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<MenuListScreen> createState() => _MenuListScreenState();
}

class _MenuListScreenState extends State<MenuListScreen> {
  List<StockMenu> _menus = [];
  List<StockMenu> _filteredMenus = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final Map<String, TextEditingController> _stockControllers = {};
  final TextEditingController _searchController = TextEditingController();
  final Color _brandColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _loadMenus();
    _searchController.addListener(_filterMenus);
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (var controller in _stockControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMenus() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final categoryWithMenus = await StockMenuService.getMenusByCategoryAndWorkstation(
        widget.categoryId,
        widget.workstation,
      );

      final allMenus = categoryWithMenus.menus;

      // Urutkan menu berdasarkan nama A-Z
      allMenus.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Initialize controllers
      for (var menu in allMenus) {
        _stockControllers[menu.menuItemId] = TextEditingController(
          text: menu.manualStock.toString(),
        );
      }

      setState(() {
        _menus = allMenus;
        _filteredMenus = allMenus;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterMenus() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMenus = _menus;
      } else {
        _filteredMenus = _menus
            .where((menu) => menu.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _updateStock(String menuItemId, String menuName) async {
    final controller = _stockControllers[menuItemId];
    if (controller == null) return;

    try {
      final newStock = int.tryParse(controller.text) ?? 0;

      final success = await StockMenuService.updateManualStock(
        menuItemId,
        newStock,
        adjustedBy: 'user',
        adjustmentNote: 'Stock adjustment from mobile app',
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stok $menuName berhasil diupdate'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        _loadMenus();
      } else {
        throw Exception('Update failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal update stok: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadMenus();
    }
  }

  Widget _buildStockInfoCard(StockMenu menu) {
    final isLowStock = menu.effectiveStock <= 10;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header dengan nama menu
            Row(
              children: [
                Expanded(
                  child: Text(
                    menu.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Status stok
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLowStock ? Colors.orange.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isLowStock ? Colors.orange.shade300 : Colors.green.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLowStock ? Icons.warning_amber_rounded : Icons.check_circle,
                        size: 16,
                        color: isLowStock ? Colors.orange.shade700 : Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${menu.effectiveStock}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isLowStock ? Colors.orange.shade800 : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Kalkulasi Stok dalam Row
            Row(
              children: [
                Expanded(
                  child: _buildCompactStockItem(
                    'Kalkulasi',
                    menu.calculatedStock.toString(),
                    Icons.calculate_outlined,
                    Colors.blue.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactStockItem(
                    'Manual',
                    menu.manualStock.toString(),
                    Icons.edit_outlined,
                    Colors.orange.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactStockItem(
                    'Efektif',
                    menu.effectiveStock.toString(),
                    Icons.inventory_2,
                    _brandColor,
                    isBold: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Input Update Stok
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _stockControllers[menu.menuItemId],
                    decoration: InputDecoration(
                      labelText: 'Update Stok',
                      labelStyle: TextStyle(fontSize: 13),
                      hintText: 'Jumlah',
                      hintStyle: TextStyle(fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStock(menu.menuItemId, menu.name),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text(
                      'Simpan',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStockItem(
      String title,
      String value,
      IconData icon,
      Color color, {
        bool isBold = false,
      }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 18 : 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isNotEmpty
                  ? Icons.search_off
                  : Icons.restaurant_menu_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Menu tidak ditemukan'
                  : 'Tidak ada menu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Coba kata kunci lain'
                  : 'Tidak ada menu dalam kategori ini',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Terjadi Kesalahan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadMenus,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMenus,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Memuat menu...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      )
          : _errorMessage.isNotEmpty
          ? _buildErrorState()
          : Column(
        children: [
          // Header dengan Search Bar
          Container(
            color: _brandColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari menu...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Info Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                Icon(Icons.restaurant_menu, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  '${_filteredMenus.length} dari ${_menus.length} menu',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(Icons.sort_by_alpha, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'A-Z',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // List Menu
          Expanded(
            child: _filteredMenus.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredMenus.length,
              itemBuilder: (context, index) {
                final menu = _filteredMenus[index];
                return _buildStockInfoCard(menu);
              },
            ),
          ),
        ],
      ),
    );
  }
}