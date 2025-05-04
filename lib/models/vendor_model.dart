// lib/models/vendor_model.dart
// Este archivo contiene TODAS las definiciones de modelos principales.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Para ValueGetter y debugPrint

// ================================================================
// MODELO CLIENTE (Renombrado de Customer para coincidir con tu servicio)
// ================================================================
class Client {
  final String id;
  final String name;              // Nombre de Contacto
  final String businessName;      // Razón Social / Nombre Comercial
  final String? email;
  final String? phone;
  final String? address;
  final String? rif;               // RIF
  final String? clientCategory;    // Categoría
  final String? priceLevel;        // Nivel de Precios
  final DateTime? createdAt;       // Fecha Creación
  final DateTime? updatedAt;       // Fecha Última Actualización
  final String? assignedVendorId;  // ID Vendedor Asignado (String único)
  final GeoPoint? location;        // Ubicación GeoPoint
  final DateTime? lastActivityTimestamp; // Fecha última actividad
  final double? totalPurchases;    // Compras totales
  final String? status;            // Estado (Activo, Inactivo, etc.)
  final String? generalNotes;      // Notas generales del cliente
  final bool? isActive;            // Estado activo (añadido porque lo usas en el constructor)

  // --- Campos NUEVOS para Dashboard ---
  final bool? isNewlyAssigned;     // ¿Nuevo asignado por admin?
  final String? adminNote;         // Nota del admin al asignar
  final bool? acknowledgedByVendor;// ¿Vendedor ya lo vio?

  // --- Campos NUEVOS para búsqueda/optimización (Opcional) ---
  final String? businessNameLower;
  final String? nameLower;

  Client({
    required this.id,
    required this.name,
    required this.businessName,
    this.email, this.phone, this.address, this.rif, this.clientCategory,
    this.priceLevel, this.createdAt, this.updatedAt, this.assignedVendorId,
    this.location, this.lastActivityTimestamp, this.totalPurchases,
    this.status, this.generalNotes, this.isActive = true, // Mantener isActive si lo usas
    this.isNewlyAssigned, this.adminNote, this.acknowledgedByVendor,
    this.businessNameLower, this.nameLower,
  });

  // --- Constructor desde Firestore ---
  factory Client.fromFirestore(doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? _toDateTime(dynamic value) => (value as Timestamp?)?.toDate();
    double? _toDouble(dynamic value) => (value as num?)?.toDouble();

    return Client(
      id: doc.id,
      name: data['name'] ?? '', // Asegúrate que 'name' exista en Firestore
      businessName: data['businessName'] ?? data['name'] ?? '', // 'businessName' o fallback
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      address: data['address'] as String?,
      rif: data['rif'] as String?,               // Lee 'rif'
      clientCategory: data['clientCategory'] as String?, // Lee 'clientCategory'
      priceLevel: data['priceLevel'] as String?,
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
      assignedVendorId: data['assignedVendorId'] as String?, // Lee 'assignedVendorId'
      location: data['location'] as GeoPoint?,
      lastActivityTimestamp: _toDateTime(data['lastActivityTimestamp']),
      totalPurchases: _toDouble(data['totalPurchases']),
      status: data['status'] as String?,
      generalNotes: data['notes'] as String?, // Lee 'notes' como notas generales
      isActive: data['isActive'] as bool? ?? true, // Default a true si es null
      isNewlyAssigned: data['isNewlyAssigned'] as bool?,
      adminNote: data['adminNote'] as String?,
      acknowledgedByVendor: data['acknowledgedByVendor'] as bool?,
      businessNameLower: data['businessNameLower'] as String?,
      nameLower: data['nameLower'] as String?,
    );
  }

  // --- Convertir a Map para Firestore ---
  Map<String, dynamic> toMap() {
    // Prepara los campos en minúscula ANTES de crear el mapa final
    final String effectiveBusinessNameLower = businessName.toLowerCase();
    final String effectiveNameLower = name.toLowerCase();

    return {
      'name': name, 'businessName': businessName, 'email': email, 'phone': phone,
      'address': address, 'rif': rif, 'clientCategory': clientCategory, 'priceLevel': priceLevel,
      // Guarda Timestamps (si la fecha no es null)
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': FieldValue.serverTimestamp(), // Siempre actualizar timestamp de modificación
      'assignedVendorId': assignedVendorId, 'location': location,
      'lastActivityTimestamp': lastActivityTimestamp != null ? Timestamp.fromDate(lastActivityTimestamp!) : null,
      'totalPurchases': totalPurchases, 'status': status, 'notes': generalNotes,
      'isActive': isActive, 'isNewlyAssigned': isNewlyAssigned, 'adminNote': adminNote,
      'acknowledgedByVendor': acknowledgedByVendor,
      // Guarda campos en minúscula si los manejas desde la app
      'businessNameLower': effectiveBusinessNameLower,
      'nameLower': effectiveNameLower,
    }..removeWhere((key, value) => value == null); // Buena práctica: elimina nulos antes de guardar
  }

  // --- Método CopyWith Actualizado ---
  Client copyWith({
    String? id, String? name, String? businessName, ValueGetter<String?>? email, ValueGetter<String?>? phone,
    ValueGetter<String?>? address, ValueGetter<String?>? rif, ValueGetter<String?>? clientCategory, ValueGetter<String?>? priceLevel,
    ValueGetter<DateTime?>? createdAt, ValueGetter<DateTime?>? updatedAt, ValueGetter<String?>? assignedVendorId,
    ValueGetter<GeoPoint?>? location, ValueGetter<DateTime?>? lastActivityTimestamp, ValueGetter<double?>? totalPurchases,
    ValueGetter<String?>? status, ValueGetter<String?>? generalNotes, ValueGetter<bool?>? isActive,
    ValueGetter<bool?>? isNewlyAssigned, ValueGetter<String?>? adminNote, ValueGetter<bool?>? acknowledgedByVendor,
    ValueGetter<String?>? businessNameLower, ValueGetter<String?>? nameLower,
  }) {
    return Client(
      id: id ?? this.id, name: name ?? this.name, businessName: businessName ?? this.businessName,
      email: email != null ? email() : this.email, phone: phone != null ? phone() : this.phone,
      address: address != null ? address() : this.address, rif: rif != null ? rif() : this.rif,
      clientCategory: clientCategory != null ? clientCategory() : this.clientCategory,
      priceLevel: priceLevel != null ? priceLevel() : this.priceLevel,
      createdAt: createdAt != null ? createdAt() : this.createdAt, updatedAt: updatedAt != null ? updatedAt() : this.updatedAt,
      assignedVendorId: assignedVendorId != null ? assignedVendorId() : this.assignedVendorId,
      location: location != null ? location() : this.location,
      lastActivityTimestamp: lastActivityTimestamp != null ? lastActivityTimestamp() : this.lastActivityTimestamp,
      totalPurchases: totalPurchases != null ? totalPurchases() : this.totalPurchases,
      status: status != null ? status() : this.status, generalNotes: generalNotes != null ? generalNotes() : this.generalNotes,
      isActive: isActive != null ? isActive() : this.isActive,
      isNewlyAssigned: isNewlyAssigned != null ? isNewlyAssigned() : this.isNewlyAssigned,
      adminNote: adminNote != null ? adminNote() : this.adminNote,
      acknowledgedByVendor: acknowledgedByVendor != null ? acknowledgedByVendor() : this.acknowledgedByVendor,
      businessNameLower: businessNameLower != null ? businessNameLower() : this.businessNameLower,
      nameLower: nameLower != null ? nameLower() : this.nameLower,
    );
  }

  // --- Getters y Métodos de Utilidad ---
  bool get hasValidCoordinates => location != null;
  bool get isActiveClient => isActive ?? true;
  String get displayName => businessName.isNotEmpty ? businessName : name;
  bool get isPendingAcknowledgement => (isNewlyAssigned ?? false) || !(acknowledgedByVendor ?? true);
}

// ================================================================
// MODELO VENDEDOR
// ================================================================
class Vendor {
  final String id; // UID de Firebase Auth
  final String name;
  final String email;
  final String? phone;
  final List<String> assignedZones;
  // final List<String> assignedCustomerIds; // Eliminado: Mejor consultar Clientes por assignedVendorId
  final String? fcmToken; // Para notificaciones push
  final String? role; // Ej: 'vendor', 'admin'

  Vendor({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.assignedZones = const [],
    // this.assignedCustomerIds = const [], // Eliminado
    this.fcmToken,
    this.role,
  });

  factory Vendor.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return Vendor(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] as String?,
      assignedZones: List<String>.from(data['assignedZones'] ?? []),
      // assignedCustomerIds: List<String>.from(data['assignedCustomerIds'] ?? []), // Eliminado
      fcmToken: data['fcmToken'] as String?,
      role: data['role'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'assignedZones': assignedZones,
      'fcmToken': fcmToken,
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(), // Añadir timestamp de actualización
    }..removeWhere((key, value) => value == null);
  }

  Vendor copyWith({
    String? id, String? name, String? email, ValueGetter<String?>? phone,
    List<String>? assignedZones, ValueGetter<String?>? fcmToken, ValueGetter<String?>? role,
  }) {
    return Vendor(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone != null ? phone() : this.phone,
      assignedZones: assignedZones ?? this.assignedZones,
      fcmToken: fcmToken != null ? fcmToken() : this.fcmToken,
      role: role != null ? role() : this.role,
    );
  }
}