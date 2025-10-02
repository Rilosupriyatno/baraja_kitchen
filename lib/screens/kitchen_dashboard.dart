// screens/kitchen_dashboard.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/order.dart';
import '../services/order_service.dart';
import '../services/socket_service.dart';
import '../services/notification_service.dart';
import '../services/thermal_print_service.dart';
import '../widgets/order_card_compact.dart';
import 'package:flutter/foundation.dart';

import 'batch_cooking_screen.dart';

class KitchenDashboard extends StatefulWidget {
  const KitchenDashboard({super.key});

  @override
  State<KitchenDashboard> createState() => _KitchenDashboardState();
}

class _KitchenDashboardState extends State<KitchenDashboard> {
  static const Color brandColor = Color(0xFF077A4B);

  List<Order> queue = [];
  List<Order> preparing = [];
  List<Order> done = [];
  List<Order> reservations = [];
  String search = '';
  bool _isLoading = false;
  String? _errorMessage;
  int _selectedTabIndex = 0;

  late Timer _mainTimer;
  late Timer _refreshTimer;
  DateTime _currentTime = DateTime.now();

  final Map<String, bool> _alertPlayedMap = {};
  final NotificationService _notificationService = NotificationService();
  final ThermalPrintService _printService = ThermalPrintService();
  final Set<String> _existingOrderIds = <String>{};
  final Map<String, bool> _expandedOrders = {};

  // Status auto print
  bool _autoPrintEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _initializeTimers();

    SocketService.connect(
      outletId: "outlet-1",
      onNewOrder: (newOrder) {
        _refreshOrders();
      },
    );
  }

  void _initializeTimers() {
    _mainTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _currentTime = DateTime.now();
      });
      _checkForLateOrders();
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshOrders();
    });
  }

  void _checkForLateOrders() {
    for (var order in queue) {
      if (order.isLate) {
        final alreadyPlayed = _alertPlayedMap[order.orderId] ?? false;
        if (!alreadyPlayed) {
          _alertPlayedMap[order.orderId ?? ""] = true;
        }
      }
    }
  }

  @override
  void dispose() {
    _mainTimer.cancel();
    _refreshTimer.cancel();
    SocketService.disconnect();
    _notificationService.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ordersMap = await OrderService.refreshOrders();
      await _mergeOrdersWithAlertState(ordersMap, isInitialLoad: true);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshOrders() async {
    try {
      final ordersMap = await OrderService.refreshOrders();
      await _mergeOrdersWithAlertState(ordersMap);
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing orders: $e');
      }
    }
  }

  Future<void> _mergeOrdersWithAlertState(
      Map<String, List<Order>> ordersMap, {
        bool isInitialLoad = false,
      }) async {
    final newQueue = ordersMap['pending'] ?? [];
    final newPreparing = ordersMap['preparing'] ?? [];
    final newDone = ordersMap['completed'] ?? [];
    final newReservations = ordersMap['reservations'] ?? [];

    for (var order in newQueue) {
      if (order.orderId != null) {
        await OrderService.updateOrderStatus(order.orderId!, 'OnProcess');
        if (kDebugMode) {
          print('✅ Auto-confirmed order ${order.orderId} to OnProcess');
        }
      }
    }

    final allPreparing = [...newPreparing, ...newQueue];

    if (!isInitialLoad) {
      final currentReservationIds = reservations.map((o) => o.orderId).toSet();

      for (var order in allPreparing) {
        if (order.orderId != null) {
          // Cek apakah ini order baru
          if (!_existingOrderIds.contains(order.orderId)) {
            if (kDebugMode) {
              print('🆕 Order baru terdeteksi di Penyiapan: ${order.orderId}');
            }

            // Play notification
            await _notificationService.playNewOrderNotification(
              order.orderId!,
              soundPath: 'sounds/alert.mp3',
            );

            // 🖨️ Auto print jika enabled
            if (_autoPrintEnabled && _printService.isConfigured) {
              final printed = await _printService.autoPrintOrder(order);
              if (printed && mounted) {
                _showPrintSuccessSnackbar(order.orderId!);
              }
            }
          }
          // Cek apakah ini reservasi yang baru dipindah
          else if (currentReservationIds.contains(order.orderId) &&
              order.service.contains('Reservation')) {
            if (kDebugMode) {
              print('📅 Reservasi ${order.orderId} dipindah ke penyiapan');
            }

            await _notificationService.playNewOrderNotification(
              order.orderId!,
              soundPath: 'sounds/alert.mp3',
            );

            // 🖨️ Auto print reservasi yang masuk penyiapan
            if (_autoPrintEnabled && _printService.isConfigured) {
              final printed = await _printService.autoPrintOrder(order);
              if (printed && mounted) {
                _showPrintSuccessSnackbar(order.orderId!);
              }
            }
          }
        }
      }

      for (var order in newReservations) {
        if (order.orderId != null && !_existingOrderIds.contains(order.orderId)) {
          if (kDebugMode) {
            print('🆕 Reservasi baru terdeteksi: ${order.orderId}');
          }
          await _notificationService.playNewOrderNotification(
            order.orderId!,
            soundPath: 'sounds/ding.mp3',
          );
        }
      }
    }

    _existingOrderIds.clear();
    for (var order in [...allPreparing, ...newDone, ...newReservations]) {
      if (order.orderId != null) {
        _existingOrderIds.add(order.orderId!);
      }
    }

    for (var o in allPreparing) {
      if (_alertPlayedMap.containsKey(o.orderId)) {
      } else {
        _alertPlayedMap[o.orderId ?? ""] = false;
      }
    }

    allPreparing.sort((a, b) {
      if (a.updatedAt == null && b.updatedAt == null) return 0;
      if (a.updatedAt == null) return 1;
      if (b.updatedAt == null) return -1;
      return a.updatedAt!.compareTo(b.updatedAt!);
    });

    newDone.sort((a, b) {
      if (a.updatedAt == null && b.updatedAt == null) return 0;
      if (a.updatedAt == null) return 1;
      if (b.updatedAt == null) return -1;
      return a.updatedAt!.compareTo(b.updatedAt!);
    });

    newReservations.sort((a, b) {
      if (a.updatedAt == null && b.updatedAt == null) return 0;
      if (a.updatedAt == null) return 1;
      if (b.updatedAt == null) return -1;
      return a.updatedAt!.compareTo(b.updatedAt!);
    });

    setState(() {
      queue = [];
      preparing = allPreparing;
      done = newDone;
      reservations = newReservations;
    });
  }

  void _showPrintSuccessSnackbar(String orderId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.print, color: Colors.white),
            const SizedBox(width: 8),
            Text('Order $orderId berhasil diprint'),
          ],
        ),
        backgroundColor: brandColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _completeOrder(Order order) async {
    setState(() {
      preparing.remove(order);
      done.add(order);
    });

    if (order.orderId != null) {
      await OrderService.updateOrderStatus(order.orderId!, 'Completed');
    }
    _showOrderCompleteDialog(order);
  }

  void _completeBatchOrders(List<String> orderIds) async {
    for (var orderId in orderIds) {
      final order = preparing.firstWhere(
            (o) => o.orderId == orderId,
        orElse: () => preparing.first,
      );

      setState(() {
        preparing.remove(order);
        done.add(order);
      });

      await OrderService.updateOrderStatus(orderId, 'Completed');
    }

    _showBatchCompleteDialog(orderIds.length);
  }

  void _showOrderCompleteDialog(Order order) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: brandColor, size: 28),
            const SizedBox(width: 12),
            const Text('Pesanan Selesai'),
          ],
        ),
        content: Text(
          '${order.name} (Meja ${order.table}) selesai dalam ${order.totalCookTime()}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            child: const Text('OK', style: TextStyle(fontSize: 16, color: brandColor)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showBatchCompleteDialog(int count) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: brandColor, size: 28),
            const SizedBox(width: 12),
            const Text('Batch Selesai'),
          ],
        ),
        content: Text(
          '$count pesanan berhasil diselesaikan secara batch!',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            child: const Text('OK', style: TextStyle(fontSize: 16, color: brandColor)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showPrinterSettings() {
    final ipController = TextEditingController(text: _printService.printerIp);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pengaturan Printer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'IP Address Printer',
                hintText: '192.168.1.100',
                prefixIcon: Icon(Icons.print),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Auto Print'),
                const Spacer(),
                Switch(
                  value: _autoPrintEnabled,
                  onChanged: (value) {
                    setState(() {
                      _autoPrintEnabled = value;
                    });
                  },
                  activeColor: brandColor,
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ip = ipController.text.trim();
              if (ip.isNotEmpty) {
                _printService.configurePrinter(ip);

                // Test koneksi
                final success = await _printService.testConnection();

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          success
                              ? 'Printer berhasil dikonfigurasi!'
                              : 'Gagal terhubung ke printer'
                      ),
                      backgroundColor: success ? brandColor : Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: brandColor),
            child: const Text('Test & Simpan'),
          ),
        ],
      ),
    );
  }

  void _addTimeToOrder(Order order, int minutes) {
    setState(() {
      if (order.updatedAt != null) {
        order.updatedAt = order.updatedAt!.add(Duration(minutes: minutes));
      }
    });
  }

  Widget _buildErrorWidget() {
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
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade400,
              ),
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
              _errorMessage ?? 'Terjadi kesalahan yang tidak diketahui',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 5,
              color: brandColor,
            ),
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

  List<Order> _getFilteredOrders(List<Order> orders) {
    if (search.isEmpty) return orders;

    return orders.where((order) {
      final nameMatch = order.name.toLowerCase().contains(search);
      final itemsMatch = order.items.any((item) =>
          item.name.toLowerCase().contains(search)
      );
      return nameMatch || itemsMatch;
    }).toList();
  }

  Widget _buildOrdersList(List<Order> orders, bool showTimer, bool isFinished) {
    final filteredOrders = _getFilteredOrders(orders);

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              search.isEmpty ? 'Tidak ada pesanan' : 'Tidak ada hasil pencarian',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double cardWidth = constraints.maxWidth - 48;

        if (constraints.maxWidth > 800) {
          cardWidth = (constraints.maxWidth - 48 - 16) / 2;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: filteredOrders.map((order) {
              final isExpanded = _expandedOrders[order.orderId] ?? false;

              return SizedBox(
                width: cardWidth,
                child: OrderCardCompact(
                  order: order,
                  isExpanded: isExpanded,
                  showTimer: showTimer,
                  isFinished: isFinished,
                  onToggleExpand: () {
                    setState(() {
                      _expandedOrders[order.orderId ?? ''] = !isExpanded;
                    });
                  },
                  onComplete: showTimer && !isFinished ? () => _completeOrder(order) : null,
                  onAddTime: showTimer ? _addTimeToOrder : null,
                  onReprint: () async {
                    final success = await _printService.manualPrint(order);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                success ? Icons.check_circle : Icons.error,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(success
                                  ? 'Berhasil print ulang'
                                  : 'Gagal print, cek koneksi printer'
                              ),
                            ],
                          ),
                          backgroundColor: success ? brandColor : Colors.red,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSidebar() {
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
      child: Column(
        children: [
          _buildSidebarTab(0, 'Penyiapan', preparing.length),
          _buildSidebarTab(1, 'Batch Cook', preparing.length),
          _buildSidebarTab(2, 'Selesai', done.length),
          _buildSidebarTab(3, 'Reservasi', reservations.length),
        ],
      ),
    );
  }

  Widget _buildSidebarTab(int index, String title, int count) {
    final isSelected = _selectedTabIndex == index;

    int displayCount = count;
    if (index == 1) {
      final grouped = _groupIdenticalItemsForCount();
      displayCount = grouped.length;
    }

    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
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
                '$displayCount',
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

  Map<String, List<BatchItem>> _groupIdenticalItemsForCount() {
    final Map<String, List<BatchItem>> grouped = {};

    for (var order in preparing) {
      for (var item in order.items) {
        final addonsKey = item.addons?.map((a) => a['name']).join(',') ?? '';
        final toppingsKey = item.toppings?.map((t) => t['name']).join(',') ?? '';
        final notesKey = item.notes ?? '';

        final key = '${item.name}|$addonsKey|$toppingsKey|$notesKey';

        if (!grouped.containsKey(key)) {
          grouped[key] = [];
        }

        grouped[key]!.add(BatchItem(
          orderId: order.orderId ?? '',
          orderName: order.name,
          tableNumber: order.table,
          menuName: item.name,
          quantity: item.qty,
          addons: item.addons,
          toppings: item.toppings,
          notes: item.notes,
        ));
      }
    }

    return Map.fromEntries(
      grouped.entries.where((entry) {
        final totalQty = entry.value.fold(0, (sum, item) => sum + item.quantity);
        return totalQty >= 2;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        toolbarHeight: 70,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: brandColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                'assets/icons/logo.png',
                height: 32,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.restaurant, color: Colors.white, size: 32);
                },
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Baraja Kitchen',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Printer Status Indicator
            if (_printService.isConfigured)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _autoPrintEnabled
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _autoPrintEnabled
                        ? Colors.green.shade300
                        : Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.print,
                      size: 14,
                      color: _autoPrintEnabled
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _autoPrintEnabled ? 'Auto' : 'Manual',
                      style: TextStyle(
                        color: _autoPrintEnabled
                            ? Colors.green.shade900
                            : Colors.orange.shade900,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            if (_notificationService.queueLength > 0)
              Container(
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
                      '${_notificationService.queueLength}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            // Printer Settings Button
            Container(
              decoration: BoxDecoration(
                color: brandColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(Icons.print, color: brandColor, size: 24),
                onPressed: _showPrinterSettings,
                tooltip: 'Pengaturan Printer',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: brandColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(Icons.refresh, color: brandColor, size: 24),
                onPressed: _isLoading ? null : _loadOrders,
                tooltip: 'Refresh',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: brandColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: brandColor, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('HH:mm:ss').format(_currentTime),
                    style: const TextStyle(
                      color: brandColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            color: Colors.white,
            child: TextField(
              onChanged: (value) => setState(() => search = value.toLowerCase()),
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Cari produk...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                suffixIcon: search.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade600),
                  onPressed: () => setState(() => search = ''),
                )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: brandColor, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoadingWidget()
          : _errorMessage != null
          ? _buildErrorWidget()
          : Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Container(
              color: const Color(0xFFF9FAFB),
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [
                  _buildOrdersList(preparing, true, false),
                  BatchCookingView(
                    orders: preparing,
                    onBatchComplete: _completeBatchOrders,
                  ),
                  _buildOrdersList(done, false, true),
                  _buildOrdersList(reservations, false, false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}