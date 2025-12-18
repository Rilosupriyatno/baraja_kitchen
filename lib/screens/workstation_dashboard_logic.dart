// screens/workstation_dashboard_logic.dart (UPDATED - Using Workstation API)
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;
import '../models/order.dart';
import '../models/device.dart';
import '../services/order_service.dart';
import '../services/socket_service.dart';
import '../services/stockmenu_service.dart';
import 'workstation_dashboard_state.dart';
import 'printer_settings_dialog.dart';
import 'unified_stock_screen.dart';
import 'batch_cooking_screen.dart';
import '../widgets/order_card_compact.dart';

mixin WorkstationDashboardLogic<T extends StatefulWidget> on State<T> implements WorkstationDashboardState {

  Color get brandColor => const Color(0xFF077A4B);

  Device get currentDevice;

  @override
  String get workstation => currentDevice.workstationTypeString;

  String get workstationDisplayName => currentDevice.workstationName;

  @override
  void initState() {
    super.initState();

    printService.setDevice(currentDevice);

    if (kDebugMode) {
      print('╔═══════════════════════════════════════════════════════╗');
      print('📱 Dashboard Device: ${currentDevice.deviceName}');
      print('📍 Workstation Type: $workstation');
      print('📍 Display Name: $workstationDisplayName');
      print('📍 Location: ${currentDevice.location}');
      print('📍 Handles Beverages: ${currentDevice.shouldHandleBeverages}');
      print('📍 Handles Kitchen: ${currentDevice.shouldHandleKitchen}');
      print('╚═══════════════════════════════════════════════════════╝');
    }

    loadOrders();
    loadStockMenu();
    loadCategories();
    initializeTimers();
    loadOutOfStockItems();

    stockCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      loadOutOfStockItems();
    });

    final outletId = currentDevice.outlet.id;

    SocketService.connect(
      outletId: outletId,
      device: currentDevice,
      onNewOrder: (_) => refreshOrders(),
      onBeverageOrder: (beverageData) {
        if (currentDevice.shouldHandleBeverages) {
          handleBeverageOrder(beverageData);
        }
      },
      onStockUpdate: (stockData) {
        if (kDebugMode) {
          print('📦 Stock updated: ${stockData['menuItemId']}');
        }
        refreshOutOfStockAfterUpdate(stockData['menuItemId'] ?? '');
        loadStockMenu();
      },
      onImmediatePrint: handleImmediatePrint,
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

  // ✅ UPDATED: Using new workstation endpoint
  Future<void> loadOrders() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      if (kDebugMode) {
        print('📡 Loading orders for ${currentDevice.deviceName}...');
      }

      final ordersMap = await OrderService.refreshWorkstationOrders(currentDevice);
      await mergeOrdersWithAlertState(ordersMap, isInitialLoad: true);

      setState(() {
        isLoading = false;
      });

      if (kDebugMode) {
        print('✅ Orders loaded successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading orders: $e');
      }

      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // ✅ UPDATED: Using new workstation endpoint
  Future<void> refreshOrders() async {
    try {
      if (kDebugMode) {
        print('🔄 Refreshing orders for ${currentDevice.workstationTypeString}...');
      }

      final ordersMap = await OrderService.refreshWorkstationOrders(currentDevice);
      await mergeOrdersWithAlertState(ordersMap);

      if (kDebugMode && preparing.isNotEmpty) {
        debugPrintStatus(preparing.first);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error refreshing orders: $e');
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

    // ✅ Auto-confirm waiting orders using Device context
    final confirmedOrders = <Order>[];
    for (var order in newWaiting) {
      if (order.orderId != null) {
        if (kDebugMode) {
          print('🚀 Auto-confirming ${order.orderType ?? 'order'} ${order.orderId}');
        }

        final updated = await OrderService.updateWorkstationOrderStatus(
          order.orderId!,
          'OnProcess',
          currentDevice,
        );

        if (updated) {
          order.status = 'OnProcess';
          confirmedOrders.add(order);
        }
      }
    }

    // ✅ Auto-confirm reservations
    for (var order in newReservations) {
      if (order.orderId != null && OrderService.shouldMoveReservationToPreparation(order)) {
        if (kDebugMode) {
          print('📅 Auto-confirming reservation ${order.orderId}');
        }

        final updated = await OrderService.updateWorkstationOrderStatus(
          order.orderId!,
          'OnProcess',
          currentDevice,
        );

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

    // Use WIB time for sorting
    allPreparing.sort((a, b) => (a.updatedAtWIB ?? DateTime(0)).compareTo(b.updatedAtWIB ?? DateTime(0)));
    newDone.sort((a, b) => (b.updatedAtWIB ?? DateTime(0)).compareTo(a.updatedAtWIB ?? DateTime(0))); // Descending: terbaru di atas
    newReservations.sort((a, b) => (a.updatedAtWIB ?? DateTime(0)).compareTo(b.updatedAtWIB ?? DateTime(0)));

    if (mounted) {
      setState(() {
        queue = [];
        preparing = allPreparing;
        done = newDone;
        reservations = newReservations;
      });
    }
  }

  /// @deprecated This function is NOT actively used.
  /// The actual process is handled by `_processPrintQueue` in `workstation_dashboard.dart`.
  /// Kept for reference only - DO NOT MODIFY, modify `workstation_dashboard.dart` instead.
  @Deprecated('Use _processPrintQueue in workstation_dashboard.dart instead')
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

  /// @deprecated This function is NOT actively used.
  /// The actual auto-print is handled by `_processPrintQueue` in `workstation_dashboard.dart`.
  /// Kept for reference only - DO NOT MODIFY, modify `workstation_dashboard.dart` instead.
  @Deprecated('Use _processPrintQueue in workstation_dashboard.dart instead')
  Future<void> autoPrintNewItems(Order order, List<OrderItem> newItems) async {

      print('🖨️ [DEPRECATED] Attempting to print ${newItems.length} new items from ${order.orderId}');
      print('🔍 [DEBUG] Original order.cashierName: "${order.cashierName ?? "NULL"}"');

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
      cashierName: order.cashierName,  // ✅ CRITICAL: Tambahkan cashierName!
    );

    if (kDebugMode) {
      print('🔍 [DEBUG] tempOrderForPrint.cashierName: "${tempOrderForPrint.cashierName ?? "NULL"}"');
    }

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

  /// @deprecated This function is NOT actively used.
  /// The actual immediate print is handled by `_handleImmediatePrint` in `workstation_dashboard.dart`.
  /// Kept for reference only - DO NOT MODIFY, modify `workstation_dashboard.dart` instead.
  @Deprecated('Use _handleImmediatePrint in workstation_dashboard.dart instead')
  void handleImmediatePrint(Map<String, dynamic> printData) async {
    try {
      if (!autoPrintEnabled || !printService.isConfigured) return;

      final orderId = printData['orderId'] as String?;
      if (orderId == null) return;

      notificationService
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

      final workstationItems = orderItems.where((item) {
        final mainCat = (item.mainCategory ?? '').toLowerCase();
        final ws = (item.workstation ?? '').toLowerCase();

        if (currentDevice.shouldHandleBeverages) {
          return mainCat.contains('beverage') || mainCat.contains('minuman') || ws.contains('bar');
        } else if (currentDevice.shouldHandleKitchen) {
          return !mainCat.contains('beverage') && !mainCat.contains('minuman') && !ws.contains('bar');
        } else {
          return true;
        }
      }).toList();

      if (workstationItems.isEmpty) return;

      for (final item in workstationItems) {
        displayedItemIds.add(item.itemId);
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
        cashierName: printData['cashierName'],  // ✅ Parse dari socket data
      );

      printService.autoPrintOrder(tempOrder, isOpenBill: false).then((printed) {
        if (printed && mounted) {
          showPrintSuccessSnackbar(orderId);
        }
      }).catchError((e) {
        if (kDebugMode) print('❌ Immediate print error: $e');
      });
    } catch (e) {
      if (kDebugMode) print('❌ Error handling immediate print: $e');
    }
  }

  // ✅ UPDATED: Using new workstation endpoint
  void completeOrder(Order order) async {
    setState(() {
      preparing.remove(order);
      done.add(order);
    });

    if (order.orderId != null) {
      await OrderService.updateWorkstationOrderStatus(
        order.orderId!,
        'Completed',
        currentDevice,
      );
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

      await OrderService.updateWorkstationOrderStatus(
        orderId,
        'Completed',
        currentDevice,
      );
    }

    showBatchCompleteDialog(orderIds.length);
  }

  void addTimeToOrder(Order order, int minutes) {
    setState(() {
      // Use WIB time for adding minutes
      if (order.updatedAtWIB != null) {
        order.updatedAtWIB = order.updatedAtWIB!.add(Duration(minutes: minutes));
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
    print('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓');
    print('📊 DEBUG: Order ${order.orderId}');
    print('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
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
    // Implementation in widgets file
  }

  void showPrinterSettings() {
    showDialog(
      context: context,
      builder: (context) => PrinterSettingsDialog(
        printService: printService,
        autoPrintEnabled: autoPrintEnabled,
        onAutoPrintChanged: (value) {
          setState(() {
            autoPrintEnabled = value;
          });
        },
        brandColor: brandColor,
      ),
    );
  }

  void showPrintSuccessSnackbar(String orderId) {
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

  Widget buildOrdersList(List<Order> orders, bool showTimer, bool isFinished) {
    final filteredOrders = getFilteredOrders(orders);

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
            children: filteredOrders.asMap().entries.map((entry) {
              final index = entry.key;
              final order = entry.value;
              final isExpanded = expandedOrders[order.orderId] ?? false;

              return SizedBox(
                width: cardWidth,
                child: OrderCardCompact(
                  order: order,
                  isExpanded: isExpanded,
                  showTimer: showTimer,
                  isFinished: isFinished,
                  queueNumber: showTimer && !isFinished ? index + 1 : null,
                  onToggleExpand: () {
                    setState(() {
                      expandedOrders[order.orderId ?? ''] = !isExpanded;
                    });
                  },
                  onComplete: showTimer && !isFinished ? () => completeOrder(order) : null,
                  onAddTime: showTimer ? addTimeToOrder : null,
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
              );
            }).toList(),
          ),
        );
      },
    );
  }
}