// lib/services/product_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart'; // Asegúrate que el path es correcto
import 'package:collection/collection.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener todos los productos (intenta Firestore, fallback a local)
  Future<List<Product>> getAllProducts() async {
    try {
      final snapshot = await _firestore
          .collection('products') // Asegúrate que 'products' es tu colección
          .limit(100) // Considera paginación
          .get();

      if (snapshot.docs.isNotEmpty) {
        print("✅ Productos cargados desde Firestore.");
        return snapshot.docs.map((doc) => Product.fromFirestore(doc.id, doc.data())).toList();
      } else {
        print("⚠️ No hay productos en Firestore, usando datos locales de ejemplo.");
        return _getLocalExampleProducts(); // Usar fallback
      }
    } catch (e) {
      print('❌ Error al obtener productos de Firestore: $e. Usando datos locales.');
      return _getLocalExampleProducts(); // Usar fallback en caso de error
    }
  }

  // Alias para consistencia
  Future<List<Product>> getProducts() async {
    return await getAllProducts();
  }

  // Obtener un producto por ID
  Future<Product?> getProductById(String id) async {
    try {
      final doc = await _firestore.collection('products').doc(id).get();
      if (doc.exists && doc.data() != null) {
        return Product.fromFirestore(doc.id, doc.data()!);
      } else {
        print("⚠️ Producto $id no encontrado en Firestore, buscando en locales.");
        final localProducts = _getLocalExampleProducts();
        try {
          return localProducts.firstWhere((p) => p.id == id);
        } catch (e) {
          print("❌ Producto $id tampoco encontrado localmente.");
          return null; // Retornar null en lugar de lanzar excepción
        }
      }
    } catch (e) {
      print('❌ Error obteniendo producto por ID $id: $e. Buscando en locales.');
      final localProducts = _getLocalExampleProducts();
      try {
        return localProducts.firstWhere((p) => p.id == id);
      } catch (_) {
        print("No se pudo encontrar el producto: $id");
        return null; // Retornar null permitiendo mejor manejo en la UI
      }
    }
  }

  // Obtener productos por categoría (Query a Firestore)
  Future<List<Product>> getProductsByCategory(String category) async {
    if (category.toLowerCase() == 'all' || category.isEmpty) {
      return await getAllProducts(); // Devolver todos si no hay categoría específica
    }
    try {
      Query query = _firestore.collection('products').where('category', isEqualTo: category);
      final snapshot = await query.limit(50).get(); // Limitar resultados

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => Product.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
            .toList();
      } else {
        print("️⚠️ No se encontraron productos en Firestore para la categoría '$category'.");
        // Opcional: buscar en productos locales con la misma categoría
        final localProducts = _getLocalExampleProducts();
        return localProducts.where((p) => p.category.toLowerCase() == category.toLowerCase()).toList();
      }
    } catch (e) {
      print('❌ Error obteniendo productos por categoría ($category) desde Firestore: $e.');
      return []; // Devolver lista vacía en caso de error
    }
  }

  // Obtener categorías únicas
  Future<List<String>> getCategories() async {
    // Intenta obtener de una colección 'categories' si existe y tiene un campo 'name'
    try {
      final snapshot = await _firestore.collection('categories').orderBy('name').get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) => doc.data()['name'] as String).toList();
      }
    } catch(e) {
      print('ℹ️ Colección "categories" no encontrada o error: $e. Obteniendo de productos.');
    }
    // Fallback: Obtener de los productos existentes (puede ser menos eficiente)
    final products = await getAllProducts(); // O usar _getLocal... si prefieres offline
    final categories = products.map((product) => product.category).toSet().toList();
    categories.sort();
    return categories;
  }

  // Buscar productos (Idealmente en backend/Firestore)
  Future<List<Product>> searchProducts(String query) async {
    // Implementación simple filtrando localmente (MEJORAR CON BACKEND SEARCH)
    final products = await getAllProducts();
    if (query.trim().isEmpty) return products;
    final lowerCaseQuery = query.toLowerCase();
    return products.where((product) =>
    product.name.toLowerCase().contains(lowerCaseQuery) ||
        (product.description?.toLowerCase().contains(lowerCaseQuery) ?? false) ||
        product.category.toLowerCase().contains(lowerCaseQuery) ||
        (product.brand?.toLowerCase().contains(lowerCaseQuery) ?? false) ||
        (product.sku?.toLowerCase().contains(lowerCaseQuery) ?? false) ||
        (product.tags?.any((tag) => tag.toLowerCase().contains(lowerCaseQuery)) ?? false)
    ).toList();
  }

  Future<List<Product>> getFeaturedProducts() async {
    // Query a Firestore o filtrar local
    final products = await getAllProducts();
    return products.where((product) => product.featured).toList();
  }

  Future<List<Product>> getRelatedProducts(Product currentProduct) async {
    // Lógica mejorada
    final allInCategory = await getProductsByCategory(currentProduct.category);
    return allInCategory
        .where((p) => p.id != currentProduct.id)
        .take(10) // Limitar cantidad
        .toList();
  }

  // --- Métodos de Reviews/Rating (mover a su propio servicio es lo ideal) ---
  Future<double> getUserRatingForProduct(String productId) async { return 3.5; } // Ejemplo
  Future<void> submitProductReview(String productId, String review, double rating) async { print("Review Enviada"); }
  Future<List<Map<String, dynamic>>> getProductReviews(String productId) async {
    // Ejemplo de datos de reseñas para mostrar en la UI
    return [
      {
        'userName': 'Cliente Satisfecho',
        'rating': 5.0,
        'date': '15/03/2025',
        'comment': 'Excelente producto, cumple con todas las especificaciones. Muy recomendado para instalaciones profesionales.'
      },
      {
        'userName': 'Técnico HVAC',
        'rating': 4.5,
        'date': '02/03/2025',
        'comment': 'Buen rendimiento y fácil instalación. Solo le falta un poco más de documentación técnica.'
      },
      {
        'userName': 'Distribuidor Local',
        'rating': 4.0,
        'date': '25/02/2025',
        'comment': 'Buena relación calidad-precio. Mis clientes están muy satisfechos con el producto.'
      }
    ];
  }

  // --- Datos Locales de Ejemplo ---
  List<Product> _getLocalExampleProducts() {
    return [
      // Categoría: SPLIT
      Product(
        id: 'DGSX12CRNW',
        name: 'GTRONIC AA SPLIT 12K N1-W 220V ULTRA MAX AIR',
        description: 'Aire acondicionado Split de 12,000 BTU con tecnología Ultra Max para máxima eficiencia y confort.',
        price: 225.00,
        stock: 10,
        category: 'SPLIT',
        imageUrl: 'https://via.placeholder.com/400x300',
        featured: true,
        unitsPerBox: 1,
      ),
      Product(
        id: 'DGSX18CRNW',
        name: 'GTRONIC AA SPLIT 18K 230V ULTRA MAX AIR',
        description: 'Aire acondicionado Split de 18,000 BTU con tecnología Ultra Max Air. Alto rendimiento y bajo consumo energético.',
        price: 369.99,
        stock: 8,
        category: 'SPLIT',
        imageUrl: 'https://via.placeholder.com/400x300',
        featured: true,
        unitsPerBox: 1,
      ),
      Product(
        id: 'DGSX24CRNW',
        name: 'GTRONIC SPLIT 24K 230V N1-W ULTRA MAX AIR',
        description: 'Aire acondicionado Split de 24,000 BTU N1-W. Ideal para espacios amplios con tecnología Ultra Max para máxima eficiencia.',
        price: 449.00,
        stock: 12,
        category: 'SPLIT',
        imageUrl: 'https://via.placeholder.com/400x300',
        unitsPerBox: 1,
      ),
      Product(
        id: 'DGSX24CRNM',
        name: 'GTRONIC 24CRN1-M 230V 24K ALL EASY',
        description: 'Aire acondicionado Split de 24,000 BTU con sistema All Easy para fácil instalación y mantenimiento.',
        price: 599.00,
        stock: 7,
        category: 'SPLIT',
        imageUrl: 'https://via.placeholder.com/400x300',
        unitsPerBox: 1,
      ),

      // Categoría: AIRE DE VENTANA
      Product(
        id: 'DGWF-5CM',
        name: 'AIRE DE VENTANA GTRONIC DE 5.000 BTU CM 115V',
        description: 'Aire acondicionado de ventana compacto de 5,000 BTU con control manual. Ideal para espacios pequeños.',
        price: 115.00,
        stock: 15,
        category: 'AIRE DE VENTANA',
        imageUrl: 'https://via.placeholder.com/400x300',
        featured: true,
        unitsPerBox: 1,
      ),
      Product(
        id: 'DGWF-12CM-T',
        name: 'AIRE DE VENTANA GTRONIC DE 12.000 BTU CM COMPACTO',
        description: 'Aire acondicionado de ventana de 12,000 BTU con diseño compacto y control manual. Perfecto para habitaciones medianas.',
        price: 220.00,
        stock: 10,
        category: 'AIRE DE VENTANA',
        imageUrl: 'https://via.placeholder.com/400x300',
        unitsPerBox: 1,
      ),
      Product(
        id: 'DGWF18CM',
        name: 'AIRE DE VENTANA 18.000 BTU CONTROL MANUAL',
        description: 'Aire acondicionado de ventana de 18,000 BTU con control manual. Alto rendimiento para espacios grandes.',
        price: 350.00,
        stock: 6,
        category: 'AIRE DE VENTANA',
        imageUrl: 'https://via.placeholder.com/400x300',
        unitsPerBox: 1,
      ),
      Product(
        id: 'DGWF25CR',
        name: 'AIRE DE VENTANA 25.000 BTU CONTROL REMOTO',
        description: 'Aire acondicionado de ventana de alta capacidad (25,000 BTU) con control remoto para mayor comodidad.',
        price: 395.00,
        stock: 4,
        category: 'AIRE DE VENTANA',
        imageUrl: 'https://via.placeholder.com/400x300',
        unitsPerBox: 1,
      ),

      // Categoría: AIRES PORTÁTILES
      Product(
        id: 'DGPHB12CRN1BH',
        name: 'AIRE PORTÁTIL 12.000 BTU SERIE HB LUXURY',
        description: 'Aire acondicionado portátil de 12,000 BTU serie HB Luxury. Tecnología de enfriamiento eficiente con diseño premium.',
        price: 275.00,
        stock: 8,
        category: 'AIRES PORTÁTILES',
        imageUrl: 'https://via.placeholder.com/400x300',
        featured: true,
        unitsPerBox: 1,
      ),
      Product(
        id: 'DGPDA12CRN1B15',
        name: 'AIRE PORTÁTIL 12.000 BTU DIAMOND',
        description: 'Aire acondicionado portátil Serie Diamond de 12,000 BTU con tecnología avanzada y diseño elegante.',
        price: 305.00,
        stock: 5,
        category: 'AIRES PORTÁTILES',
        imageUrl: 'https://via.placeholder.com/400x300',
        unitsPerBox: 1,
      ),

      // Categoría: DESHUMIDIFICADORES
      Product(
        id: 'DGUDP40AEN1BA9',
        name: 'DESHUMEDIFICADOR DE 40 PINTS',
        description: 'Deshumidificador de alta capacidad (40 Pints) ideal para espacios húmedos. Elimina eficientemente la humedad del ambiente.',
        price: 179.00,
        stock: 6,
        category: 'DESHUMIDIFICADORES',
        imageUrl: 'https://via.placeholder.com/400x300',
        unitsPerBox: 1,
      ),
      Product(
        id: 'DGUDP50AEN1BA9',
        name: 'DESHUMEDIFICADOR DE 50 PINTS',
        description: 'Deshumidificador de máxima capacidad (50 Pints) para espacios grandes o con humedad extrema.',
        price: 189.00,
        stock: 7,
        category: 'DESHUMIDIFICADORES',
        imageUrl: 'https://via.placeholder.com/400x300',
        featured: true,
        unitsPerBox: 1,
      ),

      // Categoría: CONGELADORES
      Product(
        id: 'GT-300L',
        name: 'GTRONIC CONGELADOR DE 300L GT300L',
        description: 'Congelador de alta capacidad (300L) ideal para el hogar o negocio. Diseño eficiente y bajo consumo energético.',
        price: 349.00,
        stock: 0, // AGOTADO
        category: 'CONGELADORES',
        imageUrl: 'https://via.placeholder.com/400x300',
        unitsPerBox: 1,
      ),

      // Categoría: PROTECTORES
      Product(
        id: 'GT-V010-220V',
        name: 'PROTECTOR DE VOLTAJE DE AIRES SPLIT O VENTANA 220V',
        description: 'Protector de voltaje especialmente diseñado para aires acondicionados Split o de ventana que operan a 220V.',
        price: 7.50,
        stock: 25,
        category: 'PROTECTORES',
        imageUrl: 'https://via.placeholder.com/400x300',
        unitsPerBox: 4,
      ),
      Product(
        id: 'GT-V099',
        name: 'PROTECTOR DE VOLTAJE DE 220V AIRES SPLIT O VENTANA',
        description: 'Protector de voltaje premium para aires acondicionados que operan a 220V, ofrece máxima protección contra fluctuaciones eléctricas.',
        price: 8.90,
        stock: 20,
        category: 'PROTECTORES',
        imageUrl: 'https://via.placeholder.com/400x300',
        featured: true,
        unitsPerBox: 4,
      ),

      // Categoría: MANTENIMIENTO
      Product(
        id: 'OCEANGUARD',
        name: 'SPRAY ANTICORROSIVO OCEANGUARD',
        description: 'Spray anticorrosivo adaptable a todo clima. Extiende la vida útil prolongando durabilidad de las unidades HVAC en zonas costeras. Mejora la eficiencia de las unidades acondicionadoras. Tiempo de secado 20 minutos.',
        price: 9.00,
        stock: 30,
        category: 'MANTENIMIENTO',
        imageUrl: 'https://via.placeholder.com/400x300',
        featured: true,
        unitsPerBox: 6,
      ),
      Product(
        id: 'CONDICLEAN',
        name: 'SPRAY PARA HIGIENE Y CUIDADO DEL A/A',
        description: 'Limpia el aire acondicionado de manera eficaz. Elimina las bacterias que se generan en la humedad. Actúa contra la acumulación de biofilm que obstruye los drenajes. Mejora la calidad del aire y eficiencia energética.',
        price: 2.90,
        stock: 45,
        category: 'MANTENIMIENTO',
        imageUrl: 'https://via.placeholder.com/400x300',
        unitsPerBox: 12,
      ),
      Product(
        id: 'COBREMAX',
        name: 'SPRAY DE COBRE ANTICORROSIVO PUREZA 99.9%',
        description: 'Secado rápido y resistencia a la corrosión. Tratamiento anticorrosivo ultra. Diseñado para proteger los equipos de aires acondicionados de manera eficaz. Adaptable a todo clima. Soporta temperaturas mayores a 100 grados. Secado en 4-6 minutos.',
        price: 19.00,
        stock: 15,
        category: 'MANTENIMIENTO',
        imageUrl: 'https://via.placeholder.com/400x300',
        unitsPerBox: 6,
      ),
    ];
  }
}