// widgets/stock/category_list_widget.dart
import 'package:flutter/material.dart';
import '../../../models/category_model.dart';
import '../../../models/stock_menu.dart';

class CategoryListWidget extends StatelessWidget {
  final double width;
  final List<Category> categories;
  final Category? selectedCategory;
  final String? preSelectedCategoryId;
  final Map<String, List<StockMenu>> menuCache;
  final String workstation;
  final Color brandColor;
  final ScrollController scrollController;
  final Function(Category) onCategorySelected;

  const CategoryListWidget({
    super.key,
    required this.width,
    required this.categories,
    required this.selectedCategory,
    required this.preSelectedCategoryId,
    required this.menuCache,
    required this.workstation,
    required this.brandColor,
    required this.scrollController,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
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
            color: workstation == 'bar'
                ? Colors.blue[100]
                : brandColor.withOpacity(0.1),
            child: Text(
              'KATEGORI',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: workstation == 'bar' ? Colors.blue[700] : brandColor,
              ),
            ),
          ),
          Expanded(child: _buildCategoryList()),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              'Tidak ada kategori',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    // OPTIMIZATION: Gunakan ListView.builder dengan itemExtent
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 48),
      itemCount: categories.length,
      // OPTIMIZATION: Set tinggi estimasi item
      itemExtent: 88,
      // OPTIMIZATION: Tambahkan cache extent
      cacheExtent: 400,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = selectedCategory?.id == category.id;
        final menuCount = menuCache[category.id]?.length ?? category.itemCount;
        final isPreSelected = preSelectedCategoryId == category.id;

        // OPTIMIZATION: Gunakan widget terpisah dengan key
        return _CategoryCard(
          key: ValueKey(category.id),
          category: category,
          isSelected: isSelected,
          isPreSelected: isPreSelected,
          menuCount: menuCount,
          workstation: workstation,
          brandColor: brandColor,
          onCategorySelected: () => onCategorySelected(category),
        );
      },
    );
  }
}

// OPTIMIZATION: Widget terpisah untuk category card
class _CategoryCard extends StatelessWidget {
  final Category category;
  final bool isSelected;
  final bool isPreSelected;
  final int menuCount;
  final String workstation;
  final Color brandColor;
  final VoidCallback onCategorySelected;

  const _CategoryCard({
    super.key,
    required this.category,
    required this.isSelected,
    required this.isPreSelected,
    required this.menuCount,
    required this.workstation,
    required this.brandColor,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: isSelected ? 4 : 1,
        color: isSelected
            ? (workstation == 'bar'
            ? Colors.blue[100]
            : brandColor.withOpacity(0.1))
            : (isPreSelected ? Colors.yellow.shade50 : Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected
                ? (workstation == 'bar' ? Colors.blue[700]! : brandColor)
                : (isPreSelected ? Colors.yellow.shade700 : Colors.transparent),
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: onCategorySelected,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 14,
                          color: isSelected
                              ? (workstation == 'bar' ? Colors.blue[700] : brandColor)
                              : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPreSelected && !isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'BARU',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (workstation == 'bar' ? Colors.blue[700] : brandColor)
                        : Colors.grey.shade200,
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
      ),
    );
  }
}