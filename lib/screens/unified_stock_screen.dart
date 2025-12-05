// screens/unified_stock_screen.dart
import 'package:flutter/material.dart';
import '../services/stockmenu_service.dart';
import '../services/stock_cache_manager.dart';
import '../models/category_model.dart';
import '../models/stock_menu.dart';
import '../widgets/stock/category_list_widget.dart';
import '../widgets/stock/menu_list_widget.dart';
import '../widgets/stock/edit_panel_widget.dart';
import '../widgets/stock/loading_screen_widget.dart';
import '../widgets/stock/refresh_overlay_widget.dart';
import '../dialogs/unsynced_changes_dialog.dart';
import '../dialogs/cache_info_dialog.dart';
import '../dialogs/clear_cache_dialog.dart';

class UnifiedStockScreen extends StatefulWidget {
  final String workstation;
  final String? preSelectedCategoryId;

  const UnifiedStockScreen({
    super.key,
    required this.workstation,
    this.preSelectedCategoryId,
  });

  @override
  State<UnifiedStockScreen> createState() => _UnifiedStockScreenState();
}

class _UnifiedStockScreenState extends State<UnifiedStockScreen> {
  List<Category> _categories = [];
  final Map<String, List<StockMenu>> _menuCache = {};
  final Map<String, Map<String, dynamic>> _unsyncedChanges = {};
  List<StockMenu> _filteredMenus = [];
  Category? _selectedCategory;
  final Set<String> _selectedMenuIds = {};
  final Map<String, TextEditingController> _stockControllers = {};
  final Map<String, int> _pendingUpdates = {};

  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingFromCache = false;
  double _loadingProgress = 0.0;
  String _loadingMessage = '';

  final TextEditingController _searchController = TextEditingController();
  final Color _brandColor = Color(0xFF077A4B);

  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _menuScrollController = ScrollController();

  final _cacheManager = StockCacheManager();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterMenus);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryScrollController.dispose();
    _menuScrollController.dispose();
    for (var controller in _stockControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Data Loading Methods
  Future<void> _loadData() async {
    if (_cacheManager.isDataLoaded(widget.workstation)) {
      print('📦 Loading from cache for ${widget.workstation}');
      _loadFromCache();
    } else {
      print('🌐 Loading from server for ${widget.workstation}');
      await _loadAllDataFromServer();
    }
  }

  void _loadFromCache() {
    setState(() {
      _isLoadingFromCache = true;
      _loadingMessage = 'Memuat dari cache...';
    });

    final cachedCategories = _cacheManager.getCachedCategories(widget.workstation);
    final cachedMenus = _cacheManager.getAllCachedMenus(widget.workstation);

    if (cachedCategories != null && cachedMenus != null) {
      setState(() {
        _categories = cachedCategories;
        _menuCache.clear();
        _menuCache.addAll(cachedMenus);
        _isInitialLoading = false;
        _isLoadingFromCache = false;

        if (widget.preSelectedCategoryId != null && _categories.isNotEmpty) {
          try {
            _selectedCategory = _categories.firstWhere(
                  (cat) => cat.id == widget.preSelectedCategoryId,
            );
          } catch (e) {
            _selectedCategory = _categories.first;
          }
        } else if (_categories.isNotEmpty) {
          _selectedCategory = _categories.first;
        }

        _displayMenusFromCache();

        if (widget.preSelectedCategoryId != null && _selectedCategory != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToSelectedCategory();
          });
        }
      });
    } else {
      _loadAllDataFromServer();
    }
  }

  Future<void> _loadAllDataFromServer() async {
    setState(() {
      _isInitialLoading = true;
      _loadingProgress = 0.0;
      _loadingMessage = 'Memuat kategori...';
    });

    try {
      final categories = await StockMenuService.getCategoriesByWorkstation(widget.workstation);
      categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (mounted) {
        setState(() {
          _categories = categories;
          _loadingProgress = 0.1;
        });
      }

      _cacheManager.saveCategories(widget.workstation, categories);
      _menuCache.clear();
      final totalCategories = categories.length;

      if (mounted) {
        setState(() {
          _loadingMessage = 'Memuat semua menu...';
        });
      }

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
              _loadingMessage = 'Memuat menu... (${index + 1}/$totalCategories)';
            });
          }

          return MapEntry(category.id, menus);
        } catch (e) {
          return MapEntry(category.id, <StockMenu>[]);
        }
      }).toList();

      final results = await Future.wait(menuFutures);

      for (var entry in results) {
        _menuCache[entry.key] = entry.value;
      }

      _cacheManager.saveAllMenus(widget.workstation, Map.from(_menuCache));
      _cacheManager.markAsLoaded(widget.workstation);

      if (mounted) {
        setState(() {
          _loadingProgress = 1.0;
          _loadingMessage = 'Selesai!';
          _isInitialLoading = false;

          if (widget.preSelectedCategoryId != null && categories.isNotEmpty) {
            try {
              _selectedCategory = categories.firstWhere(
                    (cat) => cat.id == widget.preSelectedCategoryId,
              );
            } catch (e) {
              _selectedCategory = categories.first;
            }
          } else if (categories.isNotEmpty) {
            _selectedCategory = categories.first;
          }

          _displayMenusFromCache();

          if (widget.preSelectedCategoryId != null && _selectedCategory != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToSelectedCategory();
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
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
      final categories = await StockMenuService.getCategoriesByWorkstation(widget.workstation);
      categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (mounted) {
        setState(() {
          _categories = categories;
          _loadingProgress = 0.1;
        });
      }

      _cacheManager.saveCategories(widget.workstation, categories);
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
          return MapEntry(category.id, <StockMenu>[]);
        }
      }).toList();

      final results = await Future.wait(menuFutures);

      for (var entry in results) {
        _menuCache[entry.key] = entry.value;
      }

      _cacheManager.saveAllMenus(widget.workstation, Map.from(_menuCache));

      if (mounted) {
        setState(() {
          _loadingProgress = 1.0;
          _isRefreshing = false;

          if (_selectedCategory != null) {
            _displayMenusFromCache();
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Data berhasil diperbarui'),
              ],
            ),
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

  // UI Helper Methods
  void _displayMenusFromCache() {
    if (_selectedCategory == null) return;

    final menus = _menuCache[_selectedCategory!.id] ?? [];

    print('📋 Displaying ${menus.length} menus from cache');

    // Bersihkan controllers yang lama
    for (var controller in _stockControllers.values) {
      controller.dispose();
    }
    _stockControllers.clear();

    // Inisialisasi controller dengan nilai yang benar
    for (var menu in menus) {
      // Cek apakah menu ini ada di unsyncedChanges
      int initialStock;
      if (_unsyncedChanges.containsKey(menu.menuItemId)) {
        // Jika ada di unsyncedChanges, gunakan newStock dari sana
        initialStock = _unsyncedChanges[menu.menuItemId]!['newStock'];
        print('  📝 ${menu.name}: using unsyncedChanges value = $initialStock');
      } else {
        // Jika tidak, gunakan manualStock dari menu
        initialStock = menu.manualStock;
        print('  📦 ${menu.name}: using cache value = $initialStock');
      }

      _stockControllers[menu.menuItemId] = TextEditingController(
        text: initialStock.toString(),
      );
    }

    setState(() {
      _filteredMenus = menus;
    });

    _filterMenus();
  }

  void _refreshControllers() {
    if (_selectedCategory == null) return;

    print('🔄 Refreshing controllers...');

    // Hapus pending updates untuk item yang sudah tidak ada di unsyncedChanges
    _pendingUpdates.removeWhere((key, value) => !_unsyncedChanges.containsKey(key));

    // Refresh display untuk update controller values
    _displayMenusFromCache();
  }

  void _filterMenus() {
    if (_selectedCategory == null) return;

    final menus = _menuCache[_selectedCategory!.id] ?? [];
    final query = _searchController.text.toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredMenus = menus;
      } else {
        _filteredMenus = menus.where((menu) => menu.name.toLowerCase().contains(query)).toList();
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

    _displayMenusFromCache();
  }

  void _scrollToSelectedCategory() {
    if (_selectedCategory == null) return;

    final index = _categories.indexWhere((cat) => cat.id == _selectedCategory!.id);
    if (index >= 0 && _categoryScrollController.hasClients) {
      const double itemHeight = 80.0;
      final double offset = index * itemHeight;

      _categoryScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
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

  Future<void> _saveToCache() async {
    if (_pendingUpdates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada perubahan untuk disimpan'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final timestamp = DateTime.now();

    for (var entry in _pendingUpdates.entries) {
      final menuItemId = entry.key;
      final newStock = entry.value;

      final menu = _filteredMenus.firstWhere((m) => m.menuItemId == menuItemId);

      final oldStock = _unsyncedChanges.containsKey(menuItemId)
          ? _unsyncedChanges[menuItemId]!['oldStock']
          : menu.manualStock;

      _unsyncedChanges[menuItemId] = {
        'menuName': menu.name,
        'oldStock': oldStock,
        'newStock': newStock,
        'timestamp': timestamp,
      };

      menu.manualStock = newStock;
      _cacheManager.updateMenuItem(widget.workstation, _selectedCategory!.id, menu);
    }

    setState(() {
      _selectedMenuIds.clear();
      _pendingUpdates.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_unsyncedChanges.length} perubahan disimpan ke data sementara'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Lihat',
          textColor: Colors.white,
          onPressed: () => showUnsyncedChangesDialog(
            context: context,
            unsyncedChanges: _unsyncedChanges,
            onUpdate: () {
              setState(() {});
              _refreshControllers();
            },
            onRefresh: _refreshData,
            cacheManager: _cacheManager,
            workstation: widget.workstation,
            currentCategoryId: _selectedCategory?.id,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return LoadingScreenWidget(
        workstation: widget.workstation,
        isLoadingFromCache: _isLoadingFromCache,
        loadingProgress: _loadingProgress,
        loadingMessage: _loadingMessage,
        brandColor: _brandColor,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('Manajemen Stok - ${widget.workstation}'),
            const SizedBox(width: 12),
            if (_cacheManager.isDataLoaded(widget.workstation))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cached, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Cached', style: TextStyle(fontSize: 11, color: Colors.white)),
                  ],
                ),
              ),
          ],
        ),
        backgroundColor: widget.workstation == 'bar' ? Colors.blue[700] : _brandColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.storage),
                if (_unsyncedChanges.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${_unsyncedChanges.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => showUnsyncedChangesDialog(
              context: context,
              unsyncedChanges: _unsyncedChanges,
              onUpdate: () {
                setState(() {});
                _refreshControllers();
              },
              onRefresh: _refreshData,
              cacheManager: _cacheManager,
              workstation: widget.workstation,
              currentCategoryId: _selectedCategory?.id,
            ),
            tooltip: 'Lihat Data Sementara',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
            tooltip: 'Refresh Data',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'clear_cache') {
                showClearCacheDialog(
                  context: context,
                  cacheManager: _cacheManager,
                  workstation: widget.workstation,
                );
              } else if (value == 'cache_info') {
                showCacheInfoDialog(
                  context: context,
                  cacheManager: _cacheManager,
                  workstation: widget.workstation,
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'cache_info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 8),
                    Text('Info Cache'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_cache',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Hapus Cache', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final double categoryWidth = constraints.maxWidth * 0.2;
              final double editWidth = constraints.maxWidth * 0.3;

              return Row(
                children: [
                  CategoryListWidget(
                    width: categoryWidth.clamp(150.0, 250.0),
                    categories: _categories,
                    selectedCategory: _selectedCategory,
                    preSelectedCategoryId: widget.preSelectedCategoryId,
                    menuCache: _menuCache,
                    workstation: widget.workstation,
                    brandColor: _brandColor,
                    scrollController: _categoryScrollController,
                    onCategorySelected: _selectCategory,
                  ),
                  Expanded(
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
                        Expanded(
                          child: MenuListWidget(
                            filteredMenus: _filteredMenus,
                            selectedMenuIds: _selectedMenuIds,
                            unsyncedChanges: _unsyncedChanges,
                            searchText: _searchController.text,
                            workstation: widget.workstation,
                            brandColor: _brandColor,
                            scrollController: _menuScrollController,
                            onToggleSelection: _toggleMenuSelection,
                          ),
                        ),
                      ],
                    ),
                  ),
                  EditPanelWidget(
                    width: editWidth.clamp(200.0, 350.0),
                    selectedMenuIds: _selectedMenuIds,
                    filteredMenus: _filteredMenus,
                    stockControllers: _stockControllers,
                    pendingUpdates: _pendingUpdates,
                    unsyncedChanges: _unsyncedChanges,
                    workstation: widget.workstation,
                    brandColor: _brandColor,
                    onUpdateStock: _updatePendingStock,
                    onClearSelection: () {
                      setState(() {
                        _selectedMenuIds.clear();
                        _pendingUpdates.clear();
                      });
                    },
                    onSave: _saveToCache,
                  ),
                ],
              );
            },
          ),
          RefreshOverlayWidget(
            isRefreshing: _isRefreshing,
            loadingProgress: _loadingProgress,
            loadingMessage: _loadingMessage,
            workstation: widget.workstation,
            brandColor: _brandColor,
          ),
        ],
      ),
    );
  }
}