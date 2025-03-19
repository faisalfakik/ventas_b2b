import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SpecialPrice {
  final String id;
  final String productId;
  final String? clientId; // Null si es un descuento general
  final double price;
  final double? discountPercentage;
  final int? minQuantity; // Para descuentos por volumen
  final DateTime? startDate; // Para promociones temporales
  final DateTime? endDate;   // Para promociones temporales
  final String? notes;

  SpecialPrice({
    required this.id,
    required this.productId,
    this.clientId,
    required this.price,
    this.discountPercentage,
    this.minQuantity,
    this.startDate,
    this.endDate,
    this.notes,
  });

  // Constructor para crear una copia con cambios
  SpecialPrice copyWith({
    String? id,
    String? productId,
    String? clientId,
    double? price,
    double? discountPercentage,
    int? minQuantity,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
  }) {
    return SpecialPrice(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      clientId: clientId ?? this.clientId,
      price: price ?? this.price,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      minQuantity: minQuantity ?? this.minQuantity,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
    );
  }

  // Verifica si el precio especial está activo actualmente
  bool isActive() {
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) {
      return false;
    }
    if (endDate != null && now.isAfter(endDate!)) {
      return false;
    }
    return true;
  }

  // Verifica si aplica para una cantidad específica
  bool appliesForQuantity(int quantity) {
    if (minQuantity == null) {
      return true;
    }
    return quantity >= minQuantity!;
  }

  // Convertir a un Map para guardar en Firestore
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'clientId': clientId,
      'price': price,
      'discountPercentage': discountPercentage,
      'minQuantity': minQuantity,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Crear un SpecialPrice desde un Map de Firestore
  static SpecialPrice fromMap(Map<String, dynamic> map, String documentId) {
    return SpecialPrice(
      id: documentId,
      productId: map['productId'] ?? '',
      clientId: map['clientId'],
      price: (map['price'] ?? 0.0).toDouble(),
      discountPercentage: map['discountPercentage'] != null
          ? (map['discountPercentage'] as num).toDouble()
          : null,
      minQuantity: map['minQuantity'],
      startDate: map['startDate'] != null
          ? (map['startDate'] as Timestamp).toDate()
          : null,
      endDate: map['endDate'] != null
          ? (map['endDate'] as Timestamp).toDate()
          : null,
      notes: map['notes'],
    );
  }

  // Método para verificar si este precio es mejor que otro
  bool isBetterThan(SpecialPrice other) {
    return this.price < other.price;
  }

  @override
  String toString() {
    return 'SpecialPrice(id: $id, productId: $productId, clientId: $clientId, price: $price)';
  }
}