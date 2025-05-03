import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart'; // Necesario

// Asegúrate que estos imports usan tus archivos/modelos finales
import '../models/product_model.dart';
import '../services/product_service.dart'; // Asume existencia y funcionalidad
import 'product_detail_screen.dart';     // Asume existencia

class RelatedProductsScreen extends StatefulWidget {
  final String category;
  final String currentProductId;

  const RelatedProductsScreen({
    Key? key,
    required this.category,
    required this.currentProductId,
  }) : super(key: key);

  @override
  _RelatedProductsScreenState createState() => _RelatedProductsScreenState();
}

class _RelatedProductsScreenState extends State<RelatedProductsScreen> {
  final ProductService _productService = ProductService(); // Considerar inyectar
  late Future<List<Product>> _relatedProductsFuture;
  final RefreshController _refreshController = RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
    _loadRelatedProducts();
  }

  @override
  void dispose() {
    _refreshController.dispose(); // Liberar controlador
    super.dispose();
  }

  // Carga o recarga los productos relacionados
  Future<void> _loadRelatedProducts() async {
    // Usar setState para asegurar que el FutureBuilder se reconstruya al reintentar
    if (mounted) {
      setState(() {
        _relatedProductsFuture = _productService
            .getProductsByCategory(widget.category) // Asume método existe
        // Filtrar el producto actual DESPUÉS de obtener la lista
            .then((products) => products.where((p) => p.id != widget.currentProductId).toList())
            .catchError((error, stacktrace) {
          // Manejar error aquí si el servicio no lo hace internamente
          print("Error en _loadRelatedProducts: $error");
          // Puedes lanzar el error para que lo capture FutureBuilder
          throw error;
        });
      });
    }
  }

  // Callback para SmartRefresher
  void _onRefresh() async {
    await _loadRelatedProducts();
    // Indicar al controlador que el refresh terminó (incluso si falló la carga)
    if (mounted) _refreshController.refreshCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Más en ${widget.category}'),
        elevation: 1,
      ),
      body: FutureBuilder<List<Product>>(
        future: _relatedProductsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Manejo de Error Mejorado
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error);
          }

          final products = snapshot.data ?? [];

          // Manejo de Estado Vacío Mejorado
          if (products.isEmpty) {
            return _buildEmptyState();
          }

          // Lista con Pull-to-Refresh
          return SmartRefresher(
            controller: _refreshController,
            onRefresh: _onRefresh,
            enablePullDown: true, // Habilitar pull down
            header: const WaterDropHeader( // Indicador visual de refresh
              waterDropColor: Colors.blueAccent, // Color del indicador
            ),
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 2 columnas
                childAspectRatio: 0.70, // Ajustar según diseño de tarjeta
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                // Usar el widget de tarjeta refactorizado
                return _RelatedProductCard(
                    product: product,
                    // Pasar Hero tag único para posible animación desde detalle
                    heroTagPrefix: 'related_product_${widget.currentProductId}'
                );
              },
            ),
          );
        },
      ),
    );
  }

  // --- Widgets para Estados ---
  Widget _buildErrorState(Object? error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text('No se pudieron cargar los productos',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(error?.toString() ?? 'Error desconocido',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            onPressed: _loadRelatedProducts,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.category_outlined, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('No hay productos relacionados',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Prueba con otra categoría o vuelve más tarde.'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}


// --- Widget Tarjeta Producto Relacionado ---
class _RelatedProductCard extends StatelessWidget {
  final Product product;
  final String heroTagPrefix; // Prefijo para asegurar tags únicos

  const _RelatedProductCard({
    required this.product,
    required this.heroTagPrefix, // Recibir prefijo
    Key? key
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool hasDiscount = product.isOnSale;
    final bool isInStock = product.inStock; // Usar getter correcto
    final double displayPrice = product.salePrice; // Usar getter correcto

    // Tag único para Hero
    final String heroTag = '${heroTagPrefix}_${product.id}';

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3, // Sombra más pronunciada
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            // --- Imagen ---
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: Hero(
                      tag: heroTag, // Usar tag único
                      child: CachedNetworkImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey.shade200),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  // Badge Descuento - CORRECCIÓN: Widget completo en lugar de placeholder
                  if (hasDiscount)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
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
                  // Overlay Sin Stock - CORRECCIÓN: Widget completo en lugar de placeholder
                  if (!isInStock)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.6),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SIN STOCK',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // --- Información ---
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CORRECCIÓN: Widget Text completo en lugar de placeholder
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (hasDiscount)
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  // CORRECCIÓN: Widget Text completo en lugar de placeholder
                  Text(
                    '\$${displayPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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