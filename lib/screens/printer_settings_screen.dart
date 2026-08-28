import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/printer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav_bar.dart';

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
    try {
      _printerService.startScan();
    } catch (e) {
      debugPrint('Scan exception: $e');
    }
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
            content: Text('Test receipt sent successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print result: ${result.msg}'),
            backgroundColor: AppTheme.secondaryAmber,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Print error: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isTestingPrint = false);
    }
  }

  String _getDeviceName(BluetoothDevice device, String? advName) {
    if (device.platformName.isNotEmpty) return device.platformName;
    if (advName != null && advName.isNotEmpty) return advName;
    return 'Unknown Device';
  }

  @override
  Widget build(BuildContext context) {
    final selectedPrinter = _printerService.selectedPrinter;

    return Scaffold(
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 3),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.print_rounded, color: AppTheme.secondaryAmber),
            SizedBox(width: 10),
            Text('Thermal Printer Setup'),
          ],
        ),
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
                    ),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Scan for devices',
                onPressed: _startScan,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Active Printer Banner Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: selectedPrinter != null
                  ? AppTheme.primaryEmerald.withOpacity(0.08)
                  : AppTheme.secondaryAmber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selectedPrinter != null
                    ? AppTheme.primaryEmerald.withOpacity(0.3)
                    : AppTheme.secondaryAmber.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selectedPrinter != null
                            ? AppTheme.primaryEmerald.withOpacity(0.15)
                            : AppTheme.secondaryAmber.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.print_rounded,
                        color: selectedPrinter != null
                            ? AppTheme.primaryEmerald
                            : AppTheme.secondaryAmber,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
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
                            selectedPrinter != null
                                ? _getDeviceName(selectedPrinter, selectedPrinter.advName)
                                : 'No printer selected',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (selectedPrinter != null)
                            Text(
                              'ID / Address: ${selectedPrinter.remoteId.str}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: selectedPrinter == null || _isTestingPrint
                        ? null
                        : _testPrint,
                    icon: _isTestingPrint
                        ? const SizedBox.shrink()
                        : const Icon(Icons.receipt_long_rounded, size: 18),
                    label: _isTestingPrint
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Send Test Receipt Print'),
                  ),
                ),
                const Divider(height: 28),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Auto-Print Receipts on Checkout',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Triggers print job automatically after payment completes',
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
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Discovered Bluetooth Devices',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Discovered Printers List
          Expanded(
            child: StreamBuilder<List<ScanResult>>(
              stream: _printerService.scanResults,
              initialData: const [],
              builder: (context, snapshot) {
                final scanResults = snapshot.data ?? [];

                if (scanResults.isEmpty) {
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
                            Icon(
                              Icons.bluetooth_searching_rounded,
                              size: 56,
                              color: Colors.grey.withOpacity(0.4),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No Bluetooth thermal printers found',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: _startScan,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Scan Again'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: scanResults.length,
                  itemBuilder: (context, index) {
                    final scanResult = scanResults[index];
                    final device = scanResult.device;
                    final deviceName = _getDeviceName(
                      device,
                      scanResult.advertisementData.advName,
                    );
                    final isSelected =
                        _printerService.selectedPrinter?.remoteId.str ==
                            device.remoteId.str;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? AppTheme.primaryEmerald.withOpacity(0.15)
                              : Colors.grey.withOpacity(0.15),
                          child: Icon(
                            Icons.bluetooth_rounded,
                            color: isSelected
                                ? AppTheme.primaryEmerald
                                : Colors.grey,
                          ),
                        ),
                        title: Text(
                          deviceName,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          device.remoteId.str,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: isSelected
                            ? Chip(
                                avatar: const Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: AppTheme.primaryEmerald,
                                ),
                                label: const Text('Active'),
                                backgroundColor:
                                    AppTheme.primaryEmerald.withOpacity(0.15),
                                side: BorderSide.none,
                              )
                            : OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _printerService.selectPrinter(device);
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
