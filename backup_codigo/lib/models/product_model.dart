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
  final int? unitsPerBox; // Nuevo campo para unidades por caja
  final List<String>? additionalImages; // Para el carrusel de imágenes
  final String? technicalInfo; // Para la ficha técnica
  final Map<String, double>? clientPrices; // Precios especiales por tipo de cliente
  final List<String>? tags; // Añadido para mejorar la búsqueda y filtrado
  final DateTime? createdAt; // Útil para nuevos productos o seguimiento

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.discountPercentage,
    required this.stock,
    required this.category,
    required this.imageUrl,
    this.featured = false,
    this.unitsPerBox, // Inicializado como nulo por defecto
    this.additionalImages,
    this.technicalInfo,
    this.clientPrices,
    this.tags,
    this.createdAt,
  });

  // Verificar si el producto está en stock
  bool get isInStock => stock > 0;

  // Verificar si el producto está en oferta
  bool get isOnSale => discountPercentage != null && discountPercentage! > 0;

  // Calcular precio con descuento
  double get salePrice {
    if (discountPercentage == null || discountPercentage! <= 0) {
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
    if (discountPercentage == null || discountPercentage! <= 0) {
      return 0;
    }
    return price * (discountPercentage! / 100);
  }

  // Calcular número de cajas completas necesarias
  int calculateBoxes(int quantity) {
    if (unitsPerBox == null || unitsPerBox! <= 1) return quantity;
    return (quantity / unitsPerBox!).ceil();
  }

  // Calcular unidades totales basadas en número de cajas
  int calculateUnits(int boxes) {
    if (unitsPerBox == null || unitsPerBox! <= 1) return boxes;
    return boxes * unitsPerBox!;
  }

  // Método para verificar si el producto coincide con ciertos filtros
  bool matchesFilter({
    String? searchQuery,
    String? categoryFilter,
    bool? inStockOnly,
    bool? onSaleOnly,
  }) {
    // Filtro de búsqueda por nombre o tags
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lowercaseQuery = searchQuery.toLowerCase();
      final matchesName = name.toLowerCase().contains(lowercaseQuery);
      final matchesDescription = description.toLowerCase().contains(lowercaseQuery);
      final matchesTags = tags?.any((tag) =>
          tag.toLowerCase().contains(lowercaseQuery)) ?? false;
      if (!matchesName && !matchesDescription && !matchesTags) return false;
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

  // Clonar producto con nuevos valores
  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    double? discountPercentage,
    int? stock,
    String? category,
    String? imageUrl,
    bool? featured,
    int? unitsPerBox,
    List<String>? additionalImages,
    String? technicalInfo,
    Map<String, double>? clientPrices,
    List<String>? tags,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      featured: featured ?? this.featured,
      unitsPerBox: unitsPerBox ?? this.unitsPerBox,
      additionalImages: additionalImages ?? this.additionalImages,
      technicalInfo: technicalInfo ?? this.technicalInfo,
      clientPrices: clientPrices ?? this.clientPrices,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Conversión a Map para facilitar almacenamiento en base de datos
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'discountPercentage': discountPercentage,
      'stock': stock,
      'category': category,
      'imageUrl': imageUrl,
      'featured': featured,
      'unitsPerBox': unitsPerBox,
      'additionalImages': additionalImages,
      'technicalInfo': technicalInfo,
      'clientPrices': clientPrices,
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
      price: (map['price'] is int) ? (map['price'] as int).toDouble() : map['price'],
      discountPercentage: map['discountPercentage'],
      stock: map['stock'],
      category: map['category'],
      imageUrl: map['imageUrl'],
      featured: map['featured'] ?? false,
      unitsPerBox: map['unitsPerBox'],
      additionalImages: map['additionalImages'] != null
          ? List<String>.from(map['additionalImages'])
          : null,
      technicalInfo: map['technicalInfo'],
      clientPrices: map['clientPrices'] != null
          ? Map<String, double>.from(map['clientPrices'])
          : null,
      tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : null,
    );
  }

  // Constructor para crear un producto desde un documento de Firestore
  factory Product.fromFirestore(String docId, Map<String, dynamic> data) {
    // Creamos un nuevo mapa con el ID incluido para reutilizar el fromMap
    final Map<String, dynamic> completeData = {
      ...data,
      'id': docId, // Aseguramos que el ID del documento se use como ID del producto
    };

    return Product.fromMap(completeData);
  }
}