// screens/kitchen_dashboard.dart
import 'unified_stock_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async';
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
import 'batch_cooking_screen.dart';
import 'kitchen_dashboard_widgets.dart';
import 'printer_settings_dialog.dart';

class KitchenDashboard extends StatefulWidget {
  final String? barType;

  const KitchenDashboard({super.key, this.barType});

  @override
  State<KitchenDashboard> createState() => _KitchenDashboardState();
}

class _KitchenDashboardState extends State<KitchenDashboard> {
  static const Color brandColor = Color(0xFF077A4B);

  // Lists
  List<Order> queue = [];
  List<Order> preparing = [];
  List<Order> done = [];
  List<Order> reservations = [];
  List<StockMenu> stockmenu = [];
  List<Category> categories = [];
  List<OutOfStockItem> outOfStockItems = [];

  // UI State
  String search = '';
  bool isLoading = false;
  String? errorMessage;
  int selectedTabIndex = 0;
  Order? selectedOrder;
  bool showDetailPanel = false;

  // Timers
  late Timer mainTimer;
  late Timer refreshTimer;
  Timer? stockCheckTimer;
  DateTime currentTime = DateTime.now();

  // Maps and Sets
  final Map<String, bool> alertPlayedMap = {};
  final Set<String> displayedItemIds = <String>{};
  final Map<String, bool> expandedOrders = {};

  // Services
  final NotificationService notificationService = NotificationService();
  final ThermalPrintService printService = ThermalPrintService();

  // Auto Print
  bool autoPrintEnabled = true;

  String get workstation {
    if (widget.barType == 'depan' || widget.barType == 'belakang') {
      return 'bar';
    } else {
      return 'kitchen';
    }
  }

  String _formatTime(DateTime dateTime) {
    // Format: "08 Nov, 14:30"
    List<String> months = ['Januari', 'Febuari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

    String day = dateTime.day.toString().padLeft(2, '0');
    String month = months[dateTime.month - 1];
    String year = dateTime.year.toString();
    String hour = dateTime.hour.toString().padLeft(2, '0');
    String minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day $month $year, $hour:$minute';
  }

  @override
  void initState() {
    super.initState();

    printService.setBarType(widget.barType);

    loadOrders();
    loadStockMenu();
    loadCategories();
    initializeTimers();
    loadOutOfStockItems();

    stockCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      loadOutOfStockItems();
    });

    const outletId = "outlet-1";

    SocketService.connect(
      outletId: outletId,
      barType: widget.barType,
      onNewOrder: (_) => refreshOrders(),
      onBeverageOrder: (beverageData) {
        if (widget.barType != null) {
          handleBeverageOrder(beverageData);
        }
      },
      onStockUpdate: (stockData) {
        refreshOutOfStockAfterUpdate(stockData['menuItemId'] ?? '');
        loadStockMenu();
      },
    );
  }

  @override
  void dispose() {
    mainTimer.cancel();
    refreshTimer.cancel();
    stockCheckTimer?.cancel();
    SocketService.disconnect();
    notificationService.dispose();
    super.dispose();
  }

  void initializeTimers() {
    mainTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        currentTime = DateTime.now();
      });
      checkForLateOrders();
    });

    refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      refreshOrders();
    });
  }

  Future<void> loadOrders() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final ordersMap = (widget.barType == 'depan' || widget.barType == 'belakang')
          ? await OrderService.refreshBarOrders(widget.barType!)
          : await OrderService.refreshKitchenOrders();
      await mergeOrdersWithAlertState(ordersMap, isInitialLoad: true);
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> refreshOrders() async {
    try {
      final orderService = (widget.barType == 'depan' || widget.barType == 'belakang')
          ? await OrderService.refreshBarOrders(widget.barType!)
          : await OrderService.refreshKitchenOrders();
      await mergeOrdersWithAlertState(orderService);
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing orders: $e');
      }
    }
  }

  Future<void> loadStockMenu() async {
    setState(() => isLoading = true);
    try {
      final data = await StockMenuService.getMenusByCategoryAndWorkstation('', workstation);
      setState(() {
        stockmenu = data.menus;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> loadCategories() async {
    try {
      final data = await StockMenuService.getCategoriesByWorkstation(workstation);
      setState(() {
        categories = data;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading categories: $e');
      }
    }
  }

  Future<void> loadOutOfStockItems() async {
    try {
      final items = await StockMenuService.getOutOfStockItems(workstation);
      if (mounted) {
        setState(() {
          outOfStockItems = items;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading out of stock items: $e');
      }
    }
  }

  Future<void> mergeOrdersWithAlertState(
      Map<String, List<Order>> ordersMap, {
        bool isInitialLoad = false,
      }) async {
    final newWaiting = ordersMap['waiting'] ?? [];
    final newPreparing = ordersMap['preparing'] ?? [];
    final newDone = ordersMap['completed'] ?? [];
    final newReservations = ordersMap['reservations'] ?? [];

    final confirmedOrders = <Order>[];
    for (var order in newWaiting) {
      if (order.orderId != null) {
        if (kDebugMode) {
          print('🚀 Auto-confirming ${order.orderType ?? 'order'} ${order.orderId}');
        }

        final updated = await OrderService.updateOrderStatus(order.orderId!, 'OnProcess');
        if (updated) {
          order.status = 'OnProcess';
          confirmedOrders.add(order);
        }
      }
    }

    for (var order in newReservations) {
      if (order.orderId != null && OrderService.shouldMoveReservationToPreparation(order)) {
        if (kDebugMode) {
          print('📅 Auto-confirming reservation ${order.orderId}');
        }

        final updated = await OrderService.updateOrderStatus(order.orderId!, 'OnProcess');
        if (updated) {
          order.status = 'OnProcess';
          confirmedOrders.add(order);
        }
      }
    }

    final allPreparing = [...newPreparing, ...confirmedOrders];

    if (!isInitialLoad) {
      await processNewItems(allPreparing);
      await processNewReservations(newReservations);
    } else {
      trackExistingItems([...allPreparing, ...newDone, ...newReservations]);
    }

    for (var o in allPreparing) {
      alertPlayedMap.putIfAbsent(o.orderId ?? "", () => false);
    }

    allPreparing.sort((a, b) => (a.updatedAt ?? DateTime(0)).compareTo(b.updatedAt ?? DateTime(0)));
    newDone.sort((a, b) => (a.updatedAt ?? DateTime(0)).compareTo(b.updatedAt ?? DateTime(0)));
    newReservations.sort((a, b) => (a.updatedAt ?? DateTime(0)).compareTo(b.updatedAt ?? DateTime(0)));

    if (mounted) {
      setState(() {
        queue = [];
        preparing = allPreparing;
        done = newDone;
        reservations = newReservations;
      });
    }
  }

  Future<void> processNewItems(List<Order> allPreparing) async {
    for (var order in allPreparing) {
      if (order.orderId == null) continue;

      final newItems = <OrderItem>[];
      for (final item in order.items) {
        if (!displayedItemIds.contains(item.itemId)) {
          newItems.add(item);
          displayedItemIds.add(item.itemId);

          if (kDebugMode) {
            print('🆕 NEW ITEM: ${item.name} (${item.itemId})');
          }
        }
      }

      if (newItems.isNotEmpty && autoPrintEnabled && printService.isConfigured) {
        await autoPrintNewItems(order, newItems);
      }
    }
  }

  Future<void> autoPrintNewItems(Order order, List<OrderItem> newItems) async {
    if (kDebugMode) {
      print('🖨️ Attempting to print ${newItems.length} new items from ${order.orderId}');
    }

    notificationService.playNewOrderNotification(
      order.orderId!,
      soundPath: 'sounds/alert.mp3',
    ).catchError((e) => false);

    final isOpenBill = order.items.length > newItems.length;

    final tempOrderForPrint = Order(
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
    );

    printService.autoPrintOrder(tempOrderForPrint, isOpenBill: isOpenBill).then((printed) {
      if (printed && mounted) {
        showPrintSuccessSnackbar(order.orderId!);
      }
    }).catchError((e) {
      if (kDebugMode) {
        print('❌ Print error: $e');
      }
    });
  }

  Future<void> processNewReservations(List<Order> newReservations) async {
    for (var order in newReservations) {
      if (order.orderId != null && !OrderService.shouldMoveReservationToPreparation(order)) {
        for (final item in order.items) {
          if (!displayedItemIds.contains(item.itemId)) {
            displayedItemIds.add(item.itemId);
          }
        }

        notificationService.playNewOrderNotification(
          order.orderId!,
          soundPath: 'sounds/ding.mp3',
        ).catchError((e) => false);
      }
    }
  }

  void trackExistingItems(List<Order> orders) {
    for (var order in orders) {
      for (final item in order.items) {
        displayedItemIds.add(item.itemId);
      }
    }

    if (kDebugMode) {
      print('📋 Initial load: Tracked ${displayedItemIds.length} existing items');
    }
  }

  void completeOrder(Order order) async {
    setState(() {
      preparing.remove(order);
      done.add(order);
      if (selectedOrder?.orderId == order.orderId) {
        selectedOrder = null;
        showDetailPanel = false;
      }
    });

    if (order.orderId != null) {
      await OrderService.updateOrderStatus(order.orderId!, 'Completed');
    }
    showOrderCompleteDialog(order);
  }

  void completeBatchOrders(List<String> orderIds) async {
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

    setState(() {
      if (selectedOrder != null && orderIds.contains(selectedOrder!.orderId)) {
        selectedOrder = null;
        showDetailPanel = false;
      }
    });

    showBatchCompleteDialog(orderIds.length);
  }

  void addTimeToOrder(Order order, int minutes) {
    setState(() {
      if (order.updatedAt != null) {
        order.updatedAt = order.updatedAt!.add(Duration(minutes: minutes));
      }
    });
  }

  void checkForLateOrders() {
    for (var order in queue) {
      if (order.isLate) {
        final alreadyPlayed = alertPlayedMap[order.orderId] ?? false;
        if (!alreadyPlayed) {
          alertPlayedMap[order.orderId ?? ""] = true;
        }
      }
    }
  }

  List<Order> getFilteredOrders(List<Order> orders) {
    if (search.isEmpty) return orders;

    return orders.where((order) {
      final nameMatch = order.name.toLowerCase().contains(search);
      final itemsMatch = order.items.any((item) => item.name.toLowerCase().contains(search));
      return nameMatch || itemsMatch;
    }).toList();
  }

  Map<String, List<BatchItem>> groupIdenticalItemsForCount() {
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

  void debugPrintStatus(Order order) {
    print('┌────────────────────────────────────┐');
    print('📊 DEBUG: Order ${order.orderId}');
    print('└────────────────────────────────────┘');
    print('Total items: ${order.items.length}');
    for (final item in order.items) {
      final isPrinted = printService.isItemAlreadyPrinted(item.itemId);
      print('  ${isPrinted ? "✅" : "❌"} ${item.name} (${item.itemId})');
    }
  }

  void handleBeverageOrder(Map<String, dynamic> beverageData) {
    notificationService.playNewOrderNotification(
      beverageData['orderId'] ?? 'unknown',
      soundPath: 'sounds/alert.mp3',
    ).catchError((e) => false);
  }

  Future<void> refreshOutOfStockAfterUpdate(String menuItemId) async {
    try {
      final updatedItems = await StockMenuService.getOutOfStockItems(workstation);

      if (mounted) {
        setState(() {
          outOfStockItems = updatedItems;
        });

        if (updatedItems.isEmpty && Navigator.canPop(context)) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Semua stok berhasil diperbarui!'),
                ],
              ),
              backgroundColor: Color(0xFF077A4B),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing out of stock: $e');
      }
    }
  }

  void showOutOfStockDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => OutOfStockDialog(
        outOfStockItems: outOfStockItems,
        workstation: workstation,
        brandColor: brandColor,
        onRefresh: () async {
          await loadOutOfStockItems();

    _notificationService
        .playNewOrderNotification(
      beverageData['orderId'] ?? 'unknown',
      soundPath: 'sounds/alert.mp3',
    )
        .catchError((e) => false);

    if (_autoPrintEnabled && _printService.isConfigured) {
      // TODO: Implement beverage order printing
    }
  }

  Future<void> _loadCategories() async {
    try {
      final data = await StockMenuService.getCategoriesByWorkstation(
        workstation,
      );
      setState(() {
        categories = data;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading categories: $e');
      }
    }
  }

  Future<void> _loadStockMenu() async {
    setState(() => _isLoading = true);
    try {
      final data = await StockMenuService.getMenusByCategoryAndWorkstation(
        '',
        workstation,
      );
      setState(() {
        stockmenu = data.menus;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
    _stockCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ordersMap =
      (widget.barType == 'depan' || widget.barType == 'belakang')
          ? await OrderService.refreshBarOrders(widget.barType!)
          : await OrderService.refreshKitchenOrders();
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
      final orderService =
      (widget.barType == 'depan' || widget.barType == 'belakang')
          ? await OrderService.refreshBarOrders(widget.barType!)
          : await OrderService.refreshKitchenOrders();
      await _mergeOrdersWithAlertState(orderService);
      // Debug print status
      if (kDebugMode && preparing.isNotEmpty) {
        _debugPrintStatus(preparing.first);
      }

    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing orders: $e');
      }
    }
  }

  // ✅ SOLUSI: Print SEBELUM API confirmation selesai
  Future<void> _mergeOrdersWithAlertState(
      Map<String, List<Order>> ordersMap, {
        bool isInitialLoad = false,
      }) async {
    final newWaiting = ordersMap['waiting'] ?? [];
    final newPreparing = ordersMap['preparing'] ?? [];
    final newDone = ordersMap['completed'] ?? [];
    final newReservations = ordersMap['reservations'] ?? [];

    // ✅ KUNCI: Collect orders yang perlu di-auto-confirm
    final ordersToConfirm = <Order>[];
    final confirmedOrders = <Order>[];

    // Process waiting orders
    for (var order in newWaiting) {
      if (order.orderId != null) {
        ordersToConfirm.add(order);
      }
    }

    // Process reservations yang sudah waktunya
    for (var order in newReservations) {
      if (order.orderId != null && OrderService.shouldMoveReservationToPreparation(order)) {
        ordersToConfirm.add(order);
      }
    }

    // ✅ OPTIMASI 1: Update status PARALLEL (tidak blocking print)
    if (ordersToConfirm.isNotEmpty) {
      // Fire and forget - jangan await di sini
      _confirmOrdersInBackground(ordersToConfirm, confirmedOrders);

      // Langsung masukkan ke preparing untuk print
      for (var order in ordersToConfirm) {
        order.status = 'OnProcess';
        confirmedOrders.add(order);
      }
    }

    // Combine preparing orders
    final allPreparing = [...newPreparing, ...confirmedOrders];

    // ✅ OPTIMASI 2: PRINT IMMEDIATELY (tidak tunggu API)
    if (!isInitialLoad) {
      _processPrintQueue(allPreparing); // Fire and forget
    } else {
      // Initial load: Track semua items yang sudah ada
      for (var order in [...allPreparing, ...newDone, ...newReservations]) {
        for (final item in order.items) {
          _displayedItemIds.add(item.itemId);
        }
      }

      if (kDebugMode) {
        print('📋 Initial load: Tracked ${_displayedItemIds.length} existing items');
      }
    }

    // Process new reservations (yang belum waktunya)
    for (var order in newReservations) {
      if (order.orderId != null &&
          !OrderService.shouldMoveReservationToPreparation(order)) {

        // Track items dari reservasi
        for (final item in order.items) {
          if (!_displayedItemIds.contains(item.itemId)) {
            _displayedItemIds.add(item.itemId);
          }
        }

        _notificationService
            .playNewOrderNotification(
          order.orderId!,
          soundPath: 'sounds/ding.mp3',
        )
            .catchError((e) => false);
      }
    }

    // Initialize alert played map
    for (var o in allPreparing) {
      _alertPlayedMap.putIfAbsent(o.orderId ?? "", () => false);
    }

    // Sort orders
    allPreparing.sort(
          (a, b) =>
          (a.updatedAt ?? DateTime(0)).compareTo(b.updatedAt ?? DateTime(0)),
    );
  }

// ✅ HELPER: Confirm orders in background (parallel)
  Future<void> _confirmOrdersInBackground(
      List<Order> ordersToConfirm,
      List<Order> confirmedOrders,
      ) async {
    // Run all confirmations in parallel
    final confirmFutures = ordersToConfirm.map((order) async {
      try {
        if (kDebugMode) {
          print('🚀 Auto-confirming ${order.orderType ?? 'order'} ${order.orderId} from Waiting to OnProcess');
        }

        final updated = await OrderService.updateOrderStatus(
          order.orderId!,
          'OnProcess',
        );

        if (updated) {
          if (kDebugMode) {
            print('✅ Order ${order.orderId} confirmed and moved to preparing');
          }
        } else {
          if (kDebugMode) {
            print('⚠️ Failed to confirm: ${order.orderId}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error confirming ${order.orderId}: $e');
        }
      }
    });

    // Wait for all confirmations (but don't block the UI/print)
    await Future.wait(confirmFutures);
  }

// ✅ HELPER: Process print queue async (non-blocking)
  void _processPrintQueue(List<Order> allPreparing) async {
    for (var order in allPreparing) {
      if (order.orderId == null) continue;

      // Check for new items
      final newItems = <OrderItem>[];

      for (final item in order.items) {
        final isNewItem = !_displayedItemIds.contains(item.itemId);

        if (isNewItem) {
          newItems.add(item);
          _displayedItemIds.add(item.itemId);

          if (kDebugMode) {
            print('🆕 NEW ITEM: ${item.name} (${item.itemId})');
          }
        }
      }

      // Print new items immediately
      if (newItems.isNotEmpty && _autoPrintEnabled && _printService.isConfigured) {
        if (kDebugMode) {
          print('🖨️ FAST PRINT: ${newItems.length} items from ${order.orderId}');
        }

        // Play notification
        _notificationService
            .playNewOrderNotification(
          order.orderId!,
          soundPath: 'sounds/alert.mp3',
        )
            .catchError((e) => false);

        // Detect open bill
        final isOpenBill = order.items.length > newItems.length;

        // Create temp order for printing
        final tempOrderForPrint = Order(
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
        );

        // ✅ OPTIMASI 3: Print tanpa await (fire and forget)
        _printService
            .autoPrintOrder(tempOrderForPrint, isOpenBill: isOpenBill)
            .then((printed) {
          if (printed && mounted) {
            _showPrintSuccessSnackbar(order.orderId!);
          } else if (!printed && kDebugMode) {
            print('⚠️ Auto-print failed for ${order.orderId}');
          }
        })
            .catchError((e) {
          if (kDebugMode) {
            print('❌ Print error for ${order.orderId}: $e');
          }
        });
      }
    }
  }
  //new one
  // Future<void> _mergeOrdersWithAlertState(
  //     Map<String, List<Order>> ordersMap, {
  //       bool isInitialLoad = false,
  //     }) async {
  //   final newWaiting = ordersMap['waiting'] ?? [];
  //   final newPreparing = ordersMap['preparing'] ?? [];
  //   final newDone = ordersMap['completed'] ?? [];
  //   final newReservations = ordersMap['reservations'] ?? [];
  //
  //   // ✅ AUTO-CONFIRM WAITING ORDERS
  //   final confirmedOrders = <Order>[];
  //   for (var order in newWaiting) {
  //     if (order.orderId != null) {
  //       if (kDebugMode) {
  //         print('🚀 Auto-confirming ${order.orderType ?? 'order'} ${order.orderId} from Waiting to OnProcess');
  //       }
  //
  //       final updated = await OrderService.updateOrderStatus(order.orderId!, 'OnProcess');
  //
  //       if (updated) {
  //         order.status = 'OnProcess';
  //         confirmedOrders.add(order);
  //
  //         if (kDebugMode) {
  //           print('✅ Order ${order.orderId} confirmed and moved to preparing');
  //         }
  //       }
  //     }
  //   }
  //
  //   // ✅ AUTO-CONFIRM RESERVATIONS yang sudah waktunya
  //   for (var order in newReservations) {
  //     if (order.orderId != null && OrderService.shouldMoveReservationToPreparation(order)) {
  //       if (kDebugMode) {
  //         print('📅 Auto-confirming reservation ${order.orderId} to OnProcess');
  //       }
  //
  //       final updated = await OrderService.updateOrderStatus(order.orderId!, 'OnProcess');
  //
  //       if (updated) {
  //         order.status = 'OnProcess';
  //         confirmedOrders.add(order);
  //
  //         if (kDebugMode) {
  //           print('✅ Reservation ${order.orderId} confirmed and moved to preparing');
  //         }
  //       }
  //     }
  //   }
  //
  //   // Combine preparing orders
  //   final allPreparing = [...newPreparing, ...confirmedOrders];
  //
  //   // ✅ PROCESS NEW ITEMS & AUTO-PRINT
  //   if (!isInitialLoad) {
  //     for (var order in allPreparing) {
  //       if (order.orderId == null) continue;
  //
  //       // ✅ CEK ITEMS YANG BARU MUNCUL DI DASHBOARD
  //       final newItems = <OrderItem>[];
  //
  //       for (final item in order.items) {
  //         final isNewItem = !_displayedItemIds.contains(item.itemId);
  //
  //         if (isNewItem) {
  //           newItems.add(item);
  //           _displayedItemIds.add(item.itemId); // ✅ Mark sebagai sudah muncul
  //
  //           if (kDebugMode) {
  //             print('🆕 NEW ITEM in dashboard: ${item.name} (${item.itemId}) from order ${order.orderId}');
  //           }
  //         }
  //       }
  //
  //       // ✅ JIKA ADA ITEMS BARU, PRINT HANYA ITEMS BARU SAJA
  //       if (newItems.isNotEmpty && _autoPrintEnabled && _printService.isConfigured) {
  //         if (kDebugMode) {
  //           print('🖨️ Attempting to print ${newItems.length} new items from order ${order.orderId}');
  //           for (final item in newItems) {
  //             print('   📝 ${item.name} x${item.qty}');
  //           }
  //         }
  //
  //         // Play notification untuk item baru
  //         _notificationService
  //             .playNewOrderNotification(
  //           order.orderId!,
  //           soundPath: 'sounds/alert.mp3',
  //         )
  //             .catchError((e) => false);
  //
  //         // ✅ DETEKSI APAKAH INI OPEN BILL
  //         final isOpenBill = order.items.length > newItems.length;
  //
  //         // ✅ KUNCI: Buat order TEMPORARY yang hanya berisi items BARU
  //         final tempOrderForPrint = Order(
  //           orderId: order.orderId,
  //           name: order.name,
  //           table: order.table,
  //           status: order.status,
  //           items: newItems, // ✅ HANYA ITEMS BARU
  //           createdAt: order.createdAt,
  //           updatedAt: order.updatedAt,
  //           createdAtWIB: order.createdAtWIB,
  //           updatedAtWIB: order.updatedAtWIB,
  //           service: order.service,
  //           orderType: order.orderType,
  //           reservationDateTime: order.reservationDateTime,
  //           totalPrice: order.totalPrice,
  //           source: order.source,
  //           paymentMethod: order.paymentMethod,
  //         );
  //
  //         // ✅ Print order temporary dengan flag isOpenBill
  //         _printService
  //             .autoPrintOrder(tempOrderForPrint, isOpenBill: isOpenBill)
  //             .then((printed) {
  //           if (printed && mounted) {
  //             _showPrintSuccessSnackbar(order.orderId!);
  //           } else if (!printed && kDebugMode) {
  //             print('⚠️ Auto-print failed for ${order.orderId}');
  //           }
  //         })
  //             .catchError((e) {
  //           if (kDebugMode) {
  //             print('❌ Print error for ${order.orderId}: $e');
  //           }
  //         });
  //       } else if (newItems.isEmpty && kDebugMode) {
  //         print('✅ Order ${order.orderId} - No new items to print');
  //       }
  //     }
  //
  //     // ✅ Process new reservations (yang belum waktunya)
  //     for (var order in newReservations) {
  //       if (order.orderId != null &&
  //           !OrderService.shouldMoveReservationToPreparation(order)) {
  //
  //         // Track items dari reservasi
  //         for (final item in order.items) {
  //           if (!_displayedItemIds.contains(item.itemId)) {
  //             _displayedItemIds.add(item.itemId);
  //
  //             if (kDebugMode) {
  //               print('📅 Reservasi item tracked: ${item.name} (${item.itemId})');
  //             }
  //           }
  //         }
  //
  //         _notificationService
  //             .playNewOrderNotification(
  //           order.orderId!,
  //           soundPath: 'sounds/ding.mp3',
  //         )
  //             .catchError((e) => false);
  //       }
  //     }
  //   } else {
  //     // ✅ INITIAL LOAD: Track semua items yang sudah ada
  //     for (var order in [...allPreparing, ...newDone, ...newReservations]) {
  //       for (final item in order.items) {
  //         _displayedItemIds.add(item.itemId);
  //       }
  //     }
  //
  //     if (kDebugMode) {
  //       print('📋 Initial load: Tracked ${_displayedItemIds.length} existing items');
  //     }
  //   }
  //
  //   // Initialize alert played map
  //   for (var o in allPreparing) {
  //     _alertPlayedMap.putIfAbsent(o.orderId ?? "", () => false);
  //   }
  //
  //   // Sort orders
  //   allPreparing.sort(
  //         (a, b) =>
  //         (a.updatedAt ?? DateTime(0)).compareTo(b.updatedAt ?? DateTime(0)),
  //   );
  //   newDone.sort(
  //         (a, b) =>
  //         (a.updatedAt ?? DateTime(0)).compareTo(b.updatedAt ?? DateTime(0)),
  //   );
  //   newReservations.sort(
  //         (a, b) =>
  //         (a.updatedAt ?? DateTime(0)).compareTo(b.updatedAt ?? DateTime(0)),
  //   );
  //
  //   if (mounted) {
  //     setState(() {
  //       queue = [];
  //       preparing = allPreparing;
  //       done = newDone;
  //       reservations = newReservations;
  //     });
  //   }
  // }


  //old
  // Future<void> _mergeOrdersWithAlertState(
  //     Map<String, List<Order>> ordersMap, {
  //       bool isInitialLoad = false,
  //     }) async {
  //   final newWaiting = ordersMap['waiting'] ?? [];
  //   final newPreparing = ordersMap['preparing'] ?? [];
  //   final newDone = ordersMap['completed'] ?? [];
  //   final newReservations = ordersMap['reservations'] ?? [];
  //
  //   // ✅ AUTO-CONFIRM WAITING ORDERS
  //   final confirmedOrders = <Order>[];
  //   for (var order in newWaiting) {
  //     if (order.orderId != null) {
  //       if (kDebugMode) {
  //         print('🚀 Auto-confirming ${order.orderType ?? 'order'} ${order.orderId} from Waiting to OnProcess');
  //       }
  //
  //       final updated = await OrderService.updateOrderStatus(order.orderId!, 'OnProcess');
  //
  //       if (updated) {
  //         order.status = 'OnProcess';
  //         confirmedOrders.add(order);
  //
  //         if (kDebugMode) {
  //           print('✅ Order ${order.orderId} confirmed and moved to preparing');
  //         }
  //       }
  //     }
  //   }
  //
  //   // ✅ AUTO-CONFIRM RESERVATIONS yang sudah waktunya
  //   for (var order in newReservations) {
  //     if (order.orderId != null && OrderService.shouldMoveReservationToPreparation(order)) {
  //       if (kDebugMode) {
  //         print('📅 Auto-confirming reservation ${order.orderId} to OnProcess');
  //       }
  //
  //       final updated = await OrderService.updateOrderStatus(order.orderId!, 'OnProcess');
  //
  //       if (updated) {
  //         order.status = 'OnProcess';
  //         confirmedOrders.add(order);
  //
  //         if (kDebugMode) {
  //           print('✅ Reservation ${order.orderId} confirmed and moved to preparing');
  //         }
  //       }
  //     }
  //   }
  //
  //   // Combine preparing orders
  //   final allPreparing = [...newPreparing, ...confirmedOrders];
  //
  //   // ✅ PROCESS NEW ITEMS & AUTO-PRINT
  //   if (!isInitialLoad) {
  //     for (var order in allPreparing) {
  //       if (order.orderId == null) continue;
  //
  //       // ✅ CEK ITEMS YANG BARU MUNCUL DI DASHBOARD
  //       final newItems = <OrderItem>[];
  //
  //       for (final item in order.items) {
  //         final isNewItem = !_displayedItemIds.contains(item.itemId);
  //
  //         if (isNewItem) {
  //           newItems.add(item);
  //           _displayedItemIds.add(item.itemId); // ✅ Mark sebagai sudah muncul
  //
  //           if (kDebugMode) {
  //             print('🆕 NEW ITEM in dashboard: ${item.name} (${item.itemId}) from order ${order.orderId}');
  //           }
  //         }
  //       }
  //
  //       // ✅ JIKA ADA ITEMS BARU, PRINT HANYA ITEMS BARU SAJA
  //       if (newItems.isNotEmpty && _autoPrintEnabled && _printService.isConfigured) {
  //         if (kDebugMode) {
  //           print('🖨️ Attempting to print ${newItems.length} new items from order ${order.orderId}');
  //           for (final item in newItems) {
  //             print('   📝 ${item.name} x${item.qty}');
  //           }
  //         }
  //
  //         // Play notification untuk item baru
  //         _notificationService
  //             .playNewOrderNotification(
  //           order.orderId!,
  //           soundPath: 'sounds/alert.mp3',
  //         )
  //             .catchError((e) => false);
  //
  //         // ✅ KUNCI: Buat order TEMPORARY yang hanya berisi items BARU
  //         final tempOrderForPrint = Order(
  //           orderId: order.orderId,
  //           name: order.name,
  //           table: order.table,
  //           status: order.status,
  //           items: newItems, // ✅ HANYA ITEMS BARU
  //           createdAt: order.createdAt,
  //           updatedAt: order.updatedAt,
  //           createdAtWIB: order.createdAtWIB,
  //           updatedAtWIB: order.updatedAtWIB,
  //           service: order.service,
  //           orderType: order.orderType,
  //           reservationDateTime: order.reservationDateTime,
  //           totalPrice: order.totalPrice,
  //           source: order.source,
  //           paymentMethod: order.paymentMethod,
  //         );
  //
  //         // Print order temporary (hanya items baru)
  //         _printService
  //             .autoPrintOrder(tempOrderForPrint)
  //             .then((printed) {
  //           if (printed && mounted) {
  //             _showPrintSuccessSnackbar(order.orderId!);
  //           } else if (!printed && kDebugMode) {
  //             print('⚠️ Auto-print failed for ${order.orderId}');
  //           }
  //         })
  //             .catchError((e) {
  //           if (kDebugMode) {
  //             print('❌ Print error for ${order.orderId}: $e');
  //           }
  //         });
  //       } else if (newItems.isEmpty && kDebugMode) {
  //         print('✅ Order ${order.orderId} - No new items to print');
  //       }
  //     }
  //
  //     // ✅ Process new reservations (yang belum waktunya)
  //     for (var order in newReservations) {
  //       if (order.orderId != null &&
  //           !OrderService.shouldMoveReservationToPreparation(order)) {
  //
  //         // Track items dari reservasi
  //         for (final item in order.items) {
  //           if (!_displayedItemIds.contains(item.itemId)) {
  //             _displayedItemIds.add(item.itemId);
  //
  //             if (kDebugMode) {
  //               print('📅 Reservasi item tracked: ${item.name} (${item.itemId})');
  //             }
  //           }
  //         }
  //
  //         _notificationService
  //             .playNewOrderNotification(
  //           order.orderId!,
  //           soundPath: 'sounds/ding.mp3',
  //         )
  //             .catchError((e) => false);
  //       }
  //     }
  //   } else {
  //     // ✅ INITIAL LOAD: Track semua items yang sudah ada
  //     for (var order in [...allPreparing, ...newDone, ...newReservations]) {
  //       for (final item in order.items) {
  //         _displayedItemIds.add(item.itemId);
  //       }
  //     }
  //
  //     if (kDebugMode) {
  //       print('📋 Initial load: Tracked ${_displayedItemIds.length} existing items');
  //     }
  //   }
  //
  //   // Initialize alert played map
  //   for (var o in allPreparing) {
  //     _alertPlayedMap.putIfAbsent(o.orderId ?? "", () => false);
  //   }
  //
  //   // Sort orders
  //   allPreparing.sort(
  //         (a, b) =>
  //         (a.updatedAt ?? DateTime(0)).compareTo(b.updatedAt ?? DateTime(0)),
  //   );
  //   newDone.sort(
  //         (a, b) =>
  //         (a.updatedAt ?? DateTime(0)).compareTo(b.updatedAt ?? DateTime(0)),
  //   );
  //   newReservations.sort(
  //         (a, b) =>
  //         (a.updatedAt ?? DateTime(0)).compareTo(b.updatedAt ?? DateTime(0)),
  //   );
  //
  //   if (mounted) {
  //     setState(() {
  //       queue = [];
  //       preparing = allPreparing;
  //       done = newDone;
  //       reservations = newReservations;
  //     });
  //   }
  // }

  void _showPrintSuccessSnackbar(String orderId) {
    if (kDebugMode) {
      print('✅ [AUTO PRINT] Order $orderId berhasil diprint otomatis');
    }

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

  void showOrderCompleteDialog(Order order) {
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
            child: Text('OK', style: TextStyle(fontSize: 16, color: brandColor)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void showBatchCompleteDialog(int count) {
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
            child: Text('OK', style: TextStyle(fontSize: 16, color: brandColor)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void navigateToCategories() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedStockScreen(workstation: workstation),
      ),
    );
  }

  // BUILD ORDER LIST (CENTER COLUMN)
  Widget buildOrderListCenter(List<Order> orders) {
    final filteredOrders = getFilteredOrders(orders);

    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            onChanged: (value) {
              setState(() {
                search = value.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Cari pesanan',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: brandColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),

        // Order List
        Expanded(
          child: filteredOrders.isEmpty
              ? Center(
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
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredOrders.length,
            itemBuilder: (context, index) {
              final order = filteredOrders[index];
              final isSelected = selectedOrder?.orderId == order.orderId;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? brandColor : Colors.grey[200]!,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color: brandColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                      : [],
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      selectedOrder = order;
                      showDetailPanel = true;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Queue Number
                        if (selectedTabIndex == 0)
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: brandColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        if (selectedTabIndex == 0) const SizedBox(width: 12),

                        // Order Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.table_restaurant, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Meja ${order.table}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.restaurant, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${order.items.length} item',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    order.updatedAtWIB != null
                                        ? _formatTime(order.updatedAtWIB!)
                                        : '-',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Status indicator
                        if (isSelected)
                          Icon(Icons.chevron_right, color: brandColor, size: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // BUILD ORDER DETAIL (RIGHT COLUMN)
  Widget buildOrderDetail() {
    if (selectedOrder == null || !showDetailPanel) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Pilih pesanan untuk melihat detail',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      );
    }

    final order = selectedOrder!;
    final isInPreparation = selectedTabIndex == 0;
    final isExpanded = expandedOrders[order.orderId] ?? false;

    return Column(
      children: [
        // Header with close button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Detail Pesanan',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    showDetailPanel = false;
                    selectedOrder = null;
                  });
                },
                tooltip: 'Tutup detail',
              ),
            ],
          ),
        ),

        // Order Card Compact (Reuse existing widget)
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: OrderCardCompact(
              order: order,
              isExpanded: isExpanded,
              showTimer: isInPreparation,
              isFinished: selectedTabIndex == 2,
              queueNumber: null,
              onToggleExpand: () {
                setState(() {
                  expandedOrders[order.orderId ?? ''] = !isExpanded;
                });
              },
              onComplete: isInPreparation ? () => completeOrder(order) : null,
              onAddTime: isInPreparation ? addTimeToOrder : null,
              onReprint: () async {
                final success = await printService.manualPrint(order);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(success ? Icons.check_circle : Icons.error, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(success ? 'Berhasil print ulang' : 'Gagal print'),
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: KitchenDashboardWidgets.buildAppBar(
        context: context,
        barType: widget.barType,
        currentTime: currentTime,
        printService: printService,
        autoPrintEnabled: autoPrintEnabled,
        notificationService: notificationService,
        outOfStockItems: outOfStockItems,
        isLoading: isLoading,
        onPrinterSettings: showPrinterSettings,
        onOutOfStockDialog: showOutOfStockDialog,
        onRefresh: loadOrders,
      ),
      body: isLoading
          ? KitchenDashboardWidgets.buildLoadingWidget(brandColor)
          : errorMessage != null
          ? KitchenDashboardWidgets.buildErrorWidget(
        errorMessage: errorMessage,
        brandColor: brandColor,
        onRetry: loadOrders,
      )
          : Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LEFT SIDEBAR - Navigation
          KitchenDashboardWidgets.buildSidebar(
            selectedTabIndex: selectedTabIndex,
            preparing: preparing,
            done: done,
            reservations: reservations,
            categories: categories,
            brandColor: brandColor,
            onTabSelected: (index) {
              setState(() {
                selectedTabIndex = index;
                selectedOrder = null;
                showDetailPanel = false;

                if (index == 5) {
                  navigateToCategories();
                }
              });
            },
            groupIdenticalItemsForCount: groupIdenticalItemsForCount,
          ),

          // CENTER - Order List
          Expanded(
            flex: 2,
            child: Container(
              color: const Color(0xFFF9FAFB),
              child: IndexedStack(
                index: selectedTabIndex,
                children: [
                  buildOrderListCenter(preparing),
                  BatchCookingView(
                    orders: preparing,
                    onBatchComplete: completeBatchOrders,
                  ),
                  buildOrderListCenter(done),
                  buildOrderListCenter(reservations),
                  TableStockmenu(
                    stockMenu: stockmenu,
                    onRefresh: loadStockMenu,
                    brandColor: brandColor,
                  ),
                  KitchenDashboardWidgets.buildCategoriesPlaceholder(
                    brandColor: brandColor,
                    onNavigate: navigateToCategories,
                  ),
                ],
              ),
            ),
          ),

          // RIGHT - Order Detail (Always shown for certain tabs)
          if (selectedTabIndex != 1 && selectedTabIndex != 4 && selectedTabIndex != 5)
            Container(
              width: 400,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              child: buildOrderDetail(),
            ),
        ],
      ),
    );
  }
}