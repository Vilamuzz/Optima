import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../services/auth_service.dart';
import '../services/transaction_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'daily_sales_screen.dart';
import 'pos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryEmerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: AppTheme.primaryEmerald,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'OPTIMA',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Daily Sales Report',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DailySalesScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PosScreen()),
          );
        },
        backgroundColor: AppTheme.primaryEmerald,
        foregroundColor: Colors.white,
        tooltip: 'Open POS Register',
        child: const Icon(Icons.point_of_sale_rounded),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
      body: CustomScrollView(
        slivers: [
          // Monthly & Periodic Sales Revenue Card
          SliverToBoxAdapter(
            child: StreamBuilder<List<TransactionModel>>(
              stream: _transactionService.getTransactionsFromDateStream(
                DateTime(DateTime.now().year, DateTime.now().month, 1),
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error loading revenue card: ${snapshot.error}',
                      style: const TextStyle(color: AppTheme.errorRed),
                    ),
                  );
                }
                final monthTransactions = snapshot.data ?? [];
                return _buildSalesRevenueCard(monthTransactions, theme);
              },
            ),
          ),

          // History Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 20,
                    color: AppTheme.primaryEmerald,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Transactions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Recent 50 max',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sales Transactions Log List
          StreamBuilder<List<TransactionModel>>(
            stream: _transactionService.getRecentTransactionsStream(limit: 50),
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
                    child: Text(
                      'Error loading transactions: ${snapshot.error}',
                    ),
                  ),
                );
              }

              final recentTransactions = snapshot.data ?? [];

              if (recentTransactions.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 64,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.25,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No transactions recorded yet.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PosScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.point_of_sale_rounded),
                          label: const Text('Open POS Register'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.only(bottom: 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final trx = recentTransactions[index];
                    return _buildTransactionTile(context, trx, theme);
                  }, childCount: recentTransactions.length),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Monthly Sales Revenue Card ───────────────────────────
  Widget _buildSalesRevenueCard(
    List<TransactionModel> allTransactions,
    ThemeData theme,
  ) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);

    final todayList = allTransactions
        .where((t) => !t.createdAt.isBefore(startOfToday))
        .toList();
    final weeklyList = allTransactions
        .where((t) => !t.createdAt.isBefore(startOfWeek))
        .toList();
    final monthlyList = allTransactions
        .where((t) => !t.createdAt.isBefore(startOfMonth))
        .toList();

    final todayTotal = todayList.fold(0.0, (sum, t) => sum + t.totalAmount);
    final weeklyTotal = weeklyList.fold(0.0, (sum, t) => sum + t.totalAmount);
    final monthlyTotal = monthlyList.fold(0.0, (sum, t) => sum + t.totalAmount);
    final monthName = DateFormat('MMMM yyyy').format(now);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                      Icons.insights_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Monthly Revenue ($monthName)',
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
              AppTheme.formatCurrency(monthlyTotal),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Today',
                    amount: todayTotal,
                    count: todayList.length,
                  ),
                ),
                Container(
                  height: 32,
                  width: 1,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'This Week',
                    amount: weeklyTotal,
                    count: weeklyList.length,
                  ),
                ),
                Container(
                  height: 32,
                  width: 1,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'This Month',
                    amount: monthlyTotal,
                    count: monthlyList.length,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sales Transaction Card ───────────────────────────────
  Widget _buildTransactionTile(
    BuildContext context,
    TransactionModel trx,
    ThemeData theme,
  ) {
    final dateStr = DateFormat('dd MMM yyyy  HH:mm').format(trx.createdAt);
    final fmtTotal = AppTheme.formatCurrency(trx.totalAmount);
    final totalItems = trx.items.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: () => _showTransactionDetails(context, trx),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryEmerald.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: AppTheme.primaryEmerald,
          ),
        ),
        title: Text(
          trx.transactionNumber,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '$totalItems item(s)  ·  $dateStr',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              fmtTotal,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.primaryEmerald,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ── Show Transaction Details Dialog ──────────────────────
  void _showTransactionDetails(BuildContext context, TransactionModel trx) {
    final dateStr = DateFormat('dd MMM yyyy  HH:mm').format(trx.createdAt);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.receipt_rounded, color: AppTheme.primaryEmerald),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                trx.transactionNumber,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date: $dateStr',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Divider(height: 20),
                const Text(
                  'Items Purchased:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...trx.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.productName} × ${item.quantity}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          AppTheme.formatCurrency(item.subtotal),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      AppTheme.formatCurrency(trx.totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryEmerald,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Amount Paid:', style: TextStyle(fontSize: 12)),
                    Text(
                      AppTheme.formatCurrency(trx.amountPaid),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Change:', style: TextStyle(fontSize: 12)),
                    Text(
                      AppTheme.formatCurrency(trx.change),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final double amount;
  final int count;

  const _StatTile({
    required this.label,
    required this.amount,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            AppTheme.formatCurrency(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$count orders',
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
