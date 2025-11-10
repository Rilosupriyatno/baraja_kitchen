// screens/category_selection_screen.dart
import 'package:baraja_bar/screens/create_menu_screen.dart';
import 'package:flutter/material.dart';
import '../services/stockmenu_service.dart';
import '../models/category_model.dart';
import 'menu_list_screen.dart';

class CategorySelectionScreen extends StatefulWidget {
  final String workstation;
  final String? preSelectedCategoryId; // TAMBAHAN: untuk auto-navigate dari notifikasi stok

  const CategorySelectionScreen({
    super.key,
    required this.workstation,
    this.preSelectedCategoryId,
  });

  @override
  State<CategorySelectionScreen> createState() => _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen> {
  List<Category> _categories = [];
  List<Category> _filteredCategories = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchController.addListener(_filterCategories);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final categories = await StockMenuService.getCategoriesByWorkstation(widget.workstation);

      // Urutkan kategori berdasarkan nama A-Z
      categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      setState(() {
        _categories = categories;
        _filteredCategories = categories;
        _isLoading = false;
      });

      // TAMBAHAN: Auto-navigate jika ada preSelectedCategoryId
      if (widget.preSelectedCategoryId != null && mounted) {
        final selectedCategory = categories.firstWhere(
              (cat) => cat.id == widget.preSelectedCategoryId,
          orElse: () => categories.isNotEmpty ? categories.first : Category(id: '', name: '', itemCount: 0),
        );

        if (selectedCategory.id.isNotEmpty) {
          // Delay sedikit agar UI tidak langsung jump
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _navigateToMenuList(selectedCategory.id, selectedCategory.name);
            }
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterCategories() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCategories = _categories;
      } else {
        _filteredCategories = _categories
            .where((category) => category.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _navigateToMenuList(String categoryId, String categoryName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MenuListScreen(
          workstation: widget.workstation,
          categoryId: categoryId,
          categoryName: categoryName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kategori - ${widget.workstation}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.workstation == 'bar') ...[
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Tambah Menu',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CreateMenuScreen()),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadCategories,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          : Column(
        children: [
          // Header dengan Search Bar
          Container(
            color: Colors.blue,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      hintText: 'Cari kategori...',
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
                Icon(Icons.category, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  '${_filteredCategories.length} dari ${_categories.length} kategori',
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

          // List Kategori
          Expanded(
            child: _filteredCategories.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Kategori tidak ditemukan',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Coba kata kunci lain',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredCategories.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final category = _filteredCategories[index];
                // TAMBAHAN: Highlight kategori yang dipilih dari notifikasi
                final isPreSelected = widget.preSelectedCategoryId == category.id;

                return Card(
                  elevation: isPreSelected ? 4 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isPreSelected ? Colors.red.shade300 : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => _navigateToMenuList(
                      category.id,
                      category.name,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Icon Kategori
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isPreSelected
                                    ? [
                                  Colors.red.shade400,
                                  Colors.red.shade600,
                                ]
                                    : [
                                  Colors.blue.shade400,
                                  Colors.blue.shade600,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: (isPreSelected ? Colors.red : Colors.blue).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                category.itemCount.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Info Kategori
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        category.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: isPreSelected ? Colors.red.shade900 : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    // TAMBAHAN: Badge untuk kategori yang dipilih dari notifikasi
                                    if (isPreSelected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.red.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              size: 12,
                                              color: Colors.red.shade700,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Ada masalah stok',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.restaurant_menu,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${category.itemCount} item menu',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Arrow Icon
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 18,
                            color: isPreSelected ? Colors.red.shade400 : Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}