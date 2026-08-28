import 'dart:async';
import 'package:flutter/material.dart';

import '../models/category_model.dart';
import '../models/product.dart';
import '../services/category_service.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'add_product_screen.dart';
import 'edit_product_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({Key? key}) : super(key: key);

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ProductService _productService = ProductService();
  final CategoryService _categoryService = CategoryService();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _filterLowStockOnly = false;
  String? _selectedCategoryFilter;
  Timer? _debounceTimer;

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _searchQuery = value.toLowerCase());
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _showCategoryFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CategoryFilterSheet(
        categoryService: _categoryService,
        selectedCategory: _selectedCategoryFilter,
        onCategorySelected: (catName) {
          setState(() {
            _selectedCategoryFilter = catName;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.inventory_2_rounded, color: AppTheme.accentIndigo),
            SizedBox(width: 10),
            Text('Product Inventory'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products by name...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 10),

                // Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedCategoryFilter == null &&
                            !_filterLowStockOnly,
                        onSelected: (_) {
                          setState(() {
                            _selectedCategoryFilter = null;
                            _filterLowStockOnly = false;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: AppTheme.secondaryAmber,
                        ),
                        label: const Text('Low Stock'),
                        selected: _filterLowStockOnly,
                        onSelected: (selected) {
                          setState(() => _filterLowStockOnly = selected);
                        },
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: Icon(
                          Icons.category_rounded,
                          size: 16,
                          color: _selectedCategoryFilter != null
                              ? AppTheme.accentIndigo
                              : Colors.grey,
                        ),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedCategoryFilter != null
                                  ? 'Cat: $_selectedCategoryFilter'
                                  : 'Category',
                              style: TextStyle(
                                fontWeight: _selectedCategoryFilter != null
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _selectedCategoryFilter != null
                                    ? AppTheme.accentIndigo
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 18,
                              color: _selectedCategoryFilter != null
                                  ? AppTheme.accentIndigo
                                  : Colors.grey,
                            ),
                          ],
                        ),
                        backgroundColor: _selectedCategoryFilter != null
                            ? AppTheme.accentIndigo.withValues(alpha: 0.12)
                            : null,
                        side: _selectedCategoryFilter != null
                            ? const BorderSide(color: AppTheme.accentIndigo)
                            : null,
                        onPressed: () => _showCategoryFilterModal(context),
                      ),
                      if (_selectedCategoryFilter != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.cancel_rounded,
                              size: 18, color: Colors.grey),
                          tooltip: 'Clear Category Filter',
                          onPressed: () =>
                              setState(() => _selectedCategoryFilter = null),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Product List
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: _productService.getProducts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading products: ${snapshot.error}',
                      style: const TextStyle(color: AppTheme.errorRed),
                    ),
                  );
                }

                final products = snapshot.data ?? [];

                // Filter by search query, category, and low stock toggle
                final filtered = products.where((p) {
                  final matchesSearch =
                      p.name.toLowerCase().contains(_searchQuery);
                  final isLowStock = p.stockQty <= p.lowStockThreshold;
                  final matchesCategory = _selectedCategoryFilter == null ||
                      p.category == _selectedCategoryFilter;

                  if (_filterLowStockOnly) {
                    return matchesSearch && isLowStock && matchesCategory;
                  }
                  return matchesSearch && matchesCategory;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_rounded,
                          size: 60,
                          color: Colors.grey.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No products found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    final isOutOfStock = product.stockQty <= 0;
                    final isLowStock = product.stockQty > 0 &&
                        product.stockQty <= product.lowStockThreshold &&
                        product.lowStockThreshold > 0;

                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accentIndigo.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.local_offer_outlined,
                            color: AppTheme.accentIndigo,
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          '${AppTheme.formatCurrency(product.price)}  ·  Stock: ${product.stockQty}${product.category != null ? "  ·  ${product.category}" : ""}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isOutOfStock)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorRed.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Out of Stock',
                                  style: TextStyle(
                                    color: AppTheme.errorRed,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else if (isLowStock)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryAmber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Low Stock',
                                  style: TextStyle(
                                    color: AppTheme.secondaryAmber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                          ],
                        ),
                        onTap: () => EditProductScreen.showModal(context, product),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AddProductScreen.showModal(context),
        backgroundColor: AppTheme.primaryEmerald,
        foregroundColor: Colors.white,
        tooltip: 'Add New Product',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Category Filter Modal Bottom Sheet
// ─────────────────────────────────────────────────────────────
class _CategoryFilterSheet extends StatefulWidget {
  final CategoryService categoryService;
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;

  const _CategoryFilterSheet({
    required this.categoryService,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  State<_CategoryFilterSheet> createState() => _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends State<_CategoryFilterSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Modal Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentIndigo.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.category_rounded,
                        color: AppTheme.accentIndigo, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Select Category',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Search Bar for Categories
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search categories...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),

            // Category List
            Expanded(
              child: StreamBuilder<List<CategoryModel>>(
                stream: widget.categoryService.getCategories(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final categories = snapshot.data ?? [];
                  final filtered = categories.where((c) {
                    return _searchQuery.isEmpty ||
                        c.name.toLowerCase().contains(_searchQuery.toLowerCase());
                  }).toList();

                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      // "All Categories" option
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: widget.selectedCategory == null
                            ? AppTheme.accentIndigo.withValues(alpha: 0.1)
                            : null,
                        leading: Icon(
                          Icons.grid_view_rounded,
                          color: widget.selectedCategory == null
                              ? AppTheme.accentIndigo
                              : Colors.grey,
                        ),
                        title: Text(
                          'All Categories',
                          style: TextStyle(
                            fontWeight: widget.selectedCategory == null
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: widget.selectedCategory == null
                                ? AppTheme.accentIndigo
                                : null,
                          ),
                        ),
                        trailing: widget.selectedCategory == null
                            ? const Icon(Icons.check_circle_rounded,
                                color: AppTheme.accentIndigo)
                            : null,
                        onTap: () {
                          widget.onCategorySelected(null);
                          Navigator.pop(context);
                        },
                      ),
                      const Divider(),

                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No categories found',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ...filtered.map((c) {
                          final isSelected = widget.selectedCategory == c.name;
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            tileColor: isSelected
                                ? AppTheme.accentIndigo.withValues(alpha: 0.1)
                                : null,
                            leading: Icon(
                              Icons.label_outline_rounded,
                              color: isSelected
                                  ? AppTheme.accentIndigo
                                  : Colors.grey,
                            ),
                            title: Text(
                              c.name,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected ? AppTheme.accentIndigo : null,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded,
                                    color: AppTheme.accentIndigo)
                                : null,
                            onTap: () {
                              widget.onCategorySelected(c.name);
                              Navigator.pop(context);
                            },
                          );
                        }),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
