import 'package:flutter/material.dart';

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
}