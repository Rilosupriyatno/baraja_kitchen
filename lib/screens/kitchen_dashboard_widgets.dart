// screens/kitchen_dashboard_widgets.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../models/out_of_stock_model.dart';
import '../models/category_model.dart';
import '../services/notification_service.dart';
import '../services/thermal_print_service.dart';
import 'batch_cooking_screen.dart';

class KitchenDashboardWidgets {
  static const Color brandColor = Color(0xFF077A4B);

  static PreferredSizeWidget buildAppBar({
    required BuildContext context,
    required String? barType,
    required DateTime currentTime,
    required ThermalPrintService printService,
    required bool autoPrintEnabled,
    required NotificationService notificationService,
    required List<OutOfStockItem> outOfStockItems,
    required bool isLoading,
    required VoidCallback onPrinterSettings,
    required VoidCallback onOutOfStockDialog,
    required VoidCallback onRefresh,
  }) {
    final appBarColor = barType == 'depan'
        ? Colors.blue[700]
        : barType == 'belakang'
        ? Colors.orange[700]
        : brandColor;

    return AppBar(
      elevation: 1,
      toolbarHeight: 70,
      backgroundColor: appBarColor,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: Image.asset(
              'assets/icons/logo.png',
              height: 32,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.restaurant, color: Colors.white, size: 32);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  barType == 'depan'
                      ? 'Bar Depan'
                      : barType == 'belakang'
                      ? 'Bar Belakang'
                      : 'Dapur Utama',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  barType == 'depan'
                      ? 'Bar Depan'
                      : barType == 'belakang'
                      ? 'Bar Belakang'
                      : 'Dapur Utama',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _buildBarTypeIndicator(barType),
          if (printService.isConfigured) _buildPrinterStatus(printService),
          if (printService.isConfigured) _buildAutoPrintStatus(autoPrintEnabled),
          if (notificationService.queueLength > 0)
            _buildNotificationBadge(notificationService.queueLength),
          _buildPrinterButton(onPrinterSettings),
          const SizedBox(width: 8),
          if (outOfStockItems.isNotEmpty)
            _buildOutOfStockButton(outOfStockItems.length, onOutOfStockDialog),
          const SizedBox(width: 8),
          _buildRefreshButton(isLoading, onRefresh),
          const SizedBox(width: 8),
          _buildTimeDisplay(currentTime),
        ],
      ),
    );
  }

  static Widget _buildBarTypeIndicator(String? barType) {
    // Define colors based on barType
    final Color bgColor;
    final Color borderColor;
    final Color iconColor;
    final Color textColor;

    if (barType == 'depan') {
      bgColor = Colors.blue[50]!;
      borderColor = Colors.blue[300]!;
      iconColor = Colors.blue[700]!;
      textColor = Colors.blue[900]!;
    } else if (barType == 'belakang') {
      bgColor = Colors.orange[50]!;
      borderColor = Colors.orange[300]!;
      iconColor = Colors.orange[700]!;
      textColor = Colors.orange[900]!;
    } else {
      bgColor = Colors.white;
      borderColor = const Color(0xFF9CC5B0);
      iconColor = brandColor;
      textColor = const Color(0xFF055234);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            barType == 'depan' || barType == 'belakang'
                ? Icons.local_bar
                : Icons.restaurant,
            size: 14,
            color: iconColor,
          ),
          const SizedBox(width: 4),
          Text(
            barType == 'depan'
                ? 'Depan'
                : barType == 'belakang'
                ? 'Belakang'
                : 'Dapur',
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildPrinterStatus(ThermalPrintService printService) {
    final isConnected = printService.consecutiveFailures == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected ? Colors.green.shade300 : Colors.orange.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            printService.connectionType == PrinterConnectionType.wifi
                ? Icons.wifi
                : Icons.bluetooth,
            size: 14,
            color: isConnected ? Colors.green.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            isConnected ? 'Tersambung' : 'Periksa',
            style: TextStyle(
              color: isConnected ? Colors.green.shade900 : Colors.orange.shade900,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildAutoPrintStatus(bool autoPrintEnabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: autoPrintEnabled ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: autoPrintEnabled ? Colors.green.shade300 : Colors.orange.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.print,
            size: 14,
            color: autoPrintEnabled ? Colors.green.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            autoPrintEnabled ? 'Auto' : 'Manual',
            style: TextStyle(
              color: autoPrintEnabled ? Colors.green.shade900 : Colors.orange.shade900,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildNotificationBadge(int queueLength) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade400,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_active, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$queueLength',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildPrinterButton(VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: const Icon(Icons.print, color: brandColor, size: 24),
        onPressed: onPressed,
        tooltip: 'Pengaturan Printer',
      ),
    );
  }

  static Widget _buildOutOfStockButton(int count, VoidCallback onPressed) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: Icon(Icons.inventory_2_outlined, color: Colors.red.shade700, size: 24),
            onPressed: onPressed,
            tooltip: 'Stok Habis/Kritis',
          ),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildRefreshButton(bool isLoading, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: const Icon(Icons.refresh, color: brandColor, size: 24),
        onPressed: isLoading ? null : onPressed,
        tooltip: 'Refresh',
      ),
    );
  }

  static Widget _buildTimeDisplay(DateTime currentTime) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, color: brandColor, size: 18),
          const SizedBox(width: 6),
          Text(
            DateFormat('HH:mm:ss').format(currentTime),
            style: const TextStyle(
              color: brandColor,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildLoadingWidget(Color brandColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(strokeWidth: 5, color: brandColor),
          ),
          const SizedBox(height: 24),
          const Text(
            'Memuat pesanan...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildErrorWidget({
    required String? errorMessage,
    required Color brandColor,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            ),
            const SizedBox(height: 24),
            const Text(
              'Terjadi Kesalahan',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage ?? 'Terjadi kesalahan yang tidak diketahui',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildSidebar({
    required int selectedTabIndex,
    required List<Order> preparing,
    required List<Order> done,
    required List<Order> reservations,
    required List<Category> categories,
    required Color brandColor,
    required Function(int) onTabSelected,
    required Map<String, List<BatchItem>> Function() groupIdenticalItemsForCount,
  }) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildSidebarTab(0, 'Penyiapan', preparing.length, selectedTabIndex, brandColor, onTabSelected),
            _buildSidebarTab(
              1,
              'Batch Cook',
              groupIdenticalItemsForCount().length,
              selectedTabIndex,
              brandColor,
              onTabSelected,
            ),
            _buildSidebarTab(2, 'Selesai', done.length, selectedTabIndex, brandColor, onTabSelected),
            _buildSidebarTab(3, 'Reservasi', reservations.length, selectedTabIndex, brandColor, onTabSelected),
            _buildSidebarTab(5, 'Stok by Kategori', categories.length, selectedTabIndex, brandColor, onTabSelected),
          ],
        ),
      ),
    );
  }

  static Widget _buildSidebarTab(
      int index,
      String title,
      int count,
      int selectedTabIndex,
      Color brandColor,
      Function(int) onTap,
      ) {
    final isSelected = selectedTabIndex == index;

    return InkWell(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? brandColor.withOpacity(0.08) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? brandColor : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? brandColor : Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? brandColor : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildCategoriesPlaceholder({
    required Color brandColor,
    required VoidCallback onNavigate,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Kelola Stok Berdasarkan Kategori',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pilih kategori untuk mengorganisir update stok',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onNavigate,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Buka Kategori'),
            style: ElevatedButton.styleFrom(
              backgroundColor: brandColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}