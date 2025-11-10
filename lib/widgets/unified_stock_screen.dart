// screens/unified_stock_screen.dart
import 'package:flutter/material.dart';
import '../services/stockmenu_service.dart';
import '../models/category_model.dart';
import '../models/stock_menu.dart';

class UnifiedStockScreen extends StatefulWidget {
  final String workstation;

  const UnifiedStockScreen({super.key, required this.workstation});

  @override
  State<UnifiedStockScreen> createState() => _UnifiedStockScreenState();
}

class _UnifiedStockScreenState extends State<UnifiedStockScreen> {
  List<Category> _categories = [];

  // Cache: menyimpan semua menu per kategori
  final Map<String, List<StockMenu>> _menuCache = {};

  List<StockMenu> _filteredMenus = [];

  Category? _selectedCategory;
  final Set<String> _selectedMenuIds = {};
  final Map<String, TextEditingController> _stockControllers = {};
  final Map<String, int> _pendingUpdates = {};

  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  double _loadingProgress = 0.0;
  String _loadingMessage = '';
  String _errorMessage = '';

  final TextEditingController _searchController = TextEditingController();
  final Color _brandColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _loadAllData();
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

  Future<void> _loadAllData() async {
    setState(() {
      _isInitialLoading = true;
      _loadingProgress = 0.0;
      _loadingMessage = 'Memuat kategori...';
      _errorMessage = '';
    });

    try {
      // Step 1: Load categories (10% progress)
      final categories = await StockMenuService.getCategoriesByWorkstation(widget.workstation);
      categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (mounted) {
        setState(() {
          _categories = categories;
          _loadingProgress = 0.1;
        });
      }

      // Step 2: Load all menus PARALLEL untuk semua kategori
      _menuCache.clear();
      final totalCategories = categories.length;

      if (mounted) {
        setState(() {
          _loadingMessage = 'Memuat semua menu...';
        });
      }

      // PARALLEL LOADING menggunakan Future.wait
      final menuFutures = categories.asMap().entries.map((entry) async {
        final index = entry.key;
        final category = entry.value;

        try {
          final categoryWithMenus = await StockMenuService.getMenusByCategoryAndWorkstation(
            category.id,
            widget.workstation,
          );

          final menus = categoryWithMenus.menus;
          menus.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          // Update progress secara berkala
          if (mounted) {
            setState(() {
              _loadingProgress = 0.1 + (0.9 * ((index + 1) / totalCategories));
              _loadingMessage = 'Memuat menu... (${index + 1}/$totalCategories)';
            });
          }

          return MapEntry(category.id, menus);
        } catch (e) {
          print('Error loading menus for ${category.name}: $e');
          return MapEntry(category.id, <StockMenu>[]);
        }
      }).toList();

      // Tunggu semua request selesai
      final results = await Future.wait(menuFutures);

      // Simpan ke cache
      for (var entry in results) {
        _menuCache[entry.key] = entry.value;
      }

      if (mounted) {
        setState(() {
          _loadingProgress = 1.0;
          _loadingMessage = 'Selesai!';
          _isInitialLoading = false;

          // Auto-select first category
          if (categories.isNotEmpty) {
            _selectedCategory = categories.first;
            _displayMenusFromCache();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isInitialLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _loadingProgress = 0.0;
      _loadingMessage = 'Memperbarui data...';
    });

    try {
      // Step 1: Load categories
      final categories = await StockMenuService.getCategoriesByWorkstation(widget.workstation);
      categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (mounted) {
        setState(() {
          _categories = categories;
          _loadingProgress = 0.1;
        });
      }

      // Step 2: PARALLEL LOADING untuk refresh
      _menuCache.clear();
      final totalCategories = categories.length;

      final menuFutures = categories.asMap().entries.map((entry) async {
        final index = entry.key;
        final category = entry.value;

        try {
          final categoryWithMenus = await StockMenuService.getMenusByCategoryAndWorkstation(
            category.id,
            widget.workstation,
          );

          final menus = categoryWithMenus.menus;
          menus.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          if (mounted) {
            setState(() {
              _loadingProgress = 0.1 + (0.9 * ((index + 1) / totalCategories));
              _loadingMessage = 'Memperbarui... (${index + 1}/$totalCategories)';
            });
          }

          return MapEntry(category.id, menus);
        } catch (e) {
          print('Error refreshing menus for ${category.name}: $e');
          return MapEntry(category.id, <StockMenu>[]);
        }
      }).toList();

      final results = await Future.wait(menuFutures);

      for (var entry in results) {
        _menuCache[entry.key] = entry.value;
      }

      if (mounted) {
        setState(() {
          _loadingProgress = 1.0;
          _isRefreshing = false;

          // Refresh current category display
          if (_selectedCategory != null) {
            _displayMenusFromCache();
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data berhasil diperbarui'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _displayMenusFromCache() {
    if (_selectedCategory == null) return;

    final menus = _menuCache[_selectedCategory!.id] ?? [];

    // Initialize controllers for this category's menus
    _stockControllers.clear();
    for (var menu in menus) {
      _stockControllers[menu.menuItemId] = TextEditingController(
        text: menu.manualStock.toString(),
      );
    }

    setState(() {
      _filteredMenus = menus;
    });

    // Apply search filter if exists
    _filterMenus();
  }

  void _filterMenus() {
    if (_selectedCategory == null) return;

    final menus = _menuCache[_selectedCategory!.id] ?? [];
    final query = _searchController.text.toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredMenus = menus;
      } else {
        _filteredMenus = menus
            .where((menu) => menu.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _selectCategory(Category category) {
    setState(() {
      _selectedCategory = category;
      _selectedMenuIds.clear();
      _pendingUpdates.clear();
      _searchController.clear();
    });

    // Load from cache (instant, no loading)
    _displayMenusFromCache();
  }

  void _toggleMenuSelection(String menuItemId) {
    setState(() {
      if (_selectedMenuIds.contains(menuItemId)) {
        _selectedMenuIds.remove(menuItemId);
        _pendingUpdates.remove(menuItemId);
      } else {
        _selectedMenuIds.add(menuItemId);
      }
    });
  }

  void _updatePendingStock(String menuItemId, int newStock) {
    setState(() {
      _pendingUpdates[menuItemId] = newStock;
    });
  }

  Future<void> _saveSelectedUpdates() async {
    if (_pendingUpdates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada perubahan untuk disimpan'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading dialog
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
                Text('Menyimpan ${_pendingUpdates.length} perubahan...'),
              ],
            ),
          ),
        ),
      ),
    );

    // PARALLEL SAVING untuk mempercepat proses
    final saveFutures = _pendingUpdates.entries.map((entry) async {
      try {
        final success = await StockMenuService.updateManualStock(
          entry.key,
          entry.value,
          adjustedBy: 'user',
          adjustmentNote: 'Bulk stock adjustment from mobile app',
        );
        return success ? 1 : 0;
      } catch (e) {
        return 0;
      }
    }).toList();

    final results = await Future.wait(saveFutures);
    final successCount = results.where((r) => r == 1).length;
    final failCount = results.length - successCount;

    // Close loading dialog
    if (mounted) {
      Navigator.of(context).pop();
    }

    setState(() {
      _selectedMenuIds.clear();
      _pendingUpdates.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil: $successCount, Gagal: $failCount'),
          backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
        ),
      );
    }

    // Refresh data after save untuk mendapatkan data terbaru dari server
    await _refreshData();
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 80,
                color: _brandColor.withOpacity(0.5),
              ),
              const SizedBox(height: 32),
              Text(
                'Memuat Data Stok',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _brandColor,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 300,
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _loadingProgress,
                      backgroundColor: Colors.grey.shade200,
                      color: _brandColor,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${(_loadingProgress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _brandColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loadingMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshOverlay() {
    if (!_isRefreshing) return const SizedBox.shrink();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 250,
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: _loadingProgress,
                          backgroundColor: Colors.grey.shade200,
                          color: _brandColor,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${(_loadingProgress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _brandColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _loadingMessage,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('Tidak ada kategori', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final isSelected = _selectedCategory?.id == category.id;
        final menuCount = _menuCache[category.id]?.length ?? category.itemCount;

        return Card(
          elevation: isSelected ? 4 : 1,
          color: isSelected ? _brandColor.withOpacity(0.1) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? _brandColor : Colors.transparent,
              width: 2,
            ),
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => _selectCategory(category),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                      color: isSelected ? _brandColor : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? _brandColor : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$menuCount item',
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildMenuList() {
    if (_filteredMenus.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty ? 'Menu tidak ditemukan' : 'Tidak ada menu',
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredMenus.length,
      itemBuilder: (context, index) {
        final menu = _filteredMenus[index];
        final isSelected = _selectedMenuIds.contains(menu.menuItemId);
        final isLowStock = menu.effectiveStock <= 10;

        return Card(
          elevation: isSelected ? 3 : 1,
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? _brandColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: () => _toggleMenuSelection(menu.menuItemId),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleMenuSelection(menu.menuItemId),
                    activeColor: _brandColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          menu.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildStockBadge('Manual', menu.manualStock, Colors.orange.shade600),
                            const SizedBox(width: 4),
                            _buildStockBadge('Efektif', menu.effectiveStock,
                                isLowStock ? Colors.red.shade600 : Colors.green.shade600),
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

  Widget _buildEditPanel() {
    if (_selectedMenuIds.isEmpty) {
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

    final selectedMenus = _filteredMenus
        .where((menu) => _selectedMenuIds.contains(menu.menuItemId))
        .toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: _brandColor.withOpacity(0.1),
          child: Row(
            children: [
              Icon(Icons.edit, size: 18, color: _brandColor),
              const SizedBox(width: 8),
              Text(
                'Edit Stok (${_selectedMenuIds.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _brandColor,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedMenuIds.clear();
                    _pendingUpdates.clear();
                  });
                },
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
            padding: const EdgeInsets.all(12),
            itemCount: selectedMenus.length,
            itemBuilder: (context, index) {
              final menu = selectedMenus[index];
              final controller = _stockControllers[menu.menuItemId]!;

              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        menu.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                          suffixIcon: _pendingUpdates.containsKey(menu.menuItemId)
                              ? Icon(Icons.check_circle, color: Colors.green, size: 18)
                              : null,
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14),
                        onChanged: (value) {
                          final newStock = int.tryParse(value);
                          if (newStock != null) {
                            _updatePendingStock(menu.menuItemId, newStock);
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
        Container(
          padding: const EdgeInsets.all(12),
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
              onPressed: _pendingUpdates.isEmpty ? null : _saveSelectedUpdates,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              icon: const Icon(Icons.save),
              label: Text(
                _pendingUpdates.isEmpty
                    ? 'Tidak Ada Perubahan'
                    : 'Simpan ${_pendingUpdates.length} Perubahan',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen on initial load
    if (_isInitialLoading) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Manajemen Stok - ${widget.workstation}'),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              Container(
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(
                    right: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: _brandColor.withOpacity(0.1),
                      child: Text(
                        'KATEGORI',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: _brandColor,
                        ),
                      ),
                    ),
                    Expanded(child: _buildCategoryList()),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.white,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari menu...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
                          )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          isDense: true,
                        ),
                      ),
                    ),
                    Expanded(child: _buildMenuList()),
                  ],
                ),
              ),
              Container(
                width: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: _buildEditPanel(),
              ),
            ],
          ),
          _buildRefreshOverlay(),
        ],
      ),
    );
  }
}