import 'package:cloud_firestore/cloud_firestore.dart';
import 'quote_item.dart'; // Cambiar nombre si es necesario

class Quote {
  final String id;
  final String clientId;
  final String vendorId;
  final List<QuoteItem> items;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String status; // 'pending', 'approved', 'rejected', 'expired'
  final String? notes;

  Quote({
    required this.id,
    required this.clientId,
    required this.vendorId,
    required this.items,
    required this.createdAt,
    this.expiresAt,
    this.status = 'pending',
    this.notes,
  });

  // Calcular el total de la cotización
  double calculateTotal() {
    double total = 0;
    for (var item in items) {
      double itemTotal = item.price * item.quantity;
      double discountAmount = itemTotal * (item.discount / 100);
      total += itemTotal - discountAmount;
    }
    return total;
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'vendorId': vendorId,
      'items': items.map((item) => {
        'productId': item.product.id,
        'quantity': item.quantity,
        'price': item.price,
        'discount': item.discount,
      }).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'status': status,
      'notes': notes,
    };
  }

  // Crear desde Map de Firestore
  factory Quote.fromMap(Map<String, dynamic> map, String documentId, List<QuoteItem> items) {
    return Quote(
      id: documentId,
      clientId: map['clientId'] ?? '',
      vendorId: map['vendorId'] ?? '',
      items: items,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      expiresAt: map['expiresAt'] != null
          ? (map['expiresAt'] as Timestamp).toDate()
          : null,
      status: map['status'] ?? 'pending',
      notes: map['notes'],
    );
  }
}