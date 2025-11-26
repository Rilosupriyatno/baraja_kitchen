// screens/kitchen_dashboard.dart (FIXED - Auto-Confirm & Print Logic)
import 'package:baraja_bar/widgets/unified_stock_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
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

class KitchenDashboard extends StatefulWidget {
  final String? barType; // 'depan', 'belakang', atau null untuk kitchen

  const KitchenDashboard({super.key, this.barType});

  @override
  State<KitchenDashboard> createState() => _KitchenDashboardState();
}

class _KitchenDashboardState extends State<KitchenDashboard> {
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

  late Timer _mainTimer;
  late Timer _refreshTimer;
  DateTime _currentTime = DateTime.now();

  final Map<String, bool> _alertPlayedMap = {};
  final NotificationService _notificationService = NotificationService();
  final ThermalPrintService _printService = ThermalPrintService();
  // final Set<String> _existingOrderIds = <String>{};
  final Set<String> _displayedItemIds = <String>{};
  final Map<String, bool> _expandedOrders = {};
  List<OutOfStockItem> _outOfStockItems = [];
  Timer? _stockCheckTimer;

  // Tentukan workstation berdasarkan barType
  String get workstation {
    // Hanya 'depan' dan 'belakang' yang bar, sisanya kitchen
    if (widget.barType == 'depan' || widget.barType == 'belakang') {
      return 'bar';
    } else {
      return 'kitchen';
    }
  }

  bool _autoPrintEnabled = true;

  @override
  void initState() {
    super.initState();

    _printService.setBarType(widget.barType);

    if (kDebugMode) {
      print('╔════════════════════════════════════╗');
      print('📍 Dashboard barType: ${widget.barType}');
      print('📍 Workstation: $workstation');
      print('╚════════════════════════════════════╝');
    }

    _initializePrinter();

    _loadOrders();
    _loadStockMenu();
    _loadCategories();
    _initializeTimers();
    _loadOutOfStockItems();

    _stockCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _loadOutOfStockItems();
    });

    const outletId = "outlet-1";

    SocketService.connect(
      outletId: outletId,
      barType: widget.barType,
      onNewOrder: (_) {
        _refreshOrders();
      },
      onBeverageOrder: (beverageData) {
        if (widget.barType != null) {
          _handleBeverageOrder(beverageData);
        }
      },
      onStockUpdate: (stockData) {
        if (kDebugMode) {
          print('📦 Stock updated received in dashboard: ${stockData['menuItemId']}');
        }
        _refreshOutOfStockAfterUpdate(stockData['menuItemId'] ?? '');
        _loadStockMenu();
      },
      // 🔥 NEW: Immediate print handler
      onImmediatePrint: (printData) {
        _handleImmediatePrint(printData);
      },
    );
  }

  Future<void> _initializePrinter() async {
    print('🔥 [INIT] Prewarming printer...');
    await _printService.prewarmConnection();
    print('✅ [INIT] Printer ready for immediate print');
  }
  void _handleImmediatePrint(Map<String, dynamic> printData) async {
    try {
      if (!_autoPrintEnabled || !_printService.isConfigured) {
        if (kDebugMode) {
          print('⚠️ Auto-print disabled or printer not configured');
        }
        return;
      }

      final orderId = printData['orderId'] as String?;
      if (orderId == null) {
        if (kDebugMode) {
          print('❌ No orderId in immediate print data');
        }
        return;
      }

      if (kDebugMode) {
        print('🔥 [IMMEDIATE PRINT] Received at: ${DateTime.now()}');
        print('   Order ID: $orderId');
      }

      // 🔊 Sound (parallel, non-blocking)
      _notificationService
          .playNewOrderNotification(orderId, soundPath: 'sounds/alert.mp3')
          .catchError((e) => false);

      // Convert to Order object
      final orderItems = (printData['orderItems'] as List<dynamic>?)
          ?.map((item) {
        return OrderItem(
          itemId: item['_id'] ?? '',
          menuItemId: item['menuItemId'],
          name: item['name'] ?? '',
          qty: item['quantity'] ?? 1,
          notes: item['notes'],
          addons: item['addons'],
          toppings: item['toppings'],
          workstation: item['workstation'] ?? 'kitchen',
          mainCategory: item['mainCategory'],
        );
      }).toList() ?? [];

      if (orderItems.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No items to print for $orderId');
        }
        return;
      }

      // Filter items for this workstation
      final workstationItems = orderItems.where((item) {
        if (widget.barType == 'depan' || widget.barType == 'belakang') {
          // Bar: only beverages
          final mainCat = (item.mainCategory ?? '').toLowerCase();
          final workstation = (item.workstation ?? '').toLowerCase();
          return mainCat.contains('beverage') ||
              mainCat.contains('minuman') ||
              workstation.contains('bar');
        } else {
          // Kitchen: non-beverages
          final mainCat = (item.mainCategory ?? '').toLowerCase();
          final workstation = (item.workstation ?? '').toLowerCase();
          return !mainCat.contains('beverage') &&
              !mainCat.contains('minuman') &&
              !workstation.contains('bar');
        }
      }).toList();

      if (workstationItems.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No items for this workstation in $orderId');
        }
        return;
      }

      // Track items immediately
      for (final item in workstationItems) {
        _displayedItemIds.add(item.itemId);
      }

      final tempOrder = Order(
        orderId: orderId,
        name: printData['name'] ?? 'Guest',
        table: printData['tableNumber'] ?? '',
        status: 'OnProcess', // Backend already confirmed
        items: workstationItems,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdAtWIB: DateTime.now(),
        updatedAtWIB: DateTime.now(),
        service: printData['service'] ?? 'Dine-In',
        orderType: printData['orderType'] ?? 'dine-in',
        source: printData['source'] ?? 'Cashier',
        paymentMethod: printData['paymentMethod'] ?? 'Cash',
      );

      // 🔥 INSTANT PRINT (fire and forget)
      if (kDebugMode) {
        print('🔥 [INSTANT] Printing ${workstationItems.length} items NOW');
      }

      _printService.autoPrintOrder(tempOrder, isOpenBill: false).then((printed) {
        if (printed && mounted) {
          _showPrintSuccessSnackbar(orderId);
        }
      }).catchError((e) {
        if (kDebugMode) print('❌ Immediate print error: $e');
      });

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error handling immediate print: $e');
      }
    }
  }

  Future<void> _loadOutOfStockItems() async {
    try {
      final items = await StockMenuService.getOutOfStockItems(workstation);
      if (mounted) {
        setState(() {
          _outOfStockItems = items;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading out of stock items: $e');
      }
    }
  }

  void _showOutOfStockDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => OutOfStockDialog(
        outOfStockItems: _outOfStockItems,
        workstation: workstation,
        brandColor: brandColor,
        onRefresh: () async {
          await _loadOutOfStockItems();

          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
            if (_outOfStockItems.isNotEmpty) {
              _showOutOfStockDialog();
            }
          }
        },
      ),
    );
  }

  Future<void> _refreshOutOfStockAfterUpdate(String menuItemId) async {
    try {
      final updatedItems = await StockMenuService.getOutOfStockItems(
        workstation,
      );

      if (mounted) {
        setState(() {
          _outOfStockItems = updatedItems;
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
        print('Error refreshing out of stock after update: $e');
      }
    }
  }

  void _handleBeverageOrder(Map<String, dynamic> beverageData) {
    print('🥤 Beverage order received: ${beverageData['orderId']}');

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
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error refreshing orders: $e');
      }
    }
  }
  // ✅ SOLUSI: Print SEBELUM API confirmation selesai
  // Future<void> _mergeOrdersWithAlertState(
  //     Map<String, List<Order>> ordersMap, {
  //       bool isInitialLoad = false,
  //     }) async {
  //   final newWaiting = ordersMap['waiting'] ?? [];
  //   final newPreparing = ordersMap['preparing'] ?? [];
  //   final newDone = ordersMap['completed'] ?? [];
  //   final newReservations = ordersMap['reservations'] ?? [];
  //
  //   // ✅ KUNCI: Collect orders yang perlu di-auto-confirm
  //   final ordersToConfirm = <Order>[];
  //   final confirmedOrders = <Order>[];
  //
  //   // Process waiting orders
  //   for (var order in newWaiting) {
  //     if (order.orderId != null) {
  //       ordersToConfirm.add(order);
  //     }
  //   }
  //
  //   // Process reservations yang sudah waktunya
  //   for (var order in newReservations) {
  //     if (order.orderId != null && OrderService.shouldMoveReservationToPreparation(order)) {
  //       ordersToConfirm.add(order);
  //     }
  //   }
  //
  //   // ✅ OPTIMASI 1: Update status PARALLEL (tidak blocking print)
  //   if (ordersToConfirm.isNotEmpty) {
  //     // Fire and forget - jangan await di sini
  //     _confirmOrdersInBackground(ordersToConfirm, confirmedOrders);
  //
  //     // Langsung masukkan ke preparing untuk print
  //     for (var order in ordersToConfirm) {
  //       order.status = 'OnProcess';
  //       confirmedOrders.add(order);
  //     }
  //   }
  //
  //   // Combine preparing orders
  //   final allPreparing = [...newPreparing, ...confirmedOrders];
  //
  //   // ✅ OPTIMASI 2: PRINT IMMEDIATELY (tidak tunggu API)
  //   if (!isInitialLoad) {
  //     _processPrintQueue(allPreparing); // Fire and forget
  //   } else {
  //     // Initial load: Track semua items yang sudah ada
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
  //   // Process new reservations (yang belum waktunya)
  //   for (var order in newReservations) {
  //     if (order.orderId != null &&
  //         !OrderService.shouldMoveReservationToPreparation(order)) {
  //
  //       // Track items dari reservasi
  //       for (final item in order.items) {
  //         if (!_displayedItemIds.contains(item.itemId)) {
  //           _displayedItemIds.add(item.itemId);
  //         }
  //       }
  //
  //       _notificationService
  //           .playNewOrderNotification(
  //         order.orderId!,
  //         soundPath: 'sounds/ding.mp3',
  //       )
  //           .catchError((e) => false);
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
      if (order.orderId != null) {
        ordersToConfirm.add(order);
      }
    }

    // Collect ready reservations
    for (var order in newReservations) {
      if (order.orderId != null && OrderService.shouldMoveReservationToPreparation(order)) {
        ordersToConfirm.add(order);
      }
    }

    // ✅ BATCH CONFIRM (non-blocking)
    if (ordersToConfirm.isNotEmpty) {
      _confirmOrdersInBackground(ordersToConfirm, confirmedOrders);

      // Langsung set status untuk display
      for (var order in ordersToConfirm) {
        order.status = 'OnProcess';
        confirmedOrders.add(order);
      }
    }

    final allPreparing = [...newPreparing, ...confirmedOrders];

    // ✅ PROCESS PRINT (non-blocking)
    if (!isInitialLoad) {
      _processPrintQueue(allPreparing);
    } else {
      // Track existing items
      for (var order in [...allPreparing, ...newDone, ...newReservations]) {
        for (final item in order.items) {
          _displayedItemIds.add(item.itemId);
        }
      }
    }

    // Process reservations
    for (var order in newReservations) {
      if (order.orderId != null &&
          !OrderService.shouldMoveReservationToPreparation(order)) {
        for (final item in order.items) {
          if (!_displayedItemIds.contains(item.itemId)) {
            _displayedItemIds.add(item.itemId);
          }
        }
        _notificationService
            .playNewOrderNotification(order.orderId!, soundPath: 'sounds/ding.mp3')
            .catchError((e) => false);
      }
    }

    // Initialize alert map
    for (var o in allPreparing) {
      _alertPlayedMap.putIfAbsent(o.orderId ?? "", () => false);
    }

    // Sort
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

// ✅ BATCH CONFIRM (parallel, non-blocking)
  Future<void> _confirmOrdersInBackground(
      List<Order> ordersToConfirm,
      List<Order> confirmedOrders,
      ) async {
    if (ordersToConfirm.length > 1) {
      final orderIds = ordersToConfirm.map((o) => o.orderId!).toList();
      try {
        print('🚀 Batch confirming ${orderIds.length} orders');
        await OrderService.batchAutoConfirmOrders(orderIds);
        print('✅ Batch confirm success');
      } catch (e) {
        print('❌ Batch confirm error: $e');
      }
    } else {
      for (var order in ordersToConfirm) {
        try {
          await OrderService.updateOrderStatus(order.orderId!, 'OnProcess');
        } catch (e) {
          print('❌ Confirm error: $e');
        }
      }
    }
  }

// ✅ PRINT QUEUE (fire and forget)
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
        print('🖨️ FAST PRINT: ${newItems.length} items from ${order.orderId}');

        _notificationService
            .playNewOrderNotification(order.orderId!, soundPath: 'sounds/alert.mp3')
            .catchError((e) => false);

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
        );

        // Fire and forget
        _printService
            .autoPrintOrder(tempOrder, isOpenBill: isOpenBill)
            .then((printed) {
          if (printed && mounted) {
            _showPrintSuccessSnackbar(order.orderId!);
          }
        })
            .catchError((e) => print('❌ Print error: $e'));
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

  void _debugPrintStatus(Order order) {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📊 DEBUG: Order ${order.orderId}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Total items: ${order.items.length}');
    print('Items:');
    for (final item in order.items) {
      final isPrinted = _printService.isItemAlreadyPrinted(item.itemId);
      print('  ${isPrinted ? "✅" : "❌"} ${item.name} (${item.itemId})');
    }
    print('Printed items count: ${_printService.getPrintedItemsCount(order.orderId!)}');
    print('Order already printed: ${_printService.isAlreadyPrinted(order.orderId)}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
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
            child: const Text(
              'OK',
              style: TextStyle(fontSize: 16, color: brandColor),
            ),
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
            child: const Text(
              'OK',
              style: TextStyle(fontSize: 16, color: brandColor),
            ),
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
        onAutoPrintChanged: (value) {
          setState(() {
            _autoPrintEnabled = value;
          });
        },
        brandColor: brandColor,
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

  void _navigateToCategories() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedStockScreen(workstation: workstation),
      ),
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
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
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

  List<Order> _getFilteredOrders(List<Order> orders) {
    if (search.isEmpty) return orders;

    return orders.where((order) {
      final nameMatch = order.name.toLowerCase().contains(search);
      final itemsMatch = order.items.any(
            (item) => item.name.toLowerCase().contains(search),
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
              search.isEmpty
                  ? 'Tidak ada pesanan'
                  : 'Tidak ada hasil pencarian',
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
              final isExpanded = _expandedOrders[order.orderId] ?? false;

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
                      _expandedOrders[order.orderId ?? ''] = !isExpanded;
                    });
                  },
                  onComplete: showTimer && !isFinished
                      ? () => _completeOrder(order)
                      : null,
                  onAddTime: showTimer ? _addTimeToOrder : null,
                  onReprint: () async {
                    print('Attempting to reprint order ${order.orderId}');
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
                              Text(
                                success
                                    ? 'Berhasil print ulang'
                                    : 'Gagal print, cek koneksi printer',
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
    return SingleChildScrollView(
      child: Container(
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
            _buildSidebarTab(5, 'Stok by Kategori', categories.length),
          ],
        ),
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
        if (index == 5) {
          _navigateToCategories();
        }
      },
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
        final toppingsKey =
            item.toppings?.map((t) => t['name']).join(',') ?? '';
        final notesKey = item.notes ?? '';

        final key = '${item.name}|$addonsKey|$toppingsKey|$notesKey';

        if (!grouped.containsKey(key)) {
          grouped[key] = [];
        }

        grouped[key]!.add(
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

    return Map.fromEntries(
      grouped.entries.where((entry) {
        final totalQty = entry.value.fold(
          0,
              (sum, item) => sum + item.quantity,
        );
        return totalQty >= 2;
      }),
    );
  }

  Widget _buildCategoriesPlaceholder() {
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
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        toolbarHeight: 70,
        backgroundColor: widget.barType == 'depan'
            ? Colors.blue[700]
            : widget.barType == 'belakang'
            ? Colors.orange[700]
            : brandColor,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                'assets/icons/logo.png',
                height: 32,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.restaurant,
                    color: Colors.white,
                    size: 32,
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.barType == 'depan'
                        ? 'Bar Depan'
                        : widget.barType == 'belakang'
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
                    widget.barType == 'depan'
                        ? 'Bar Depan'
                        : widget.barType == 'belakang'
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

            // Bar Type Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: widget.barType == 'depan'
                    ? Colors.blue[50]
                    : widget.barType == 'belakang'
                    ? Colors.orange[50]
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.barType == 'depan'
                      ? Colors.blue[300]!
                      : widget.barType == 'belakang'
                      ? Colors.orange[300]!
                      : brandColor,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.barType == 'depan'
                        ? Icons.local_bar
                        : widget.barType == 'belakang'
                        ? Icons.local_bar
                        : Icons.restaurant,
                    size: 14,
                    color: widget.barType == 'depan'
                        ? Colors.blue[700]
                        : widget.barType == 'belakang'
                        ? Colors.orange[700]
                        : brandColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.barType == 'depan'
                        ? 'Depan'
                        : widget.barType == 'belakang'
                        ? 'Belakang'
                        : 'Dapur',
                    style: TextStyle(
                      color: widget.barType == 'depan'
                          ? Colors.blue[900]
                          : widget.barType == 'belakang'
                          ? Colors.orange[900]
                          : brandColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Status koneksi printer
            if (_printService.isConfigured)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _printService.consecutiveFailures == 0
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _printService.consecutiveFailures == 0
                        ? Colors.green.shade300
                        : Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _printService.connectionType == PrinterConnectionType.wifi
                          ? Icons.wifi
                          : Icons.bluetooth,
                      size: 14,
                      color: _printService.consecutiveFailures == 0
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _printService.consecutiveFailures == 0
                          ? 'Tersambung'
                          : 'Periksa',
                      style: TextStyle(
                        color: _printService.consecutiveFailures == 0
                            ? Colors.green.shade900
                            : Colors.orange.shade900,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            if (_printService.isConfigured)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
                      _printService.connectionType == PrinterConnectionType.wifi
                          ? Icons.wifi
                          : Icons.bluetooth,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
                    const Icon(
                      Icons.notifications_active,
                      size: 16,
                      color: Colors.white,
                    ),
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

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(Icons.print, color: brandColor, size: 24),
                onPressed: _showPrinterSettings,
                tooltip: 'Pengaturan Printer',
              ),
            ),
            const SizedBox(width: 8),
            if (_outOfStockItems.isNotEmpty)
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.red.shade700,
                        size: 24,
                      ),
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
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        '${_outOfStockItems.length}',
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
              ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
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
                color: Colors.white,
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
                  TableStockmenu(
                    stockMenu: stockmenu,
                    onRefresh: _loadStockMenu,
                    brandColor: brandColor,
                  ),
                  _buildCategoriesPlaceholder(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Printer Settings Dialog dengan penyimpanan konfigurasi
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
        final Set<String> existingAddresses = _bluetoothDevices
            .map((d) => d.address)
            .toSet();
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
                final exists = _bluetoothDevices.any(
                      (d) => d.address == device.address,
                );
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
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green[700],
                        size: 20,
                      ),
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
                              style: TextStyle(
                                color: Colors.green[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              SegmentedButton<int>(
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
              ),
              const SizedBox(height: 20),
              if (_selectedConnectionType == 0) ...[
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
              if (_selectedConnectionType == 1) ...[
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                            : const Icon(Icons.bluetooth_searching),
                        label: Text(
                          _isScanning ? 'Mencari...' : 'Lihat Paired',
                        ),
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
                if (_bluetoothDevices.isNotEmpty) ...[
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
                        final isSelected =
                            _selectedDevice?.address == device.address;
                        return ListTile(
                          leading: Icon(
                            Icons.print_outlined,
                            color: isSelected
                                ? widget.brandColor
                                : Colors.grey[600],
                          ),
                          title: Text(
                            device.name?.isEmpty ?? true
                                ? 'Unknown Device'
                                : device.name!,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            device.address,
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: isSelected
                              ? Icon(
                            Icons.check_circle,
                            color: widget.brandColor,
                          )
                              : null,
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
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.bluetooth_disabled,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Belum ada perangkat',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pair printer di Settings > Bluetooth,\nlalu tekan "Lihat Paired"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_isScanning) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
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
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontSize: 12,
                            ),
                          ),
                        ),
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
                        Text(
                          'Auto Print',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
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
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _showClearConfigDialog();
          },
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
}