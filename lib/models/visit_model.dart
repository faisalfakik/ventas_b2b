// lib/models/visit_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class Visit {
  final String id;
  final String customerId;
  final String vendorId;
  final DateTime date;
  final String notes;
  final String status; // 'Programada', 'Completada', 'Cancelada', 'Alerta Pendiente'
  final bool? isAdminAlert;
  final bool? isAlertActive;
  final GeoPoint? location;
  final DateTime? createdAt;

  //test
  Visit({
    required this.id, required this.customerId, required this.vendorId, required this.date,
    required this.notes, required this.status, this.isAdminAlert, this.isAlertActive,
    this.location, this.createdAt,
  });

  factory Visit.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? _toDateTime(dynamic value) => (value as Timestamp?)?.toDate();

    return Visit(
      id: doc.id, customerId: data['customerId'] ?? '', vendorId: data['vendorId'] ?? '',
      date: _toDateTime(data['date']) ?? DateTime.now(), notes: data['notes'] ?? '',
      status: data['status'] ?? 'Programada', isAdminAlert: data['isAdminAlert'] as bool?,
      isAlertActive: data['isAlertActive'] as bool?, location: data['location'] as GeoPoint?,
      createdAt: _toDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId, 'vendorId': vendorId, 'date': Timestamp.fromDate(date),
      'notes': notes, 'status': status, 'isAdminAlert': isAdminAlert, 'isAlertActive': isAlertActive,
      'location': location,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    }..removeWhere((key, value) => value == null);
  }

  Visit copyWith({
    String? id, String? customerId, String? vendorId, DateTime? date, String? notes,
    String? status, bool? isAdminAlert, bool? isAlertActive, GeoPoint? location, DateTime? createdAt,
  }) {
    return Visit(
      id: id ?? this.id, customerId: customerId ?? this.customerId, vendorId: vendorId ?? this.vendorId,
      date: date ?? this.date, notes: notes ?? this.notes, status: status ?? this.status,
      isAdminAlert: isAdminAlert ?? this.isAdminAlert, isAlertActive: isAlertActive ?? this.isAlertActive,
      location: location ?? this.location, createdAt: createdAt ?? this.createdAt,
    );
  }

  DateTime? get scheduledDate => date;
}

extension VisitExtensionsHelper on Visit {
  bool get isAlertActiveReal => (isAdminAlert ?? false) && (isAlertActive ?? true);
}