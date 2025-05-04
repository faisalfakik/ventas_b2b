import 'package:cloud_firestore/cloud_firestore.dart'; // Necesario para fromFirestore/toFirestore
import 'package:meta/meta.dart';

@immutable // Clase inmutable
class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final double? discountPercentage;
  final int stock;
  final String category;
  final String imageUrl;
  final bool featured;
  final int? unitsPerBox;
  final List<String>? additionalImages;
  final String? technicalInfo;
  final Map<String, double>? clientPrices; // Incluido
  final List<String>? tags;
  final DateTime? createdAt;
  final double commissionRate; // Incluido
  final String? sku;
  final String? brand;
  final String? model;
  final String? dimensions;
  final double? weight;
  final String? warranty;
  final double? averageRating;
  final int? reviewCount;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.discountPercentage,
    required this.stock,
    required this.category,
    required this.imageUrl,
    this.featured = false,
    this.unitsPerBox,
    this.additionalImages,
    this.technicalInfo,
    this.clientPrices, // Incluido
    this.tags,
    this.createdAt,
    this.commissionRate = 0.0, // Incluido
    this.sku,
    this.brand,
    this.model,
    this.dimensions,
    this.weight,
    this.warranty,
    this.averageRating,
    this.reviewCount,
  });

  // --- GETTERS ---
  bool get inStock => stock > 0;
  bool get isOnSale => discountPercentage != null && discountPercentage! > 0 && discountPercentage! < 100; // Añadido < 100 por si acaso

  double get salePrice {
    if (!isOnSale) return price;
    return price * (1 - discountPercentage! / 100);
  }

  double get discountAmount {
    if (!isOnSale) return 0;
    return price - salePrice;
  }

  double get commissionAmount {
    // Asumiendo comisión sobre precio original
    return price * (commissionRate / 100);
  }

  // --- MÉTODOS ---
  double getPriceForCustomer(String clientId) {
    return clientPrices?[clientId] ?? salePrice;
  }

  int calculateBoxes(int quantity) {
    if (unitsPerBox == null || unitsPerBox! <= 1) return quantity;
    return (quantity / unitsPerBox!).ceil();
  }

  int calculateUnits(int boxes) {
    if (unitsPerBox == null || unitsPerBox! <= 1) return boxes;
    return boxes * unitsPerBox!;
  }

  bool matchesFilter({ String? searchQuery, String? categoryFilter, bool? inStockOnly, bool? onSaleOnly }) {
    // Implementación completa del filtro (como en tu versión)
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lowercaseQuery = searchQuery.toLowerCase();
      final matchesName = name.toLowerCase().contains(lowercaseQuery);
      final matchesDescription = description.toLowerCase().contains(lowercaseQuery);
      final matchesTags = tags?.any((tag) => tag.toLowerCase().contains(lowercaseQuery)) ?? false;
      final matchesSku = sku?.toLowerCase().contains(lowercaseQuery) ?? false;
      final matchesBrand = brand?.toLowerCase().contains(lowercaseQuery) ?? false;
      if (!matchesName && !matchesDescription && !matchesTags && !matchesSku && !matchesBrand) return false;
    }
    if (categoryFilter != null && category != categoryFilter) return false;
    if (inStockOnly == true && !inStock) return false;
    if (onSaleOnly == true && !isOnSale) return false;
    return true;
  }

  // --- SERIALIZACIÓN / CLONACIÓN ---

  Product copyWith({
    String? id, String? name, String? description, double? price,
    double? discountPercentage, int? stock, String? category, String? imageUrl,
    bool? featured, int? unitsPerBox, List<String>? additionalImages,
    String? technicalInfo, Map<String, double>? clientPrices, List<String>? tags,
    DateTime? createdAt, double? commissionRate, String? sku, String? brand,
    String? model, String? dimensions, double? weight, String? warranty,
    double? averageRating, int? reviewCount
  }) {
    return Product(
      id: id ?? this.id, name: name ?? this.name, description: description ?? this.description,
      price: price ?? this.price, discountPercentage: discountPercentage ?? this.discountPercentage,
      stock: stock ?? this.stock, category: category ?? this.category, imageUrl: imageUrl ?? this.imageUrl,
      featured: featured ?? this.featured, unitsPerBox: unitsPerBox ?? this.unitsPerBox,
      additionalImages: additionalImages ?? this.additionalImages, technicalInfo: technicalInfo ?? this.technicalInfo,
      clientPrices: clientPrices ?? this.clientPrices, tags: tags ?? this.tags, createdAt: createdAt ?? this.createdAt,
      commissionRate: commissionRate ?? this.commissionRate, sku: sku ?? this.sku, brand: brand ?? this.brand,
      model: model ?? this.model, dimensions: dimensions ?? this.dimensions, weight: weight ?? this.weight,
      warranty: warranty ?? this.warranty, averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }

  Map<String, dynamic> toMap() { // Para uso general (puede usarse para Firestore también)
    return {
      'id': id, 'name': name, 'description': description, 'price': price,
      'discountPercentage': discountPercentage, 'stock': stock, 'category': category,
      'imageUrl': imageUrl, 'featured': featured, 'unitsPerBox': unitsPerBox,
      'additionalImages': additionalImages, 'technicalInfo': technicalInfo,
      'clientPrices': clientPrices, 'tags': tags, 'createdAt': createdAt?.toIso8601String(),
      'commissionRate': commissionRate, 'sku': sku, 'brand': brand, 'model': model,
      'dimensions': dimensions, 'weight': weight, 'warranty': warranty,
      'averageRating': averageRating, 'reviewCount': reviewCount,
    };
  }

  Map<String, dynamic> toFirestore() { // Método específico si quieres excluir el 'id' del mapa
    return {
      // Excluye 'id' porque es el ID del documento
      'name': name, 'description': description, 'price': price,
      'discountPercentage': discountPercentage, 'stock': stock, 'category': category,
      'imageUrl': imageUrl, 'featured': featured, 'unitsPerBox': unitsPerBox,
      'additionalImages': additionalImages, 'technicalInfo': technicalInfo,
      'clientPrices': clientPrices, 'tags': tags, 'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null, // Usar Timestamp
      'commissionRate': commissionRate, 'sku': sku, 'brand': brand, 'model': model,
      'dimensions': dimensions, 'weight': weight, 'warranty': warranty,
      'averageRating': averageRating, 'reviewCount': reviewCount,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, [String? docId]) { // Acepta ID opcional
    return Product(
      id: docId ?? map['id'] ?? '', // Usa docId si se provee, sino el del mapa
      name: map['name'] ?? 'Sin nombre',
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      discountPercentage: (map['discountPercentage'] as num?)?.toDouble(),
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      category: map['category'] ?? 'Sin categoría',
      imageUrl: map['imageUrl'] ?? '',
      featured: map['featured'] as bool? ?? false,
      unitsPerBox: (map['unitsPerBox'] as num?)?.toInt(),
      additionalImages: map['additionalImages'] != null ? List<String>.from(map['additionalImages']) : null,
      technicalInfo: map['technicalInfo'] as String?,
      clientPrices: map['clientPrices'] != null ? Map<String, double>.from(map['clientPrices'].map((k, v) => MapEntry(k, (v as num).toDouble()))) : null,
      tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
      // Manejo de Timestamp de Firestore o ISO String
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : (map['createdAt'] is String ? DateTime.tryParse(map['createdAt']) : null),
      commissionRate: (map['commissionRate'] as num?)?.toDouble() ?? 0.0,
      sku: map['sku'] as String?,
      brand: map['brand'] as String?,
      model: map['model'] as String?,
      dimensions: map['dimensions'] as String?,
      weight: (map['weight'] as num?)?.toDouble(),
      warranty: map['warranty'] as String?,
      averageRating: (map['averageRating'] as num?)?.toDouble(),
      reviewCount: (map['reviewCount'] as num?)?.toInt(),
    );
  }

  factory Product.fromFirestore(String docId, Map<String, dynamic> data) {
    // Llama a fromMap pasando el ID del documento explícitamente
    return Product.fromMap(data, docId);
  }

  // --- Igualdad ---
  @override
  bool operator ==(Object other) => identical(this, other) || other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}