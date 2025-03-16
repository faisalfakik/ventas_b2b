import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import 'product_detail_screen.dart';

class ProductCatalogScreen extends StatefulWidget {
  final String? categoryFilter;
  final String? title;
  final bool isAdmin;

  const ProductCatalogScreen({
    Key? key,
    this.categoryFilter,
    this.title,
    this.isAdmin = false,
  }) : super(key: key);

  @override
  _ProductCatalogScreenState createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  final ProductService _productService = ProductService();
  List<Product> _products = [];
  List<String> _categories = [];
  String? _selectedCategory;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int _cartItemCount = 0;

  @override
  void initState() {
    super.initState();
    _categories = _productService.getCategories();

    // Aplicar filtro de categoría si se proporcionó
    if (widget.categoryFilter != null) {
      _selectedCategory = widget.categoryFilter;
      _products = _productService.getProductsByCategory(_selectedCategory!);
    } else {
      _products = _productService.getProducts();
    }

    _loadCartItemCount();
  }

  void _loadCartItemCount() {
    setState(() {
      _cartItemCount = _productService.getCartItems().length;
    });
  }

  void _filterProducts() {
    setState(() {
      if (_searchQuery.isNotEmpty) {
        _products = _productService.searchProducts(_searchQuery);
      } else if (_selectedCategory != null) {
        _products = _productService.getProductsByCategory(_selectedCategory!);
      } else {
        _products = _productService.getProducts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Catálogo de Productos'),
        actions: [
          // Mostrar botón de administración si es admin
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Opciones de administrador',
              onPressed: () {
                // TODO: Implementar opciones de administrador
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Funciones de administración próximamente')),
                );
              },
            ),
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  // TODO: Implementar navegación al carrito
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
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar productos',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                    _filterProducts();
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _filterProducts();
              },
            ),
          ),
          // Filtro de categorías
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: _selectedCategory == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = null;
                    });
                    _filterProducts();
                  },
                ),
                const SizedBox(width: 8),
                ..._categories.map(
                      (category) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = selected ? category : null;
                        });
                        _filterProducts();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Lista de productos
          Expanded(
            child: _products.isEmpty
                ? const Center(
              child: Text('No se encontraron productos'),
            )
                : GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return _buildProductCard(product);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton(
        onPressed: () {
          // TODO: Implementar agregar nuevo producto
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Función para agregar producto próximamente')),
          );
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      )
          : (_cartItemCount > 0
          ? FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implementar navegación al carrito
        },
        label: Text('Ver Carrito'),
        icon: const Icon(Icons.shopping_cart),
        backgroundColor: Colors.green.shade700,
      )
          : null),
    );
  }

  Widget _buildProductCard(Product product) {
    final hasDiscount = product.discountPercentage != null && product.discountPercentage! > 0;
    final displayPrice = hasDiscount ? product.salePrice : product.price;
    final isProductInCart = _productService.isInCart(product.id);
    final quantityInCart = _productService.getQuantityInCart(product.id);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen y acceso a detalles
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(product: product),
                ),
              );
            },
            child: AspectRatio(
              aspectRatio: 1.2,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      product.imageUrl,
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
                  if (hasDiscount)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(10),
                          ),
                        ),
                        child: Text(
                          '-${product.discountPercentage!.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  // Agregar indicador para modo admin
                  if (widget.isAdmin)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: InkWell(
                        onTap: () {
                          // TODO: Implementar edición de producto
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Editar ${product.name}')),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre del producto
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Precio
                if (hasDiscount)
                  Row(
                    children: [
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '\$${displayPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 4),
                // Stock
                Text(
                  'Stock: ${product.stock}',
                  style: TextStyle(
                    color: product.isInStock ? Colors.black54 : Colors.red,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                // Control de cantidades (solo para no-admin)
                if (!widget.isAdmin && product.isInStock)
                  Row(
                    children: [
                      if (!isProductInCart)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              try {
                                _productService.addToCart(product);
                                _loadCartItemCount();
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                            ),
                            child: const Text('Agregar'),
                          ),
                        )
                      else
                        Expanded(
                          child: Row(
                            children: [
                              // Botón para decrementar
                              InkWell(
                                onTap: () {
                                  if (quantityInCart <= 1) {
                                    _productService.removeFromCart(product.id);
                                  } else {
                                    _productService.updateCartItemQuantity(
                                        product.id,
                                        quantityInCart - 1
                                    );
                                  }
                                  _loadCartItemCount();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade700,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(Icons.remove, color: Colors.white, size: 16),
                                ),
                              ),
                              // Mostrar cantidad actual
                              Expanded(
                                child: Text(
                                  quantityInCart.toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Botón para incrementar
                              InkWell(
                                onTap: () {
                                  try {
                                    _productService.updateCartItemQuantity(
                                        product.id,
                                        quantityInCart + 1
                                    );
                                    _loadCartItemCount();
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade700,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(Icons.add, color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                // Botones de administración para admin
                else if (widget.isAdmin)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            // TODO: Implementar administración de stock
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Administrar stock de ${product.name}')),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 0),
                            foregroundColor: Colors.blue,
                          ),
                          child: const Text('Gestionar', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  )
                else if (!product.isInStock)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Sin Stock',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}