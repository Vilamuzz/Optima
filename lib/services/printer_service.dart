import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/store_profile.dart';
import '../models/transaction.dart';
import 'store_profile_service.dart';

enum PosPrintResult {
  success('Success'),
  timeout('Timeout'),
  printerNotSelected('Printer not selected'),
  ticketEmpty('Ticket is empty'),
  printInProgress('Print in progress'),
  scanInProgress('Scan in progress'),
  bluetoothUnavailable('Bluetooth unavailable'),
  error('Error printing');

  final String msg;
  const PosPrintResult(this.msg);
}

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  BluetoothDevice? _selectedPrinter;
  bool autoPrintOnCheckout = true;

  BluetoothDevice? get selectedPrinter => _selectedPrinter;
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  void startScan({Duration timeout = const Duration(seconds: 4)}) async {
    try {
      if (await FlutterBluePlus.isSupported == false) return;
      await FlutterBluePlus.startScan(timeout: timeout);
    } catch (_) {
      // Ignore errors on Web / unsupported platforms
    }
  }

  void stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  void selectPrinter(BluetoothDevice printer) {
    _selectedPrinter = printer;
  }

  /// Generates raw ESC/POS byte commands for a POS sale receipt.
  /// Template includes: Store Name, Items, Qty, Price, Total, Timestamp Printed.
  Future<List<int>> generateReceiptBytes(
    TransactionModel transaction, {
    StoreProfileModel? storeProfile,
    String? storeName,
    String? storeAddress,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);

    final activeProfile = storeProfile ?? await StoreProfileService().getProfile();
    final nameToPrint = storeName ?? activeProfile.name;
    final addressToPrint = storeAddress ?? activeProfile.address;

    List<int> bytes = [];

    final DateTime printTime = DateTime.now();
    final String printTimeStr =
        '${printTime.year}-${printTime.month.toString().padLeft(2, '0')}-${printTime.day.toString().padLeft(2, '0')} ${printTime.hour.toString().padLeft(2, '0')}:${printTime.minute.toString().padLeft(2, '0')}:${printTime.second.toString().padLeft(2, '0')}';

    // 1. STORE NAME & HEADER
    bytes += generator.setGlobalCodeTable('CP1252');
    bytes += generator.text(
      nameToPrint,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      addressToPrint,
      styles: const PosStyles(align: PosAlign.center),
    );
    if (activeProfile.phone.isNotEmpty) {
      bytes += generator.text(
        'Tel: ${activeProfile.phone}',
        styles: const PosStyles(align: PosAlign.center),
      );
    }
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
      PosColumn(text: 'TOTAL:', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: 'Rp${transaction.totalAmount.toStringAsFixed(0)}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        text: 'Amount Paid:',
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
      activeProfile.receiptFooter.isNotEmpty
          ? activeProfile.receiptFooter
          : 'Thank you for shopping!',
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
  Future<List<int>> generateTestBytes({StoreProfileModel? storeProfile}) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final activeProfile = storeProfile ?? await StoreProfileService().getProfile();

    List<int> bytes = [];
    bytes += generator.text(
      activeProfile.name,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      'TEST PRINT OK',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      'Optima POS Thermal Printer',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.emptyLines(2);
    bytes += generator.cut();
    return bytes;
  }

  /// Transmits ESC/POS byte stream to selected Bluetooth printer via BLE GATT write characteristic.
  Future<PosPrintResult> _sendBytesToPrinter(
    BluetoothDevice device,
    List<int> bytes,
  ) async {
    if (bytes.isEmpty) return PosPrintResult.ticketEmpty;

    try {
      // Connect to printer device if not already connected
      try {
        await device.connect(timeout: const Duration(seconds: 15));
      } catch (_) {
        // Device might already be connected
      }

      // Discover available GATT services
      List<BluetoothService> services = await device.discoverServices();
      BluetoothCharacteristic? writeCharacteristic;

      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write ||
              characteristic.properties.writeWithoutResponse) {
            writeCharacteristic = characteristic;
            break;
          }
        }
        if (writeCharacteristic != null) break;
      }

      if (writeCharacteristic == null) {
        return PosPrintResult.error;
      }

      // Transmit byte stream in MTU-friendly chunks
      int chunkSize = 100;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        List<int> chunk = bytes.sublist(i, end);
        await writeCharacteristic.write(
          chunk,
          withoutResponse: writeCharacteristic.properties.writeWithoutResponse,
        );
        await Future.delayed(const Duration(milliseconds: 20));
      }

      return PosPrintResult.success;
    } catch (_) {
      return PosPrintResult.error;
    }
  }

  /// Sends raw ESC/POS receipt print job to selected Bluetooth thermal printer.
  Future<PosPrintResult> printTransaction(
    TransactionModel transaction, {
    StoreProfileModel? storeProfile,
  }) async {
    if (_selectedPrinter == null) {
      return PosPrintResult.printerNotSelected;
    }
    final bytes = await generateReceiptBytes(transaction, storeProfile: storeProfile);
    return await _sendBytesToPrinter(_selectedPrinter!, bytes);
  }

  /// Sends a raw ESC/POS test print job to selected Bluetooth thermal printer.
  Future<PosPrintResult> printTest({StoreProfileModel? storeProfile}) async {
    if (_selectedPrinter == null) {
      return PosPrintResult.printerNotSelected;
    }
    final bytes = await generateTestBytes(storeProfile: storeProfile);
    return await _sendBytesToPrinter(_selectedPrinter!, bytes);
  }
}
