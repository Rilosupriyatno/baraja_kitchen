// screens/unified_stock_screen.dart
import 'dart:async';
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

  // Continue load state
  bool _canContinueLoad = false;
  int _lastLoadedCategoryIndex = -1;

  final TextEditingController _searchController = TextEditingController();
  final Color _brandColor = Color(0xFF077A4B);

  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _menuScrollController = ScrollController();

  final _cacheManager = StockCacheManager();

  // Debounce timer untuk search
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    print('🔍 Search changed: "${_searchController.text}"');
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      print('⏱️ Debounce completed, calling _filterMenus()');
      _filterMenus();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _categoryScrollController.dispose();
    _menuScrollController.dispose();
    for (var controller in _stockControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Data Loading Methods
  // ⚡ OPTIMIZED: Try single-call first, fallback to legacy if fails
  Future<void> _loadData() async {
    if (_cacheManager.isDataLoaded(widget.workstation)) {
      print('📦 Loading from cache for ${widget.workstation}');
      _loadFromCache();
    } else {
      print('⚡ [OPTIMIZED] Trying single-call load for ${widget.workstation}');
      
      // Try optimized endpoint first
      final optimizedData = await StockMenuService.getAllWorkstationData(widget.workstation);
      
      if (optimizedData != null) {
        // SUCCESS: Use optimized data
        _loadFromOptimizedData(optimizedData);
      } else {
        // FALLBACK: Use legacy sequential loading
        print('⚠️ Optimized endpoint failed, falling back to legacy load...');
        await _loadAllDataFromServer();
      }
    }
  }

  // ⚡ OPTIMIZED: Load from single-call optimized data
  void _loadFromOptimizedData(WorkstationData data) {
    setState(() {
      _isInitialLoading = true;
      _loadingProgress = 0.5;
      _loadingMessage = 'Memproses data...';
    });

    // Convert WorkstationData to local format
    _categories = data.categories.map((c) => c.category).toList();
    _menuCache.clear();
    
    for (final categoryWithMenus in data.categories) {
      _menuCache[categoryWithMenus.category.id] = categoryWithMenus.menus;
    }

    // Save to cache for next time
    _cacheManager.saveCategories(widget.workstation, _categories);
    _cacheManager.saveAllMenus(widget.workstation, Map.from(_menuCache));
    _cacheManager.markAsLoaded(widget.workstation);

    setState(() {
      _loadingProgress = 1.0;
      _loadingMessage = 'Selesai!';
      _isInitialLoading = false;

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

    print('✅ [OPTIMIZED] Data loaded: ${data.totalMenus} menus, ${data.totalCategories} categories');
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

  Future<void> _loadAllDataFromServer({bool isContinue = false}) async {
    setState(() {
      _isInitialLoading = true;
      if (!isContinue) {
        _loadingProgress = 0.0;
        _lastLoadedCategoryIndex = -1;
      }
      _loadingMessage = isContinue ? 'Melanjutkan download...' : 'Memuat kategori...';
      _canContinueLoad = false;
    });

    try {
      // Load categories jika belum ada atau bukan continue
      if (_categories.isEmpty || !isContinue) {
        final categories = await StockMenuService.getCategoriesByWorkstation(widget.workstation);
        categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        if (mounted) {
          setState(() {
            _categories = categories;
            _loadingProgress = 0.1;
          });
        }

        _cacheManager.saveCategories(widget.workstation, categories);

        if (!isContinue) {
          _menuCache.clear();
        }
      }

      final totalCategories = _categories.length;
      final startIndex = isContinue ? _lastLoadedCategoryIndex + 1 : 0;

      if (mounted) {
        setState(() {
          _loadingMessage = isContinue
              ? 'Melanjutkan dari kategori ${startIndex + 1}/$totalCategories...'
              : 'Memuat semua menu...';
        });
      }

      // Load menu per kategori dengan error handling
      for (int index = startIndex; index < totalCategories; index++) {
        final category = _categories[index];

        try {
          final categoryWithMenus = await StockMenuService.getMenusByCategoryAndWorkstation(
            category.id,
            widget.workstation,
          );

          final menus = categoryWithMenus.menus;
          menus.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          _menuCache[category.id] = menus;

          // Save progress ke cache setiap kategori berhasil
          _cacheManager.saveMenus(widget.workstation, category.id, menus);

          if (mounted) {
            setState(() {
              _lastLoadedCategoryIndex = index;
              _loadingProgress = 0.1 + (0.9 * ((index + 1) / totalCategories));
              _loadingMessage = 'Memuat menu... (${index + 1}/$totalCategories)';
            });
          }
        } catch (e) {
          print('❌ Error loading category ${category.name}: $e');

          // Jika error, set flag untuk bisa continue
          if (mounted) {
            setState(() {
              _canContinueLoad = true;
              _isInitialLoading = false;
            });
          }

          // Show dialog untuk continue atau retry
          if (mounted) {
            final shouldContinue = await _showContinueDialog(
              'Koneksi terputus saat memuat kategori "${category.name}".\n'
                  'Progress: ${index + 1}/$totalCategories kategori',
            );

            if (shouldContinue) {
              // Continue loading
              await _loadAllDataFromServer(isContinue: true);
              return;
            } else {
              // Cancel, tampilkan data yang sudah ada
              _finalizeLoading();
              return;
            }
          }
          return;
        }
      }

      // Jika semua berhasil
      _cacheManager.saveAllMenus(widget.workstation, Map.from(_menuCache));
      _cacheManager.markAsLoaded(widget.workstation);

      _finalizeLoading();
    } catch (e) {
      print('❌ Error in _loadAllDataFromServer: $e');

      if (mounted) {
        setState(() {
          _canContinueLoad = _lastLoadedCategoryIndex >= 0;
          _isInitialLoading = false;
        });

        if (_canContinueLoad) {
          final shouldContinue = await _showContinueDialog(
            'Terjadi kesalahan saat memuat data.\n'
                'Progress: ${_lastLoadedCategoryIndex + 1}/${_categories.length} kategori',
          );

          if (shouldContinue) {
            await _loadAllDataFromServer(isContinue: true);
          } else {
            _finalizeLoading();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memuat data: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  void _finalizeLoading() {
    if (mounted) {
      setState(() {
        _loadingProgress = 1.0;
        _loadingMessage = 'Selesai!';
        _isInitialLoading = false;
        _canContinueLoad = false;

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
    }
  }

  Future<bool> _showContinueDialog(String message) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Download Terputus'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            const Text(
              'Anda dapat melanjutkan download dari posisi terakhir atau membatalkan untuk menggunakan data yang sudah tersedia.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal & Gunakan Data'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.refresh),
            label: const Text('Lanjutkan Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _loadingProgress = 0.0;
      _loadingMessage = 'Memperbarui data...';
      _lastLoadedCategoryIndex = -1;
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

      for (int index = 0; index < totalCategories; index++) {
        final category = categories[index];

        try {
          final categoryWithMenus = await StockMenuService.getMenusByCategoryAndWorkstation(
            category.id,
            widget.workstation,
          );

          final menus = categoryWithMenus.menus;
          menus.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          _menuCache[category.id] = menus;

          if (mounted) {
            setState(() {
              _loadingProgress = 0.1 + (0.9 * ((index + 1) / totalCategories));
              _loadingMessage = 'Memperbarui... (${index + 1}/$totalCategories)';
            });
          }
        } catch (e) {
          print('❌ Error refreshing category ${category.name}: $e');
          _menuCache[category.id] = [];
        }
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
    if (_selectedCategory == null) {
      print('⚠️ _displayMenusFromCache called but no category selected');
      return;
    }

    final menus = _menuCache[_selectedCategory!.id] ?? [];

    print('📋 Displaying ${menus.length} menus from cache for category: ${_selectedCategory!.name}');

    // Hapus controllers untuk menu yang tidak ada lagi
    final menuIds = menus.map((m) => m.menuItemId).toSet();

    final controllersToRemove = <String>[];
    _stockControllers.forEach((key, controller) {
      if (!menuIds.contains(key)) {
        controllersToRemove.add(key);
      }
    });

    for (var key in controllersToRemove) {
      _stockControllers[key]?.dispose();
      _stockControllers.remove(key);
      print('   🗑️ Removed controller for: $key');
    }

    // Inisialisasi controller hanya untuk menu yang belum ada
    for (var menu in menus) {
      if (!_stockControllers.containsKey(menu.menuItemId)) {
        int initialStock;
        if (_unsyncedChanges.containsKey(menu.menuItemId)) {
          initialStock = _unsyncedChanges[menu.menuItemId]!['newStock'];
          print('   🔄 ${menu.name}: using unsyncedChanges value = $initialStock');
        } else {
          initialStock = menu.manualStock;
          print('   📦 ${menu.name}: using cache value = $initialStock');
        }

        _stockControllers[menu.menuItemId] = TextEditingController(
          text: initialStock.toString(),
        );
      }
    }

    print('   Total controllers: ${_stockControllers.length}');

    // Langsung panggil filter untuk update filtered menus
    _filterMenus();
  }

  void _refreshControllers() {
    if (_selectedCategory == null) return;

    print('🔄 Refreshing controllers...');

    // Hapus pending updates untuk item yang sudah tidak ada di unsyncedChanges
    _pendingUpdates.removeWhere((key, value) => !_unsyncedChanges.containsKey(key));

    // Update controller values untuk menu yang ada di unsyncedChanges
    for (var entry in _unsyncedChanges.entries) {
      final menuId = entry.key;
      final newStock = entry.value['newStock'];

      if (_stockControllers.containsKey(menuId)) {
        _stockControllers[menuId]!.text = newStock.toString();
      }
    }

    // Refresh filtered menus
    _filterMenus();
  }

  void _filterMenus() {
    if (_selectedCategory == null) {
      print('⚠️ _filterMenus called but no category selected');
      return;
    }

    final menus = _menuCache[_selectedCategory!.id] ?? [];
    final query = _searchController.text.toLowerCase().trim();

    print('🔍 Filtering menus:');
    print('   Category: ${_selectedCategory!.name}');
    print('   Query: "$query"');
    print('   Total menus in cache: ${menus.length}');
    print('   _filteredMenus before: ${_filteredMenus.length}');

    setState(() {
      if (query.isEmpty) {
        _filteredMenus = menus;
        print('   ✅ No filter applied, showing all ${menus.length} menus');
      } else {
        _filteredMenus = menus.where((menu) {
          final matches = menu.name.toLowerCase().contains(query);
          if (matches) {
            print('   ✓ Match found: ${menu.name}');
          }
          return matches;
        }).toList();
        print('   ✅ Filter applied, showing ${_filteredMenus.length} menus');
      }
      print('   _filteredMenus after: ${_filteredMenus.length}');
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

    print('🔘 Selection toggled: $menuItemId');
    print('🔘 Selected IDs: $_selectedMenuIds');
    print('⏳ Pending updates: $_pendingUpdates');
  }

  void _updatePendingStock(String menuItemId, int newStock) {
    print('📝 Update pending stock: $menuItemId = $newStock');

    final allMenus = _menuCache[_selectedCategory?.id] ?? [];
    final menu = allMenus.cast<StockMenu?>().firstWhere(
          (m) => m?.menuItemId == menuItemId,
      orElse: () => null,
    );

    if (menu == null) {
      print('   ⚠️ Menu not found in cache: $menuItemId');
      return;
    }

    final originalStock = _unsyncedChanges.containsKey(menuItemId)
        ? _unsyncedChanges[menuItemId]!['oldStock'] as int
        : menu.manualStock;

    print('   Original stock: $originalStock');
    print('   New stock: $newStock');

    setState(() {
      if (newStock != originalStock) {
        _pendingUpdates[menuItemId] = newStock;
        print('   ✅ Added to pending updates');
      } else {
        _pendingUpdates.remove(menuItemId);
        print('   🗑️ Removed from pending (same as original)');
      }
    });

    print('   Total pending: ${_pendingUpdates.length}');
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

    print('💾 Starting save process...');
    print('   Pending updates: ${_pendingUpdates.length}');
    print('   Selected category: ${_selectedCategory?.id}');

    final timestamp = DateTime.now();
    int savedCount = 0;
    int skippedCount = 0;

    final allMenus = _menuCache[_selectedCategory!.id] ?? [];
    final menuMap = <String, StockMenu>{};
    for (var menu in allMenus) {
      menuMap[menu.menuItemId] = menu;
    }

    print('   Menu cache size: ${allMenus.length}');
    print('   Menu map size: ${menuMap.length}');

    for (var entry in _pendingUpdates.entries) {
      final menuItemId = entry.key;
      final newStock = entry.value;

      print('   Processing: $menuItemId -> $newStock');

      final menu = menuMap[menuItemId];

      if (menu == null) {
        print('   ⚠️ Menu dengan ID $menuItemId tidak ditemukan dalam cache');
        skippedCount++;
        continue;
      }

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
      savedCount++;

      print('   ✅ Saved: ${menu.name} ($oldStock -> $newStock)');
    }

    print('💾 Save complete: $savedCount saved, $skippedCount skipped');

    setState(() {
      _selectedMenuIds.clear();
      _pendingUpdates.clear();
    });

    if (savedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$savedCount perubahan disimpan ke data sementara${skippedCount > 0 ? ' ($skippedCount dilewati)' : ''}'),
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak ada perubahan yang berhasil disimpan${skippedCount > 0 ? ' ($skippedCount menu tidak ditemukan)' : ''}'),
          backgroundColor: Colors.orange,
        ),
      );
    }
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
        canContinue: _canContinueLoad,
        onContinue: _canContinueLoad ? () => _loadAllDataFromServer(isContinue: true) : null,
        onCancel: _canContinueLoad ? _finalizeLoading : null,
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
                            onChanged: (value) {
                              print('📝 TextField onChanged: "$value"');
                              // Trigger rebuild untuk update suffixIcon
                              setState(() {});
                            },
                            decoration: InputDecoration(
                              hintText: 'Cari menu...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  print('🗑️ Clear button pressed');
                                  _searchController.clear();
                                  setState(() {});
                                },
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
                    stockControllers: _stockControllers,
                    pendingUpdates: _pendingUpdates,
                    unsyncedChanges: _unsyncedChanges,
                    menuCache: _menuCache,
                    selectedCategoryId: _selectedCategory?.id,
                    workstation: widget.workstation,
                    brandColor: _brandColor,
                    onUpdateStock: _updatePendingStock,
                    onClearSelection: () {
                      print('🗑️ Clearing selection...');
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