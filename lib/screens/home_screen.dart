import 'dart:async';
import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import 'product_catalog_screen.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ProductService _productService = ProductService();
  late List<Product> _featuredProducts;
  late List<String> _categories;
  int _cartItemCount = 0;

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
    _featuredProducts = _productService.getFeaturedProducts();
    _categories = _productService.getCategories();

    // Inicializar el controlador de página y el temporizador
    _pageController = PageController(initialPage: 0);
    _startAutoSlide();
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
      if (_currentPage < _bannerImages.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
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
                  setState(() {
                    _featuredProducts = _productService.getFeaturedProducts();
                    _categories = _productService.getCategories();
                  });
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
          }
          // Implementar navegación para otras pestañas
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
                // Navegar al carrito (implementar después)
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
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  // Navegar al carrito
                },
              ),
              if (_cartItemCount > 0)
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
                      _cartItemCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
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
    return Container(
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
    );
  }

  IconData _getCategoryIcon(String category) {
    // Asignar iconos según la categoría
    switch (category.toLowerCase()) {
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

  // Nuevo método para el carrusel personalizado
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
    final displayPrice = hasDiscount ? product.salePrice : product.price;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(product: product),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del producto
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                  child: Image.network(
                    product.imageUrl,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        width: double.infinity,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, color: Colors.grey),
                      );
                    },
                  ),
                ),
                if (hasDiscount)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(10),
                          bottomLeft: Radius.circular(10),
                        ),
                      ),
                      child: Text(
                        '-${product.discountPercentage!.round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Información del producto
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (hasDiscount) ...[
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    '\$${displayPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Agregar al carrito
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Agregar',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}