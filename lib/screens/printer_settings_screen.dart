import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _printerService = PrinterService.instance;

  static const Color _blue = Color(0xFF1565C0);
  static const Color _bg = Color(0xFFF5F7FA);
  static const Color _textDark = Color(0xFF102A43);
  static const Color _textSub = Color(0xFF627D98);

  PrinterSettings _settings = const PrinterSettings();
  bool _isLoading = true;
  bool _isBusy = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _refreshPrinterState();
  }

  Future<void> _refreshPrinterState() async {
    final settings = await _printerService.loadSettings();
    final connected = await _printerService.isConnected();

    if (!mounted) return;
    setState(() {
      _settings = settings;
      _isConnected = connected;
      _isLoading = false;
    });
  }

  Future<void> _openPrinterPicker() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PrinterPickerSheet(
        onRefresh: _refreshPrinterState,
      ),
    );

    if (result == true && mounted) {
      await _refreshPrinterState();
    }
  }

  Future<void> _disconnectPrinter() async {
    setState(() => _isBusy = true);
    try {
      await _printerService.disconnectPrinter();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printer disconnected')),
      );
      await _refreshPrinterState();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to disconnect the printer right now.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _testPrint() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await _printerService.printTestPage(
        printerName: _settings.printerName,
        paperSize: _settings.paperSize,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test print sent to printer')),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to print. Please check the printer connection.\n$message'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSavedPrinter = _settings.printerName != null && _settings.printerAddress != null;
    final statusTitle = _isConnected
        ? 'Printer Connected'
        : hasSavedPrinter
            ? 'Printer Saved – Not Connected'
            : 'No Printer Connected';

    final statusSubtitle = _isConnected
        ? (_settings.printerName ?? 'Bluetooth Printer')
        : hasSavedPrinter
            ? 'Saved printer is not available right now'
            : 'Connect a thermal printer to print bills';

    final isCardConnected = _isConnected;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _textDark),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Printer Settings',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: _textDark),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(8),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: isCardConnected ? Colors.green.shade50 : const Color(0xFFE8F1FB),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.print_rounded,
                              color: isCardConnected ? Colors.green.shade700 : _blue,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            statusTitle,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            statusSubtitle,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: _textSub,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: isCardConnected ? Colors.green : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isCardConnected ? 'Connected' : 'Disconnected',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: isCardConnected ? Colors.green.shade700 : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_isConnected) ...[
                            Text(
                              'Connection: Bluetooth',
                              style: GoogleFonts.poppins(fontSize: 13, color: _textSub),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Status: Connected',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ] else ...[
                            Text(
                              'Connection: Bluetooth',
                              style: GoogleFonts.poppins(fontSize: 13, color: _textSub),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _isBusy ? null : _testPrint,
                                  icon: const Icon(Icons.print_rounded),
                                  label: const Text('Test Print'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isBusy ? null : _disconnectPrinter,
                                  icon: const Icon(Icons.bluetooth_disabled_rounded),
                                  label: const Text('Disconnect'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SettingsPanel(
                      title: 'Connection',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bluetooth',
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: _textDark),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _settings.printerName ?? 'No printer selected',
                            style: GoogleFonts.poppins(fontSize: 14, color: _textSub),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isBusy ? null : _openPrinterPicker,
                              icon: const Icon(Icons.add_rounded),
                              label: Text(
                                hasSavedPrinter ? 'Change Printer' : 'Connect Printer',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SettingsPanel(
                      title: 'Printer Configuration',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Printer Name',
                            style: GoogleFonts.poppins(fontSize: 12, color: _textSub),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _settings.printerName ?? 'Not configured',
                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: _textDark),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Connection Type',
                            style: GoogleFonts.poppins(fontSize: 12, color: _textSub),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Bluetooth',
                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: _textDark),
                          ),
                          const SizedBox(height: 18),
                          Text('Paper Size', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Radio<String>(
                                      value: '58mm',
                                      groupValue: _settings.paperSize,
                                      onChanged: (value) async {
                                        if (value == null) return;
                                        await _printerService.updateSettings(paperSize: value);
                                        await _refreshPrinterState();
                                      },
                                    ),
                                    const Text('58 mm'),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    Radio<String>(
                                      value: '80mm',
                                      groupValue: _settings.paperSize,
                                      onChanged: (value) async {
                                        if (value == null) return;
                                        await _printerService.updateSettings(paperSize: value);
                                        await _refreshPrinterState();
                                      },
                                    ),
                                    const Text('80 mm'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Character / Print Mode', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Radio<bool>(
                                      value: false,
                                      groupValue: _settings.compactMode,
                                      onChanged: (value) async {
                                        if (value == null) return;
                                        await _printerService.updateSettings(compactMode: value);
                                        await _refreshPrinterState();
                                      },
                                    ),
                                    const Text('Normal'),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    Radio<bool>(
                                      value: true,
                                      groupValue: _settings.compactMode,
                                      onChanged: (value) async {
                                        if (value == null) return;
                                        await _printerService.updateSettings(compactMode: value);
                                        await _refreshPrinterState();
                                      },
                                    ),
                                    const Text('Compact'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile.adaptive(
                            value: _settings.autoCut,
                            title: const Text('Auto Cut'),
                            contentPadding: EdgeInsets.zero,
                            onChanged: (value) async {
                              await _printerService.updateSettings(autoCut: value);
                              await _refreshPrinterState();
                            },
                          ),
                          SwitchListTile.adaptive(
                            value: _settings.openCashDrawer,
                            title: const Text('Open Cash Drawer'),
                            contentPadding: EdgeInsets.zero,
                            onChanged: (value) async {
                              await _printerService.updateSettings(openCashDrawer: value);
                              await _refreshPrinterState();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SettingsPanel(
                      title: 'Default Printer',
                      child: Text(
                        _settings.printerName ?? 'No default printer selected',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: _textDark),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        'Make sure your thermal printer is powered on and paired with your Android device.',
                        style: GoogleFonts.poppins(fontSize: 12, color: _textSub),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF102A43)),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PrinterPickerSheet extends StatefulWidget {
  const _PrinterPickerSheet({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  State<_PrinterPickerSheet> createState() => _PrinterPickerSheetState();
}

class _PrinterPickerSheetState extends State<_PrinterPickerSheet> {
  final _printerService = PrinterService.instance;
  bool _isLoading = true;
List<BluetoothDevice> _devices = const <BluetoothDevice>[];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final available = await _printerService.discoverPrinters();
      if (!mounted) return;
      setState(() {
        _devices = available;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _error = message;
        _isLoading = false;
      });
    }
  }

  Future<void> _connect(BluetoothDevice printer) async {
    try {
      final connected = await _printerService.connectPrinter(printer);
      if (!mounted) return;
      if (!connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to connect to the selected printer.')),
        );
        return;
      }
      await widget.onRefresh();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Connect Printer',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Connection Type',
            style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF627D98)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Bluetooth'),
                  selected: true,
                  onSelected: (_) {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Text('USB'),
                  selected: false,
                  onSelected: (_) {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: GoogleFonts.poppins(color: Colors.red.shade700),
              ),
            )
          else if (_devices.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'No paired Bluetooth printers found. Turn on the printer and pair it with the phone first.',
                style: GoogleFonts.poppins(color: const Color(0xFF102A43)),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _devices.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final device = _devices[index];
                  return ListTile(
                    title: Text(device.name ?? 'Bluetooth Printer'),
                    subtitle: const Text('Bluetooth Printer'),
                    trailing: TextButton(
                      onPressed: () => _connect(device),
                      child: const Text('Connect'),
                    ),
                    onTap: () => _connect(device),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
