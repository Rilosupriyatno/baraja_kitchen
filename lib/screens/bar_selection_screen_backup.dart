// screens/bar_selection_screen.dart
import 'package:flutter/material.dart';
import 'kitchen_dashboard.dart';

class BarSelectionScreen extends StatefulWidget {
  const BarSelectionScreen({super.key});

  @override
  State<BarSelectionScreen> createState() => _BarSelectionScreenState();
}

class _BarSelectionScreenState extends State<BarSelectionScreen> {
  static const Color brandColor = Color(0xFF077A4B);
  String? _selectedBarType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          child: SingleChildScrollView(  // ← Tambahkan ini
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

                // Bar Type Selection
                Row(
                  children: [
                    Expanded(
                      child: _BarTypeCard(
                        title: 'Bar Depan',
                        description: 'Area meja A-I',
                        icon: Icons.local_bar,
                        isSelected: _selectedBarType == 'depan',
                        onTap: () {
                          setState(() {
                            _selectedBarType = 'depan';
                          });
                        },
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: _BarTypeCard(
                        title: 'Bar Belakang',
                        description: 'Area meja J-Z',
                        icon: Icons.local_bar_outlined,
                        isSelected: _selectedBarType == 'belakang',
                        onTap: () {
                          setState(() {
                            _selectedBarType = 'belakang';
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Kitchen Option
                _BarTypeCard(
                  title: 'Kitchen',
                  description: 'Kelola semua pesanan makanan',
                  icon: Icons.kitchen,
                  isSelected: _selectedBarType == 'kitchen',
                  onTap: () {
                    setState(() {
                      _selectedBarType = 'kitchen';
                    });
                  },
                ),

                const SizedBox(height: 40),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _selectedBarType != null ? _continueToDashboard : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
                      foregroundColor: Colors.white,
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
          ),  // ← Tutup SingleChildScrollView
        ),
      ),
    );
  }

  String _getInfoText() {
    switch (_selectedBarType) {
      case 'depan':
        return 'Bar Depan akan menerima pesanan minuman untuk meja A-I';
      case 'belakang':
        return 'Bar Belakang akan menerima pesanan minuman untuk meja J-Z';
      case 'kitchen':
        return 'Kitchen akan menerima semua pesanan makanan';
      default:
        return 'Pilih tipe bar untuk melihat informasi area penanganan';
    }
  }

  void _continueToDashboard() {
    if (_selectedBarType != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => KitchenDashboard(
            barType: _selectedBarType == 'kitchen' ? null : _selectedBarType,
          ),
        ),
      );
    }
  }
}

class _BarTypeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _BarTypeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? const Color(0xFF077A4B) : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF077A4B).withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF077A4B) : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey[600],
                  size: 30,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? const Color(0xFF077A4B) : Colors.black87,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? const Color(0xFF077A4B) : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}