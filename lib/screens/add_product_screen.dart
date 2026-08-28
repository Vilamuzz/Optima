import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../services/category_service.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../widgets/barcode_scanner_dialog.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  static Future<void> showModal(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const AddProductScreen(),
    );
  }

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final ProductService _productService = ProductService();
  final CategoryService _categoryService = CategoryService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _lowStockController = TextEditingController();
  String? _selectedCategory;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    final controller = TextEditingController();
    final newCategoryName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create New Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Category Name *',
            hintText: 'e.g. Beverages, Snacks, Food',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryEmerald,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                try {
                  final cat = await _categoryService.addCategory(text);
                  if (ctx.mounted) Navigator.pop(ctx, cat.name);
                } catch (e) {
                  // ignore
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (newCategoryName != null && newCategoryName.isNotEmpty) {
      setState(() {
        _selectedCategory = newCategoryName;
      });
    }
  }

  Future<void> _handleAddProduct() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Product name is required');
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (_priceController.text.trim().isEmpty || price == null || price < 0) {
      setState(() => _errorMessage = 'Valid product price is required');
      return;
    }

    final stock = int.tryParse(_stockController.text.trim());
    if (_stockController.text.trim().isEmpty || stock == null || stock < 0) {
      setState(() => _errorMessage = 'Valid stock quantity is required');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final product = Product(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        barcode: _barcodeController.text.trim().isNotEmpty
            ? _barcodeController.text.trim()
            : null,
        category: _selectedCategory,
        price: price,
        stockQty: stock,
        lowStockThreshold: int.tryParse(_lowStockController.text.trim()) ?? 0,
        createdAt: DateTime.now(),
      );

      await _productService.addProduct(product);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} created successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error saving product: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Modal Header Drag Handle & Title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryEmerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add_box_rounded,
                      color: AppTheme.primaryEmerald,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add New Product',
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

            // Form Body
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name *',
                      hintText: 'e.g. Minyak Goreng 2L',
                      prefixIcon: Icon(Icons.shopping_bag_outlined),
                    ),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 14),
                  StreamBuilder<List<CategoryModel>>(
                    stream: _categoryService.getCategories(),
                    builder: (context, snapshot) {
                      final categories = snapshot.data ?? [];
                      final hasMatching = categories.any(
                        (c) => c.name == _selectedCategory,
                      );
                      return Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              // ignore: deprecated_member_use
                              value: hasMatching ? _selectedCategory : null,
                              decoration: const InputDecoration(
                                labelText: 'Category (Optional)',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              items: categories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.name,
                                      child: Text(c.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedCategory = val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.add_rounded,
                              color: AppTheme.primaryEmerald,
                            ),
                            tooltip: 'Create New Category',
                            onPressed: () => _showAddCategoryDialog(context),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: 'Barcode SKU (Optional)',
                      hintText: 'e.g. 8991234567890',
                      prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.center_focus_strong_rounded,
                          color: AppTheme.primaryEmerald,
                        ),
                        tooltip: 'Scan Barcode / SKU',
                        onPressed: _isLoading
                            ? null
                            : () async {
                                final code = await BarcodeScannerDialog.scan(
                                  context,
                                );
                                if (code != null && code.isNotEmpty) {
                                  setState(() {
                                    _barcodeController.text = code;
                                  });
                                }
                              },
                      ),
                    ),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Selling Price (Rp) *',
                      hintText: 'e.g. 25000',
                      prefixIcon: Icon(Icons.payments_outlined),
                      prefixText: 'Rp ',
                    ),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stock Qty *',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _lowStockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Low Stock Alert',
                      prefixIcon: Icon(Icons.warning_amber_rounded),
                    ),
                    enabled: !_isLoading,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.errorRed.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppTheme.errorRed,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppTheme.errorRed,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryEmerald,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isLoading ? null : _handleAddProduct,
                      icon: _isLoading
                          ? const SizedBox.shrink()
                          : const Icon(Icons.add_rounded),
                      label: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Product'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
