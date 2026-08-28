import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../models/restock_batch_item.dart';
import '../services/auth_service.dart';
import '../services/category_service.dart';
import '../services/product_service.dart';
import '../services/restock_service.dart';
import '../theme/app_theme.dart';

class AddRestockScreen extends StatefulWidget {
  final Product? preselectedProduct;

  const AddRestockScreen({super.key, this.preselectedProduct});

  @override
  State<AddRestockScreen> createState() => _AddRestockScreenState();
}

class _AddRestockScreenState extends State<AddRestockScreen> {
  final ProductService _productService = ProductService();
  final CategoryService _categoryService = CategoryService();
  final RestockService _restockService = RestockService();
  final AuthService _authService = AuthService();

  final _addItemFormKey = GlobalKey<FormState>();
  Product? _pickedProduct;
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _costController = TextEditingController();

  final List<RestockBatchItem> _orderItems = [];

  bool _isSubmitting = false;
  String? _errorMessage;
  List<Product> _allProducts = [];

  @override
  void initState() {
    super.initState();
    if (widget.preselectedProduct != null) {
      _pickedProduct = widget.preselectedProduct;
    }
  }

  Future<void> _showProductPickerModal(List<Product> available) async {
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ProductPickerSheet(
        available: available,
        categoryService: _categoryService,
      ),
    );
    if (picked != null) {
      setState(() => _pickedProduct = picked);
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    super.dispose();
  }

  double get _grandTotal =>
      _orderItems.fold(0.0, (sum, item) => sum + item.subtotal);

  String _fmt(double v) =>
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
          .format(v);

  void _addItem() {
    if (!_addItemFormKey.currentState!.validate()) return;
    if (_pickedProduct == null) {
      setState(() => _errorMessage = 'Please select a product first.');
      return;
    }
    final qty = int.parse(_qtyController.text.trim());
    final cost = double.parse(_costController.text.trim());
    final alreadyIdx =
        _orderItems.indexWhere((i) => i.product.id == _pickedProduct!.id);
    setState(() {
      _errorMessage = null;
      if (alreadyIdx >= 0) {
        _orderItems[alreadyIdx].quantity += qty;
        _orderItems[alreadyIdx].costPerUnit = cost;
      } else {
        _orderItems.add(RestockBatchItem(
          product: _pickedProduct!,
          quantity: qty,
          costPerUnit: cost,
        ));
      }
      _pickedProduct = null;
      _qtyController.clear();
      _costController.clear();
    });
  }

  void _removeItem(int index) => setState(() => _orderItems.removeAt(index));

  Future<void> _handleSubmit() async {
    if (_orderItems.isEmpty) {
      setState(() => _errorMessage = 'Add at least one product to the order.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final currentUser = _authService.getCurrentUser();
      final lines = _orderItems
          .map((item) => RestockLineInput(
                productId: item.product.id,
                quantity: item.quantity,
                costPerUnit: item.costPerUnit,
              ))
          .toList();
      final results = await _restockService.processBulkRestock(
        lines: lines,
        userId: currentUser?.email ?? currentUser?.uid,
      );
      if (!mounted) return;
      final grandTotal = results.fold(0.0, (sum, r) => sum + r.totalCost);

      Navigator.pop(context); // Return to RestockScreen

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${results.length} product(s) restocked  ·  Total: ${_fmt(grandTotal)}',
          ),
          backgroundColor: AppTheme.primaryEmerald,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Restock Order'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAddItemSection(theme),
          const SizedBox(height: 16),
          _buildOrderTable(theme),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.errorRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppTheme.errorRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: AppTheme.errorRed, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: _buildSubmitBar(theme),
    );
  }

  Widget _buildAddItemSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _addItemFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_box_rounded,
                        color: Colors.teal, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('Add Product to Order', style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 14),
              StreamBuilder<List<Product>>(
                stream: _productService.getProducts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }
                  _allProducts = snapshot.data ?? [];
                  final available = _allProducts
                      .where((p) =>
                          !_orderItems.any((i) => i.product.id == p.id))
                      .toList();

                  return GestureDetector(
                    onTap: () => _showProductPickerModal(available),
                    child: AbsorbPointer(
                      child: FormField<Product>(
                        validator: (_) => _pickedProduct == null
                            ? 'Please select a product'
                            : null,
                        builder: (field) {
                          return InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Select Product *',
                              prefixIcon: const Icon(
                                  Icons.inventory_2_rounded),
                              suffixIcon: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 18),
                              errorText: field.errorText,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            child: _pickedProduct == null
                                ? Text(
                                    'Tap to search product...',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.45),
                                    ),
                                  )
                                : Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.teal
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                            Icons.inventory_2_outlined,
                                            color: Colors.teal,
                                            size: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _pickedProduct!.name,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 14),
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Stock: ${_pickedProduct!.stockQty}${_pickedProduct!.category != null ? "  ·  ${_pickedProduct!.category}" : ""}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded,
                                            size: 16, color: Colors.grey),
                                        onPressed: () => setState(
                                            () => _pickedProduct = null),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity *',
                  hintText: 'e.g. 50',
                  prefixIcon: Icon(Icons.format_list_numbered_rounded),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Required';
                  final q = int.tryParse(val.trim());
                  if (q == null || q <= 0) return '> 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _costController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Unit Cost (Rp) *',
                  hintText: 'e.g. 15000',
                  prefixText: 'Rp ',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Required';
                  final c = double.tryParse(val.trim());
                  if (c == null || c < 0) return 'Invalid';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Add to Order'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal,
                    side: const BorderSide(color: Colors.teal),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTable(ThemeData theme) {
    if (_orderItems.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 40,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'No items in restock order yet.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.accentIndigo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppTheme.accentIndigo,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Order Summary', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    Text(
                      '${_orderItems.length} item(s)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isCompact) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          'Product',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Qty',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Unit Cost',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Subtotal',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ] else ...[
                const Divider(height: 1),
              ],
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _orderItems.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, i) {
                  final item = _orderItems[i];
                  return _OrderItemRow(
                    item: item,
                    isCompact: isCompact,
                    onRemove: () => _removeItem(i),
                    onChanged: (qty, cost) => setState(() {
                      item.quantity = qty;
                      item.costPerUnit = cost;
                    }),
                    fmtCurrency: _fmt,
                  );
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Grand Total',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _fmt(_grandTotal),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryEmerald,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubmitBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryEmerald,
              foregroundColor: Colors.white,
            ),
            onPressed:
                (_isSubmitting || _orderItems.isEmpty) ? null : _handleSubmit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              _isSubmitting
                  ? 'Submitting Restock…'
                  : 'Submit Restock Order  •  ${_fmt(_grandTotal)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sub-widget: Editable order-item row in cart
// ─────────────────────────────────────────────────────────────
class _OrderItemRow extends StatefulWidget {
  final RestockBatchItem item;
  final bool isCompact;
  final VoidCallback onRemove;
  final void Function(int qty, double cost) onChanged;
  final String Function(double) fmtCurrency;

  const _OrderItemRow({
    required this.item,
    this.isCompact = false,
    required this.onRemove,
    required this.onChanged,
    required this.fmtCurrency,
  });

  @override
  State<_OrderItemRow> createState() => _OrderItemRowState();
}

class _OrderItemRowState extends State<_OrderItemRow> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _costCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.item.quantity.toString());
    _costCtrl = TextEditingController(
        text: widget.item.costPerUnit.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    final qty = int.tryParse(_qtyCtrl.text) ?? widget.item.quantity;
    final cost = double.tryParse(_costCtrl.text) ?? widget.item.costPerUnit;
    widget.onChanged(qty, cost);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.item.product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.errorRed,
                    size: 20,
                  ),
                  onPressed: widget.onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Qty',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        isDense: true,
                      ),
                      onChanged: (_) => _notify(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _costCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Unit Cost',
                        prefixText: 'Rp ',
                        prefixStyle: TextStyle(fontSize: 11),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        isDense: true,
                      ),
                      onChanged: (_) => _notify(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Subtotal: ${widget.fmtCurrency(widget.item.subtotal)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.primaryEmerald,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              widget.item.product.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  isDense: true,
                ),
                onChanged: (_) => _notify(),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _costCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  isDense: true,
                  prefixText: 'Rp ',
                  prefixStyle: TextStyle(fontSize: 11),
                ),
                onChanged: (_) => _notify(),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              widget.fmtCurrency(widget.item.subtotal),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded,
                color: Colors.red, size: 20),
            onPressed: widget.onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Product Picker Modal Bottom Sheet
// ─────────────────────────────────────────────────────────────
class _ProductPickerSheet extends StatefulWidget {
  final List<Product> available;
  final CategoryService categoryService;

  const _ProductPickerSheet({
    required this.available,
    required this.categoryService,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filtered = widget.available.where((p) {
      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          p.name.toLowerCase().contains(query);
      final matchesCategory =
          _selectedCategory == null || p.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_rounded,
                        color: Colors.teal, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Select Product',
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

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by product name...',
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

            // Category filter chips
            StreamBuilder<List<CategoryModel>>(
              stream: widget.categoryService.getCategories(),
              builder: (context, catSnap) {
                final cats = catSnap.data ?? [];
                if (cats.isEmpty) return const SizedBox.shrink();
                return SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedCategory == null,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = null),
                      ),
                      ...cats.map((c) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: FilterChip(
                              label: Text(c.name),
                              selected: _selectedCategory == c.name,
                              onSelected: (sel) => setState(() =>
                                  _selectedCategory = sel ? c.name : null),
                            ),
                          )),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 4),

            // Product List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 48,
                              color: Colors.grey.withValues(alpha: 0.5)),
                          const SizedBox(height: 8),
                          const Text(
                            'No products found',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        final isLowStock = p.stockQty > 0 &&
                            p.stockQty <= p.lowStockThreshold &&
                            p.lowStockThreshold > 0;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            onTap: () => Navigator.pop(context, p),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.inventory_2_outlined,
                                  color: Colors.teal, size: 18),
                            ),
                            title: Text(
                              p.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text(
                              'Stock: ${p.stockQty}${p.category != null ? "  ·  ${p.category}" : ""}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: isLowStock
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondaryAmber
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text('Low Stock',
                                        style: TextStyle(
                                            color: AppTheme.secondaryAmber,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  )
                                : null,
                          ),
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
