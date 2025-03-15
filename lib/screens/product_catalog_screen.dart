import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../models/cart_model.dart';
import '../services/product_service.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';

class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({Key? key}) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _products = _productService.getProducts();
    _categories = _productService.getCategories();
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
        title: const Text('Catálogo de Productos'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CartScreen()),
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
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                bottom: 0,
                child: Consumer<Cart>(
                  builder: (ctx, cart, child) {
                    return cart.itemCount == 0
                        ? const SizedBox()
                        : Text(
                      '\$${cart.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
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
      floatingActionButton: Consumer<Cart>(
        builder: (ctx, cart, child) {
          return cart.itemCount > 0
              ? FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartScreen()),
              );
            },
            label: Text('Ver Carrito (\$${cart.totalAmount.toStringAsFixed(2)})'),
            icon: const Icon(Icons.shopping_cart),
            backgroundColor: Colors.green.shade700,
          )
              : const SizedBox();
        },
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final cart = Provider.of<Cart>(context, listen: false);

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
                  if (product.discountPercentage != null)
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
                if (product.discountPercentage != null)
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
                        '\$${product.salePrice.toStringAsFixed(2)}',
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
                // Control de cantidades
                if (product.isInStock)
                  Consumer<Cart>(
                    builder: (context, cart, child) {
                      final cartItem = cart.items[product.id];
                      final int quantity = cartItem?.quantity ?? 0;

                      return Row(
                        children: [
                          if (quantity == 0)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  cart.addProduct(product);
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
                                      if (quantity == 1) {
                                        cart.removeItem(product.id);
                                      } else {
                                        cart.removeSingleItem(product.id);
                                      }
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
                                      quantity.toString(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  // Botón para incrementar
                                  InkWell(
                                    onTap: () {
                                      cart.addProduct(product);
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
                      );
                    },
                  )
                else
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