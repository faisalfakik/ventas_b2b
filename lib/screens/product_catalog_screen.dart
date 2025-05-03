// lib/screens/product_catalog_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:collection/collection.dart'; // Importar para firstWhereOrNull

// Tus imports (verifica paths)
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../services/cart_service.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';
import 'related_products_screen.dart';

// --- Placeholders Admin (REEMPLAZAR) ---
class AdminOptionsScreen extends StatelessWidget { const AdminOptionsScreen({Key? key}) : super(key: key); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Admin'))); }
class AdminAddProductScreen extends StatelessWidget { const AdminAddProductScreen({Key? key}) : super(key: key); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Añadir Producto'))); }
class AdminEditProductScreen extends StatelessWidget { final Product product; const AdminEditProductScreen({required this.product, Key? key}) : super(key: key); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text('Editar ${product.name}'))); }
// --- Fin Placeholders ---

// --- Constantes de UI ---
const Duration _kDebounceDuration = Duration(milliseconds: 400);
const EdgeInsets _kScreenPadding = EdgeInsets.all(12.0);
const double _kGridSpacing = 12.0;
const double _kGridAspectRatio = 0.68;

class ProductCatalogScreen extends StatefulWidget {
  final String? categoryFilter;
  final String? title;
  final bool isAdmin;
  const ProductCatalogScreen({ Key? key, this.categoryFilter, this.title, this.isAdmin = false }) : super(key: key);
  @override
  _ProductCatalogScreenState createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<String> _categories = [];
  String? _selectedCategory;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  Object? _loadingError;
  Timer? _debounce;
  final RefreshController _refreshController = RefreshController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_products.isEmpty && _isLoading) {
      _loadInitialData();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData({bool isRefresh = false}) async {
    if (!isRefresh && mounted) setState(() { _isLoading = true; _loadingError = null; });
    final productService = context.read<ProductService>();
    try {
      final results = await Future.wait([
        productService.getCategories(),
        productService.getProducts(),
      ]);
      if (!mounted) return;
      _categories = results[0] as List<String>;
      _products = results[1] as List<Product>;
      _selectedCategory = widget.categoryFilter;
      setState(() { _filterProducts(); _isLoading = false; });
    } catch (e, s) {
      print("Error cargando datos iniciales: $e\n$s");
      if (mounted) setState(() { _isLoading = false; _loadingError = e; });
    } finally {
      if (isRefresh) _refreshController.refreshCompleted();
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  void _onRefresh() => _loadInitialData(isRefresh: true);

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(_kDebounceDuration, () {
      final currentText = _searchController.text.trim();
      if (_searchQuery != currentText && mounted) {
        setState(() => _searchQuery = currentText.toLowerCase());
        _filterProducts();
      }
    });
  }

  void _filterProducts() {
    List<Product> tempProducts; // CORREGIDO: Declarar aquí
    if (_selectedCategory != null) {
      tempProducts = _products.where((p) => p.category == _selectedCategory).toList();
    } else {
      tempProducts = List.from(_products);
    }
    if (_searchQuery.isNotEmpty) {
      tempProducts = tempProducts.where((p) => p.matchesFilter(searchQuery: _searchQuery)).toList();
    }
    if (mounted) {
      setState(() => _filteredProducts = tempProducts);
    }
  }

  void _selectCategory(String? category) {
    if (!mounted || _selectedCategory == category) return;
    setState(() => _selectedCategory = category);
    _filterProducts();
  }

  void _clearFilters() { /* ... (igual que antes) ... */ }

  // --- Lógica de Carrito (Llama a CartService vía Provider) ---
  void _handleAddToCart(Product product) {
    try {
      context.read<CartService>().addToCart(product, quantity: 1);
      _showFeedbackSnackbar('${product.name} añadido', isSuccess: true);
    } catch (e) { _showErrorSnackbar(e.toString()); }
  }
  void _handleUpdateQuantity(Product product, int newQuantity) {
    try {
      context.read<CartService>().updateCartItemQuantity(product.id, newQuantity);
    } catch (e) { _showErrorSnackbar(e.toString()); }
  }
  void _handleRemoveFromCart(String productId) {
    try {
      context.read<CartService>().removeFromCart(productId);
    } catch (e) { _showErrorSnackbar(e.toString()); }
  }

  // Helper Snackbar definido DENTRO del State
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $message'), backgroundColor: Colors.redAccent));
  }
  void _showFeedbackSnackbar(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? Colors.redAccent : (isSuccess ? Colors.green : null),
      margin: const EdgeInsets.fromLTRB(15, 5, 15, 15), // Margen ajustado
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // --- Navegación ---
  void _navigateToCart() { Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())); }
  void _navigateToAdminOptions() { Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOptionsScreen())); }
  void _navigateToAddProduct() { Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAddProductScreen())); }
  void _navigateToEditProduct(Product product) { Navigator.push(context, MaterialPageRoute(builder: (_) => AdminEditProductScreen(product: product))); }
  void _navigateToRelatedProducts(Product product) { Navigator.push(context, MaterialPageRoute(builder: (_) => RelatedProductsScreen(category: product.category, currentProductId: product.id))); }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: _buildAppBar(context, theme),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(children: [ _buildSearchBar(context), _buildCategoryFilter(context, theme), const Divider(height: 1, thickness: 1), Expanded(child: _buildBodyContent(context)), ]),
      ),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  // --- Widgets Constructores Helper ---
  AppBar _buildAppBar(BuildContext context, ThemeData theme) {
    return AppBar(
      title: Text(widget.title ?? 'Catálogo'),
      elevation: 1,
      actions: [
        if (widget.isAdmin) IconButton(icon: const Icon(Icons.settings_outlined), tooltip: 'Admin', onPressed: _navigateToAdminOptions),
        // CORRECCIÓN: Consumer con builder correcto
        Consumer<CartService>(
          builder: (context, cart, child) { // CORREGIDO
            final itemCount = cart.totalQuantity;
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  tooltip: 'Ver Carrito (${cart.uniqueItemCount})',
                  onPressed: _navigateToCart,
                ),
                if (itemCount > 0)
                  Positioned(
                    right: 6, top: 6,
                    child: Container( // Badge
                      padding: EdgeInsets.all(itemCount > 9 ? 2 : 3),
                      decoration: BoxDecoration(color: theme.colorScheme.error, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        itemCount.toString(),
                        style: TextStyle(color: theme.colorScheme.onError, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          }, // CORREGIDO
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // CORRECCIÓN: Asegurar que retornen Widgets válidos
  Widget _buildSearchBar(BuildContext context) { return Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: TextField(/* ... */)); }
  Widget _buildCategoryFilter(BuildContext context, ThemeData theme) {
    return SizedBox(
        height: 55,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final category = _categories[index];
            final isSelected = _selectedCategory == category;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (_) => _selectCategory(isSelected ? null : category),
                backgroundColor: Colors.grey.shade200,
                selectedColor: theme.primaryColor.withOpacity(0.2),
              ),
            );
          },
        )
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _isLoading ? 0.0 : 1.0,
      child: Builder(
        builder: (context) {
          if (_isLoading) return _buildLoadingShimmer();
          if (_loadingError != null) return _buildErrorWidget(_loadingError!);
          if (_filteredProducts.isEmpty) return _buildEmptyWidget();

          return SmartRefresher(
            controller: _refreshController,
            onRefresh: _onRefresh,
            header: WaterDropHeader(complete: Text('¡Actualizado!', style: TextStyle(color: Theme.of(context).primaryColor))),
            child: GridView.builder(
              key: const PageStorageKey('productGrid'),
              padding: _kScreenPadding,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // CORREGIDO
                childAspectRatio: _kGridAspectRatio,
                crossAxisSpacing: _kGridSpacing,
                mainAxisSpacing: _kGridSpacing,
              ),
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                // Leer cantidad aquí para pasarla a la tarjeta
                final quantityInCart = context.watch<CartService>().getQuantityInCart(product.id);

                return _ProductCard(
                  key: ValueKey(product.id),
                  product: product,
                  isAdmin: widget.isAdmin,
                  quantityInCart: quantityInCart,
                  // Pasar los handlers del State a la tarjeta
                  onAddToCart: () => _handleAddToCart(product),
                  onUpdateQuantity: (newQuantity) => _handleUpdateQuantity(product, newQuantity),
                  onRemoveFromCart: () => _handleRemoveFromCart(product.id),
                  onEdit: () => _navigateToEditProduct(product),
                  onManageStock: () { /* Placeholder */ },
                  onViewRelated: () => _navigateToRelatedProducts(product),
                  // Pasar el handler de snackbar de errores
                  onError: _showErrorSnackbar,
                );
              },
            ),
          );
        },
      ),
    );
  }

  // CORRECCIÓN: Asegurar que retornen Widgets válidos
  Widget _buildLoadingShimmer() { return Shimmer.fromColors(baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!, child: GridView.builder(padding: _kScreenPadding, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: _kGridAspectRatio, crossAxisSpacing: _kGridSpacing, mainAxisSpacing: _kGridSpacing ), itemCount: 6, itemBuilder: (context, index) => Card(/* Placeholder card */))); }
  Widget _buildErrorWidget(Object error) { return Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.cloud_off_outlined, size: 70, color: Theme.of(context).colorScheme.error.withOpacity(0.6)), const SizedBox(height: 24), Text('¡Ups! Algo salió mal', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.error)), const SizedBox(height: 12), Text('No pudimos cargar los productos.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700)), const SizedBox(height: 32), ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text('Reintentar'), onPressed: () => _loadInitialData())] ) ) ); }

  Widget _buildEmptyWidget() {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 24),
                  Text('No se encontraron productos',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('Prueba con otros filtros de búsqueda',
                      style: TextStyle(color: Colors.grey.shade700)),
                  if (_searchQuery.isNotEmpty || _selectedCategory != null)
                    TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Limpiar filtros')
                    )
                ]
            )
        )
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return Consumer<CartService>(
        builder: (context, cartService, child) {
          final hasItemsInCart = cartService.uniqueItemCount > 0;

          // Siempre devolver un widget, incluso cuando no hay elementos
          if (!hasItemsInCart) {
            return const SizedBox.shrink(); // Widget vacío en lugar de null
          }

          return FloatingActionButton.extended(
            onPressed: _navigateToCart,
            icon: const Icon(Icons.shopping_cart_checkout),
            label: Text('Ver carrito (${cartService.uniqueItemCount})'),
            backgroundColor: Theme.of(context).primaryColor,
          );
        }
    );
  }
} // Fin _ProductCatalogScreenState


// --- Widget _ProductCard (Revertido a usar Callbacks) ---
// (Incluye las correcciones de sintaxis y scope)
class _ProductCard extends StatelessWidget {
  final Product product;
  final bool isAdmin;
  final int quantityInCart;
  final VoidCallback onAddToCart;
  final ValueChanged<int> onUpdateQuantity;
  final VoidCallback onRemoveFromCart;
  final VoidCallback onEdit;
  final VoidCallback onManageStock;
  final VoidCallback onViewRelated;
  final ValueChanged<String> onError; // Recibe callback de error

  const _ProductCard({
    required this.product, required this.isAdmin, required this.quantityInCart,
    required this.onAddToCart, required this.onUpdateQuantity, required this.onRemoveFromCart,
    required this.onEdit, required this.onManageStock, required this.onViewRelated,
    required this.onError, // Recibir
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isProductInCart = quantityInCart > 0;
    final bool isInStock = product.inStock;
    final bool hasDiscount = product.isOnSale;
    final double displayPrice = product.salePrice;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2.5,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: Stack(children: [
              Positioned.fill(
                child: Hero(
                  tag: 'product_image_${product.id}',
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    errorWidget: (context, url, error) => Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            color: Colors.grey.shade400,
                            size: 40)),
                  ),
                ),
              ),
              if (hasDiscount) Positioned(top: 8, right: 8, child: _buildDiscountChip(context)),
              if (isAdmin) Positioned(top: 5, left: 5, child: _buildAdminEditButton(context)),
              if (!isInStock) Positioned.fill(child: _buildOutOfStockOverlay()),
              Positioned(bottom: 5, right: 5, child: _buildViewRelatedButton(context)),
            ])),
            Expanded(flex: 2, child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(product.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ if (hasDiscount) Text('\$${product.price.toStringAsFixed(2)}', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 11)), Text('\$${displayPrice.toStringAsFixed(2)}', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 14)) ]),
                      if (isAdmin) _buildAdminStockButton(context, isInStock)
                      else if (isInStock) _buildQuantityControl(context, isProductInCart, quantityInCart)
                      else const SizedBox(height: 36), // Altura consistente
                    ]
                )
            )),
          ],
        ),
      ),
    );
  }

  // --- Widgets Internos de Tarjeta ---
  Widget _buildAdminEditButton(BuildContext context) => CircleAvatar(radius: 14, backgroundColor: Colors.black.withOpacity(0.6), child: IconButton(iconSize: 14, visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, constraints: const BoxConstraints(), splashRadius: 16, color: Colors.white, icon: const Icon(Icons.edit_outlined), onPressed: onEdit, tooltip: 'Editar'));
  Widget _buildViewRelatedButton(BuildContext context) => CircleAvatar(radius: 14, backgroundColor: Colors.black.withOpacity(0.6), child: IconButton(iconSize: 16, visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, constraints: const BoxConstraints(), splashRadius: 16, color: Colors.white, icon: const Icon(Icons.more_horiz), onPressed: onViewRelated, tooltip: 'Ver relacionados'));

  // CORRECCIÓN: Definido método que faltaba y sintaxis corregida
  Widget _buildAdminStockButton(BuildContext context, bool isInStock) {
    return SizedBox(height: 36, width: double.infinity, child: OutlinedButton.icon(
        icon: Icon(Icons.inventory_2_outlined, size: 16),
        label: Text('Stock: ${product.stock}', style: const TextStyle(fontSize: 12)),
        onPressed: onManageStock,
        style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: isInStock ? Colors.blueAccent : Colors.redAccent,
            side: BorderSide(color: isInStock ? Colors.blueAccent.withOpacity(0.5) : Colors.redAccent.withOpacity(0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
        ) // Cierre styleFrom
    ) // Cierre OutlinedButton.icon
    ); // Cierre SizedBox
  }

  Widget _buildDiscountChip(BuildContext context) {
    return Chip( label: Text('-${product.discountPercentage!.round()}%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)), backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap );
  }
  Widget _buildOutOfStockOverlay() {
    return Container( alignment: Alignment.center, color: Colors.black.withOpacity(0.6), child: const Text('AGOTADO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)));
  }

  // CORRECCIÓN: Asegurar que los métodos internos retornen Widget
  Widget _buildQuantityControl(BuildContext context, bool isProductInCart, int quantityInCart) {
    return SizedBox(
      height: 36,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
        child: isProductInCart
            ? _buildPlusMinusControl(context, quantityInCart)
            : _buildAddButton(context),
      ),
    ); // Devuelve SizedBox
  }

  Widget _buildAddButton(BuildContext context) {
    return SizedBox(
      key: ValueKey('add_${product.id}'),
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add_shopping_cart, size: 18),
        label: const Text('Agregar'),
        onPressed: () { try { onAddToCart(); } catch(e) { onError(e.toString()); } },
        style: ElevatedButton.styleFrom( // CORRECCIÓN: Usar styleFrom
            backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold)
        ), // Cierre styleFrom
      ), // Cierre ElevatedButton.icon
    ); // Cierre SizedBox
  }

  Widget _buildPlusMinusControl(BuildContext context, int quantity) {
    return Container(
      key: ValueKey('qty_${product.id}'),
      decoration: BoxDecoration( color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)), // CORRECCIÓN: decoración correcta
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: Icon(Icons.remove_circle_outline, color: Colors.redAccent.withOpacity(0.8), size: 22), onPressed: () { try { (quantity <= 1) ? onRemoveFromCart() : onUpdateQuantity(quantity - 1); } catch(e) { onError(e.toString()); } }, tooltip: 'Quitar uno', padding: EdgeInsets.zero, constraints: const BoxConstraints()), // CORRECCIÓN: Añadir const
          Expanded(child: Text(quantity.toString(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
          IconButton(icon: Icon(Icons.add_circle_outline, color: Theme.of(context).primaryColor.withOpacity(0.9), size: 22), onPressed: () { try { onUpdateQuantity(quantity + 1); } catch(e) { onError(e.toString()); } }, tooltip: 'Añadir uno', padding: EdgeInsets.zero, constraints: const BoxConstraints()), // CORRECCIÓN: Añadir const
        ],
      ),
    ); // Devuelve Container
  }
} // Fin _ProductCard