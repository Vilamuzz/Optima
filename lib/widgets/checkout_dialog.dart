import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';

import '../models/transaction_model.dart';
import '../providers/cart_provider.dart';
import '../screens/printer_settings_screen.dart';
import '../services/auth_service.dart';
import '../services/printer_service.dart';
import '../services/transaction_service.dart';

class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({Key? key}) : super(key: key);

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  final TransactionService _transactionService = TransactionService();
  final TextEditingController _amountPaidController = TextEditingController();

  String _paymentMethod = 'cash'; // 'cash', 'qris', 'card'
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Default cash amount paid to total amount
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
    if (_paymentMethod != 'cash') return total;
    return double.tryParse(_amountPaidController.text) ?? 0;
  }

  Future<void> _processPayment(CartProvider cart) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final double amountPaid = _getAmountPaid(cart.total);
    final user = AuthService().getCurrentUser();

    try {
      final transaction = await _transactionService.processCheckout(
        cartItems: cart.items,
        paymentMethod: _paymentMethod,
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
        printerService.printTransaction(transaction).catchError((e) {
          debugPrint('Auto-print exception: $e');
          return PosPrintResult.unknown;
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('Transaction Complete'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'POS SUMBER BERKAT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      'Receipt #: ${transaction.transactionNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      'Printed: ${DateTime.now().toString().split('.').first}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ),
                  if (autoPrinted) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.print, size: 16, color: Colors.green),
                          SizedBox(width: 6),
                          Text(
                            'Receipt auto-printed to thermal printer',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 24),
                  ...transaction.items.map((item) => Padding(
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
                                  '  ${item.quantity} x Rp${item.priceAtSale.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                Text(
                                  'Rp${item.subtotal.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Method:'),
                      Text(
                        transaction.paymentMethod.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Rp${transaction.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount Paid:'),
                      Text('Rp${transaction.amountPaid.toStringAsFixed(0)}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Change:'),
                      Text(
                        'Rp${transaction.change.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
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
                      content: const Text('No Bluetooth printer selected.'),
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

                final result = await printerService.printTransaction(transaction);
                if (!context.mounted) return;

                if (result == PosPrintResult.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Receipt printed successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Print job status: ${result.msg}'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.print),
              label: const Text('Print Receipt'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
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
    final bool isAmountSufficient = _paymentMethod != 'cash' || amountPaid >= total;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Checkout',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              // Total Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total (${cart.itemCount} items):',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Rp${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                'Payment Method',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Cash')),
                      selected: _paymentMethod == 'cash',
                      onSelected: _isProcessing
                          ? null
                          : (sel) {
                              if (sel) {
                                setState(() {
                                  _paymentMethod = 'cash';
                                  _amountPaidController.text =
                                      total.toStringAsFixed(0);
                                });
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('QRIS')),
                      selected: _paymentMethod == 'qris',
                      onSelected: _isProcessing
                          ? null
                          : (sel) {
                              if (sel) {
                                setState(() => _paymentMethod = 'qris');
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Card')),
                      selected: _paymentMethod == 'card',
                      onSelected: _isProcessing
                          ? null
                          : (sel) {
                              if (sel) {
                                setState(() => _paymentMethod = 'card');
                              }
                            },
                    ),
                  ),
                ],
              ),

              if (_paymentMethod == 'cash') ...[
                const SizedBox(height: 16),
                const Text(
                  'Amount Paid (Rp)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountPaidController,
                  keyboardType: TextInputType.number,
                  enabled: !_isProcessing,
                  decoration: const InputDecoration(
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 8),
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
                        label: Text('Rp${amt ~/ 1000}k'),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAmountSufficient
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isAmountSufficient ? 'Change (Kembalian):' : 'Insufficient Payment:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isAmountSufficient
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                      Text(
                        isAmountSufficient
                            ? 'Rp${change.toStringAsFixed(0)}'
                            : 'Rp${(total - amountPaid).toStringAsFixed(0)} missing',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isAmountSufficient
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.vertical: 16),
                onPressed: (!isAmountSufficient || _isProcessing)
                    ? null
                    : () => _processPayment(cart),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Process Payment & Complete Sale',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
