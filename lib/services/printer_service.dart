import 'dart:io';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterSettings {
  const PrinterSettings({
    this.printerName,
    this.printerAddress,
    this.paperSize = '58mm',
    this.compactMode = false,
    this.autoCut = true,
    this.openCashDrawer = false,
  });

  final String? printerName;
  final String? printerAddress;
  final String paperSize;
  final bool compactMode;
  final bool autoCut;
  final bool openCashDrawer;

  PrinterSettings copyWith({
    String? printerName,
    String? printerAddress,
    String? paperSize,
    bool? compactMode,
    bool? autoCut,
    bool? openCashDrawer,
  }) {
    return PrinterSettings(
      printerName: printerName ?? this.printerName,
      printerAddress: printerAddress ?? this.printerAddress,
      paperSize: paperSize ?? this.paperSize,
      compactMode: compactMode ?? this.compactMode,
      autoCut: autoCut ?? this.autoCut,
      openCashDrawer: openCashDrawer ?? this.openCashDrawer,
    );
  }
}

class PrinterService {
  PrinterService._();

  static final PrinterService instance = PrinterService._();

  static const String _printerNameKey = 'printer_name';
  static const String _printerAddressKey = 'printer_address';
  static const String _paperSizeKey = 'printer_paper_size';
  static const String _compactModeKey = 'printer_compact_mode';
  static const String _autoCutKey = 'printer_auto_cut';
  static const String _cashDrawerKey = 'printer_cash_drawer';

  BlueThermalPrinter get printer => BlueThermalPrinter.instance;

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<PrinterSettings> loadSettings() async {
    final prefs = await _prefs;
    return PrinterSettings(
      printerName: prefs.getString(_printerNameKey),
      printerAddress: prefs.getString(_printerAddressKey),
      paperSize: prefs.getString(_paperSizeKey) ?? '58mm',
      compactMode: prefs.getBool(_compactModeKey) ?? false,
      autoCut: prefs.getBool(_autoCutKey) ?? true,
      openCashDrawer: prefs.getBool(_cashDrawerKey) ?? false,
    );
  }

  Future<void> saveSettings(PrinterSettings settings) async {
    final prefs = await _prefs;
    if (settings.printerName != null) {
      await prefs.setString(_printerNameKey, settings.printerName!);
    }
    if (settings.printerAddress != null) {
      await prefs.setString(_printerAddressKey, settings.printerAddress!);
    }
    await prefs.setString(_paperSizeKey, settings.paperSize);
    await prefs.setBool(_compactModeKey, settings.compactMode);
    await prefs.setBool(_autoCutKey, settings.autoCut);
    await prefs.setBool(_cashDrawerKey, settings.openCashDrawer);
  }

  Future<void> clearSavedPrinter() async {
    final prefs = await _prefs;
    await prefs.remove(_printerNameKey);
    await prefs.remove(_printerAddressKey);
  }

  Future<bool> requestBluetoothPermissions() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final permissions = <Permission>[];
    permissions.addAll([
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ]);

    final states = await permissions.request();
    for (final status in states.values) {
      if (status.isDenied || status.isPermanentlyDenied || status.isRestricted) {
        return false;
      }
    }

    return true;
  }

  Future<bool> ensurePrinterAvailable() async {
    try {
      final isAvailable = await printer.isAvailable;
      if (!(isAvailable ?? false)) {
        return false;
      }
      final isOn = await printer.isOn;
      return (isOn ?? false);
    } catch (_) {
      return false;
    }
  }

  Future<List<BluetoothDevice>> discoverPrinters() async {
    final granted = await requestBluetoothPermissions();
    if (!granted) {
      throw Exception('Bluetooth permission was denied.');
    }

    final available = await printer.isAvailable;
    if (!(available ?? false)) {
      throw Exception('No Bluetooth adapter is available on this device.');
    }

    final isOn = await printer.isOn;
    if (!(isOn ?? false)) {
      throw Exception('Bluetooth is turned off.');
    }

    final devices = await printer.getBondedDevices();
    final seen = <String>{};
    final unique = <BluetoothDevice>[];

    for (final device in devices) {
      final key = '${device.name ?? 'Unknown'}::${device.address ?? ''}';
      if (device.name != null && device.name!.trim().isNotEmpty && !seen.contains(key)) {
        seen.add(key);
        unique.add(device);
      }
    }

    return unique;
  }

  Future<bool> isConnected() async {
    try {
      final connected = await printer.isConnected;
      return connected ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> connectPrinter(BluetoothDevice device) async {
    final available = await ensurePrinterAvailable();
    if (!available) {
      throw Exception('Bluetooth is turned off or unavailable.');
    }

    try {
      await printer.connect(device);
      final connected = await isConnected();
      if (connected) {
        final settings = await loadSettings();
        await saveSettings(
          settings.copyWith(
            printerName: device.name ?? settings.printerName,
            printerAddress: device.address ?? settings.printerAddress,
          ),
        );
      }
      return connected;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnectPrinter() async {
    try {
      await printer.disconnect();
    } catch (_) {
      // Silently fail to avoid app crashes if the printer is already disconnected.
    }
  }

  Future<bool> connectSavedPrinter() async {
    final settings = await loadSettings();
    final name = settings.printerName;
    final address = settings.printerAddress;
    if (name == null || address == null || address.isEmpty) {
      return false;
    }

    final connected = await connectPrinter(BluetoothDevice(name, address));
    return connected;
  }

  Future<bool> hasSavedPrinter() async {
    final settings = await loadSettings();
    return settings.printerName != null && settings.printerAddress != null;
  }

  Future<void> updateSettings({
    String? paperSize,
    bool? compactMode,
    bool? autoCut,
    bool? openCashDrawer,
  }) async {
    final settings = await loadSettings();
    await saveSettings(
      settings.copyWith(
        paperSize: paperSize ?? settings.paperSize,
        compactMode: compactMode ?? settings.compactMode,
        autoCut: autoCut ?? settings.autoCut,
        openCashDrawer: openCashDrawer ?? settings.openCashDrawer,
      ),
    );
  }

  Future<void> printTestPage({required String? printerName, required String paperSize}) async {
    final connected = await isConnected();
    if (!connected) {
      final savedConnected = await connectSavedPrinter();
      if (!savedConnected) {
        throw Exception('Printer is not connected.');
      }
    }

    final settings = await loadSettings();
    final displayName = printerName ?? settings.printerName ?? 'Printer';
    final lines = <String>[
      '--------------------------------',
      '       SWAMIDATTA ERP',
      '    WHOLESALE FOOTWEAR',
      '--------------------------------',
      '',
      'Printer Test Successful',
      '',
      'Printer: $displayName',
      'Connection: Bluetooth',
      'Paper: $paperSize',
      '--------------------------------',
    ];

    await _printLines(lines, settings: settings);
  }

  Future<bool> printBillText({
    required String invoiceNumber,
    required String customerName,
    required String customerMobile,
    required List<String> itemLines,
    required double grandTotal,
  }) async {
    final connected = await isConnected();
    if (!connected) {
      final savedConnected = await connectSavedPrinter();
      if (!savedConnected) {
        return false;
      }
    }

    final settings = await loadSettings();
    final totalValue = '₹${grandTotal.toStringAsFixed(grandTotal % 1 == 0 ? 0 : 2)}';

    final lines = <String>[
      '--------------------------------',
      '       SWAMIDATTA ERP',
      '    WHOLESALE FOOTWEAR',
      '--------------------------------',
      'Bill: $invoiceNumber',
      'Customer: $customerName',
      'Mobile: $customerMobile',
      '--------------------------------',
      ...itemLines,
      '--------------------------------',
      'TOTAL: $totalValue',
      '--------------------------------',
    ];

    await _printLines(lines, settings: settings);
    return true;
  }

  Future<void> _printLines(List<String> lines, {required PrinterSettings settings}) async {
    for (final line in lines) {
      if (line.isEmpty) {
        await printer.printNewLine();
      } else {
        await printer.printCustom(line, 1, 0, charset: 'UTF-8');
        await printer.printNewLine();
      }
    }

    if (settings.autoCut) {
      try {
        await printer.paperCut();
      } catch (_) {}
    }

    if (settings.openCashDrawer) {
      try {
        await printer.drawerPin5();
      } catch (_) {}
    }
  }
}
