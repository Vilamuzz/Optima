import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/product.dart';
import '../models/restock.dart';
import '../services/restock_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav_bar.dart';

import 'add_restock_screen.dart';

class RestockScreen extends StatefulWidget {
  final Product? preselectedProduct;
  const RestockScreen({super.key, this.preselectedProduct});

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  final RestockService _restockService = RestockService();

  @override
  void initState() {
    super.initState();
    if (widget.preselectedProduct != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openNewRestockScreen(
          context,
          preselectedProduct: widget.preselectedProduct,
        );
      });
    }
  }

  String _fmt(double v) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(v);

  void _openNewRestockScreen(
    BuildContext context, {
    Product? preselectedProduct,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) =>
            AddRestockScreen(preselectedProduct: preselectedProduct),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
      appBar: AppBar(title: const Text('Restock Inventory')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNewRestockScreen(context),
        backgroundColor: AppTheme.primaryEmerald,
        foregroundColor: Colors.white,
        tooltip: 'Add New Restock',
        child: const Icon(Icons.add_rounded),
      ),
      body: CustomScrollView(
        slivers: [
          // Monthly Expense Banner Card
          SliverToBoxAdapter(
            child: StreamBuilder<List<RestockModel>>(
              stream: _restockService.getRestocksForMonthStream(DateTime.now()),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error loading month expenses: ${snapshot.error}'),
                  );
                }
                final monthRestocks = snapshot.data ?? [];
                return _buildMonthlyExpenseCard(monthRestocks, theme);
              },
            ),
          ),

          // Section Title: History Log
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 20,
                    color: AppTheme.primaryEmerald,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Restock History Log',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // History list stream (limited to 100)
          StreamBuilder<List<RestockModel>>(
            stream: _restockService.getRestocksStream(limit: 100),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: ${snapshot.error}'),
                  ),
                );
              }

              final restocks = snapshot.data ?? [];

              if (restocks.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 64,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.25,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No restock history yet.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _openNewRestockScreen(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create First Restock'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return _buildHistorySliverList(restocks, theme);
            },
          ),
        ],
      ),
    );
  }

  // ── Monthly Expenses Monitoring Card ──────────────────────
  Widget _buildMonthlyExpenseCard(
    List<RestockModel> allRestocks,
    ThemeData theme,
  ) {
    final now = DateTime.now();
    final monthlyRestocks = allRestocks
        .where(
          (r) => r.createdAt.year == now.year && r.createdAt.month == now.month,
        )
        .toList();
    final monthlyTotal = monthlyRestocks.fold(
      0.0,
      (sum, r) => sum + r.totalCost,
    );
    final monthName = DateFormat('MMMM yyyy').format(now);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryEmerald, Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryEmerald.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Monthly Expenses ($monthName)',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _fmt(monthlyTotal),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${monthlyRestocks.length} item entry(ies) recorded',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── History Sliver List (grouped by batchId) ──────────────
  Widget _buildHistorySliverList(List<RestockModel> restocks, ThemeData theme) {
    // Group by batchId; legacy records without batchId get their own group
    final Map<String, List<RestockModel>> groups = {};
    for (final r in restocks) {
      final key = r.batchId ?? r.id;
      groups.putIfAbsent(key, () => []).add(r);
    }

    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        final latestA = groups[a]!
            .map((r) => r.createdAt)
            .reduce((x, y) => x.isAfter(y) ? x : y);
        final latestB = groups[b]!
            .map((r) => r.createdAt)
            .reduce((x, y) => x.isAfter(y) ? x : y);
        return latestB.compareTo(latestA);
      });

    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 80),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final key = sortedKeys[index];
          final items = groups[key]!;
          final isBatch = items.length > 1;
          final batchTotal = items.fold(0.0, (sum, r) => sum + r.totalCost);
          final batchDate = items
              .map((r) => r.createdAt)
              .reduce((a, b) => a.isAfter(b) ? a : b);
          final dateStr = DateFormat('dd MMM yyyy  HH:mm').format(batchDate);

          if (!isBatch) {
            return _HistoryCard(restock: items.first, fmtCurrency: _fmt);
          }

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryEmerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.layers_rounded,
                    color: AppTheme.primaryEmerald,
                  ),
                ),
                title: Text(
                  'Batch  ·  ${items.length} products',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '$dateStr\nTotal: ${_fmt(batchTotal)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                children: items
                    .map((r) => _HistoryLineRow(restock: r, fmt: _fmt))
                    .toList(),
              ),
            ),
          );
        }, childCount: sortedKeys.length),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sub-widget: History single card
// ─────────────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final RestockModel restock;
  final String Function(double) fmtCurrency;

  const _HistoryCard({required this.restock, required this.fmtCurrency});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy  HH:mm').format(restock.createdAt);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.add_rounded, color: Colors.green),
        ),
        title: Text(
          '${restock.productName}  (+${restock.quantity})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '$dateStr\n'
          'Unit: ${fmtCurrency(restock.costPerUnit)}  |  Total: ${fmtCurrency(restock.totalCost)}',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.6),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sub-widget: History expanded line row inside batch
// ─────────────────────────────────────────────────────────────
class _HistoryLineRow extends StatelessWidget {
  final RestockModel restock;
  final String Function(double) fmt;

  const _HistoryLineRow({required this.restock, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: [
          const Icon(
            Icons.subdirectory_arrow_right_rounded,
            size: 16,
            color: Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              restock.productName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '+${restock.quantity}  x  ${fmt(restock.costPerUnit)}  =  ${fmt(restock.totalCost)}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}
