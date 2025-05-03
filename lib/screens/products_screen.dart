import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/product_service.dart';
import '../models/product_model.dart';
import '../models/cart_model.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../widgets/product_card.dart';
import '../utils/app_colors.dart';
import '../utils/app_styles.dart';

class ProductsScreen extends StatefulWidget {
  final String category;
  final String? searchQuery;
  final bool showFeaturedOnly;
  final Function(Product)? onProductSelected;

  const ProductsScreen({
    Key? key,
    required this.category,
    this.searchQuery,
    this.showFeaturedOnly = false,
    this.onProductSelected,
  }) : super(key: key);

  @override
  _ProductsScreenState createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> with SingleTickerProviderStateMixin {
  String? selectedSubcategory;
  String sortOption = 'Nombre'; // Por defecto ordenamos por nombre
  late ProductService _productService;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<Product> _products = [];
  TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  bool _showFilters = false;

  // Filtros adicionales
  bool _showInStockOnly = false;
  bool _showDiscountsOnly = false;
  RangeValues _priceRange = const RangeValues(0, 1000);
  double _maxPrice = 1000;

  @override
  void initState() {
    super.initState();
    _productService = ProductService();
    _searchController.text = widget.searchQuery ?? '';

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn)
    );

    // Cargar productos iniciales
    _loadProducts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ProductsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category ||
        oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.showFeaturedOnly != widget.showFeaturedOnly) {
      _loadProducts();
    }
  }

  // Cargar productos de manera asíncrona
  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.showFeaturedOnly) {
        _products = await _productService.getFeaturedProducts();
      } else {
        _products = await _productService.getProductsByCategory(widget.category);
      }

      // Filtrar por búsqueda si hay un término
      if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
        final query = widget.searchQuery!.toLowerCase();
        _products = _products.where((product) =>
        product.name.toLowerCase().contains(query) ||
            product.description.toLowerCase().contains(query) ||
            product.id.toLowerCase().contains(query)
        ).toList();
      }

      // Actualizar el rango de precios
      if (_products.isNotEmpty) {
        double maxProductPrice = _products.map((p) => p.price).reduce((a, b) => a > b ? a : b);
        _maxPrice = maxProductPrice + 100; // Añadir margen
        _priceRange = RangeValues(0, _maxPrice);
      }
    } catch (e) {
      print('Error loading products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar productos: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Obtener el título de la categoría
  String getCategoryName(String category) {
    switch(category) {
      case 'all': return 'Todos los Productos';
      case 'ac': return 'Aires Acondicionados';
      case 'ventilacion': return 'Ventiladores y Climatización';
      case 'cocina': return 'Electrodomésticos de Cocina';
      case 'iluminacion': return 'Iluminación';
      case 'energia': return 'Seguridad Eléctrica y Energía';
      case 'accesorios': return 'Accesorios para Electrodomésticos';
      case 'personal': return 'Cuidado Personal';
      case 'limpieza': return 'Limpieza y Mantenimiento';
      case 'otros': return 'Otros Productos';
      case 'ofertas': return 'Ofertas y Descuentos';
    // Añadimos las categorías de GTRONIC
      case 'SPLIT': return 'Aires Acondicionados Split';
      case 'AIRE DE VENTANA': return 'Aires Acondicionados de Ventana';
      case 'AIRES PORTÁTILES': return 'Aires Acondicionados Portátiles';
      case 'DESHUMIDIFICADORES': return 'Deshumidificadores';
      case 'CONGELADORES': return 'Congeladores';
      case 'PROTECTORES': return 'Protectores de Voltaje';
      case 'MANTENIMIENTO': return 'Productos de Mantenimiento';
      default: return 'Productos';
    }
  }

  // Obtener los productos filtrados por categoría y todos los filtros
  List<Product> getFilteredProducts() {
    if (_products.isEmpty) return [];

    List<Product> filteredProducts = List.from(_products);

    // Filtrar por subcategoría
    if (selectedSubcategory != null) {
      // Ajustamos según cómo hemos implementado las subcategorías
      if (selectedSubcategory!.startsWith("Caja de ")) {
        final int? boxSize = int.tryParse(selectedSubcategory!.replaceAll("Caja de ", ""));
        filteredProducts = filteredProducts.where((p) => p.unitsPerBox == boxSize).toList();
      } else if (selectedSubcategory == "Económico") {
        filteredProducts = filteredProducts.where((p) => p.price < 100).toList();
      } else if (selectedSubcategory == "Regular") {
        filteredProducts = filteredProducts.where((p) => p.price >= 100 && p.price < 300).toList();
      } else if (selectedSubcategory == "Premium") {
        filteredProducts = filteredProducts.where((p) => p.price >= 300).toList();
      }
    }

    // Filtrar por precio
    filteredProducts = filteredProducts.where((p) {
      final price = p.isOnSale ? p.salePrice : p.price;
      return price >= _priceRange.start && price <= _priceRange.end;
    }).toList();

    // Filtrar por stock
    if (_showInStockOnly) {
      filteredProducts = filteredProducts.where((p) => p.inStock).toList();
    }

    // Filtrar por descuentos
    if (_showDiscountsOnly) {
      filteredProducts = filteredProducts.where((p) => p.isOnSale).toList();
    }

    // Ordenar productos según la opción seleccionada
    switch (sortOption) {
      case 'Precio (menor a mayor)':
        filteredProducts.sort((a, b) => (a.isOnSale ? a.salePrice : a.price)
            .compareTo(b.isOnSale ? b.salePrice : b.price));
        break;
      case 'Precio (mayor a menor)':
        filteredProducts.sort((a, b) => (b.isOnSale ? b.salePrice : b.price)
            .compareTo(a.isOnSale ? a.salePrice : a.price));
        break;
      case 'Nombre':
        filteredProducts.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Disponibilidad':
        filteredProducts.sort((a, b) => a.inStock == b.inStock ? 0 : (a.inStock ? -1 : 1));
        break;
      case 'Nuevos primero':
        filteredProducts.sort((a, b) {
          if (a.createdAt == null && b.createdAt == null) return 0;
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          return b.createdAt!.compareTo(a.createdAt!);
        });
        break;
    }

    return filteredProducts;
  }

  // Obtener subcategorías disponibles
  List<String> getSubcategories() {
    // Implementación temporal hasta que se defina en ProductService
    return [
      'Económico',
      'Regular',
      'Premium',
      'Caja de 6',
      'Caja de 12',
      'Caja de 24'
    ];
    // TODO: Implementar _productService.getSubCategories cuando esté disponible
  }

  // Método para realizar búsqueda
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _products = getFilteredProducts();
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      _products = await _productService.searchProducts(query);
    } catch (e) {
      print('Error searching products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al buscar productos: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Método para compartir un producto
  void _shareProduct(Product product) {
    // Implementar lógica para compartir producto
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Compartiendo ${product.name}...'))
    );
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });

    if (_showFilters) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _addToCart(Product product) {
    final cart = Provider.of<Cart>(context, listen: false);
    if (cart != null) {
      cart.addProduct(product);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = getFilteredProducts();
    final subCategories = getSubcategories();
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 3 : 2; // Responsive grid

    return Scaffold(
      appBar: AppBar(
        title: Text(
          getCategoryName(widget.category),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        elevation: 2,
        actions: [
          // Botón de filtros
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: _toggleFilters,
            tooltip: 'Filtrar productos',
          ),
          // Botón de búsqueda
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              showSearch(
                context: context,
                delegate: ProductSearchDelegate(
                  productService: _productService,
                  onProductSelected: (product) {
                    if (widget.onProductSelected != null) {
                      widget.onProductSelected!(product);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDetailScreen(productId: product.id),
                        ),
                      );
                    }
                  },
                ),
              );
            },
            tooltip: 'Buscar productos',
          ),
          // Carrito con contador de productos
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.white),
                tooltip: 'Ver carrito',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CartScreen(),
                    ),
                  );
                },
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Consumer<Cart>(
                  builder: (ctx, cart, child) {
                    return cart.itemCount == 0
                        ? const SizedBox()
                        : Container(
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
                        '${cart.itemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: _loadProducts,
        child: Column(
          children: [
            // Panel de filtros expandible
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _showFilters ? null : 0,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: Container(
                  color: Colors.grey.shade100,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filtros Avanzados',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Filtros por rango de precios
                      const Text('Rango de precios:'),
                      RangeSlider(
                        values: _priceRange,
                        min: 0,
                        max: _maxPrice,
                        divisions: 20,
                        labels: RangeLabels(
                          '\$${_priceRange.start.toStringAsFixed(0)}',
                          '\$${_priceRange.end.toStringAsFixed(0)}',
                        ),
                        onChanged: (RangeValues values) {
                          setState(() {
                            _priceRange = values;
                          });
                        },
                      ),

                      // Filtros adicionales
                      Row(
                        children: [
                          // Filtro de disponibilidad
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Solo en stock', style: TextStyle(fontSize: 14)),
                              value: _showInStockOnly,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (value) {
                                setState(() {
                                  _showInStockOnly = value ?? false;
                                });
                              },
                            ),
                          ),

                          // Filtro de ofertas
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Solo ofertas', style: TextStyle(fontSize: 14)),
                              value: _showDiscountsOnly,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (value) {
                                setState(() {
                                  _showDiscountsOnly = value ?? false;
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      // Botón para resetear filtros
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Resetear filtros'),
                          onPressed: () {
                            setState(() {
                              _showInStockOnly = false;
                              _showDiscountsOnly = false;
                              _priceRange = RangeValues(0, _maxPrice);
                              selectedSubcategory = null;
                              sortOption = 'Nombre';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Filtros básicos y ordenamiento
            Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Filtro por subcategoría
                  if (subCategories.isNotEmpty) ...[
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Subcategoría',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                        ),
                        value: selectedSubcategory,
                        hint: const Text('Todas'),
                        isExpanded: true,
                        onChanged: (value) {
                          setState(() {
                            selectedSubcategory = value;
                          });
                        },
                        items: [
                          ...subCategories.map((subCat) => DropdownMenuItem(
                            value: subCat,
                            child: Text(
                              subCat,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Opciones de ordenamiento
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Ordenar por',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                      ),
                      value: sortOption,
                      isExpanded: true,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            sortOption = value;
                          });
                        }
                      },
                      items: [
                        'Nombre',
                        'Precio (menor a mayor)',
                        'Precio (mayor a menor)',
                        'Disponibilidad',
                        'Nuevos primero',
                      ].map((option) => DropdownMenuItem(
                        value: option,
                        child: Text(
                          option,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Contador de resultados
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filteredProducts.length} producto${filteredProducts.length != 1 ? 's' : ''} encontrado${filteredProducts.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                ],
              ),
            ),

            // Lista de productos
            Expanded(
              child: _isLoading ?
              // Shimmer loading effect
              Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: 6, // Placeholder items
                  itemBuilder: (_, __) => Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ) :
              _hasError ?
              // Error view
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      style: const TextStyle(fontSize: 16, color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                      onPressed: _loadProducts,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ) :
              filteredProducts.isEmpty ?
              // Empty results view
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'No se encontraron productos',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Intenta con otros filtros o criterios de búsqueda',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Mostrar todos'),
                      onPressed: () {
                        setState(() {
                          _showInStockOnly = false;
                          _showDiscountsOnly = false;
                          _priceRange = RangeValues(0, _maxPrice);
                          selectedSubcategory = null;
                          sortOption = 'Nombre';
                          _searchController.clear();
                        });
                        _loadProducts();
                      },
                    ),
                  ],
                ),
              ) :
              // Product grid
              GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                    child: InkWell(
                      onTap: () {
                        // Navegar a la pantalla de detalles del producto
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailScreen(productId: product.id),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Imagen o icono del producto con etiquetas de oferta/agotado
                          Stack(
                            children: [
                              Container(
                                height: 120,
                                width: double.infinity,
                                color: Colors.grey.shade200,
                                child: product.imageUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                  imageUrl: product.imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.image_not_supported,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                )
                                    : Icon(
                                  Icons.ac_unit, // Default icon, change as needed
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              if (product.isOnSale)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.only(
                                        bottomRight: Radius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      '-${product.discountPercentage!.toInt()}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              if (!product.inStock)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(10),
                                      ),
                                    ),
                                    child: const Text(
                                      'AGOTADO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              // Badges adicionales
                              if (product.featured)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.9),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(10),
                                      ),
                                    ),
                                    child: const Text(
                                      'DESTACADO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              // Botón de favoritos
                              Positioned(
                                top: 0,
                                right: product.inStock ? 0 : null,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      // Implementar lógica de favoritos
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${product.name} añadido a favoritos'),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        Icons.favorite_border,
                                        color: product.inStock ? Colors.black54 : Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Información del producto
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Referencia
                                  Text(
                                    product.id,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // Nombre del producto
                                  Text(
                                    product.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),

                                  // Información de stock
                                  Text(
                                    product.inStock
                                        ? 'Stock: ${product.stock} ${product.unitsPerBox != null ? '(${product.stock ~/ product.unitsPerBox!} cajas)' : 'unidades'}'
                                        : 'Sin stock disponible',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: product.inStock ? Colors.green.shade700 : Colors.red.shade700,
                                    ),
                                  ),

                                  const Spacer(),

                                  // Precios
                                  if (product.isOnSale) ...[
                                    Text(
                                      '\$${product.price.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        decoration: TextDecoration.lineThrough,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    Text(
                                      '\$${product.salePrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ] else ...[
                                    Text(
                                      '\$${product.price.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],

                                  // Botón agregar a carrito
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: product.inStock ? () {
                                        // Agregar al carrito
                                        _addToCart(product);

                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('${product.name} agregado a la orden'),
                                            duration: const Duration(seconds: 1),
                                            action: SnackBarAction(
                                              label: 'Ver Carrito',
                                              onPressed: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (context) => const CartScreen(),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        );
                                      } : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        textStyle: const TextStyle(fontSize: 12),
                                        disabledBackgroundColor: Colors.grey.shade300,
                                        elevation: 0,
                                      ),
                                      child: Text(product.inStock ? 'Agregar' : 'Agotado'),
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
              ),
            ),
          ],
        ),
      ),
      // Botón flotante para compartir o acciones adicionales
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        child: const Icon(Icons.filter_list),
        onPressed: _toggleFilters,
        tooltip: 'Mostrar filtros',
      ),
    );
  }
}

// Delegate para la búsqueda de productos
class ProductSearchDelegate extends SearchDelegate<Product?> {
  final ProductService productService;
  final Function(Product) onProductSelected;

  ProductSearchDelegate({
    required this.productService,
    required this.onProductSelected,
  });

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(query);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(query);
  }

  Widget _buildSearchResults(String query) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Ingresa un término para buscar productos',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<Product>>(
      future: productService.searchProducts(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final results = snapshot.data ?? [];

        if (results.isEmpty) {
          return const Center(
            child: Text('No se encontraron productos'),
          );
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final product = results[index];
            return ListTile(
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: product.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: product.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
                    ),
                  ),
                  errorWidget: (context, url, error) => Icon(
                    Icons.image_not_supported,
                    size: 24,
                    color: Colors.grey.shade400,
                  ),
                )
                    : Icon(
                  Icons.inventory_2,
                  size: 24,
                  color: Colors.grey.shade400,
                ),
              ),
              title: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${product.category} • \$${product.isOnSale ? product.salePrice.toStringAsFixed(2) : product.price.toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: product.isOnSale ? Colors.red.shade700 : Colors.grey.shade700,
                ),
              ),
              trailing: product.inStock
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.remove_circle, color: Colors.red),
              onTap: () {
                close(context, product);
                onProductSelected(product);
              },
            );
          },
        );
      },
    );
  }
}