import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';

import '../models/transaction_model.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  final PrinterBluetoothManager _printerManager = PrinterBluetoothManager();
  PrinterBluetooth? _selectedPrinter;
  bool autoPrintOnCheckout = true;

  PrinterBluetooth? get selectedPrinter => _selectedPrinter;
  Stream<List<PrinterBluetooth>> get scanResults => _printerManager.scanResults;
  Stream<bool> get isScanning => _printerManager.isScanning;

  void startScan({Duration timeout = const Duration(seconds: 4)}) {
    _printerManager.startScan(timeout);
  }

  void stopScan() {
    _printerManager.stopScan();
  }

  void selectPrinter(PrinterBluetooth printer) {
    _selectedPrinter = printer;
  }

  /// Generates raw ESC/POS byte commands for a POS sale receipt.
  /// Template includes: Store Name, Items, Qty, Price, Total, Timestamp Printed.
  Future<List<int>> generateReceiptBytes(
    TransactionModel transaction, {
    String storeName = 'POS SUMBER BERKAT',
    String storeAddress = 'Jl. Sumber Berkat No. 8',
    String storePhone = 'Tel: (021) 555-0199',
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);

    List<int> bytes = [];

    final DateTime printTime = DateTime.now();
    final String printTimeStr =
        '${printTime.year}-${printTime.month.toString().padLeft(2, '0')}-${printTime.day.toString().padLeft(2, '0')} ${printTime.hour.toString().padLeft(2, '0')}:${printTime.minute.toString().padLeft(2, '0')}:${printTime.second.toString().padLeft(2, '0')}';

    // 1. STORE NAME & HEADER
    bytes += generator.setGlobalCodeTable('CP1252');
    bytes += generator.text(
      storeName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      storeAddress,
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      storePhone,
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.emptyLines(1);

    // 2. TRANSACTION METADATA & TIMESTAMP PRINTED
    bytes += generator.text('Receipt #: ${transaction.transactionNumber}');
    bytes += generator.text('Printed: $printTimeStr');
    if (transaction.cashierId != null && transaction.cashierId!.isNotEmpty) {
      bytes += generator.text('Cashier: ${transaction.cashierId}');
    }
    bytes += generator.text('--------------------------------');

    // 3. ITEMS LIST (NAME, QTY, PRICE, SUBTOTAL)
    for (final item in transaction.items) {
      bytes += generator.text(
        item.productName,
        styles: const PosStyles(bold: true),
      );
      bytes += generator.row([
        PosColumn(
          text: '  ${item.quantity} x Rp${item.priceAtSale.toStringAsFixed(0)}',
          width: 7,
        ),
        PosColumn(
          text: 'Rp${item.subtotal.toStringAsFixed(0)}',
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    bytes += generator.text('--------------------------------');

    // 4. TOTAL & PAYMENT BREAKDOWN
    bytes += generator.row([
      PosColumn(
        text: 'TOTAL:',
        width: 6,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: 'Rp${transaction.totalAmount.toStringAsFixed(0)}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        text: 'Payment (${transaction.paymentMethod.toUpperCase()}):',
        width: 7,
      ),
      PosColumn(
        text: 'Rp${transaction.amountPaid.toStringAsFixed(0)}',
        width: 5,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Change:', width: 6),
      PosColumn(
        text: 'Rp${transaction.change.toStringAsFixed(0)}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    // 5. FOOTER
    bytes += generator.emptyLines(1);
    bytes += generator.text(
      'Thank you for shopping!',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      'Please keep this receipt.',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.emptyLines(2);
    bytes += generator.cut();

    return bytes;
  }

  /// Generates raw ESC/POS byte commands for a test print page.
  Future<List<int>> generateTestBytes() async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);

    List<int> bytes = [];
    bytes += generator.text(
      'TEST PRINT OK',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      'Optima POS Bluetooth Printer',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Thermal Printer Connected Successfully',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.emptyLines(2);
    bytes += generator.cut();
    return bytes;
  }

  /// Sends raw ESC/POS receipt print job to selected Bluetooth thermal printer.
  Future<PosPrintResult> printTransaction(TransactionModel transaction) async {
    if (_selectedPrinter == null) {
      return PosPrintResult.printerNotSelected;
    }
    _printerManager.selectPrinter(_selectedPrinter!);
    final bytes = await generateReceiptBytes(transaction);
    return await _printerManager.printTicket(bytes);
  }

  /// Sends a raw ESC/POS test print job to selected Bluetooth thermal printer.
  Future<PosPrintResult> printTest() async {
    if (_selectedPrinter == null) {
      return PosPrintResult.printerNotSelected;
    }
    _printerManager.selectPrinter(_selectedPrinter!);
    final bytes = await generateTestBytes();
    return await _printerManager.printTicket(bytes);
  }
}
