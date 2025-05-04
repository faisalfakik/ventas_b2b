import 'dart:async';
import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../screens/product_catalog_screen.dart';
import 'package:ventas_b2b/screens/product_detail_screen.dart';
import '../screens/cart_screen.dart';
import 'package:provider/provider.dart';
import '../services/cart_service.dart';



class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> _featuredProducts = [];
  List<String> _categories = [];

  // PageController para el carrusel personalizado
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  // Lista de imágenes para el banner
  final List<String> _bannerImages = [
    'https://gtronic.com/media/banners/banner-1.png',
    'https://gtronic.com/media/banners/BANNER-RANGO-DE-VOLTAJE.png',
    'https://via.placeholder.com/800x400?text=Banner+3',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();

    // Inicializar el controlador de página y el temporizador
    _pageController = PageController(initialPage: 0);
    _startAutoSlide();
  }

// Nuevo método para cargar datos
  Future<void> _loadData() async {
    // Verificar si el widget todavía está montado antes de usar context
    if (!mounted) return;

    try {
      // Usar context.read de forma segura después de initState
      final productService = context.read<ProductService>();
      // Obtener datos en paralelo si es posible y no dependen entre sí
      final results = await Future.wait([
        productService.getFeaturedProducts(),
        productService.getCategories(),
      ]);

      // Asignar resultados de forma segura (asumiendo tipos correctos)
      if (mounted) {
        setState(() {
          _featuredProducts = results[0] as List<Product>;
          _categories = results[1] as List<String>;
        });
      }
    } catch (e) {
      print("Error cargando datos home: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: ${e.toString()}')),
        );
      }
      // Mostrar error al usuario si es necesario
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

// Método para iniciar el desplazamiento automático del carrusel
  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) { // Si el widget se desmonta, cancelar el timer
        timer.cancel();
        return;
      }
      int nextPage = _currentPage + 1;
      if (nextPage >= _bannerImages.length) {
        nextPage = 0; // Volver al inicio
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
        // _currentPage se actualizará en el onPageChanged del PageView
      }
    });
  }

// Método para añadir un producto al carrito
  void _addToCart(Product product) {
    if (!mounted) return; // Comprobar si está montado
    try {
      // Obtener CartService usando context.read (seguro fuera del build)
      final cartService = context.read<CartService>();

      // Añadir el producto al carrito (o actualizar si ya existe)
      // La lógica de si es 1 unidad o la caja completa debe estar en addOrUpdateCart si es necesario
      cartService.addOrUpdateCart(product, quantity: 1);

      // Mostrar mensaje de confirmación
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} añadido al carrito'),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Ver Carrito',
            onPressed: () {
              // Navegar al carrito
              _navigateToCart(); // Usar el método existente
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        // Mostrar mensaje de error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al añadir: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Método para mostrar diálogo de cantidad
  void _showQuantityDialog(Product product) {
    final cartService = context.read<CartService>();
    int currentQuantity = cartService.getQuantityInCart(product.id);
    final TextEditingController quantityController = TextEditingController();
    quantityController.text = currentQuantity.toString();

    // Determinar si el producto tiene unidades por caja
    final bool hasUnitsPerBox = product.unitsPerBox != null && product.unitsPerBox! > 1;
    final int unitsPerBox = product.unitsPerBox ?? 1;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Cantidad para ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  hintText: 'Ingrese la cantidad deseada',
                  suffixText: hasUnitsPerBox ? 'unidades' : null,
                ),
              ),
              if (hasUnitsPerBox) ...[
                const SizedBox(height: 10),
                Text(
                  'Este producto se vende en cajas de $unitsPerBox unidades',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Cajas: ${(int.tryParse(quantityController.text) ?? 0) ~/ unitsPerBox} + ${(int.tryParse(quantityController.text) ?? 0) % unitsPerBox} unidades',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                try {
                  final newQuantity = int.parse(quantityController.text);
                  if (newQuantity > 0) {
                    if (hasUnitsPerBox) {
                      // Redondear a múltiplos de unitsPerBox si es necesario
                      final int adjustedQuantity = (newQuantity / unitsPerBox).ceil() * unitsPerBox;
                      if (adjustedQuantity != newQuantity) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'La cantidad se ha ajustado a ${adjustedQuantity} unidades (${adjustedQuantity ~/ unitsPerBox} cajas completas)'
                            ),
                          ),
                        );
                      }
                      cartService.updateCartItemQuantity(product.id, adjustedQuantity);
                    } else {
                      cartService.updateCartItemQuantity(product.id, newQuantity);
                    }
                    // La línea setState que actualizaba _cartItemCount debe ser eliminada
                  }
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor ingrese un número válido')),
                  );
                }
              },
              child: const Text('Actualizar'),
            ),
          ],
        );
      },
    );
  }

  // Método para navegar a una categoría
  void _navigateToCategory(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductCatalogScreen(
          categoryFilter: category,
          title: category,
        ),
      ),
    );
  }

  // Método para navegar al carrito
  void _navigateToCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CartScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _loadData(); // Usar el método que ya creaste
                  return Future.value();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchBar(),
                      _buildCategoriesCarousel(),
                      _buildBannerSlider(),
                      _buildFeaturedProducts(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Catálogo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Carrito',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProductCatalogScreen()),
            );
          } else if (index == 2) {
            _navigateToCart();
          }
        },
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.green.shade700,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: Colors.green),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Menú',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Inicio'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Catálogo'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProductCatalogScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('Carrito'),
              onTap: () {
                Navigator.pop(context);
                _navigateToCart();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Historial de Pedidos'),
              onTap: () {
                Navigator.pop(context);
                // Navegar al historial (implementar después)
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Configuración'),
              onTap: () {
                Navigator.pop(context);
                // Navegar a configuración (implementar después)
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo más pequeño a la izquierda
          Image.asset(
            'assets/logo.png',
            height: 40,
            // Si no tienes un logo.png, usa un placeholder
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 40,
                width: 40,
                color: Colors.green.shade700,
                child: const Center(
                  child: Text(
                    'G',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          // Nombre de usuario o empresa
          const Expanded(
            child: Text(
              'Hola Gtronic',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Icono del carrito con contador
          Consumer<CartService>(
            builder: (context, cartService, child) {
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart),
                    onPressed: () {
                      _navigateToCart();
                    },
                  ),
                  if (cartService.uniqueItemCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          cartService.uniqueItemCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Buscar en Gtronic',
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey[400],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProductCatalogScreen()),
          );
        },
      ),
    );
  }

  Widget _buildCategoriesCarousel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            'Departamentos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              return _buildCategoryItem(_categories[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(String category) {
    return InkWell(  // Envuelve el contenedor en un InkWell para hacerlo clicable
      onTap: () => _navigateToCategory(category),  // Añade la navegación
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _getCategoryIcon(category),
                size: 30,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    // Asignar iconos según la categoría
    switch (category.toLowerCase()) {
      case 'split':
        return Icons.ac_unit;
      case 'aire de ventana':
        return Icons.window;
      case 'aires portátiles':
        return Icons.weekend;
      case 'deshumidificadores':
        return Icons.water_drop;
      case 'congeladores':
        return Icons.kitchen;
      case 'protectores':
        return Icons.security;
      case 'mantenimiento':
        return Icons.handyman;
      case 'electrónicos':
        return Icons.devices;
      case 'computadoras':
        return Icons.computer;
      case 'móviles':
        return Icons.smartphone;
      case 'accesorios':
        return Icons.headset;
      case 'gaming':
        return Icons.gamepad;
      case 'redes':
        return Icons.wifi;
      case 'cables':
        return Icons.cable;
      default:
        return Icons.category;
    }
  }

  Widget _buildBannerSlider() {
    return Container(
      height: 150,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Stack(
        children: [
          // PageView para las imágenes
          PageView.builder(
            controller: _pageController,
            itemCount: _bannerImages.length,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    _bannerImages[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.image, size: 50, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          // Indicadores de página
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _bannerImages.length,
                    (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? Colors.green.shade700
                        : Colors.grey.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedProducts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Productos Destacados',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProductCatalogScreen()),
                  );
                },
                child: const Text('Ver todos'),
              ),
            ],
          ),
        ),
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _featuredProducts.length,
          itemBuilder: (context, index) {
            return _buildProductCard(_featuredProducts[index]);
          },
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    final hasDiscount = product.discountPercentage != null && product.discountPercentage! > 0;
    // Calcular precio final ANTES de construir el widget
    final double effectivePrice = hasDiscount ? product.salePrice : product.price;

    // Escuchar cambios en CartService para este producto específico
    return Consumer<CartService>(
      builder: (context, cartService, child) {
        // Obtener estado del carrito para este producto DENTRO del builder
        final bool isInCart = cartService.isInCart(product.id);
        final int quantityInCart = cartService.getQuantityInCart(product.id);

        // Tarjeta del producto
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12), // Bordes más redondeados
            boxShadow: [ // Sombra sutil
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: InkWell( // Hacer toda la tarjeta clicable
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(product: product),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12), // Efecto ripple redondeado
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Sección de Imagen ---
                Expanded( // Dar más espacio a la imagen
                  flex: 3, // Proporción de espacio para la imagen
                  child: Stack(
                    children: [
                      // Contenedor de la imagen con bordes redondeados solo arriba
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                          image: DecorationImage(
                            image: NetworkImage(product.imageUrl),
                            fit: BoxFit.contain, // 'contain' suele ser mejor para productos
                            alignment: Alignment.center,
                            onError: (exception, stackTrace) {
                              print("Error imagen producto: $exception");
                            },
                          ),
                          color: Colors.grey[100], // Fondo suave por si la imagen no carga
                        ),
                        child: Align( // Placeholder mientras carga o si falla
                          alignment: Alignment.center,
                          child: Image.network(
                            product.imageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              return progress == null ? child : Center(child: CircularProgressIndicator(strokeWidth: 2, value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null));
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.inventory_2_outlined, color: Colors.grey[400], size: 40);
                            },
                          ),
                        ),
                      ),
                      // Badge de descuento
                      if (hasDiscount)
                        Positioned(
                          top: 8,
                          left: 8, // O right: 8, según diseño
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '-${product.discountPercentage!.toStringAsFixed(0)}%', // Sin decimales para %
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // --- Sección de Información y Precio ---
                Expanded(
                  flex: 2, // Proporción de espacio para el texto y botón
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8), // Padding ajustado
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribuir espacio
                      children: [
                        // Nombre del producto
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 13, // Ligeramente más pequeño
                            fontWeight: FontWeight.w500, // Semibold
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Precios (Original tachado y precio final)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasDiscount)
                              Text(
                                '\$${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  decoration: TextDecoration.lineThrough, // Tachado
                                ),
                              ),
                            Text(
                              '\$${effectivePrice.toStringAsFixed(2)}', // Precio efectivo
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800, // Color principal más oscuro
                              ),
                            ),
                          ],
                        ),


                        // Indicador de unidades por caja (si aplica)
                        if (product.unitsPerBox != null && product.unitsPerBox! > 1)
                          Text(
                            'Caja: ${product.unitsPerBox} unid.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),


                        // --- Botón de Añadir o Control de Cantidad ---
                        SizedBox(
                          width: double.infinity,
                          height: 32, // Botón más pequeño
                          child: !isInCart
                          // Botón 'Agregar'
                              ? ElevatedButton.icon(
                            icon: const Icon(Icons.add_shopping_cart, size: 14),
                            label: const Text('Agregar', style: TextStyle(fontSize: 12)),
                            onPressed: () => _addToCart(product),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero, // Controlar padding interno si es necesario
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              visualDensity: VisualDensity.compact, // Hacerlo más compacto
                            ),
                          )
                          // Controles +/- y cantidad
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center, // Centrar controles
                            children: [
                              _buildQuantityButton( // Botón Decrementar
                                icon: Icons.remove,
                                onTap: () {
                                  if (quantityInCart <= 1) {
                                    // Considerar mostrar confirmación antes de eliminar
                                    cartService.removeFromCart(product.id);
                                  } else {
                                    int decrement = 1;
                                    if (product.unitsPerBox != null && product.unitsPerBox! > 1){
                                      // Opcional: decrementar por caja
                                      // decrement = product.unitsPerBox!;
                                    }
                                    cartService.updateCartItemQuantity(
                                        product.id, quantityInCart - decrement);
                                  }
                                },
                              ),
                              // Mostrar cantidad (clicable para diálogo)
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _showQuantityDialog(product),
                                  child: Container(
                                    color: Colors.grey.shade100, // Fondo ligero para cantidad
                                    alignment: Alignment.center,
                                    child: Text(
                                      quantityInCart.toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _buildQuantityButton( // Botón Incrementar
                                icon: Icons.add,
                                onTap: () {
                                  int increment = 1;
                                  if (product.unitsPerBox != null && product.unitsPerBox! > 1){
                                    // Opcional: incrementar por caja
                                    // increment = product.unitsPerBox!;
                                  }
                                  cartService.updateCartItemQuantity(
                                      product.id, quantityInCart + increment);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }  // Cierra el método _buildProductCard

// Helper para botones de cantidad +/- en la tarjeta
  Widget _buildQuantityButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 32, // Ancho fijo
        decoration: BoxDecoration(
          color: Colors.green.shade700,
          borderRadius: BorderRadius.circular(8), // Redondear botones individuales
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
} // Cierre de la clase _HomeScreenState