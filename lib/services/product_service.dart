import '../models/product_model.dart';

class ProductService {
  // Productos GTRONIC basados en tu catálogo real
  List<Product> getProducts() {
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
      ),
      Product(
        id: 'DGSX24CRNW',
        name: 'GTRONIC SPLIT 24K 230V N1-W ULTRA MAX AIR',
        description: 'Aire acondicionado Split de 24,000 BTU N1-W. Ideal para espacios amplios con tecnología Ultra Max para máxima eficiencia.',
        price: 449.00,
        stock: 12,
        category: 'SPLIT',
        imageUrl: 'https://via.placeholder.com/400x300',
      ),
      Product(
        id: 'DGSX24CRNM',
        name: 'GTRONIC 24CRN1-M 230V 24K ALL EASY',
        description: 'Aire acondicionado Split de 24,000 BTU con sistema All Easy para fácil instalación y mantenimiento.',
        price: 599.00,
        stock: 7,
        category: 'SPLIT',
        imageUrl: 'https://via.placeholder.com/400x300',
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
      ),
      Product(
        id: 'DGWF-12CM-T',
        name: 'AIRE DE VENTANA GTRONIC DE 12.000 BTU CM COMPACTO',
        description: 'Aire acondicionado de ventana de 12,000 BTU con diseño compacto y control manual. Perfecto para habitaciones medianas.',
        price: 220.00,
        stock: 10,
        category: 'AIRE DE VENTANA',
        imageUrl: 'https://via.placeholder.com/400x300',
      ),
      Product(
        id: 'DGWF18CM',
        name: 'AIRE DE VENTANA 18.000 BTU CONTROL MANUAL',
        description: 'Aire acondicionado de ventana de 18,000 BTU con control manual. Alto rendimiento para espacios grandes.',
        price: 350.00,
        stock: 6,
        category: 'AIRE DE VENTANA',
        imageUrl: 'https://via.placeholder.com/400x300',
      ),
      Product(
        id: 'DGWF25CR',
        name: 'AIRE DE VENTANA 25.000 BTU CONTROL REMOTO',
        description: 'Aire acondicionado de ventana de alta capacidad (25,000 BTU) con control remoto para mayor comodidad.',
        price: 395.00,
        stock: 4,
        category: 'AIRE DE VENTANA',
        imageUrl: 'https://via.placeholder.com/400x300',
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
      ),
      Product(
        id: 'DGPDA12CRN1B15',
        name: 'AIRE PORTÁTIL 12.000 BTU DIAMOND',
        description: 'Aire acondicionado portátil Serie Diamond de 12,000 BTU con tecnología avanzada y diseño elegante.',
        price: 305.00,
        stock: 5,
        category: 'AIRES PORTÁTILES',
        imageUrl: 'https://via.placeholder.com/400x300',
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
      ),
      Product(
        id: 'CONDICLEAN',
        name: 'SPRAY PARA HIGIENE Y CUIDADO DEL A/A',
        description: 'Limpia el aire acondicionado de manera eficaz. Elimina las bacterias que se generan en la humedad. Actúa contra la acumulación de biofilm que obstruye los drenajes. Mejora la calidad del aire y eficiencia energética.',
        price: 2.90,
        stock: 45,
        category: 'MANTENIMIENTO',
        imageUrl: 'https://via.placeholder.com/400x300',
      ),
      Product(
        id: 'COBREMAX',
        name: 'SPRAY DE COBRE ANTICORROSIVO PUREZA 99.9%',
        description: 'Secado rápido y resistencia a la corrosión. Tratamiento anticorrosivo ultra. Diseñado para proteger los equipos de aires acondicionados de manera eficaz. Adaptable a todo clima. Soporta temperaturas mayores a 100 grados. Secado en 4-6 minutos.',
        price: 19.00,
        stock: 15,
        category: 'MANTENIMIENTO',
        imageUrl: 'https://via.placeholder.com/400x300',
      ),
    ];
  }

  // Obtener un producto por ID
  Product? getProductById(String id) {
    try {
      return getProducts().firstWhere((product) => product.id == id);
    } catch (e) {
      return null;
    }
  }

  // Obtener productos por categoría
  List<Product> getProductsByCategory(String category) {
    return getProducts().where((product) => product.category == category).toList();
  }

  // Obtener productos destacados
  List<Product> getFeaturedProducts() {
    return getProducts().where((product) => product.featured).toList();
  }

  // Buscar productos
  List<Product> searchProducts(String query) {
    query = query.toLowerCase();
    return getProducts().where((product) =>
        product.name.toLowerCase().contains(query) ||
        product.description.toLowerCase().contains(query) ||
        product.category.toLowerCase().contains(query) ||
        product.id.toLowerCase().contains(query)
    ).toList();
  }

  // Obtener categorías disponibles
  List<String> getCategories() {
    final categories = getProducts().map((product) => product.category).toSet().toList();
    categories.sort();
    return categories;
  }
}
