import 'package:flutter/material.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final int stock;
  final String category;
  final String imageUrl;
  final double? discountPercentage;
  final Map<String, double>? clientPrices; // Precios especiales por tipo de cliente
  final bool featured;
  final List<String>? tags; // Añadido para mejorar la búsqueda y filtrado
  final DateTime? createdAt; // Útil para nuevos productos o seguimiento

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.category,
    required this.imageUrl,
    this.discountPercentage,
    this.clientPrices,
    this.featured = false,
    this.tags,
    this.createdAt,
  });

  // Clonar producto con nuevos valores
  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    int? stock,
    String? category,
    String? imageUrl,
    double? discountPercentage,
    Map<String, double>? clientPrices,
    bool? featured,
    List<String>? tags,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      clientPrices: clientPrices ?? this.clientPrices,
      featured: featured ?? this.featured,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Verificar si el producto está en stock
  bool get isInStock => stock > 0;

  // Verificar si el producto está en oferta
  bool get isOnSale => discountPercentage != null && discountPercentage! > 0;

  // Calcular precio con descuento
  double get salePrice {
    if (discountPercentage == null || discountPercentage == 0) {
      return price;
    }
    return price * (1 - discountPercentage! / 100);
  }

  // Obtener precio para un cliente específico
  double getPriceForClient(String clientId) {
    return clientPrices?[clientId] ?? price;
  }

  // Calcular descuento en valor absoluto
  double get discountAmount {
    if (discountPercentage == null || discountPercentage == 0) {
      return 0;
    }
    return price * (discountPercentage! / 100);
  }

  // Método para verificar si el producto coincide con ciertos filtros
  bool matchesFilter({
    String? searchQuery,
    String? categoryFilter,
    bool? inStockOnly,
    bool? onSaleOnly,
  }) {
    // Filtro de búsqueda por nombre o tags
    if (searchQuery != null) {
      final lowercaseQuery = searchQuery.toLowerCase();
      final matchesName = name.toLowerCase().contains(lowercaseQuery);
      final matchesTags = tags?.any((tag) =>
          tag.toLowerCase().contains(lowercaseQuery)) ?? false;
      if (!matchesName && !matchesTags) return false;
    }

    // Filtro por categoría
    if (categoryFilter != null && category != categoryFilter) {
      return false;
    }

    // Filtro de stock
    if (inStockOnly == true && !isInStock) {
      return false;
    }

    // Filtro de productos en oferta
    if (onSaleOnly == true && !isOnSale) {
      return false;
    }

    return true;
  }

  // Conversión a Map para facilitar almacenamiento en base de datos
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'stock': stock,
      'category': category,
      'imageUrl': imageUrl,
      'discountPercentage': discountPercentage,
      'clientPrices': clientPrices,
      'featured': featured,
      'tags': tags,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  // Constructor desde Map para facilitar la creación desde base de datos
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      price: map['price'].toDouble(),
      stock: map['stock'],
      category: map['category'],
      imageUrl: map['imageUrl'],
      discountPercentage: map['discountPercentage'],
      clientPrices: map['clientPrices'] != null
          ? Map<String, double>.from(map['clientPrices'])
          : null,
      featured: map['featured'] ?? false,
      tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : null,
    );
  }

  // Método para obtener un icono basado en la categoría
  IconData getCategoryIcon() {
    // Puedes personalizar los iconos según la categoría
    switch (category.toLowerCase()) {
      case 'electronica':
        return Icons.computer;
      case 'computadoras':
        return Icons.laptop;
      case 'accesorios':
        return Icons.mouse;
      default:
        return Icons.category;
    }
  }
}