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
  String? _selectedDeviceId;
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive breakpoints
          final isTablet = constraints.maxWidth >= 600;
          final isLargeTablet = constraints.maxWidth >= 900;

          // Dynamic sizing based on screen size
          final maxWidth = isLargeTablet ? 900.0 : (isTablet ? 700.0 : 500.0);
          final horizontalPadding = isTablet ? 48.0 : 24.0;
          final logoSize = isTablet ? 100.0 : 80.0;
          final titleSize = isTablet ? 36.0 : 28.0;
          final subtitleSize = isTablet ? 18.0 : 16.0;

          return Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: EdgeInsets.all(horizontalPadding),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false, // Hilangkan scrollbar
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: isTablet ? 40 : 20),

                      // Logo/Header
                      Container(
                        padding: EdgeInsets.all(isTablet ? 28 : 20),
                        decoration: BoxDecoration(
                          color: brandColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: brandColor.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/icons/logo.png',
                          height: logoSize,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.local_bar,
                              color: Colors.white,
                              size: logoSize,
                            );
                          },
                        ),
                      ),

                      SizedBox(height: isTablet ? 48 : 32),

                      // Title
                      Text(
                        'Pilih Perangkat',
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),

                      SizedBox(height: isTablet ? 12 : 8),

                      Text(
                        'Silakan pilih perangkat yang akan Anda kelola',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: subtitleSize,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),

                      SizedBox(height: isTablet ? 56 : 40),

                      // Loading, Error, or Device List
                      if (_isLoading)
                        Padding(
                          padding: EdgeInsets.all(isTablet ? 60 : 40),
                          child: Column(
                            children: [
                              SizedBox(
                                width: isTablet ? 80 : 60,
                                height: isTablet ? 80 : 60,
                                child: const CircularProgressIndicator(
                                  color: brandColor,
                                  strokeWidth: 5,
                                ),
                              ),
                              SizedBox(height: isTablet ? 24 : 16),
                              Text(
                                'Memuat data device...',
                                style: TextStyle(
                                  fontSize: isTablet ? 18 : 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_errorMessage != null)
                        _buildErrorWidget(isTablet)
                      else if (_devices.isEmpty)
                          _buildEmptyWidget(isTablet)
                        else
                          _buildDeviceSelection(isTablet, isLargeTablet),

                      SizedBox(height: isTablet ? 48 : 32),

                      // Continue Button
                      SizedBox(
                        width: double.infinity,
                        height: isTablet ? 64 : 56,
                        child: ElevatedButton(
                          onPressed: _selectedDeviceId != null ? _continueToDashboard : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[300],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: _selectedDeviceId != null ? 4 : 0,
                            shadowColor: brandColor.withOpacity(0.4),
                          ),
                          child: Text(
                            'Lanjutkan ke Dashboard',
                            style: TextStyle(
                              fontSize: isTablet ? 18 : 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: isTablet ? 24 : 20),

                      // Info Text
                      if (_selectedDeviceId != null)
                        Container(
                          padding: EdgeInsets.all(isTablet ? 20 : 16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue[100]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue[700],
                                size: isTablet ? 24 : 20,
                              ),
                              SizedBox(width: isTablet ? 16 : 12),
                              Expanded(
                                child: Text(
                                  _getInfoText(),
                                  style: TextStyle(
                                    color: Colors.blue[800],
                                    fontSize: isTablet ? 15 : 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      SizedBox(height: isTablet ? 40 : 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget(bool isTablet) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isTablet ? 28 : 20),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red[700],
                size: isTablet ? 64 : 48,
              ),
              SizedBox(height: isTablet ? 16 : 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red[800],
                  fontSize: isTablet ? 16 : 14,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isTablet ? 24 : 20),
        ElevatedButton.icon(
          onPressed: _loadDevices,
          icon: Icon(Icons.refresh, size: isTablet ? 24 : 20),
          label: Text(
            'Coba Lagi',
            style: TextStyle(fontSize: isTablet ? 16 : 14),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: brandColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 32 : 24,
              vertical: isTablet ? 16 : 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyWidget(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 28 : 20),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        children: [
          Icon(
            Icons.warning_amber,
            color: Colors.orange[700],
            size: isTablet ? 64 : 48,
          ),
          SizedBox(height: isTablet ? 16 : 12),
          Text(
            'Tidak ada device yang tersedia',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSelection(bool isTablet, bool isLargeTablet) {
    // Calculate grid columns based on screen size and device count
    int crossAxisCount = 2;
    if (isLargeTablet && _devices.length >= 3) {
      crossAxisCount = 3;
    } else if (!isTablet && _devices.length == 2) {
      crossAxisCount = 2;
    }

    // For 2 devices on tablet, use Row for better layout
    if (_devices.length == 2 && isTablet) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _BarTypeCard(
              title: _devices[0].deviceName,
              icon: Icons.local_bar,
              isSelected: _selectedDeviceId == _devices[0].deviceId,
              isOnline: _devices[0].isOnline,
              isNotes: _devices[0].notes,
              isTablet: isTablet,
              onTap: () {
                setState(() {
                  _selectedDeviceId = _devices[0].deviceId;
                });
              },
            ),
          ),
          SizedBox(width: isTablet ? 24 : 16),
          Expanded(
            child: _BarTypeCard(
              title: _devices[1].deviceName,
              icon: Icons.local_bar_outlined,
              isSelected: _selectedDeviceId == _devices[1].deviceId,
              isOnline: _devices[1].isOnline,
              isNotes: _devices[1].notes,
              isTablet: isTablet,
              onTap: () {
                setState(() {
                  _selectedDeviceId = _devices[1].deviceId;
                });
              },
            ),
          ),
        ],
      );
    }

    // Wrap layout - lebih fleksibel daripada Grid
    return Wrap(
      spacing: isTablet ? 24 : 16,
      runSpacing: isTablet ? 24 : 16,
      alignment: WrapAlignment.center,
      children: _devices.asMap().entries.map((entry) {
        final index = entry.key;
        final device = entry.value;
        final icons = [
          Icons.kitchen,
        ];

        // Calculate card width based on screen size
        final cardWidth = isLargeTablet
            ? (900 - 96 - 48) / 3  // 3 columns
            : isTablet
            ? (700 - 96 - 24) / 2  // 2 columns
            : (MediaQuery.of(context).size.width - 48 - 16) / 2;  // 2 columns mobile

        return SizedBox(
          width: cardWidth,
          child: _BarTypeCard(
            title: device.deviceName,
            icon: icons[index % icons.length],
            isSelected: _selectedDeviceId == device.deviceId,
            isOnline: device.isOnline,
            isNotes: device.notes,
            isTablet: isTablet,
            onTap: () {
              setState(() {
                _selectedDeviceId = device.deviceId;
              });
            },
          ),
        );
      }).toList(),
    );
  }

  String _getInfoText() {
    if (_selectedDeviceId == null) {
      return 'Pilih device untuk melihat informasi detail';
    }

    final selectedDevice = _devices.firstWhere(
          (d) => d.deviceId == _selectedDeviceId,
      orElse: () => _devices.first,
    );

    return '${selectedDevice.deviceName} - Siap menerima pesanan';
  }

  void _continueToDashboard() {
    if (_selectedDeviceId != null) {
      final selectedDevice = _devices.firstWhere(
            (d) => d.deviceId == _selectedDeviceId,
        orElse: () => _devices.first,
      );

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
  final String isNotes;
  final bool isTablet;
  final VoidCallback onTap;

  const _BarTypeCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    this.isOnline = true,
    required this.isNotes,
    this.isTablet = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardPadding = isTablet ? 20.0 : 16.0;
    final iconSize = isTablet ? 32.0 : 26.0;
    final iconPadding = isTablet ? 16.0 : 12.0;
    final titleSize = isTablet ? 16.0 : 15.0;
    final notesSize = isTablet ? 12.0 : 11.0;

    return Card(
      elevation: isSelected ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFF077A4B)
              : (isOnline ? Colors.grey[300]! : Colors.red[300]!),
          width: isSelected ? 3 : 1.5,
        ),
      ),
      shadowColor: isSelected
          ? const Color(0xFF077A4B).withOpacity(0.3)
          : Colors.black.withOpacity(0.1),
      child: InkWell(
        onTap: isOnline ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.all(cardPadding),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF077A4B).withOpacity(0.08)
                : (isOnline ? Colors.white : Colors.grey[100]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Container
              Container(
                padding: EdgeInsets.all(iconPadding),
                decoration: BoxDecoration(
                  color: isOnline
                      ? (isSelected ? const Color(0xFF077A4B) : Colors.grey[200])
                      : Colors.grey[300],
                  shape: BoxShape.circle,
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: const Color(0xFF077A4B).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ] : [],
                ),
                child: Icon(
                  icon,
                  color: isOnline
                      ? (isSelected ? Colors.white : Colors.grey[600])
                      : Colors.grey[500],
                  size: iconSize,
                ),
              ),

              SizedBox(height: isTablet ? 12 : 10),

              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w600,
                  color: isOnline
                      ? (isSelected ? const Color(0xFF077A4B) : Colors.black87)
                      : Colors.grey[600],
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Notes - dengan Flexible untuk auto adjust
              if (isNotes.isNotEmpty) ...[
                SizedBox(height: isTablet ? 8 : 6),
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: isTablet ? 50 : 40, // Batasi tinggi maksimal
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 10 : 8,
                      vertical: isTablet ? 5 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF077A4B).withOpacity(0.12)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF077A4B).withOpacity(0.3)
                            : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isNotes,
                      style: TextStyle(
                        fontSize: notesSize,
                        color: isSelected
                            ? const Color(0xFF077A4B)
                            : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],

              // Offline Status
              if (!isOnline) ...[
                SizedBox(height: isTablet ? 8 : 6),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 8 : 6,
                    vertical: isTablet ? 4 : 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'OFFLINE',
                    style: TextStyle(
                      fontSize: isTablet ? 10 : 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                      letterSpacing: 0.5,
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