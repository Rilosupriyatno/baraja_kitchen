// screens/bar_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:baraja_bar/services/device_service.dart';
import 'package:baraja_bar/models/device.dart';
import 'kitchen_dashboard.dart';

class BarSelectionScreen extends StatefulWidget {
  const BarSelectionScreen({super.key});

  @override
  State<BarSelectionScreen> createState() => _BarSelectionScreenState();
}

class _BarSelectionScreenState extends State<BarSelectionScreen> {
  static const Color brandColor = Color(0xFF077A4B);
  final DeviceService _deviceService = DeviceService();

  List<Device> _devices = [];
  String? _selectedDeviceLocation;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final devices = await _deviceService.getActiveDevices();
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data device: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo/Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: brandColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Image.asset(
                    'assets/icons/logo.png',
                    height: 80,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.local_bar,
                        color: Colors.white,
                        size: 80,
                      );
                    },
                  ),
                ),

                const SizedBox(height: 40),

                // Title
                const Text(
                  'Pilih Tipe Bar',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Silakan pilih bar yang akan Anda kelola',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 40),

                // Loading, Error, or Device List
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        color: brandColor,
                      ),
                    ),
                  )
                else if (_errorMessage != null)
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700], size: 48),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red[800]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _loadDevices,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  )
                else if (_devices.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange[700], size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            'Tidak ada device yang tersedia',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  else
                    _buildDeviceSelection(),

                const SizedBox(height: 40),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _selectedDeviceLocation != null ? _continueToDashboard : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Lanjutkan ke Dashboard',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Info Text
                if (_selectedDeviceLocation != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _getInfoText(),
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceSelection() {
    // Jika hanya 2 device, tampilkan dalam Row
    if (_devices.length == 2) {
      return Row(
        children: [
          Expanded(
            child: _BarTypeCard(
              title: _devices[0].deviceName ?? 'Device 1',
              icon: Icons.local_bar,
              isSelected: _selectedDeviceLocation == _devices[0].location,
              isOnline: _devices[0].isOnline,
              onTap: () {
                print('Device 0 tapped - Location: ${_devices[0].location}');
                setState(() {
                  _selectedDeviceLocation = _devices[0].location;
                  print('Selected location set to: $_selectedDeviceLocation');
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _BarTypeCard(
              title: _devices[1].deviceName ?? 'Device 2',
              icon: Icons.local_bar_outlined,
              isSelected: _selectedDeviceLocation == _devices[1].location,
              isOnline: _devices[1].isOnline,
              onTap: () {
                print('Device 1 tapped - Location: ${_devices[1].location}');
                setState(() {
                  _selectedDeviceLocation = _devices[1].location;
                  print('Selected location set to: $_selectedDeviceLocation');
                });
              },
            ),
          ),
        ],
      );
    }

    // Jika lebih dari 2, tampilkan dalam Grid
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        final icons = [
          Icons.local_bar,
          Icons.local_bar_outlined,
          Icons.kitchen,
          Icons.restaurant,
        ];

        return _BarTypeCard(
          title: device.deviceName ?? 'Device ${index + 1}',
          icon: icons[index % icons.length],
          isSelected: _selectedDeviceLocation == device.location,
          isOnline: device.isOnline,
          onTap: () {
            print('Device $index tapped - Location: ${device.location}');
            setState(() {
              _selectedDeviceLocation = device.location;
              print('Selected location set to: $_selectedDeviceLocation');
            });
          },
        );
      },
    );
  }

  String _getInfoText() {
    if (_selectedDeviceLocation == null) {
      return 'Pilih device untuk melihat informasi detail';
    }

    final selectedDevice = _devices.firstWhere(
          (d) => d.location == _selectedDeviceLocation,
      orElse: () => _devices.first,
    );

    return
        '${selectedDevice.deviceName} - Siap menerima pesanan';
  }

  void _continueToDashboard() {
    if (_selectedDeviceLocation != null) {
      final selectedDevice = _devices.firstWhere((d) => d.location == _selectedDeviceLocation);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => KitchenDashboard(
            barType: selectedDevice.location,
          ),
        ),
      );
    }
  }
}

class _BarTypeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final bool isOnline;
  final VoidCallback onTap;

  const _BarTypeCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    this.isOnline = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFF077A4B)
              : (isOnline ? Colors.grey[300]! : Colors.red[300]!),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isOnline ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF077A4B).withOpacity(0.05)
                : (isOnline ? Colors.white : Colors.grey[100]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isOnline
                      ? (isSelected ? const Color(0xFF077A4B) : Colors.grey[200])
                      : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isOnline
                      ? (isSelected ? Colors.white : Colors.grey[600])
                      : Colors.grey[500],
                  size: 30,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isOnline
                      ? (isSelected ? const Color(0xFF077A4B) : Colors.black87)
                      : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),

              if (!isOnline) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'OFFLINE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}