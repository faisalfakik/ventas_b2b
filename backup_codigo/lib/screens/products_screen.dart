import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/product_service.dart';
import '../models/cart_model.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';

class ProductsScreen extends StatefulWidget {
  final String category;

  const ProductsScreen({Key? key, required this.category}) : super(key: key);

  @override
  _ProductsScreenState createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String? selectedSubcategory;
  String sortOption = 'Nombre'; // Por defecto ordenamos por nombre

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
      default: return 'Productos';
    }
  }

  // Obtener los productos filtrados por categoría y subcategoría
  List<Product> getFilteredProducts() {
    List<Product> filteredProducts = ProductService.getProductsByCategory(widget.category);

    if (selectedSubcategory != null) {
      filteredProducts = filteredProducts
          .where((product) => product.subCategory == selectedSubcategory)
          .toList();
    }

    // Ordenar productos según la opción seleccionada
    switch (sortOption) {
      case 'Precio (menor a mayor)':
        filteredProducts.sort((a, b) => (a.isOnSale ? a.salePrice! : a.price)
            .compareTo(b.isOnSale ? b.salePrice! : b.price));
        break;
      case 'Precio (mayor a menor)':
        filteredProducts.sort((a, b) => (b.isOnSale ? b.salePrice! : b.price)
            .compareTo(a.isOnSale ? a.salePrice! : a.price));
        break;
      case 'Nombre':
        filteredProducts.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Disponibilidad':
        filteredProducts.sort((a, b) => a.inStock == b.inStock ? 0 : (a.inStock ? -1 : 1));
        break;
    }

    return filteredProducts;
  }

  // Obtener subcategorías disponibles
  List<String> getSubcategories() {
    return ProductService.getSubCategories(widget.category);
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = getFilteredProducts();
    final subCategories = getSubcategories();

    return Scaffold(
      appBar: AppBar(
        title: Text(getCategoryName(widget.category), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // Implementar búsqueda
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Búsqueda en desarrollo'))
              );
            },
          ),
          // Carrito con contador de productos
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.white),
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
      body: Column(
        children: [
          // Filtros y ordenamiento
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
                      ),
                      value: selectedSubcategory,
                      hint: const Text('Todas'),
                      onChanged: (value) {
                        setState(() {
                          selectedSubcategory = value;
                        });
                      },
                      items: [
                        ...subCategories.map((subCat) => DropdownMenuItem(
                          value: subCat,
                          child: Text(subCat.toUpperCase(),
                              style: const TextStyle(fontSize: 12)),
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
                    ),
                    value: sortOption,
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
                    ].map((option) => DropdownMenuItem(
                      value: option,
                      child: Text(option, style: const TextStyle(fontSize: 12)),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Lista de productos
          Expanded(
            child: filteredProducts.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No se encontraron productos',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
                : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
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
                              child: Icon(
                                product.icon,
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
                                    '-${product.discountPercentage}%',
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
                                    '\$${product.salePrice!.toStringAsFixed(2)}',
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

                                // Botón agregar a carrito (MODIFICADO)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: product.inStock ? () {
                                      // Agregar al carrito
                                      final cart = Provider.of<Cart>(context, listen: false);
                                      cart.addProduct(product, quantity: 1);

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
    );
  }
}