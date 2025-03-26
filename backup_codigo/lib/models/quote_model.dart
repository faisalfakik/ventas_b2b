import 'package:cloud_firestore/cloud_firestore.dart';
import 'quote_item.dart';
import '../models/product_model.dart'; // Añadido para resolver Product
import '../services/product_service.dart'; // Añadido para resolver ProductService

class Quote {
  final String id;
  final String clientId;
  final String vendorId;
  final List<QuoteItem> items;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String status; // 'pending', 'approved', 'rejected', 'expired'
  final String? notes;

  // Propiedades para cálculos
  double subtotal = 0.0;
  double tax = 0.0;
  double total = 0.0;
  int validityDays = 30;
  int deliveryDays = 5;
  String paymentTerms = 'Contado';

  Quote({
    required this.id,
    required this.clientId,
    required this.vendorId,
    required this.items,
    required this.createdAt,
    this.expiresAt,
    this.status = 'pending',
    this.notes,
    this.subtotal = 0.0,
    this.tax = 0.0,
    this.total = 0.0,
    this.validityDays = 30,
    this.deliveryDays = 5,
    this.paymentTerms = 'Contado',
  }) {
    // Inicializar los valores calculados si no se proporcionan
    if (subtotal == 0.0) {
      calculateTotals();
    }
  }

  // Calcular el total de la cotización
  void calculateTotals() {
    subtotal = 0;
    for (var item in items) {
      double itemTotal = item.price * item.quantity;
      double discountAmount = itemTotal * (item.discount / 100);
      subtotal += itemTotal - discountAmount;
    }

    // Si no quieres incluir impuestos, mantén el valor en 0
    // tax = subtotal * 0.16; // Impuesto del 16%

    total = subtotal + tax;
  }

  double calculateTotal() {
    calculateTotals();
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
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'validityDays': validityDays,
      'deliveryDays': deliveryDays,
      'paymentTerms': paymentTerms,
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
      subtotal: (map['subtotal'] ?? 0.0).toDouble(),
      tax: (map['tax'] ?? 0.0).toDouble(),
      total: (map['total'] ?? 0.0).toDouble(),
      validityDays: (map['validityDays'] ?? 30),
      deliveryDays: (map['deliveryDays'] ?? 5),
      paymentTerms: map['paymentTerms'] ?? 'Contado',
    );
  }

  // Método estático para crear un Quote directamente desde un DocumentSnapshot
  static Future<Quote> fromFirestore(DocumentSnapshot doc, {ProductService? productService}) async {
    final data = doc.data() as Map<String, dynamic>;

    // Lista para almacenar los ítems de la cotización
    List<QuoteItem> quoteItems = [];

    // Procesar los ítems si están disponibles
    if (data['items'] != null && productService != null) {
      final items = data['items'] as List<dynamic>;

      for (var itemData in items) {
        final productId = itemData['productId'];
        Product? product = await productService.getProductById(productId);

        if (product == null) {
          // Si no se encuentra el producto, crear uno genérico
          product = Product(
            id: productId,
            name: 'Producto no disponible',
            price: 0,
            description: '',
            category: '',
            imageUrl: '',
            stock: 0,
          );
        }

        quoteItems.add(QuoteItem(
          product: product,
          quantity: itemData['quantity'] ?? 1,
          price: (itemData['price'] ?? 0).toDouble(),
          discount: (itemData['discount'] ?? 0).toDouble(),
        ));
      }
    }

    // Crear el objeto Quote usando el método fromMap
    return Quote.fromMap(data, doc.id, quoteItems);
  }
}