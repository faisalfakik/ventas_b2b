// lib/models/customer_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class Customer { // <-- Nombre de clase Customer
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
  final String? generalNotes;      // Notas generales del cliente (campo 'notes' en Firestore)
  final bool? isActive;

  // --- Campos NUEVOS para Dashboard ---
  final bool? isNewlyAssigned;
  final String? adminNote;
  final bool? acknowledgedByVendor;

  // --- Campos NUEVOS para búsqueda/optimización (Opcional) ---
  final String? businessNameLower;
  final String? nameLower;

  // --- Constructor ---
  Customer({ // <-- Constructor Customer
    required this.id,
    required this.name,
    required this.businessName,
    this.email, this.phone, this.address, this.rif, this.clientCategory,
    this.priceLevel, this.createdAt, this.updatedAt, this.assignedVendorId,
    this.location, this.lastActivityTimestamp, this.totalPurchases,
    this.status, this.generalNotes, this.isActive,
    this.isNewlyAssigned, this.adminNote, this.acknowledgedByVendor,
    this.businessNameLower, this.nameLower,
  });

  // --- Constructor desde Firestore ---
  factory Customer.fromFirestore(DocumentSnapshot doc) { // <-- Factory Customer
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? _toDateTime(dynamic value) => (value as Timestamp?)?.toDate();
    double? _toDouble(dynamic value) => (value as num?)?.toDouble();
    bool? _toBool(dynamic value) => value as bool?;

    return Customer( // <-- Retorna Customer
      id: doc.id,
      name: data['name'] ?? '',
      businessName: data['businessName'] ?? data['name'] ?? '',
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      address: data['address'] as String?,
      rif: data['rif'] as String?,
      clientCategory: data['clientCategory'] as String?,
      priceLevel: data['priceLevel'] as String?,
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
      assignedVendorId: data['assignedVendorId'] as String?,
      location: data['location'] as GeoPoint?,
      lastActivityTimestamp: _toDateTime(data['lastActivityTimestamp']),
      totalPurchases: _toDouble(data['totalPurchases']),
      status: data['status'] as String?,
      generalNotes: data['notes'] as String?,
      isActive: _toBool(data['isActive']),
      isNewlyAssigned: _toBool(data['isNewlyAssigned']),
      adminNote: data['adminNote'] as String?,
      acknowledgedByVendor: _toBool(data['acknowledgedByVendor']),
      businessNameLower: data['businessNameLower'] as String?,
      nameLower: data['nameLower'] as String?,
    );
  }

  // --- Convertir a Map para Firestore ---
  Map<String, dynamic> toMap() {
    return {
      'name': name, 'businessName': businessName, 'email': email, 'phone': phone,
      'address': address, 'rif': rif, 'clientCategory': clientCategory, 'priceLevel': priceLevel,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(), 'assignedVendorId': assignedVendorId, 'location': location,
      'lastActivityTimestamp': lastActivityTimestamp != null ? Timestamp.fromDate(lastActivityTimestamp!) : null,
      'totalPurchases': totalPurchases, 'status': status, 'notes': generalNotes,
      'isActive': isActive, 'isNewlyAssigned': isNewlyAssigned, 'adminNote': adminNote,
      'acknowledgedByVendor': acknowledgedByVendor,
      'businessNameLower': businessName.toLowerCase(), 'nameLower': name.toLowerCase(),
    }..removeWhere((key, value) => value == null);
  }

  // --- Método CopyWith Actualizado ---
  Customer copyWith({ // <-- Devuelve Customer
    String? id, String? name, String? businessName, ValueGetter<String?>? email, ValueGetter<String?>? phone,
    ValueGetter<String?>? address, ValueGetter<String?>? rif, ValueGetter<String?>? clientCategory, ValueGetter<String?>? priceLevel,
    ValueGetter<DateTime?>? createdAt, ValueGetter<DateTime?>? updatedAt, ValueGetter<String?>? assignedVendorId,
    ValueGetter<GeoPoint?>? location, ValueGetter<DateTime?>? lastActivityTimestamp, ValueGetter<double?>? totalPurchases,
    ValueGetter<String?>? status, ValueGetter<String?>? generalNotes, ValueGetter<bool?>? isActive,
    ValueGetter<bool?>? isNewlyAssigned, ValueGetter<String?>? adminNote, ValueGetter<bool?>? acknowledgedByVendor,
    ValueGetter<String?>? businessNameLower, ValueGetter<String?>? nameLower,
  }) {
    return Customer( // <-- Retorna Customer
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

  // --- Overrides Estándar ---
  @override String toString() => 'Customer(id: $id, businessName: $businessName)'; // <-- Referencia a Customer
  @override bool operator ==(Object other) => identical(this, other) || other is Customer && runtimeType == other.runtimeType && id == other.id; // <-- Referencia a Customer
  @override int get hashCode => id.hashCode;

} // Fin clase Customer

// --- Extensión (Opcional, puede ir en helpers.dart o aquí) ---
extension CustomerExtensionsHelper on Customer { // <-- Referencia a Customer
  // bool get isPendingAcknowledgement => (isNewlyAssigned ?? false) || !(acknowledgedByVendor ?? true); // Ya está como getter
}