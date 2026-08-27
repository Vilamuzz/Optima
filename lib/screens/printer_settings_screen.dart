import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:flutter/material.dart';

import '../services/printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({Key? key}) : super(key: key);

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrinterService _printerService = PrinterService();
  bool _isTestingPrint = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() {
    _printerService.startScan();
  }

  Future<void> _testPrint() async {
    if (_printerService.selectedPrinter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Bluetooth printer first.')),
      );
      return;
    }

    setState(() => _isTestingPrint = true);

    try {
      final result = await _printerService.printTest();
      if (!mounted) return;

      if (result == PosPrintResult.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test print sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print result: ${result.msg}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Print error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isTestingPrint = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPrinter = _printerService.selectedPrinter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Thermal Printer'),
        actions: [
          StreamBuilder<bool>(
            stream: _printerService.isScanning,
            initialData: false,
            builder: (context, snapshot) {
              final isScanning = snapshot.data ?? false;
              if (isScanning) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Scan for printers',
                onPressed: _startScan,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Active Printer Status Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selectedPrinter != null
                  ? Colors.blue.shade50
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selectedPrinter != null
                    ? Colors.blue.shade300
                    : Colors.grey.shade300,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.print,
                      color: selectedPrinter != null
                          ? Colors.blue.shade700
                          : Colors.grey,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Active Thermal Printer',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            selectedPrinter?.name ?? 'No printer selected',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: selectedPrinter != null
                                  ? Colors.black87
                                  : Colors.grey.shade700,
                            ),
                          ),
                          if (selectedPrinter?.address != null)
                            Text(
                              'Address: ${selectedPrinter!.address}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: selectedPrinter == null || _isTestingPrint
                      ? null
                      : _testPrint,
                  icon: _isTestingPrint
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print_outlined),
                  label: const Text('Send Raw Test Print Job'),
                ),
                const Divider(height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Auto-Print Receipts on Checkout',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Triggers print job immediately after successful sale',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _printerService.autoPrintOnCheckout,
                  onChanged: (val) {
                    setState(() {
                      _printerService.autoPrintOnCheckout = val;
                    });
                  },
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Discovered Bluetooth Devices',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Discovered Printers List
          Expanded(
            child: StreamBuilder<List<PrinterBluetooth>>(
              stream: _printerService.scanResults,
              initialData: const [],
              builder: (context, snapshot) {
                final printers = snapshot.data ?? [];

                if (printers.isEmpty) {
                  return StreamBuilder<bool>(
                    stream: _printerService.isScanning,
                    initialData: false,
                    builder: (context, scanSnap) {
                      final isScanning = scanSnap.data ?? false;
                      if (isScanning) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Scanning for nearby Bluetooth thermal printers...'),
                            ],
                          ),
                        );
                      }
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bluetooth_searching,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text('No Bluetooth thermal printers found.'),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _startScan,
                              child: const Text('Scan Again'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }

                return ListView.builder(
                  itemCount: printers.length,
                  itemBuilder: (context, index) {
                    final printer = printers[index];
                    final isSelected =
                        _printerService.selectedPrinter?.address == printer.address;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          Icons.bluetooth,
                          color: isSelected ? Colors.blue : Colors.grey,
                        ),
                        title: Text(
                          printer.name ?? 'Unknown Device',
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(printer.address ?? 'No Address'),
                        trailing: isSelected
                            ? const Chip(
                                avatar: Icon(Icons.check, size: 16),
                                label: Text('Connected'),
                                backgroundColor: Colors.lightBlueAccent,
                              )
                            : OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _printerService.selectPrinter(printer);
                                  });
                                },
                                child: const Text('Pair & Select'),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
