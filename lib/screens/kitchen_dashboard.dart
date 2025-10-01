// screens/kitchen_dashboard.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/order.dart';
import '../services/order_service.dart';
import '../services/socket_service.dart';
import '../services/notification_service.dart'; // ✅ Import notification service
import '../widgets/order_column.dart';
import '../config/app_theme.dart';
import 'package:flutter/foundation.dart';

class KitchenDashboard extends StatefulWidget {
  const KitchenDashboard({super.key});

  @override
  State<KitchenDashboard> createState() => _KitchenDashboardState();
}

class _KitchenDashboardState extends State<KitchenDashboard> {
  List<Order> queue = [];
  List<Order> preparing = [];
  List<Order> done = [];
  List<Order> reservations = [];
  String search = '';
  bool _isLoading = false;
  String? _errorMessage;

  late Timer _mainTimer;
  late Timer _refreshTimer;
  DateTime _currentTime = DateTime.now();

  final Map<String, bool> _alertPlayedMap = {};

  // ✅ Tambahkan notification service
  final NotificationService _notificationService = NotificationService();

  // ✅ Track order IDs yang sudah ada sebelumnya
  final Set<String> _existingOrderIds = <String>{};

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

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
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
    _notificationService.dispose(); // ✅ Dispose notification service
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

    // Auto-konfirmasi semua order di queue ke preparing via API
    for (var order in newQueue) {
      if (order.orderId != null) {
        await OrderService.updateOrderStatus(order.orderId!, 'OnProcess');
        if (kDebugMode) {
          print('✅ Auto-confirmed order ${order.orderId} to OnProcess');
        }
      }
    }

    // Gabungkan queue langsung ke preparing
    final allPreparing = [...newPreparing, ...newQueue];

    // ✅ Deteksi order baru dan mainkan notifikasi
    if (!isInitialLoad) {
      // Cek order baru di preparing
      for (var order in allPreparing) {
        if (order.orderId != null && !_existingOrderIds.contains(order.orderId)) {
          if (kDebugMode) {
            print('🆕 Order baru terdeteksi di Penyiapan: ${order.orderId}');
          }
          // Mainkan notifikasi untuk order penyiapan
          await _notificationService.playNewOrderNotification(
            order.orderId!,
            soundPath: 'sounds/alert.mp3', // ✅ Ganti dengan path sound Anda
          );
        }
      }

      // Cek order baru di reservasi
      for (var order in newReservations) {
        if (order.orderId != null && !_existingOrderIds.contains(order.orderId)) {
          if (kDebugMode) {
            print('🆕 Reservasi baru terdeteksi: ${order.orderId}');
          }
          // Mainkan notifikasi untuk reservasi (bisa pakai sound berbeda)
          await _notificationService.playNewOrderNotification(
            order.orderId!,
            soundPath: 'sounds/ding.mp3', // ✅ Ganti dengan path sound Anda
          );
        }
      }
    }

    // ✅ Update existing order IDs
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

    setState(() {
      queue = []; // Kosongkan queue
      preparing = allPreparing; // Semua masuk preparing
      done = newDone;
      reservations = newReservations;
    });
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

  void _showOrderCompleteDialog(Order order) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pesanan Selesai'),
        content: Text(
            '${order.name} (Meja ${order.table}) selesai dalam ${order.totalCookTime()}'),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Error loading orders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error occurred',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading orders...'),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          child: OrderColumn(
            title: 'Penyiapan',
            orders: preparing,
            onAction: _completeOrder,
            searchQuery: search,
            showTimer: true,
            onAddTime: _addTimeToOrder,
          ),
        ),
        Expanded(
          child: OrderColumn(
            title: 'Selesai',
            orders: done,
            onAction: (_) {},
            searchQuery: search,
            isFinished: true,
          ),
        ),
        Expanded(
          child: OrderColumn(
            title: 'Reservasi',
            orders: reservations,
            onAction: (_) {},
            searchQuery: search,
            isReservation: true,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: AppTheme.primaryColor,
            child: const TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: 'Penyiapan'),
                Tab(text: 'Selesai'),
                Tab(text: 'Reservasi'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                OrderColumn(
                  title: 'Penyiapan',
                  orders: preparing,
                  onAction: _completeOrder,
                  searchQuery: search,
                  showTimer: true,
                  onAddTime: _addTimeToOrder,
                ),
                OrderColumn(
                  title: 'Selesai',
                  orders: done,
                  onAction: (_) {},
                  searchQuery: search,
                  isFinished: true,
                ),
                OrderColumn(
                  title: 'Reservasi',
                  orders: reservations,
                  onAction: (_) {},
                  searchQuery: search,
                  isReservation: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        titleSpacing: 16,
        backgroundColor: AppTheme.primaryColor,
        title: Row(
          children: [
            Image.asset('assets/icons/logo.png', height: 36),
            const SizedBox(width: 12),
            const Text(
              'Baraja Kitchen',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            // ✅ Tambahkan badge untuk notifikasi queue
            if (_notificationService.queueLength > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications_active, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '${_notificationService.queueLength}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _isLoading ? null : _loadOrders,
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('HH:mm:ss').format(_currentTime),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              onChanged: (value) =>
                  setState(() => search = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Cari nama pelanggan atau produk...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
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
          : LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 1000) {
            return _buildDesktopLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }
}