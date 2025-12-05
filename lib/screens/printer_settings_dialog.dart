// screens/printer_settings_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../services/thermal_print_service.dart';

class PrinterSettingsDialog extends StatefulWidget {
  final ThermalPrintService printService;
  final bool autoPrintEnabled;
  final Function(bool) onAutoPrintChanged;
  final Color brandColor;

  const PrinterSettingsDialog({
    super.key,
    required this.printService,
    required this.autoPrintEnabled,
    required this.onAutoPrintChanged,
    required this.brandColor,
  });

  @override
  State<PrinterSettingsDialog> createState() => _PrinterSettingsDialogState();
}

class _PrinterSettingsDialogState extends State<PrinterSettingsDialog> {
  int _selectedConnectionType = 0;
  final TextEditingController _ipController = TextEditingController();
  List<BluetoothDevice> _bluetoothDevices = [];
  BluetoothDevice? _selectedDevice;
  bool _isScanning = false;
  String? _errorMessage;
  late bool _autoPrintEnabled;

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
  }

  void _loadSavedConfig() {
    final printService = widget.printService;

    _selectedConnectionType =
    printService.connectionType == PrinterConnectionType.wifi ? 0 : 1;

    _ipController.text = printService.printerIp ?? '';

    _selectedDevice = printService.bluetoothDevice;
    if (_selectedDevice != null) {
      _bluetoothDevices = [_selectedDevice!];
    }

    _autoPrintEnabled = widget.autoPrintEnabled;
  }

  Future<void> _scanBluetoothDevices() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final devices = await widget.printService.getPairedDevices();
      setState(() {
        final Set<String> existingAddresses =
        _bluetoothDevices.map((d) => d.address).toSet();
        for (var device in devices) {
          if (!existingAddresses.contains(device.address)) {
            _bluetoothDevices.add(device);
          }
        }
        _isScanning = false;
      });

      if (devices.isEmpty && _bluetoothDevices.isEmpty) {
        setState(() {
          _errorMessage =
          'Tidak ada printer yang dipasangkan. Silakan pair printer di pengaturan Bluetooth perangkat terlebih dahulu.';
        });
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _showManualMacAddressDialog() {
    final TextEditingController macController = TextEditingController();
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Input Manual MAC Address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Printer (Opsional)',
                hintText: 'Thermal Printer',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: macController,
              decoration: const InputDecoration(
                labelText: 'MAC Address',
                hintText: '00:11:22:33:44:55',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 8),
            Text(
              'Format: XX:XX:XX:XX:XX:XX\nContoh: 00:11:22:33:44:55',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final mac = macController.text.trim();
              final name = nameController.text.trim();

              if (mac.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('MAC Address tidak boleh kosong'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final device = BluetoothDevice(
                address: mac,
                name: name.isEmpty ? 'Thermal Printer' : name,
              );

              setState(() {
                _selectedDevice = device;
                final exists =
                _bluetoothDevices.any((d) => d.address == device.address);
                if (!exists) {
                  _bluetoothDevices.add(device);
                }
              });

              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.brandColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  Future<void> _testAndSave() async {
    if (_selectedConnectionType == 0) {
      final ip = _ipController.text.trim();
      if (ip.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('IP Address tidak boleh kosong'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      widget.printService.configurePrinter(ip);
    } else {
      if (_selectedDevice == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilih printer Bluetooth terlebih dahulu'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      widget.printService.configureBluetoothPrinter(_selectedDevice!);
    }

    widget.printService.setAutoPrintEnabled(_autoPrintEnabled);

    final success = await widget.printService.testConnection();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Printer berhasil dikonfigurasi dan disimpan!'
                : 'Gagal terhubung ke printer',
          ),
          backgroundColor: success ? widget.brandColor : Colors.red,
        ),
      );
    }
  }

  void _showClearConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Konfigurasi Printer'),
        content: const Text(
          'Konfigurasi printer yang tersimpan akan dihapus. Anda perlu mengkonfigurasi ulang printer untuk menggunakan fitur auto print.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.printService.clearConfiguration();
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Konfigurasi printer berhasil dihapus'),
                  backgroundColor: widget.brandColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pengaturan Printer'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.printService.isConfigured)
                _buildConfiguredPrinterInfo(),
              _buildConnectionTypeSelector(),
              const SizedBox(height: 20),
              if (_selectedConnectionType == 0)
                _buildWiFiConfiguration()
              else
                _buildBluetoothConfiguration(),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              _buildAutoPrintToggle(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _showClearConfigDialog,
          child: const Text('Hapus Konfigurasi'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _testAndSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.brandColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Test & Simpan'),
        ),
      ],
    );
  }

  Widget _buildConfiguredPrinterInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Printer tersimpan',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  widget.printService.printerInfo,
                  style: TextStyle(color: Colors.green[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionTypeSelector() {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(
          value: 0,
          label: Text('WiFi/LAN'),
          icon: Icon(Icons.wifi),
        ),
        ButtonSegment(
          value: 1,
          label: Text('Bluetooth'),
          icon: Icon(Icons.bluetooth),
        ),
      ],
      selected: {_selectedConnectionType},
      onSelectionChanged: (Set<int> newSelection) {
        setState(() {
          _selectedConnectionType = newSelection.first;
          _errorMessage = null;
        });
      },
    );
  }

  Widget _buildWiFiConfiguration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ipController,
          decoration: const InputDecoration(
            labelText: 'IP Address Printer',
            hintText: '192.168.1.100',
            prefixIcon: Icon(Icons.computer),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        Text(
          'Masukkan IP Address printer thermal di jaringan lokal',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildBluetoothConfiguration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errorMessage != null) _buildErrorMessage(),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _scanBluetoothDevices,
                icon: _isScanning
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Icon(Icons.bluetooth_searching),
                label: Text(_isScanning ? 'Mencari...' : 'Lihat Paired'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.brandColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showManualMacAddressDialog,
                icon: const Icon(Icons.edit),
                label: const Text('Input MAC'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_bluetoothDevices.isNotEmpty)
          _buildDeviceList()
        else if (!_isScanning)
          _buildNoDevicesFound(),
        if (_isScanning) _buildScanningIndicator(),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Perangkat Ditemukan:',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _bluetoothDevices.length,
            itemBuilder: (context, index) {
              final device = _bluetoothDevices[index];
              final isSelected = _selectedDevice?.address == device.address;

              return ListTile(
                leading: Icon(
                  Icons.print_outlined,
                  color: isSelected ? widget.brandColor : Colors.grey[600],
                ),
                title: Text(
                  device.name?.isEmpty ?? true ? 'Unknown Device' : device.name!,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                subtitle: Text(device.address, style: const TextStyle(fontSize: 11)),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: widget.brandColor)
                    : null,
                selected: isSelected,
                selectedTileColor: widget.brandColor.withOpacity(0.1),
                onTap: () => setState(() => _selectedDevice = device),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoDevicesFound() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'Belum ada perangkat',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Pair printer di Settings > Bluetooth,\nlalu tekan "Lihat Paired"',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Mencari printer yang sudah dipair...',
              style: TextStyle(color: Colors.blue[900], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoPrintToggle() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Auto Print',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              SizedBox(height: 4),
              Text(
                'Print otomatis saat order baru',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        Transform.scale(
          scale: 0.9,
          child: Switch(
            value: _autoPrintEnabled,
            onChanged: (value) {
              setState(() => _autoPrintEnabled = value);
              widget.onAutoPrintChanged(value);
            },
            activeColor: widget.brandColor,
          ),
        ),
      ],
    );
  }
}