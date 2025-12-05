import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ NEW: Workstation Type Enum
enum WorkstationType {
  kitchen,
  bar,
  general;

  String get displayName {
    switch (this) {
      case WorkstationType.kitchen:
        return 'KITCHEN';
      case WorkstationType.bar:
        return 'BAR';
      case WorkstationType.general:
        return 'GENERAL';
    }
  }

  String get apiKey {
    switch (this) {
      case WorkstationType.kitchen:
        return 'kitchen';
      case WorkstationType.bar:
        return 'bar';
      case WorkstationType.general:
        return 'general';
    }
  }

  Color getDefaultColor() {
    switch (this) {
      case WorkstationType.kitchen:
        return const Color(0xFF077A4B); // Green
      case WorkstationType.bar:
        return const Color(0xFF1976D2); // Blue
      case WorkstationType.general:
        return const Color(0xFF757575); // Grey
    }
  }
}

class Device {
  final String id;
  final Outlet outlet;
  final String deviceId;
  final String deviceName;
  final String deviceType;
  final String location;
  final List<String> assignedAreas;
  final List<String> assignedTables;
  final List<String> orderTypes;
  final bool isActive;
  final bool isOnline;
  final String? socketId;
  final DateTime? lastMaintenance;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int v;

  // ✅ NEW: Optional properties for better scalability
  final WorkstationType? workstationType;
  final String? themeColor;
  final String? displayName;
  final bool? handlesBeverages;
  final bool? handlesKitchen;
  final bool? handlesFood;

  Device({
    required this.id,
    required this.outlet,
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.location,
    required this.assignedAreas,
    required this.assignedTables,
    required this.orderTypes,
    required this.isActive,
    required this.isOnline,
    this.socketId,
    this.lastMaintenance,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.v,
    this.workstationType,
    this.themeColor,
    this.displayName,
    this.handlesBeverages,
    this.handlesKitchen,
    this.handlesFood,
  });

  // ✅ IMPROVED: Get unique device identifier
  String get uniqueIdentifier => '$deviceId|${outlet.id}|$deviceName';

  // ✅ IMPROVED: Get workstation name with fallback
  String get workstationName => displayName ?? deviceName.toUpperCase();

  // ✅ IMPROVED: Get workstation key for API calls
  String get workstationKey => (displayName ?? deviceName)
      .toLowerCase()
      .replaceAll(' ', '_')
      .replaceAll('-', '_');

  // ✅ IMPROVED: Get workstation type with smart fallback
  WorkstationType get effectiveWorkstationType {
    // Priority 1: Use explicit workstationType if provided
    if (workstationType != null) {
      return workstationType!;
    }

    // Priority 2: Use explicit flags
    if (handlesBeverages == true) {
      return WorkstationType.bar;
    }
    if (handlesKitchen == true || handlesFood == true) {
      return WorkstationType.kitchen;
    }

    // Priority 3: Infer from deviceName (backward compatibility)
    final nameLower = deviceName.toLowerCase();
    if (nameLower.contains('bar') || nameLower.contains('beverage')) {
      return WorkstationType.bar;
    }
    if (nameLower.contains('kitchen') || nameLower.contains('dapur')) {
      return WorkstationType.kitchen;
    }

    // Priority 4: Infer from location (last resort)
    final locationLower = location.toLowerCase();
    if (locationLower.contains('bar') || locationLower.contains('depan') || locationLower.contains('belakang')) {
      return WorkstationType.bar;
    }
    if (locationLower.contains('kitchen') || locationLower.contains('dapur')) {
      return WorkstationType.kitchen;
    }

    // Default to general
    return WorkstationType.general;
  }

  // ✅ IMPROVED: Get workstation type string for API
  String get workstationTypeString => effectiveWorkstationType.apiKey;

  // ✅ IMPROVED: Check if handles beverages with fallback
  bool get shouldHandleBeverages {
    if (handlesBeverages != null) return handlesBeverages!;
    return effectiveWorkstationType == WorkstationType.bar;
  }

  // ✅ IMPROVED: Check if handles kitchen items with fallback
  bool get shouldHandleKitchen {
    if (handlesKitchen != null) return handlesKitchen!;
    if (handlesFood != null) return handlesFood!;
    return effectiveWorkstationType == WorkstationType.kitchen;
  }

  // ✅ NEW: Get theme color with fallback
  Color get effectiveThemeColor {
    if (themeColor != null && themeColor!.isNotEmpty) {
      try {
        // Support hex colors like "#077A4B" or "077A4B"
        final hexColor = themeColor!.replaceAll('#', '');
        return Color(int.parse('FF$hexColor', radix: 16));
      } catch (e) {
        // If parsing fails, use default
      }
    }

    // Fallback to location-based colors for bar (backward compatibility)
    if (shouldHandleBeverages) {
      if (location.toLowerCase() == 'depan') {
        return const Color(0xFF1976D2); // Blue for front bar
      } else if (location.toLowerCase() == 'belakang') {
        return const Color(0xFFF57C00); // Orange for back bar
      }
      return const Color(0xFF1976D2); // Default blue for bar
    }

    // Use workstation type default color
    return effectiveWorkstationType.getDefaultColor();
  }

  // ✅ NEW: Get bar type for print service (backward compatibility)
  String? get barTypeForPrint {
    if (shouldHandleBeverages) {
      return location; // Return location string for bar
    }
    return null;
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    WorkstationType? parsedWorkstationType;
    if (json['workstationType'] != null) {
      try {
        parsedWorkstationType = WorkstationType.values.firstWhere(
              (e) => e.apiKey == json['workstationType'],
        );
      } catch (e) {
        // If parsing fails, leave as null (will use fallback)
      }
    }

    return Device(
      id: json['_id'] as String,
      outlet: Outlet.fromJson(json['outlet'] as Map<String, dynamic>),
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      deviceType: json['deviceType'] as String,
      location: json['location'] as String,
      assignedAreas: List<String>.from(json['assignedAreas'] as List),
      assignedTables: List<String>.from(json['assignedTables'] as List),
      orderTypes: List<String>.from(json['orderTypes'] as List),
      isActive: json['isActive'] as bool,
      isOnline: json['isOnline'] as bool,
      socketId: json['socketId'] as String?,
      lastMaintenance: json['lastMaintenance'] != null
          ? DateTime.parse(json['lastMaintenance'] as String)
          : null,
      notes: json['notes'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      v: json['__v'] as int,
      // ✅ NEW: Parse optional properties
      workstationType: parsedWorkstationType,
      themeColor: json['themeColor'] as String?,
      displayName: json['displayName'] as String?,
      handlesBeverages: json['handlesBeverages'] as bool?,
      handlesKitchen: json['handlesKitchen'] as bool?,
      handlesFood: json['handlesFood'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'outlet': outlet.toJson(),
      'deviceId': deviceId,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'location': location,
      'assignedAreas': assignedAreas,
      'assignedTables': assignedTables,
      'orderTypes': orderTypes,
      'isActive': isActive,
      'isOnline': isOnline,
      'socketId': socketId,
      'lastMaintenance': lastMaintenance?.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      '__v': v,
      // ✅ NEW: Include optional properties
      if (workstationType != null)
        'workstationType': workstationType!.apiKey,
      if (themeColor != null) 'themeColor': themeColor,
      if (displayName != null) 'displayName': displayName,
      if (handlesBeverages != null) 'handlesBeverages': handlesBeverages,
      if (handlesKitchen != null) 'handlesKitchen': handlesKitchen,
      if (handlesFood != null) 'handlesFood': handlesFood,
    };
  }

  Device copyWith({
    String? id,
    Outlet? outlet,
    String? deviceId,
    String? deviceName,
    String? deviceType,
    String? location,
    List<String>? assignedAreas,
    List<String>? assignedTables,
    List<String>? orderTypes,
    bool? isActive,
    bool? isOnline,
    String? socketId,
    DateTime? lastMaintenance,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? v,
    WorkstationType? workstationType,
    String? themeColor,
    String? displayName,
    bool? handlesBeverages,
    bool? handlesKitchen,
    bool? handlesFood,
  }) {
    return Device(
      id: id ?? this.id,
      outlet: outlet ?? this.outlet,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceType: deviceType ?? this.deviceType,
      location: location ?? this.location,
      assignedAreas: assignedAreas ?? this.assignedAreas,
      assignedTables: assignedTables ?? this.assignedTables,
      orderTypes: orderTypes ?? this.orderTypes,
      isActive: isActive ?? this.isActive,
      isOnline: isOnline ?? this.isOnline,
      socketId: socketId ?? this.socketId,
      lastMaintenance: lastMaintenance ?? this.lastMaintenance,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      v: v ?? this.v,
      workstationType: workstationType ?? this.workstationType,
      themeColor: themeColor ?? this.themeColor,
      displayName: displayName ?? this.displayName,
      handlesBeverages: handlesBeverages ?? this.handlesBeverages,
      handlesKitchen: handlesKitchen ?? this.handlesKitchen,
      handlesFood: handlesFood ?? this.handlesFood,
    );
  }

  // Local Storage Methods
  static const String _storageKey = 'selected_device';

  Future<bool> saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceJson = toJson();
      await prefs.setString(_storageKey, jsonEncode(deviceJson));

      // Save quick access data
      await prefs.setString('device_id', deviceId);
      await prefs.setString('device_name', deviceName);
      await prefs.setString('outlet_id', outlet.id);
      await prefs.setString('outlet_name', outlet.name);

      print('✅ Device saved: $deviceName ($deviceId) at ${outlet.name}');
      return true;
    } catch (e) {
      print('❌ Error saving device: $e');
      return false;
    }
  }

  static Future<bool> clearFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      await prefs.remove('device_id');
      await prefs.remove('device_name');
      await prefs.remove('outlet_id');
      await prefs.remove('outlet_name');

      print('✅ Device cleared from local storage');
      return true;
    } catch (e) {
      print('❌ Error clearing device: $e');
      return false;
    }
  }

  static Future<bool> hasStoredDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey('device_id');
    } catch (e) {
      print('❌ Error checking stored device: $e');
      return false;
    }
  }

  static Future<Device?> getStoredDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceJson = prefs.getString(_storageKey);

      if (deviceJson != null) {
        return Device.fromJson(jsonDecode(deviceJson));
      }
      return null;
    } catch (e) {
      print('❌ Error getting stored device: $e');
      return null;
    }
  }

  static Future<Map<String, String>?> getStoredDeviceInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');
      final deviceName = prefs.getString('device_name');
      final outletId = prefs.getString('outlet_id');
      final outletName = prefs.getString('outlet_name');

      if (deviceId != null && deviceName != null) {
        return {
          'deviceId': deviceId,
          'deviceName': deviceName,
          'outletId': outletId ?? '',
          'outletName': outletName ?? '',
        };
      }
      return null;
    } catch (e) {
      print('❌ Error getting stored device info: $e');
      return null;
    }
  }
}

class Outlet {
  final String id;
  final String name;

  Outlet({
    required this.id,
    required this.name,
  });

  factory Outlet.fromJson(Map<String, dynamic> json) {
    return Outlet(
      id: json['_id'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
    };
  }

  Outlet copyWith({
    String? id,
    String? name,
  }) {
    return Outlet(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}