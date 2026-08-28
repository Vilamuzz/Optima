import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../providers/cart_provider.dart';
import '../providers/store_profile_provider.dart';
import '../screens/home_screen.dart';
import '../screens/printer_settings_screen.dart';
import '../services/auth_service.dart';
import '../services/printer_service.dart';
import '../services/transaction_service.dart';
import '../theme/app_theme.dart';

class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({Key? key}) : super(key: key);

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  final TransactionService _transactionService = TransactionService();
  final TextEditingController _amountPaidController = TextEditingController();

  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cart = context.read<CartProvider>();
      _amountPaidController.text = cart.total.toStringAsFixed(0);
    });
  }

  @override
  void dispose() {
    _amountPaidController.dispose();
    super.dispose();
  }

  double _getAmountPaid(double total) {
    return double.tryParse(_amountPaidController.text) ?? 0;
  }

  Future<void> _processPayment(CartProvider cart) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final double amountPaid = _getAmountPaid(cart.total);
    final user = AuthService().getCurrentUser();
    final storeProfile = context.read<StoreProfileProvider>().profile;

    try {
      final transaction = await _transactionService.processCheckout(
        cartItems: cart.items,
        amountPaid: amountPaid,
        cashierId: user?.uid ?? user?.email,
      );

      if (!mounted) return;
      cart.clear();
      Navigator.of(context).pop(); // Close checkout dialog

      final printerService = PrinterService();
      bool autoPrinted = false;

      // Immediate auto-print upon successful sale
      if (printerService.autoPrintOnCheckout &&
          printerService.selectedPrinter != null) {
        autoPrinted = true;
        printerService
            .printTransaction(transaction, storeProfile: storeProfile)
            .catchError((e) {
          debugPrint('Auto-print exception: $e');
          return PosPrintResult.timeout;
        });
      }

      _showReceiptDialog(context, transaction, autoPrinted: autoPrinted);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _showReceiptDialog(
    BuildContext context,
    TransactionModel transaction, {
    bool autoPrinted = false,
  }) {
    final storeProfile = context.read<StoreProfileProvider>().profile;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 40),
              SizedBox(height: 8),
              Text(
                'Transaction',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Complete',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      storeProfile.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (storeProfile.address.isNotEmpty)
                    Center(
                      child: Text(
                        storeProfile.address,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Receipt #${transaction.transactionNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      'Date: ${DateTime.now().toString().split('.').first}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),
                  if (autoPrinted) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.print_rounded, size: 16, color: AppTheme.successGreen),
                          SizedBox(width: 8),
                          Text(
                            'Receipt printed to thermal printer',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.successGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 28),
                  ...transaction.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '  ${item.quantity} x ${AppTheme.formatCurrency(item.priceAtSale)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                AppTheme.formatCurrency(item.subtotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 28),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Paid:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        AppTheme.formatCurrency(transaction.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppTheme.primaryEmerald,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount Received:'),
                      Text(AppTheme.formatCurrency(transaction.amountPaid)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Change:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        AppTheme.formatCurrency(transaction.change),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successGreen,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () async {
                final printerService = PrinterService();
                if (printerService.selectedPrinter == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('No Bluetooth printer configured.'),
                      action: SnackBarAction(
                        label: 'CONFIGURE',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PrinterSettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                  return;
                }

                final result = await printerService.printTransaction(
                  transaction,
                  storeProfile: storeProfile,
                );
                if (!context.mounted) return;

                if (result == PosPrintResult.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Receipt printed successfully!'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Print status: ${result.msg}'),
                      backgroundColor: AppTheme.secondaryAmber,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.print_rounded),
              label: const Text('Print Receipt'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryEmerald,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false,
                );
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final double total = cart.total;
    final double amountPaid = _getAmountPaid(total);
    final double change = amountPaid >= total ? amountPaid - total : 0;
    final bool isAmountSufficient = amountPaid >= total;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.point_of_sale_rounded, color: AppTheme.primaryEmerald),
                      SizedBox(width: 10),
                      Text(
                        'Checkout Order',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Total Summary Banner Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryEmerald.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryEmerald.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Payable',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${cart.itemCount} items in cart',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppTheme.formatCurrency(total),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryEmerald,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Amount Paid',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
                TextField(
                  controller: _amountPaidController,
                  keyboardType: TextInputType.number,
                  enabled: !_isProcessing,
                  decoration: const InputDecoration(
                    prefixText: 'Rp ',
                    hintText: 'Enter amount received...',
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 10),
                // Quick cash buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Exact'),
                      onPressed: _isProcessing
                          ? null
                          : () {
                              setState(() {
                                _amountPaidController.text =
                                    total.toStringAsFixed(0);
                              });
                            },
                    ),
                    ...[10000, 20000, 50000, 100000, 200000].map(
                      (amt) => ActionChip(
                        label: Text('Rp ${amt ~/ 1000}k'),
                        onPressed: _isProcessing
                            ? null
                            : () {
                                setState(() {
                                  _amountPaidController.text = amt.toString();
                                });
                              },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isAmountSufficient
                        ? AppTheme.successGreen.withOpacity(0.1)
                        : AppTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isAmountSufficient
                          ? AppTheme.successGreen.withOpacity(0.3)
                          : AppTheme.errorRed.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAmountSufficient
                            ? 'Change:'
                            : 'Insufficient Payment:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isAmountSufficient
                              ? AppTheme.successGreen
                              : AppTheme.errorRed,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAmountSufficient
                            ? AppTheme.formatCurrency(change)
                            : '${AppTheme.formatCurrency(total - amountPaid)} missing',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isAmountSufficient
                              ? AppTheme.successGreen
                              : AppTheme.errorRed,
                        ),
                      ),
                    ],
                  ),
                ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.errorRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.errorRed),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryEmerald,
                      foregroundColor: Colors.white,
                    ),
                  onPressed: (!isAmountSufficient || _isProcessing)
                      ? null
                      : () => _processPayment(cart),
                  icon: _isProcessing
                      ? const SizedBox.shrink()
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: _isProcessing
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Process Payment',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


