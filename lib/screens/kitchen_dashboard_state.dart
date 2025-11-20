// screens/kitchen_dashboard_state.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/order.dart';
import '../models/out_of_stock_model.dart';
import '../models/stock_menu.dart';
import '../models/category_model.dart';
import '../services/notification_service.dart';
import '../services/thermal_print_service.dart';

/// Mixin untuk mengelola state KitchenDashboard
mixin KitchenDashboardState {
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

  // Getters
  String get workstation;
}