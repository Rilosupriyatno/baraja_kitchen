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
  });

  factory Device.fromJson(Map<String, dynamic> json) {
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
    );
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