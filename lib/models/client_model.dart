import 'package:cloud_firestore/cloud_firestore.dart';

class Client {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String businessName;
  final String? clientType;
  final String? priceLevel;
  final DateTime? createdAt;
  final String? fcmToken;
  final String? assignedVendorId;
  final double? latitude;
  final double? longitude;
  final DateTime? lastPurchaseDate;
  final double? totalPurchases;
  final String? status;
  final String? notes;
  final String? taxId;
  final bool? isActive;

  Client({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    this.businessName = '',
    this.clientType,
    this.priceLevel,
    this.createdAt,
    this.fcmToken,
    this.assignedVendorId,
    this.latitude,
    this.longitude,
    this.lastPurchaseDate,
    this.totalPurchases,
    this.status,
    this.notes,
    this.taxId,
    this.isActive = true,
  });

  // Crear una copia del cliente con posibles campos actualizados
  Client copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? businessName,
    String? clientType,
    String? priceLevel,
    DateTime? createdAt,
    String? fcmToken,
    String? assignedVendorId,
    double? latitude,
    double? longitude,
    DateTime? lastPurchaseDate,
    double? totalPurchases,
    String? status,
    String? notes,
    String? taxId,
    bool? isActive,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      businessName: businessName ?? this.businessName,
      clientType: clientType ?? this.clientType,
      priceLevel: priceLevel ?? this.priceLevel,
      createdAt: createdAt ?? this.createdAt,
      fcmToken: fcmToken ?? this.fcmToken,
      assignedVendorId: assignedVendorId ?? this.assignedVendorId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      taxId: taxId ?? this.taxId,
      isActive: isActive ?? this.isActive,
    );
  }

  // Constructor desde Firestore
  factory Client.fromMap(Map<String, dynamic> map, String documentId) {
    return Client(
      id: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      businessName: map['businessName'] ?? '',
      clientType: map['clientType'],
      priceLevel: map['priceLevel'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.parse(map['createdAt']))
          : null,
      fcmToken: map['fcmToken'],
      assignedVendorId: map['assignedVendorId'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      lastPurchaseDate: map['lastPurchaseDate'] != null
          ? (map['lastPurchaseDate'] is Timestamp
          ? (map['lastPurchaseDate'] as Timestamp).toDate()
          : DateTime.parse(map['lastPurchaseDate']))
          : null,
      totalPurchases: map['totalPurchases']?.toDouble(),
      status: map['status'],
      notes: map['notes'],
      taxId: map['taxId'],
      isActive: map['isActive'] ?? true,
    );
  }

  // Constructor desde JSON (para APIs)
  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      businessName: json['businessName'] ?? '',
      clientType: json['clientType'],
      priceLevel: json['priceLevel'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      fcmToken: json['fcmToken'],
      assignedVendorId: json['assignedVendorId'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      lastPurchaseDate: json['lastPurchaseDate'] != null ? DateTime.parse(json['lastPurchaseDate']) : null,
      totalPurchases: json['totalPurchases']?.toDouble(),
      status: json['status'],
      notes: json['notes'],
      taxId: json['taxId'],
      isActive: json['isActive'] ?? true,
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'businessName': businessName,
      'clientType': clientType,
      'priceLevel': priceLevel,
      'createdAt': createdAt,
      'fcmToken': fcmToken,
      'assignedVendorId': assignedVendorId,
      'latitude': latitude,
      'longitude': longitude,
      'lastPurchaseDate': lastPurchaseDate,
      'totalPurchases': totalPurchases,
      'status': status,
      'notes': notes,
      'taxId': taxId,
      'isActive': isActive,
    };
  }

  // Convertir a JSON para APIs
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'businessName': businessName,
      'clientType': clientType,
      'priceLevel': priceLevel,
      'createdAt': createdAt?.toIso8601String(),
      'fcmToken': fcmToken,
      'assignedVendorId': assignedVendorId,
      'latitude': latitude,
      'longitude': longitude,
      'lastPurchaseDate': lastPurchaseDate?.toIso8601String(),
      'totalPurchases': totalPurchases,
      'status': status,
      'notes': notes,
      'taxId': taxId,
      'isActive': isActive,
    };
  }

  // Métodos de utilidad

  // Verificar si el cliente tiene coordenadas válidas
  bool hasValidCoordinates() {
    return latitude != null && longitude != null &&
        latitude! > -90 && latitude! < 90 &&
        longitude! > -180 && longitude! < 180;
  }

  // Verificar si el cliente está activo
  bool get isActiveClient => isActive ?? true;

  // Obtener nombre de visualización (prefiere businessName si está disponible)
  String get displayName => businessName.isNotEmpty ? businessName : name;

  // Obtener estado formateado
  String get formattedStatus {
    if (status == null) return 'Activo';

    switch (status!.toLowerCase()) {
      case 'active':
        return 'Activo';
      case 'inactive':
        return 'Inactivo';
      case 'lead':
        return 'Potencial';
      case 'suspended':
        return 'Suspendido';
      default:
        return status!;
    }
  }

  // Tiempo desde la última compra
  String get timeSinceLastPurchase {
    if (lastPurchaseDate == null) return 'Sin compras';

    final difference = DateTime.now().difference(lastPurchaseDate!);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'año' : 'años'}';
    } else if (difference.inDays >= 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'mes' : 'meses'}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'día' : 'días'}';
    } else {
      return 'Hoy';
    }
  }

  @override
  String toString() => 'Client(id: $id, name: $name, businessName: $businessName)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Client && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}