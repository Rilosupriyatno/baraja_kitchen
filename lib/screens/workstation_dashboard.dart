import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../models/device.dart';
import '../models/order.dart';
import '../models/out_of_stock_model.dart';
import '../models/stock_menu.dart';
import '../models/category_model.dart';
import '../services/order_service.dart';
import '../services/socket_service.dart';
import '../services/notification_service.dart';
import '../services/stockmenu_service.dart';
import '../services/thermal_print_service.dart';
import '../widgets/order_card_compact.dart';
import 'package:flutter/foundation.dart' hide Category;
import '../widgets/out_of_stock_dialog.dart';
import '../widgets/table_stockmenu.dart';
import 'unified_stock_screen.dart';
import 'device_selection_screen.dart';
import 'batch_cooking_screen.dart';
import '../widgets/digital_clock_widget.dart';
import '../widgets/order_list_item.dart';
import '../widgets/order_detail_panel.dart';

class WorkstationDashboard extends StatefulWidget {
  final Device selectedDevice; // ✅ UPDATED: Only use Device object

  const WorkstationDashboard({
    super.key,
    required this.selectedDevice, // ✅ UPDATED: Required Device object
  });

  @override
  State<WorkstationDashboard> createState() => _WorkstationDashboardState();
}

class _WorkstationDashboardState extends State<WorkstationDashboard> {
  static const Color brandColor = Color(0xFF077A4B);
  List<Order> queue = [];
  List<Order> preparing = [];
  List<Order> done = [];
  List<Order> reservations = [];
  List<StockMenu> stockmenu = [];
  List<Category> categories = [];
  String search = '';
  bool _isLoading = false;
  String? _errorMessage;
  int _selectedTabIndex = 0;
  String? _selectedOrderId; // For 3-column layout

  late Timer _mainTimer;
  late Timer _refreshTimer;

  final Map<String, bool> _alertPlayedMap = {};
  final NotificationService _notificationService = NotificationService();
  final ThermalPrintService _printService = ThermalPrintService();
  final Set<String> _displayedItemIds = <String>{};
  final Map<String, bool> _expandedOrders = {};
  List<OutOfStockItem> _outOfStockItems = [];
  Timer? _stockCheckTimer;
  bool _autoPrintEnabled = true;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Method to build actions drawer content
  Widget _buildActionsDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: brandColor.withOpacity(0.05),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Icon(Icons.settings, color: brandColor, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Pengaturan & Aksi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Status badges section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildDeviceBadge(),
                        if (_printService.isConfigured) _buildPrinterStatusBadge(),
                        if (_printService.isConfigured) _buildAutoPrintBadge(),
                        if (_notificationService.queueLength > 0) _buildNotificationBadge(),
                      ],
                    ),
                  ),
                  const Divider(height: 32),
                  // Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Aksi',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.print, color: brandColor),
                    title: const Text('Pengaturan Printer'),
                    onTap: () {
                      Navigator.pop(context);
                      _showPrinterSettings();
                    },
                  ),
                  if (_outOfStockItems.isNotEmpty)
                    ListTile(
                      leading: Icon(Icons.inventory_2_outlined, color: Colors.red.shade700),
                      title: const Text('Stok Habis/Kritis'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_outOfStockItems.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showOutOfStockDialog();
                      },
                    ),
                  ListTile(
                    leading: Icon(Icons.refresh, color: brandColor),
                    title: const Text('Refresh Data'),
                    onTap: () {
                      Navigator.pop(context);
                      if (!_isLoading) _loadOrders();
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.exit_to_app, color: brandColor),
                    title: const Text('Ganti Perangkat'),
                    onTap: () {
                      Navigator.pop(context);
                      _backToDeviceSelection();
                    },
                  ),
                  const Divider(height: 32),
                  // Time display
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: DigitalClockWidget(color: brandColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  String get workstationType => widget.selectedDevice.workstationTypeString;
  String get displayHeader => widget.selectedDevice.workstationName;
  Color get appBarColor => widget.selectedDevice.effectiveThemeColor;


  // ✅ NEW: Get unique identifier for this device
  String get uniqueDeviceId {
    return widget.selectedDevice.uniqueIdentifier;
  }

  // ✅ NEW: Get workstation key for API calls
  String get workstationKey {
    return widget.selectedDevice.workstationKey;
  }

  @override
  void initState() {
    super.initState();

    // ✅ UPDATED: Enhanced device logging
    print('📱 WorkstationDashboard initialized with device: ${widget.selectedDevice.deviceName}');
    print('╔═══════════════════════════════════════════════════╗');
    print('📱 DASHBOARD INITIALIZED WITH DEVICE:');
    print('├───────────────────────────────────────────────────┤');
    print('   Device ID: ${widget.selectedDevice.deviceId}');
    print('   Device Name: ${widget.selectedDevice.deviceName}');
    print('   Device Type: ${widget.selectedDevice.deviceType}');
    print('   Location: ${widget.selectedDevice.location}');
    print('   Outlet: ${widget.selectedDevice.outlet.name}');
    print('   Workstation Type: $workstationType');
    print('   Unique ID: $uniqueDeviceId');
    print('   Online Status: ${widget.selectedDevice.isOnline ? "✅ ONLINE" : "❌ OFFLINE"}');
    print('   Active: ${widget.selectedDevice.isActive ? "✅ ACTIVE" : "❌ INACTIVE"}');
    print('   Handles Beverages: ${widget.selectedDevice.shouldHandleBeverages}');
    print('   Handles Kitchen: ${widget.selectedDevice.shouldHandleKitchen}');
    if (widget.selectedDevice.notes.isNotEmpty) {
      print('   Notes: ${widget.selectedDevice.notes}');
    }
    if (widget.selectedDevice.assignedAreas.isNotEmpty) {
      print('   Assigned Areas: ${widget.selectedDevice.assignedAreas.join(", ")}');
    }
    if (widget.selectedDevice.assignedTables.isNotEmpty) {
      print('   Assigned Tables: ${widget.selectedDevice.assignedTables.join(", ")}');
    }
    if (widget.selectedDevice.orderTypes.isNotEmpty) {
      print('   Order Types: ${widget.selectedDevice.orderTypes.join(", ")}');
    }
    print('╚═══════════════════════════════════════════════════╝');

    // ✅ UPDATED: Use workstationType instead of barType
    _printService.setDevice(widget.selectedDevice);
    _initializePrinter();
    _loadOrders();
    _loadStockMenu();
    _loadCategories();
    _initializeTimers();
    _loadOutOfStockItems();

    _stockCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _loadOutOfStockItems();
    });

    // ✅ UPDATED: Use outlet ID from device
    final outletId = widget.selectedDevice.outlet.id;

    SocketService.connect(
      outletId: outletId,
      device: widget.selectedDevice,
      onNewOrder: (_) => _refreshOrders(),
      onBeverageOrder: (beverageData) {
        if (widget.selectedDevice.shouldHandleBeverages) {
          _handleBeverageOrder(beverageData);
        }
      },
      onStockUpdate: (stockData) {
        _refreshOutOfStockAfterUpdate(stockData['menuItemId'] ?? '');
        _loadStockMenu();
      },
      onImmediatePrint: _handleImmediatePrint,
    );
  }

  Future<void> _initializePrinter() async {
    await _printService.prewarmConnection();
  }

  Future<void> _backToDeviceSelection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[700], size: 28),
            const SizedBox(width: 12),
            const Text('Ganti Perangkat'),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin kembali ke pemilihan perangkat?\n\n'
              'Perangkat saat ini akan dihapus dari penyimpanan.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: brandColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Ganti Perangkat'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Hapus device dari local storage
      await Device.clearFromLocalStorage();

      print('📱 Navigating back to device selection...');

      // Navigate ke device selection
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const DeviceSelectionScreen(),
        ),
      );
    }
  }

  // ✅ UPDATED: Enhanced device badge
  Widget _buildDeviceBadge() {
    final device = widget.selectedDevice;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: brandColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: brandColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: device.isOnline ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.devices, size: 14, color: brandColor),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              device.deviceName,
              style: TextStyle(
                color: brandColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: const Icon(Icons.exit_to_app, color: brandColor, size: 24),
        onPressed: _backToDeviceSelection,
        tooltip: 'Ganti Perangkat',
      ),
    );
  }

  void _handleImmediatePrint(Map<String, dynamic> printData) async {
    try {
      if (!_autoPrintEnabled || !_printService.isConfigured) return;

      final orderId = printData['orderId'] as String?;
      final tableNumber = printData['tableNumber'] as String? ?? '';
      final orderType = printData['orderType'] as String? ?? 'dine-in';

      // ✅ NEW: Get device ID from backend
      final targetDeviceId = printData['deviceId'] as String?;
      final targetDeviceName = printData['targetDevice'] as String?;

      if (orderId == null) return;

      // ✅ CRITICAL: Check device ID match FIRST
      if (targetDeviceId != null && targetDeviceId.isNotEmpty) {
        if (widget.selectedDevice.deviceId != targetDeviceId) {
          if (kDebugMode) {
            print('⏭️ [${widget.selectedDevice.deviceName}] SKIPPING order $orderId');
            print('   Target device: $targetDeviceName ($targetDeviceId)');
            print('   This device: ${widget.selectedDevice.deviceName} (${widget.selectedDevice.deviceId})');
          }
          return;
        }

        if (kDebugMode) {
          print('✅ [${widget.selectedDevice.deviceName}] Device ID MATCH for $orderId');
          print('   Backend explicitly sent to this device');
        }
      }

      _notificationService
          .playNewOrderNotification(orderId, soundPath: 'sounds/alert.mp3')
          .catchError((e) => false);

      final orderItems = (printData['orderItems'] as List<dynamic>?)
          ?.map((item) => OrderItem(
        itemId: item['_id'] ?? '',
        menuItemId: item['menuItemId'],
        name: item['name'] ?? '',
        qty: item['quantity'] ?? 1,
        notes: item['notes'],
        addons: item['addons'],
        toppings: item['toppings'],
        workstation: item['workstation'] ?? 'kitchen',
        mainCategory: item['mainCategory'],
      ))
          .toList() ?? [];

      if (orderItems.isEmpty) return;

      // ✅ UPDATED: Use device properties for filtering
      final workstationItems = orderItems.where((item) {
        final mainCat = (item.mainCategory ?? '').toLowerCase();
        final ws = (item.workstation ?? '').toLowerCase();

        if (widget.selectedDevice.shouldHandleBeverages) {
          return mainCat.contains('beverage') || mainCat.contains('minuman') || ws.contains('bar');
        } else if (widget.selectedDevice.shouldHandleKitchen) {
          return !mainCat.contains('beverage') && !mainCat.contains('minuman') && !ws.contains('bar');
        } else {
          // Fallback logic for general devices
          return true;
        }
      }).toList();

      if (workstationItems.isEmpty) return;

      for (final item in workstationItems) {
        _displayedItemIds.add(item.itemId);
      }

      final tempOrder = Order(
        orderId: orderId,
        name: printData['name'] ?? 'Guest',
        table: printData['tableNumber'] ?? '',
        status: 'OnProcess',
        items: workstationItems,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdAtWIB: DateTime.now(),
        updatedAtWIB: DateTime.now(),
        service: printData['service'] ?? 'Dine-In',
        orderType: printData['orderType'] ?? 'dine-in',
        source: printData['source'] ?? 'Cashier',
        paymentMethod: printData['paymentMethod'] ?? 'Cash',
        cashierName: printData['cashierName'],  // ✅ FIX: Pass cashierName from socket data
      );

      _printService.autoPrintOrder(tempOrder, isOpenBill: false).then((printed) {
        if (printed && mounted) {
          _showPrintSuccessSnackbar(orderId);
        }
      }).catchError((e) {
        if (kDebugMode) print('❌ Immediate print error: $e');
      });
    } catch (e) {
      if (kDebugMode) print('❌ Error handling immediate print: $e');
    }
  }
  // void _handleImmediatePrint(Map<String, dynamic> printData) async {
  //   try {
  //     if (!_autoPrintEnabled || !_printService.isConfigured) return;
  //
  //     final orderId = printData['orderId'] as String?;
  //     if (orderId == null) return;
  //
  //     _notificationService
  //         .playNewOrderNotification(orderId, soundPath: 'sounds/alert.mp3')
  //         .catchError((e) => false);
  //
  //     final orderItems = (printData['orderItems'] as List<dynamic>?)
  //         ?.map((item) => OrderItem(
  //       itemId: item['_id'] ?? '',
  //       menuItemId: item['menuItemId'],
  //       name: item['name'] ?? '',
  //       qty: item['quantity'] ?? 1,
  //       notes: item['notes'],
  //       addons: item['addons'],
  //       toppings: item['toppings'],
  //       workstation: item['workstation'] ?? 'kitchen',
  //       mainCategory: item['mainCategory'],
  //     ))
  //         .toList() ?? [];
  //
  //     if (orderItems.isEmpty) return;
  //
  //     // ✅ UPDATED: Use device properties for filtering
  //     final workstationItems = orderItems.where((item) {
  //       final mainCat = (item.mainCategory ?? '').toLowerCase();
  //       final ws = (item.workstation ?? '').toLowerCase();
  //
  //       if (widget.selectedDevice.shouldHandleBeverages) {
  //         return mainCat.contains('beverage') || mainCat.contains('minuman') || ws.contains('bar');
  //       } else if (widget.selectedDevice.shouldHandleKitchen) {
  //         return !mainCat.contains('beverage') && !mainCat.contains('minuman') && !ws.contains('bar');
  //       } else {
  //         // Fallback logic for general devices
  //         return true;
  //       }
  //     }).toList();
  //
  //     if (workstationItems.isEmpty) return;
  //
  //     for (final item in workstationItems) {
  //       _displayedItemIds.add(item.itemId);
  //     }
  //
  //     final tempOrder = Order(
  //       orderId: orderId,
  //       name: printData['name'] ?? 'Guest',
  //       table: printData['tableNumber'] ?? '',
  //       status: 'OnProcess',
  //       items: workstationItems,
  //       createdAt: DateTime.now(),
  //       updatedAt: DateTime.now(),
  //       createdAtWIB: DateTime.now(),
  //       updatedAtWIB: DateTime.now(),
  //       service: printData['service'] ?? 'Dine-In',
  //       orderType: printData['orderType'] ?? 'dine-in',
  //       source: printData['source'] ?? 'Cashier',
  //       paymentMethod: printData['paymentMethod'] ?? 'Cash',
  //     );
  //
  //     _printService.autoPrintOrder(tempOrder, isOpenBill: false).then((printed) {
  //       if (printed && mounted) {
  //         _showPrintSuccessSnackbar(orderId);
  //       }
  //     }).catchError((e) {
  //       if (kDebugMode) print('❌ Immediate print error: $e');
  //     });
  //   } catch (e) {
  //     if (kDebugMode) print('❌ Error handling immediate print: $e');
  //   }
  // }

  Future<void> _loadOutOfStockItems() async {
    try {
      final items = await StockMenuService.getOutOfStockItems(workstationType);
      if (mounted) setState(() => _outOfStockItems = items);
    } catch (e) {
      if (kDebugMode) print('Error loading out of stock items: $e');
    }
  }

  void _showOutOfStockDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => OutOfStockDialog(
        outOfStockItems: _outOfStockItems,
        workstation: workstationType,
        brandColor: brandColor,
        onRefresh: () async {
          await _loadOutOfStockItems();
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
            if (_outOfStockItems.isNotEmpty) _showOutOfStockDialog();
          }
        },
      ),
    );
  }

  Future<void> _refreshOutOfStockAfterUpdate(String menuItemId) async {
    try {
      final updatedItems = await StockMenuService.getOutOfStockItems(workstationType);
      if (mounted) {
        setState(() => _outOfStockItems = updatedItems);
        if (updatedItems.isEmpty && Navigator.canPop(context)) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Semua stok berhasil diperbarui!'),
              backgroundColor: Color(0xFF077A4B),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error refreshing out of stock: $e');
    }
  }

  void _handleBeverageOrder(Map<String, dynamic> beverageData) {
    _notificationService
        .playNewOrderNotification(beverageData['orderId'] ?? 'unknown', soundPath: 'sounds/alert.mp3')
        .catchError((_) => false);
  }

  Future<void> _loadCategories() async {
    try {
      final data = await StockMenuService.getCategoriesByWorkstation(workstationType);
      if (mounted) setState(() => categories = data);
    } catch (e) {
      if (kDebugMode) print('Error loading categories: $e');
    }
  }

  Future<void> _loadStockMenu() async {
    if (stockmenu.isEmpty) setState(() => _isLoading = true);
    try {
      final data = await StockMenuService.getMenusByCategoryAndWorkstation('', workstationType);
      if (mounted) {
        setState(() {
          stockmenu = data.menus;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _initializeTimers() {
    // Timer for checking late orders only - no setState for time
    _mainTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _checkForLateOrders();
      }
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshOrders());
  }

  void _checkForLateOrders() {
    for (var order in queue) {
      if (order.isLate && !(_alertPlayedMap[order.orderId] ?? false)) {
        _alertPlayedMap[order.orderId ?? ""] = true;
      }
    }
  }

  @override
  void dispose() {
    _mainTimer.cancel();
    _refreshTimer.cancel();
    SocketService.disconnect();
    _notificationService.dispose();
    _stockCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (kDebugMode) {
        print('📡 Loading orders using workstation endpoint...');
      }

      final ordersMap = await OrderService.refreshWorkstationOrders(widget.selectedDevice);
      await _mergeOrdersWithAlertState(ordersMap, isInitialLoad: true);

      if (mounted) {
        setState(() => _isLoading = false);

        if (kDebugMode) {
          print('✅ Orders loaded successfully');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading orders: $e');
      }

      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ✅ UPDATED: Using new workstation endpoint
  Future<void> _refreshOrders() async {
    try {
      if (kDebugMode) {
        print('🔄 Refreshing orders for ${widget.selectedDevice.workstationTypeString}...');
      }

      final ordersMap = await OrderService.refreshWorkstationOrders(widget.selectedDevice);
      await _mergeOrdersWithAlertState(ordersMap);
    } catch (e) {
      if (kDebugMode) print('❌ Error refreshing orders: $e');
    }
  }

  Future<void> _mergeOrdersWithAlertState(
      Map<String, List<Order>> ordersMap, {
        bool isInitialLoad = false,
      }) async {
    final newWaiting = ordersMap['waiting'] ?? [];
    final newPreparing = ordersMap['preparing'] ?? [];
    final newDone = ordersMap['completed'] ?? [];
    final newReservations = ordersMap['reservations'] ?? [];

    final ordersToConfirm = <Order>[];
    final confirmedOrders = <Order>[];

    // Collect waiting orders
    for (var order in newWaiting) {
      if (order.orderId != null) ordersToConfirm.add(order);
    }

    // Collect ready reservations
    for (var order in newReservations) {
      if (order.orderId != null && OrderService.shouldMoveReservationToPreparation(order)) {
        ordersToConfirm.add(order);
      }
    }

    // Batch Confirm (Non-blocking)
    if (ordersToConfirm.isNotEmpty) {
      _confirmOrdersInBackground(ordersToConfirm);
      for (var order in ordersToConfirm) {
        order.status = 'OnProcess';
        confirmedOrders.add(order);
      }
    }

    final allPreparing = [...newPreparing, ...confirmedOrders];

    // Process Print (Non-blocking)
    if (!isInitialLoad) {
      _processPrintQueue(allPreparing);
    } else {
      for (var order in [...allPreparing, ...newDone, ...newReservations]) {
        for (final item in order.items) {
          _displayedItemIds.add(item.itemId);
        }
      }
    }

    // Process reservations notifications
    for (var order in newReservations) {
      if (order.orderId != null && !OrderService.shouldMoveReservationToPreparation(order)) {
        bool hasNewItems = false;
        for (final item in order.items) {
          if (!_displayedItemIds.contains(item.itemId)) {
            _displayedItemIds.add(item.itemId);
            hasNewItems = true;
          }
        }
        if (hasNewItems) {
          _notificationService
              .playNewOrderNotification(order.orderId!, soundPath: 'sounds/ding.mp3')
              .catchError((_) => false);
        }
      }
    }

    // Initialize alert map
    for (var o in allPreparing) {
      _alertPlayedMap.putIfAbsent(o.orderId ?? "", () => false);
    }

    // Sort orders
    // Use WIB time for sorting
    int sortOrders(Order a, Order b) => (a.updatedAtWIB ?? DateTime(0)).compareTo(b.updatedAtWIB ?? DateTime(0));
    int sortOrdersDesc(Order a, Order b) => (b.updatedAtWIB ?? DateTime(0)).compareTo(a.updatedAtWIB ?? DateTime(0));
    allPreparing.sort(sortOrders);
    newDone.sort(sortOrdersDesc); // Descending: terbaru di atas
    newReservations.sort(sortOrders);

    if (mounted) {
      setState(() {
        queue = []; // queue is effectively empty as waiting orders are auto-confirmed
        preparing = allPreparing;
        done = newDone;
        reservations = newReservations;
      });
    }
  }

  Future<void> _confirmOrdersInBackground(List<Order> ordersToConfirm) async {
    if (ordersToConfirm.isEmpty) return;

    final orderIds = ordersToConfirm.map((o) => o.orderId!).toList();
    try {
      if (orderIds.length > 1) {
        await OrderService.batchAutoConfirmOrders(orderIds);
      } else {
        await OrderService.updateOrderStatus(orderIds.first, 'OnProcess');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Confirm error: $e');
    }
  }

  void _processPrintQueue(List<Order> allPreparing) async {
    for (var order in allPreparing) {
      if (order.orderId == null) continue;

      final newItems = <OrderItem>[];
      for (final item in order.items) {
        if (!_displayedItemIds.contains(item.itemId)) {
          newItems.add(item);
          _displayedItemIds.add(item.itemId);
        }
      }

      if (newItems.isNotEmpty && _autoPrintEnabled && _printService.isConfigured) {
        _notificationService
            .playNewOrderNotification(order.orderId!, soundPath: 'sounds/alert.mp3')
            .catchError((_) => false);

        final isOpenBill = order.items.length > newItems.length;

        final tempOrder = Order(
          orderId: order.orderId,
          name: order.name,
          table: order.table,
          status: order.status,
          items: newItems,
          createdAt: order.createdAt,
          updatedAt: order.updatedAt,
          createdAtWIB: order.createdAtWIB,
          updatedAtWIB: order.updatedAtWIB,
          service: order.service,
          orderType: order.orderType,
          reservationDateTime: order.reservationDateTime,
          totalPrice: order.totalPrice,
          source: order.source,
          paymentMethod: order.paymentMethod,
          cashierName: order.cashierName,  // ✅ FIX: Pass cashierName from order
        );

        _printService.autoPrintOrder(tempOrder, isOpenBill: isOpenBill).then((printed) {
          if (printed && mounted) _showPrintSuccessSnackbar(order.orderId!);
        }).catchError((e) {
          if (kDebugMode) print('❌ Print error: $e');
        });
      }
    }
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
      final orderIndex = preparing.indexWhere((o) => o.orderId == orderId);
      if (orderIndex != -1) {
        final order = preparing[orderIndex];
        setState(() {
          preparing.removeAt(orderIndex);
          done.add(order);
        });
        await OrderService.updateOrderStatus(orderId, 'Completed');
      }
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
            const Icon(Icons.check_circle, color: brandColor, size: 28),
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
            const Icon(Icons.check_circle, color: brandColor, size: 28),
            const SizedBox(width: 12),
            const Text('Batch Selesai'),
          ],
        ),
        content: Text('$count pesanan berhasil diselesaikan secara batch!', style: const TextStyle(fontSize: 16)),
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
    showDialog(
      context: context,
      builder: (context) => _PrinterSettingsDialog(
        printService: _printService,
        autoPrintEnabled: _autoPrintEnabled,
        onAutoPrintChanged: (value) => setState(() => _autoPrintEnabled = value),
        brandColor: brandColor,
      ),
    );
  }

  void _addTimeToOrder(Order order, int minutes) {
    setState(() {
      // Use WIB time for adding minutes
      if (order.updatedAtWIB != null) {
        order.updatedAtWIB = order.updatedAtWIB!.add(Duration(minutes: minutes));
      }
    });
  }

  void _navigateToCategories() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UnifiedStockScreen(workstation: workstationType)),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            ),
            const SizedBox(height: 24),
            const Text('Terjadi Kesalahan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.black87)),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'Unknown error', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 15)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadOrders,
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

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 60, height: 60, child: CircularProgressIndicator(strokeWidth: 5, color: brandColor)),
          const SizedBox(height: 24),
          const Text('Memuat pesanan...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87)),
        ],
      ),
    );
  }

  List<Order> _getFilteredOrders(List<Order> orders) {
    if (search.isEmpty) return orders;
    final searchLower = search.toLowerCase();
    return orders.where((order) {
      return order.name.toLowerCase().contains(searchLower) ||
          order.items.any((item) => item.name.toLowerCase().contains(searchLower));
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
            Text(search.isEmpty ? 'Tidak ada pesanan' : 'Tidak ada hasil pencarian', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 900;
        
        // Tablet: 3-column layout
        if (isTablet) {
          return SafeArea(
            top: false,
            left: false,
            right: false,
            bottom: true,
            child: Container(
              color: Colors.white,
              child: Row(
                children: [
                  // Column 1: Order List - Full height with header at top
                  SizedBox(
                    width: 400,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              '${filteredOrders.length} Orders',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: filteredOrders.length,
                              itemBuilder: (context, index) {
                                final order = filteredOrders[index];
                                final isSelected = _selectedOrderId == order.orderId;
                                
                                return OrderListItem(
                                  order: order,
                                  queueNumber: showTimer && !isFinished ? index + 1 : index + 1,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedOrderId = order.orderId;
                                    });
                                  },
                                  brandColor: brandColor,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Divider between List and Detail
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Colors.grey.shade200,
                  ),
                  // Column 2: Detail Panel - Full height with header at top
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      child: Builder(
                        builder: (context) {
                          // Auto-select first order if none selected
                          if (_selectedOrderId == null && filteredOrders.isNotEmpty) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() {
                                  _selectedOrderId = filteredOrders.first.orderId;
                                });
                              }
                            });
                          }
                          
                          Order? selectedOrder;
                          int? selectedIndex;
                          
                          if (_selectedOrderId != null) {
                            selectedIndex = filteredOrders.indexWhere((o) => o.orderId == _selectedOrderId);
                            if (selectedIndex != -1) {
                              selectedOrder = filteredOrders[selectedIndex];
                            }
                          }
                          
                          return OrderDetailPanel(
                            order: selectedOrder,
                            queueNumber: showTimer && !isFinished && selectedIndex != null && selectedIndex != -1
                                ? selectedIndex + 1
                                : null,
                            brandColor: brandColor,
                            showTimer: showTimer && !isFinished,
                            onComplete: showTimer && !isFinished && selectedOrder != null
                                ? () => _completeOrder(selectedOrder!)
                                : null,
                            onReprint: selectedOrder != null
                                ? () async {
                                    final success = await _printService.manualPrint(selectedOrder!);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(success ? Icons.check_circle : Icons.error, color: Colors.white),
                                              const SizedBox(width: 8),
                                              Text(success ? 'Berhasil print ulang' : 'Gagal print, cek koneksi printer'),
                                            ],
                                          ),
                                          backgroundColor: success ? brandColor : Colors.red,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Mobile: Card-based layout with fixed width
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredOrders.length,
          itemBuilder: (context, index) {
            final order = filteredOrders[index];
            final isExpanded = _expandedOrders[order.orderId] ?? false;

            return RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: OrderCardCompact(
                  key: ValueKey(order.orderId),
                  order: order,
                  isExpanded: isExpanded,
                  showTimer: showTimer,
                  isFinished: isFinished,
                  queueNumber: showTimer && !isFinished ? index + 1 : null,
                  onToggleExpand: () => setState(() => _expandedOrders[order.orderId ?? ''] = !isExpanded),
                  onComplete: showTimer && !isFinished ? () => _completeOrder(order) : null,
                  onAddTime: showTimer ? _addTimeToOrder : null,
                  onReprint: () async {
                    final success = await _printService.manualPrint(order);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(success ? Icons.check_circle : Icons.error, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(success ? 'Berhasil print ulang' : 'Gagal print, cek koneksi printer'),
                            ],
                          ),
                          backgroundColor: success ? brandColor : Colors.red,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSidebar({bool isMobile = false}) {
    return Container(
      width: isMobile ? null : 240,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: isMobile ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(2, 0))],
      ),
      child: Column(  // ✅ UBAH: Dari SingleChildScrollView menjadi Column langsung
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mobile: Show badges section at top
          if (isMobile) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: brandColor.withOpacity(0.05),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status & Info',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDeviceBadge(),
                      if (_printService.isConfigured) _buildPrinterStatusBadge(),
                      if (_printService.isConfigured) _buildAutoPrintBadge(),
                      if (_notificationService.queueLength > 0) _buildNotificationBadge(),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          // Menu tabs - ✅ TAMBAH: Expanded agar mengisi sisa space
          Expanded(
            child: SingleChildScrollView(  // ✅ ScrollView di dalam Expanded
              child: Column(
                children: [
                  _buildSidebarTab(0, 'Penyiapan', preparing.length),
                  _buildSidebarTab(1, 'Batch Cook', preparing.length),
                  _buildSidebarTab(2, 'Selesai', done.length),
                  _buildSidebarTab(3, 'Reservasi', reservations.length),
                  _buildSidebarTab(5, 'Stok by Kategori', categories.length),
                ],
              ),
            ),
          ),
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
      onTap: () {
        setState(() => _selectedTabIndex = index);
        if (index == 5) _navigateToCategories();
        // Close drawer on mobile after selection
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          Navigator.pop(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? brandColor.withOpacity(0.08) : Colors.transparent,
          border: Border(left: BorderSide(color: isSelected ? brandColor : Colors.transparent, width: 3)),
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

        grouped.putIfAbsent(key, () => []).add(
          BatchItem(
            orderId: order.orderId ?? '',
            orderName: order.name,
            tableNumber: order.table,
            menuName: item.name,
            quantity: item.qty,
            addons: item.addons,
            toppings: item.toppings,
            notes: item.notes,
          ),
        );
      }
    }
    grouped.removeWhere((key, value) => value.fold(0, (sum, item) => sum + item.quantity) < 2);
    return grouped;
  }

  Widget _buildCategoriesPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Kelola Stok Berdasarkan Kategori', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Pilih kategori untuk mengorganisir update stok', style: TextStyle(fontSize: 14, color: Colors.grey[500]), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToCategories,
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

  @override
  Widget build(BuildContext context) {
    // ✅ UPDATED: Use device properties for theme colors
    final appBarColor = widget.selectedDevice.shouldHandleBeverages
        ? (widget.selectedDevice.location == 'depan' ? Colors.blue[700] : Colors.orange[700])
        : brandColor;

    // ✅ UPDATED: Use device name for title
    final titleText = displayHeader;

    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 1,
        toolbarHeight: 70,
        backgroundColor: appBarColor,
        automaticallyImplyLeading: false,
        leading: isMobile ? IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ) : null,
        title: isMobile ? Center(
          child: _buildDeviceBadge(),
        ) : Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
              child: Image.asset(
                  '/images/RestaurantLogo.jpg',
                  height: 32,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.restaurant,
                      color: Colors.white,
                      size: 32
                  )
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      titleText,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 20
                      ),
                      overflow: TextOverflow.ellipsis
                  ),
                  const SizedBox(height: 2),
                  Text(
                      '${widget.selectedDevice.outlet.name} • ${widget.selectedDevice.location}',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500
                      )
                  ),
                ],
              ),
            ),
            if (!isMobile) _buildDeviceBadge(),
            if (!isMobile && _printService.isConfigured) _buildPrinterStatusBadge(),
            if (!isMobile && _printService.isConfigured) _buildAutoPrintBadge(),
            if (!isMobile && _notificationService.queueLength > 0) _buildNotificationBadge(),
            if (!isMobile) _buildIconButton(Icons.print, _showPrinterSettings, 'Pengaturan Printer'),
            if (!isMobile) const SizedBox(width: 8),
            if (!isMobile && _outOfStockItems.isNotEmpty) _buildStockBadge(),
            if (!isMobile && _outOfStockItems.isNotEmpty) const SizedBox(width: 8),
            if (!isMobile) _buildIconButton(Icons.refresh, _isLoading ? null : _loadOrders, 'Refresh'),
            if (!isMobile) const SizedBox(width: 8),
            if (!isMobile) _buildBackButton(),
            if (!isMobile) const SizedBox(width: 8),
            if (!isMobile) const DigitalClockWidget(color: brandColor),
          ],
        ),
        actions: isMobile ? [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ] : null,
      ),
      drawer: isMobile ? Drawer(
        child: _buildSidebar(isMobile: true),
      ) : null,
      endDrawer: isMobile ? _buildActionsDrawer() : null,
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(),
          if (!isMobile) VerticalDivider(
            width: 1,
            thickness: 1,
            color: Colors.grey.shade200,
          ),
          Expanded(
            child: _isLoading
                ? _buildLoadingWidget()
                : _errorMessage != null
                ? _buildErrorWidget()
                : IndexedStack(
                  index: _selectedTabIndex,
                  children: [
                    _buildOrdersList(preparing, true, false),
                    BatchCookingView(
                        orders: preparing,
                        onBatchComplete: _completeBatchOrders
                    ),
                    _buildOrdersList(done, false, true),
                    _buildOrdersList(reservations, false, false),
                    TableStockmenu(
                        stockMenu: stockmenu,
                        onRefresh: _loadStockMenu,
                        brandColor: brandColor
                    ),
                    _buildCategoriesPlaceholder(),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback? onPressed, String tooltip) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: IconButton(
        icon: Icon(icon, color: brandColor, size: 24),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  // ✅ UPDATED: Status badge based on device properties
  Widget _buildStatusBadge() {
    final color = widget.selectedDevice.shouldHandleBeverages
        ? (widget.selectedDevice.location == 'depan' ? Colors.blue : Colors.orange)
        : Colors.green;
    final text = widget.selectedDevice.shouldHandleBeverages
        ? (widget.selectedDevice.location == 'depan' ? 'Bar Depan' : 'Bar Belakang')
        : 'Dapur';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.selectedDevice.shouldHandleKitchen ? Icons.restaurant : Icons.local_bar, size: 14, color: color[700]),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color[900], fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPrinterStatusBadge() {
    final isConnected = _printService.consecutiveFailures == 0;
    final color = isConnected ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_printService.connectionType == PrinterConnectionType.wifi ? Icons.wifi : Icons.bluetooth, size: 14, color: color.shade700),
          const SizedBox(width: 4),
          Text(isConnected ? 'Tersambung' : 'Periksa', style: TextStyle(color: color.shade900, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAutoPrintBadge() {
    final color = _autoPrintEnabled ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_printService.connectionType == PrinterConnectionType.wifi ? Icons.wifi : Icons.bluetooth, size: 14, color: color.shade700),
          const SizedBox(width: 4),
          Text(_autoPrintEnabled ? 'Auto' : 'Manual', style: TextStyle(color: color.shade900, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildNotificationBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade400,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_active, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text('${_notificationService.queueLength}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStockBadge() {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: IconButton(
            icon: Icon(Icons.inventory_2_outlined, color: Colors.red.shade700, size: 24),
            onPressed: _showOutOfStockDialog,
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
              boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            child: Text('${_outOfStockItems.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

}

// Keep the existing _PrinterSettingsDialog class unchanged
class _PrinterSettingsDialog extends StatefulWidget {
  final ThermalPrintService printService;
  final bool autoPrintEnabled;
  final Function(bool) onAutoPrintChanged;
  final Color brandColor;

  const _PrinterSettingsDialog({
    required this.printService,
    required this.autoPrintEnabled,
    required this.onAutoPrintChanged,
    required this.brandColor,
  });

  @override
  State<_PrinterSettingsDialog> createState() => _PrinterSettingsDialogState();
}

class _PrinterSettingsDialogState extends State<_PrinterSettingsDialog> {
  int _selectedConnectionType = 0;
  final TextEditingController _ipController = TextEditingController();
  List<BluetoothDevice> _bluetoothDevices = [];
  BluetoothDevice? _selectedDevice;
  bool _isScanning = false;
  bool _isTesting = false; // Add testing state
  String? _errorMessage;
  late bool _autoPrintEnabled;

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
  }

  void _loadSavedConfig() {
    final printService = widget.printService;
    _selectedConnectionType = printService.connectionType == PrinterConnectionType.wifi ? 0 : 1;
    _ipController.text = printService.printerIp ?? '';
    _selectedDevice = printService.bluetoothDevice;
    if (_selectedDevice != null) _bluetoothDevices = [_selectedDevice!];
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
        final Set<String> existingAddresses = _bluetoothDevices.map((d) => d.address).toSet();
        for (var device in devices) {
          if (!existingAddresses.contains(device.address)) _bluetoothDevices.add(device);
        }
        _isScanning = false;
      });

      if (devices.isEmpty && _bluetoothDevices.isEmpty) {
        setState(() => _errorMessage = 'Tidak ada printer yang dipasangkan. Silakan pair printer di pengaturan Bluetooth perangkat terlebih dahulu.');
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
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nama Printer (Opsional)', hintText: 'Thermal Printer', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: macController, decoration: const InputDecoration(labelText: 'MAC Address', hintText: '00:11:22:33:44:55', border: OutlineInputBorder()), textCapitalization: TextCapitalization.characters),
            const SizedBox(height: 8),
            Text('Format: XX:XX:XX:XX:XX:XX\nContoh: 00:11:22:33:44:55', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final mac = macController.text.trim();
              final name = nameController.text.trim();
              if (mac.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('MAC Address tidak boleh kosong'), backgroundColor: Colors.red));
                return;
              }
              final device = BluetoothDevice(address: mac, name: name.isEmpty ? 'Thermal Printer' : name);
              setState(() {
                _selectedDevice = device;
                if (!_bluetoothDevices.any((d) => d.address == device.address)) _bluetoothDevices.add(device);
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: widget.brandColor, foregroundColor: Colors.white),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  Future<void> _testAndSave() async {
    if (_selectedConnectionType == 0) {
      if (_ipController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IP Address tidak boleh kosong'), backgroundColor: Colors.red));
        return;
      }
      widget.printService.configurePrinter(_ipController.text.trim());
    } else {
      if (_selectedDevice == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih printer Bluetooth terlebih dahulu'), backgroundColor: Colors.red));
        return;
      }
      widget.printService.configureBluetoothPrinter(_selectedDevice!);
    }

    // Show loading state
    setState(() => _isTesting = true);

    widget.printService.setAutoPrintEnabled(_autoPrintEnabled);
    final success = await widget.printService.testConnection();

    // Hide loading state
    if (mounted) {
      setState(() => _isTesting = false);
    }

    // Close dialog first, then show snackbar
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      
      // Show snackbar after dialog is closed
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(success ? 'Printer berhasil dikonfigurasi dan disimpan!' : 'Gagal terhubung ke printer'),
            backgroundColor: success ? widget.brandColor : Colors.red,
          ));
        }
      });
    }
  }

  void _showClearConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Konfigurasi Printer'),
        content: const Text('Konfigurasi printer yang tersimpan akan dihapus. Anda perlu mengkonfigurasi ulang printer untuk menggunakan fitur auto print.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              widget.printService.clearConfiguration();
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Konfigurasi printer berhasil dihapus'), backgroundColor: widget.brandColor));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green[200]!)),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Printer tersimpan', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w600, fontSize: 14)),
                            Text(widget.printService.printerInfo, style: TextStyle(color: Colors.green[600], fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('WiFi/LAN'), icon: Icon(Icons.wifi)),
                  ButtonSegment(value: 1, label: Text('Bluetooth'), icon: Icon(Icons.bluetooth)),
                ],
                selected: {_selectedConnectionType},
                onSelectionChanged: (Set<int> newSelection) => setState(() {
                  _selectedConnectionType = newSelection.first;
                  _errorMessage = null;
                }),
              ),
              const SizedBox(height: 20),
              if (_selectedConnectionType == 0) ...[
                TextField(
                  controller: _ipController,
                  decoration: const InputDecoration(labelText: 'IP Address Printer', hintText: '192.168.1.100', prefixIcon: Icon(Icons.computer), border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                Text('Masukkan IP Address printer thermal di jaringan lokal', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
              if (_selectedConnectionType == 1) ...[
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red[200]!)),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMessage!, style: TextStyle(color: Colors.red[700], fontSize: 12))),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isScanning ? null : _scanBluetoothDevices,
                        icon: _isScanning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Icon(Icons.bluetooth_searching),
                        label: Text(_isScanning ? 'Mencari...' : 'Lihat Paired'),
                        style: ElevatedButton.styleFrom(backgroundColor: widget.brandColor, foregroundColor: Colors.white, minimumSize: const Size(0, 48)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showManualMacAddressDialog,
                        icon: const Icon(Icons.edit),
                        label: const Text('Input MAC'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700], foregroundColor: Colors.white, minimumSize: const Size(0, 48)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_bluetoothDevices.isNotEmpty) ...[
                  const Text('Perangkat Ditemukan:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _bluetoothDevices.length,
                      itemBuilder: (context, index) {
                        final device = _bluetoothDevices[index];
                        final isSelected = _selectedDevice?.address == device.address;
                        return ListTile(
                          leading: Icon(Icons.print_outlined, color: isSelected ? widget.brandColor : Colors.grey[600]),
                          title: Text(device.name?.isEmpty ?? true ? 'Unknown Device' : device.name!, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                          subtitle: Text(device.address, style: const TextStyle(fontSize: 11)),
                          trailing: isSelected ? Icon(Icons.check_circle, color: widget.brandColor) : null,
                          selected: isSelected,
                          selectedTileColor: widget.brandColor.withOpacity(0.1),
                          onTap: () => setState(() => _selectedDevice = device),
                        );
                      },
                    ),
                  ),
                ] else if (!_isScanning) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('Belum ada perangkat', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Pair printer di Settings > Bluetooth,\nlalu tekan "Lihat Paired"', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                ],
                if (_isScanning) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Mencari printer yang sudah dipair...', style: TextStyle(color: Colors.blue[900], fontSize: 12))),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Auto Print', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        SizedBox(height: 4),
                        Text('Print otomatis saat order baru', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isTesting ? null : _showClearConfigDialog, child: const Text('Hapus Konfigurasi')),
        TextButton(onPressed: _isTesting ? null : () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          onPressed: _isTesting ? null : _testAndSave,
          style: ElevatedButton.styleFrom(backgroundColor: widget.brandColor, foregroundColor: Colors.white),
          child: _isTesting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Test & Simpan'),
        ),
      ],
    );
  }
}