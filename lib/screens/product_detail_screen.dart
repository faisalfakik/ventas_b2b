import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // NECESARIO
import 'package:share_plus/share_plus.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'dart:async';  // Para Timer

// Tus Modelos y Servicios (Verifica Paths y que usen modelo final)
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../services/cart_service.dart'; // NECESARIO
import '../services/wishlist_service.dart';
import '../services/analytics_service.dart';
import '../models/customer_model.dart' as cust;

// Tus Widgets y Pantallas (Verifica Paths)
import '../widgets/animated_add_button.dart'; // Asume que existe
import 'cart_screen.dart';
import 'image_gallery_screen.dart';
import 'related_products_screen.dart';


class ProductDetailScreen extends StatefulWidget {
  final Product product;
  // Ya no es necesario pasar ProductService, se obtendrá de Provider

  const ProductDetailScreen({
    Key? key,
    required this.product,
  }) : super(key: key);

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> with SingleTickerProviderStateMixin {


  // --- Estado Local ---
  int _quantity = 1;
  // _cartItemCount se leerá del CartService con Consumer/watch
  int _currentImageIndex = 0;
  bool _isInWishlist = false;
  double _userRating = 0;
  bool _isAddingToCart = false;
  bool _showReviewForm = false;
  bool _initialDataLoaded = false;

  // --- Controladores ---
  late TabController _tabController;
  late PageController _imagePageController;
  final TextEditingController _reviewController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  // --- Animaciones ---
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _imagePageController = PageController(); // initialPage se maneja en _loadInitialData o se deja en 0
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _quantityController.text = _quantity.toString();

    // Log de vista se mueve a didChangeDependencies para asegurar que AnalyticsService esté disponible
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialDataLoaded) {
      _loadInitialData();
      _initialDataLoaded = true;
      // Log Analytics aquí
      try {
        context.read<AnalyticsService>().logProductView(widget.product);
      } catch (e) {
        print("Error logging analytics: $e"); // Manejo básico si falla el provider
      }
    }
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    _tabController.dispose();
    _reviewController.dispose();
    _quantityController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // --- Carga de Datos Inicial ---
  Future<void> _loadInitialData() async {
    // Usa context.read para obtener servicios dentro de métodos de estado
    final cartService = context.read<CartService>();
    final productService = context.read<ProductService>();

    // Obtener cantidad inicial ANTES de las otras cargas
    final cartQuantity = cartService.getQuantityInCart(widget.product.id);
    if (mounted && cartQuantity > 0) {
      setState(() {
        _quantity = cartQuantity;
        _quantityController.text = _quantity.toString();
      });
    }

    // Cargar resto en paralelo
    await Future.wait([
      _loadWishlistStatus(),
      _loadUserRating(productService), // Pasar la instancia obtenida
    ]);
  }

  Future<void> _loadWishlistStatus() async {
    if (!mounted) return;
    try {
      final wishlistService = context.read<WishlistService>();
      final isInWishlist = await wishlistService.isProductInWishlist(widget.product.id);
      if (mounted) setState(() => _isInWishlist = isInWishlist);
    } catch (e) {
      print("Error cargando wishlist: $e");
      if(mounted) _showFeedbackSnackbar('Error al cargar estado de favoritos', isError: true);
    }
  }

  Future<void> _loadUserRating(ProductService pService) async {
    if (!mounted) return;
    try {
      final rating = await pService.getUserRatingForProduct(widget.product.id);
      if (mounted) setState(() => _userRating = rating);
    } catch (e) {
      print("Error cargando rating: $e");
      // No mostrar error al usuario por esto usualmente
    }
  }

  // --- Acciones de Usuario ---

  void _updateQuantity(int newQuantity) {
    if (newQuantity <= 0) return;
    final stockLimit = widget.product.stock;

    if (newQuantity > stockLimit) {
      _showFeedbackSnackbar('Cantidad máxima disponible: $stockLimit', isError: true);
      newQuantity = stockLimit;
    }
    if (mounted) {
      setState(() {
        _quantity = newQuantity;
        _quantityController.text = _quantity.toString();
      });
    }
  }

  Future<void> _toggleWishlist() async {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    final previousStatus = _isInWishlist;
    setState(() => _isInWishlist = !previousStatus);

    try {
      final wishlistService = context.read<WishlistService>();
      final success = await wishlistService.toggleWishlistStatus(widget.product.id);
      if (!success && mounted) {
        setState(() => _isInWishlist = previousStatus);
        _showFeedbackSnackbar('Error al actualizar favoritos', isError: true);
      } else if (success && mounted) {
        _showFeedbackSnackbar(_isInWishlist ? 'Agregado a favoritos' : 'Eliminado de favoritos');
        // Log Analytics
        if (_isInWishlist) {
          context.read<AnalyticsService>().logCustomEvent(
              name: 'add_to_wishlist',
              parameters: {'item_id': widget.product.id}
          );
        } else {
          context.read<AnalyticsService>().logCustomEvent(
              name: 'remove_from_wishlist',
              parameters: {'item_id': widget.product.id}
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInWishlist = previousStatus);
        _showFeedbackSnackbar('Error: ${e.toString()}', isError: true);
      }
    }
  }

  void _shareProduct() {
    // Crear un mensaje más completo para compartir
    final String productInfo = """
¡Mira este producto!
${widget.product.name}
${widget.product.description.substring(0, (widget.product.description.length > 100 ? 100 : widget.product.description.length))}...
Precio: \$${widget.product.salePrice.toStringAsFixed(2)} ${widget.product.isOnSale ? '(Oferta)' : ''}

Encuéntralo en nuestra app: [Link a tu app o producto si tienes deep linking]
""";

    Share.share(productInfo, subject: 'Mira este producto: ${widget.product.name}');
    context.read<AnalyticsService>().logShareProduct(productId: widget.product.id);
  }

  // MODIFICADO: Usa CartService y AnalyticsService via Provider
  Future<void> _addToCart() async {
    // ** USA EL GETTER CORRECTO: inStock **
    if (!widget.product.inStock) {
      _showFeedbackSnackbar('Producto sin stock disponible', isError: true);
      return;
    }
    if (_isAddingToCart) return;

    if (mounted) setState(() => _isAddingToCart = true);
    final cartService = context.read<CartService>();
    final analyticsService = context.read<AnalyticsService>();

    try {
      cartService.addOrUpdateCart(widget.product, quantity: _quantity);
      analyticsService.logAddToCart(widget.product, _quantity);

      if (mounted) {
        _animationController.forward().then((_) => _animationController.reverse());
        HapticFeedback.mediumImpact();
        _showFeedbackSnackbar('$_quantity × ${widget.product.name} en el carrito', isSuccess: true);
      }
    } catch (e) {
      if (mounted) _showFeedbackSnackbar('Error al añadir: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  // MODIFICADO: Usa ProductService y AnalyticsService via Provider
  Future<void> _submitReview() async {
    if (_reviewController.text.trim().isEmpty && _userRating == 0) {
      _showFeedbackSnackbar('Por favor, ingresa una calificación o comentario', isError: true);
      return;
    }
    if (_userRating == 0) {
      _showFeedbackSnackbar('Por favor, selecciona una calificación', isError: true);
      return;
    }

    final productService = context.read<ProductService>();
    final analyticsService = context.read<AnalyticsService>();

    // TODO: Mostrar indicador de carga
    try {
      await productService.submitProductReview(widget.product.id, _reviewController.text.trim(), _userRating);
      analyticsService.logCustomEvent(
          name: 'submit_review',
          parameters: {'item_id': widget.product.id, 'rating': _userRating}
      );
      if(mounted) {
        setState(() => _showReviewForm = false);
        _reviewController.clear();
        _showFeedbackSnackbar('¡Gracias por tu reseña!', isSuccess: true);
        // Opcional: Recargar datos para mostrar nuevo rating/review
        // _loadInitialData();
      }
    } catch (e) {
      if(mounted) _showFeedbackSnackbar('Error al enviar reseña: ${e.toString()}', isError: true);
    }
  }

  // MODIFICADO: Navega a CartScreen real
  void _navigateToCart() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
    // Ya no necesita .then(_loadCartData) si el AppBar usa Consumer
  }

  // MODIFICADO: Pasa productId y prefijo consistente
  void _openImageGallery() {
    final List<String> images = [widget.product.imageUrl, ...(widget.product.additionalImages ?? [])];
    if (images.isEmpty) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => ImageGalleryScreen(
          images: images,
          initialIndex: _currentImageIndex,
          productName: widget.product.name,
          productId: widget.product.id, // <-- Pasar ID
          heroTagPrefix: 'product_image_detail', // <-- Prefijo consistente
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  // Muestra el BottomSheet para ingresar cantidad
  void _showQuantityInputBottomSheet() {
    // Actualizar el controlador con la cantidad actual antes de mostrar
    _quantityController.text = _quantity.toString();
    // Guardar la cantidad actual por si cancela
    final initialQuantity = _quantity;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Para que el teclado no tape el sheet
      backgroundColor: Colors.transparent, // Fondo transparente para redondear esquinas
      builder: (context) => Padding( // Padding para que el teclado no pegue al sheet
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)), // Esquinas redondeadas
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ajustar al contenido
            children: [
              // Handle visual para indicar que se puede deslizar (opcional)
              Container(
                width: 40, height: 5,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 20),
              const Text('Ingresa la Cantidad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Solo números
                textAlign: TextAlign.center,
                autofocus: true,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                  ),
                  // Mostrar cajas solo si aplica y hay valor
                  suffixText: widget.product.unitsPerBox != null && _quantityController.text.isNotEmpty
                      ? '≈ ${((int.tryParse(_quantityController.text) ?? 0) / widget.product.unitsPerBox!).toStringAsFixed(1)} cajas'
                      : null,
                  suffixStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  hintText: '0', // Hint
                  counterText: "", // Ocultar contador por defecto
                ),
                maxLength: 4, // Límite razonable
                onChanged: (value) {
                  // Actualizar el cálculo de cajas en tiempo real
                  if (mounted) setState(() {});
                },
                onSubmitted: (_) => _confirmQuantityFromBottomSheet(initialQuantity), // Confirmar con Enter
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirmar Cantidad'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _confirmQuantityFromBottomSheet(initialQuantity),
                ),
              ),
              const SizedBox(height: 10), // Espacio adicional
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      // Si el usuario cierra el sheet sin confirmar,
      // y el texto no es un número válido, revertir al valor inicial.
      final int? parsedValue = int.tryParse(_quantityController.text);
      if (parsedValue == null || parsedValue <= 0) {
        if (mounted) {
          setState(() {
            // No actualizar _quantity aquí, _updateQuantity lo hace si confirma
            _quantityController.text = initialQuantity.toString();
          });
        }
      }
    });
  }

  void _confirmQuantityFromBottomSheet(int initialQuantity) {
    final inputValue = int.tryParse(_quantityController.text);
    if (inputValue != null && inputValue > 0) {
      _updateQuantity(inputValue); // Actualiza la cantidad principal
    } else {
      // Si el valor no es válido al confirmar, revertir al inicial
      if (mounted) {
        setState(() {
          _quantityController.text = initialQuantity.toString();
          // Opcional: Mostrar SnackBar de error
        });
      }
    }
    Navigator.pop(context); // Cerrar el BottomSheet
  }

  // Helper para mostrar Snackbars
  void _showFeedbackSnackbar(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? Colors.redAccent : (isSuccess ? Colors.green : null),
      margin: const EdgeInsets.fromLTRB(15, 5, 15, 75),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      action: (isSuccess && !isError && message.contains('carrito'))
          ? SnackBarAction(label: 'VER', textColor: Colors.white, onPressed: _navigateToCart)
          : null,
    ));
  }


  // --- Build Method Principal ---
  @override
  Widget build(BuildContext context) {
    // ** USA EL GETTER CORRECTO: inStock **
    final bool isInStock = widget.product.inStock;
    final List<String> images = [widget.product.imageUrl, ...(widget.product.additionalImages ?? [])];

    return Scaffold(
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            // Usa el getter isOnSale para el SliverAppBar
            _buildSliverAppBar(context, images, widget.product.isOnSale),
            SliverPersistentHeader(delegate: _SliverTabBarDelegate(_buildTabBar(context)), pinned: true),
            SliverPadding( // Usar SliverPadding en lugar de SliverFillRemaining para evitar errores de layout con ListView
                padding: EdgeInsets.zero,
                sliver: SliverList( // Usar SliverList para contenido variable en tabs
                    delegate: SliverChildListDelegate([
                      SizedBox( // Contenedor con altura fija o calculada para TabBarView
                        // Altura calculada: (altura pantalla - altura appbar colapsada - altura tabbar - altura bottombar - safearea top/bottom)
                        // O una altura fija grande si el contenido de las tabs es extenso
                        height: MediaQuery.of(context).size.height - kToolbarHeight - kTextTabBarHeight - (isInStock ? 80 : 80) - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildDetailsTabContent(context),
                            _buildSpecificationsTabContent(context),
                            _buildReviewsTabContent(context),
                          ],
                        ),
                      )
                    ])
                )
            ),
          ],
        ),
      ),
      bottomNavigationBar: isInStock
          ? _buildBottomActionBar(context)
          : _buildOutOfStockBar(context),
    );
  }

  // --- Widgets Constructores para Subsecciones (Refinados) ---

  Widget _buildSliverAppBar(BuildContext context, List<String> images, bool hasDiscount) {
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: 320.0, // Ajustar si es necesario
      pinned: true,
      stretch: true,
      backgroundColor: theme.colorScheme.surface, // Usar color de fondo del tema
      foregroundColor: theme.colorScheme.onSurface, // Color de iconos/texto apropiado
      elevation: 1,
      leading: _buildAppBarButton(context, Icons.arrow_back, 'Volver', () => Navigator.of(context).pop()),
      actions: [
        _buildAppBarButton(context, _isInWishlist ? Icons.favorite : Icons.favorite_border_outlined, 'Favoritos', _toggleWishlist, iconColor: _isInWishlist ? theme.colorScheme.error : Colors.white), // Color error del tema
        _buildAppBarButton(context, Icons.share_outlined, 'Compartir', _shareProduct),
        // --- Icono Carrito con Consumer<CartService> ---
        Consumer<CartService>(
          builder: (context, cartService, child) {
            final itemCount = cartService.totalQuantity; // Total de unidades
            return Stack(
              alignment: Alignment.center,
              children: [
                _buildAppBarButton(context, Icons.shopping_cart_outlined, 'Ver Carrito (${cartService.uniqueItemCount})', _navigateToCart),
                if (itemCount > 0)
                  Positioned(
                    right: 10, top: 10,
                    child: Container(
                      padding: const EdgeInsets.all(2),
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
          },
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: GestureDetector(
          onTap: _openImageGallery,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Carrusel de Imágenes
              PageView.builder(
                controller: _imagePageController,
                itemCount: images.length,
                onPageChanged: (index) { if (mounted) setState(() => _currentImageIndex = index); },
                itemBuilder: (context, index) {
                  // HERO TAG CONSISTENTE
                  final heroTag = 'product_image_detail_${widget.product.id}_$index';
                  return Hero(
                    tag: heroTag,
                    child: CachedNetworkImage(
                      imageUrl: images[index],
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 60)),
                    ),
                  );
                },
              ),
              // Gradiente inferior para indicadores
              Positioned(
                bottom: 0, left: 0, right: 0, height: 60,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                    ),
                  ),
                ),
              ),
              // Indicadores de página
              if (images.length > 1) Positioned(bottom: 15, left: 0, right: 0, child: _buildPageIndicatorRow(images.length)),
              // Etiqueta Descuento
              if (hasDiscount) Positioned(top: MediaQuery.of(context).padding.top + 10, right: 16, child: _buildDiscountChip()),
              // Botón Galería
              Positioned(bottom: 45, right: 16, child: _buildGalleryButton()),
            ],
          ),
        ),
      ),
    );
  }

  // Helper para botones del AppBar
  Widget _buildAppBarButton(BuildContext context, IconData icon, String tooltip, VoidCallback onPressed, {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.all(4.0), // Reducir padding para que quepan más
      child: CircleAvatar(
        radius: 18, // Ligeramente más pequeño
        backgroundColor: Colors.black.withOpacity(0.4),
        child: IconButton(
          iconSize: 20, // Icono más pequeño
          icon: Icon(icon, color: iconColor ?? Colors.white),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }

  // Helper para indicadores de página
  Widget _buildPageIndicatorRow(int imageCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(imageCount, (i) => _buildPageIndicator(i == _currentImageIndex)),
    );
  }

  Widget _buildPageIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 8.0,
      width: isActive ? 24.0 : 8.0,
      decoration: BoxDecoration(
        color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  // Helper para chip de descuento
  Widget _buildDiscountChip() {
    return Chip(
      label: Text(
        '-${widget.product.discountPercentage!.round()}%',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
      backgroundColor: Colors.redAccent,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
    );
  }

  // Helper para botón de galería
  Widget _buildGalleryButton() {
    return CircleAvatar(
      backgroundColor: Colors.black.withOpacity(0.4),
      radius: 18,
      child: IconButton(
        icon: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
        tooltip: 'Ver Galería',
        onPressed: _openImageGallery,
      ),
    );
  }

  TabBar _buildTabBar(BuildContext context) {
    // TabBar más estilizada
    final theme = Theme.of(context);
    return TabBar(
      controller: _tabController,
      labelColor: theme.primaryColor,
      unselectedLabelColor: Colors.grey.shade700,
      indicatorColor: theme.primaryColor,
      indicatorWeight: 3,
      labelPadding: const EdgeInsets.symmetric(horizontal: 10), // Padding entre tabs
      tabs: const [
        Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.info_outline, size: 18), SizedBox(width: 8), Text('Detalles')])),
        Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.list_alt, size: 18), SizedBox(width: 8), Text('Ficha')])),
        Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.reviews_outlined, size: 18), SizedBox(width: 8), Text('Reseñas')])),
      ],
    );
  }

  // --- Contenido de las Pestañas (Refactorizado y Limpio) ---
  Widget _buildDetailsTabContent(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;
    final bool isInStock = product.inStock;
    final bool hasDiscount = product.isOnSale;
    final double displayPrice = product.salePrice;
    final double originalPrice = product.price;
    final bool hasUnitsPerBox = product.unitsPerBox != null && product.unitsPerBox! > 1;
    final int unitsPerBox = product.unitsPerBox ?? 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre y Precio (usando theme)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: Text(
                    product.name,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  )
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasDiscount)
                    Text(
                      '\$${originalPrice.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey.shade600
                      ),
                    ),
                  Text(
                    '\$${displayPrice.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildRatingSummary(context),
          const SizedBox(height: 16),
          _buildInfoChips(context, isInStock, hasUnitsPerBox, unitsPerBox),
          const SizedBox(height: 20),
          _buildDescriptionCard(context),
          if (isInStock) ...[
            const SizedBox(height: 24),
            _buildQuantityCard(context, unitsPerBox, hasUnitsPerBox),
          ],
          const SizedBox(height: 24),
          _buildRelatedProductsSection(context),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRatingSummary(BuildContext context) {
    final theme = Theme.of(context);
    final hasRating = widget.product.averageRating != null && widget.product.averageRating! > 0;
    final rating = widget.product.averageRating ?? 0.0;
    final reviewCount = widget.product.reviewCount ?? 0;

    return Row(
      children: [
        RatingBar.builder(
          initialRating: rating,
          minRating: 0,
          direction: Axis.horizontal,
          allowHalfRating: true,
          itemCount: 5,
          itemSize: 20,
          ignoreGestures: true, // No interactivo aquí
          itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber.shade700),
          onRatingUpdate: (_) {}, // No usado porque ignoreGestures es true
        ),
        const SizedBox(width: 8),
        Text(
          hasRating
              ? '${rating.toStringAsFixed(1)} ($reviewCount ${reviewCount == 1 ? 'reseña' : 'reseñas'})'
              : 'Sin reseñas',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildInfoChips(BuildContext context, bool isInStock, bool hasUnitsPerBox, int unitsPerBox) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          avatar: Icon(
            isInStock ? Icons.check_circle_outline : Icons.remove_circle_outline,
            size: 16,
            color: isInStock ? Colors.green.shade700 : Colors.red.shade700,
          ),
          label: Text(
            isInStock ? 'En stock (${widget.product.stock})' : 'Agotado',
            style: TextStyle(
              color: isInStock ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: isInStock ? Colors.green.shade50 : Colors.red.shade50,
          visualDensity: VisualDensity.compact,
        ),
        if (widget.product.category.isNotEmpty)
          Chip(
            avatar: Icon(_getCategoryIcon(widget.product.category), size: 16, color: Colors.blue.shade700),
            label: Text(widget.product.category, style: TextStyle(color: Colors.blue.shade700)),
            backgroundColor: Colors.blue.shade50,
            visualDensity: VisualDensity.compact,
          ),
        if (hasUnitsPerBox)
          Chip(
            avatar: const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.purple),
            label: Text('$unitsPerBox por caja', style: const TextStyle(color: Colors.purple)),
            backgroundColor: Colors.purple.shade50,
            visualDensity: VisualDensity.compact,
          ),
        if (widget.product.brand != null && widget.product.brand!.isNotEmpty)
          Chip(
            avatar: const Icon(Icons.business_outlined, size: 16, color: Colors.teal),
            label: Text(widget.product.brand!, style: const TextStyle(color: Colors.teal)),
            backgroundColor: Colors.teal.shade50,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _buildDescriptionCard(BuildContext context) {
    return _buildSectionCard(
      context,
      title: 'Descripción',
      icon: Icons.description_outlined,
      content: Text(
        widget.product.description.isEmpty ? 'Sin descripción.' : widget.product.description,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
      ),
    );
  }

  Widget _buildQuantityCard(BuildContext context, int unitsPerBox, bool hasUnitsPerBox) {
    return _buildSectionCard(
        context,
        title: 'Cantidad',
        icon: Icons.shopping_bag_outlined,
        content: Column(
          children: [
            // Botón Personalizar (abre BottomSheet)
            Center(child: _buildCustomQuantityButton()),
            const SizedBox(height: 16),
            // Cantidad Seleccionada
            Center(child: Text('Seleccionado: $_quantity', style: Theme.of(context).textTheme.titleMedium)),
            if (hasUnitsPerBox) ...[
              const SizedBox(height: 16),
              _buildUnitsPerBoxInfo(context, unitsPerBox),
            ],
          ],
        )
    );
  }

  Widget _buildRelatedProductsSection(BuildContext context) {
    final productService = context.read<ProductService>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Productos Relacionados',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Ver todos'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RelatedProductsScreen(
                    category: widget.product.category,
                    currentProductId: widget.product.id,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: FutureBuilder<List<Product>>(
            future: productService.getRelatedProducts(widget.product),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No hay productos relacionados'));
              }

              // Lista horizontal de productos relacionados
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final relatedProduct = snapshot.data![index];
                  return SizedBox(
                    width: 160,
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(product: relatedProduct),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: CachedNetworkImage(
                                imageUrl: relatedProduct.imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                placeholder: (context, url) => Container(color: Colors.grey[200]),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.error_outline, color: Colors.grey),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    relatedProduct.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '\$${relatedProduct.salePrice.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: theme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpecificationsTabContent(BuildContext context) {
    // Reutilizar el widget de item de especificación
    final theme = Theme.of(context);
    final specs = {
      'Marca': widget.product.brand,
      'Modelo': widget.product.model,
      'SKU': widget.product.sku ?? widget.product.id,
      'Categoría': widget.product.category,
      'Garantía': widget.product.warranty,
      if (widget.product.unitsPerBox != null) 'Unidades/Caja': '${widget.product.unitsPerBox}',
      'Dimensiones': widget.product.dimensions,
      'Peso': widget.product.weight != null ? '${widget.product.weight} kg' : null,
      // Añade más campos técnicos si los tienes
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.product.technicalInfo != null && widget.product.technicalInfo!.isNotEmpty) ...[
          _buildSectionCard(context, title: 'Ficha Técnica', icon: Icons.settings_outlined,
            content: Text(widget.product.technicalInfo!, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
          ),
          const SizedBox(height: 20),
        ],
        _buildSectionCard(
            context, title: 'Información Adicional', icon: Icons.list_alt_outlined,
            content: Column(
              children: specs.entries
                  .where((entry) => entry.value != null && entry.value!.isNotEmpty) // Mostrar solo si hay valor
                  .map((entry) => _buildSpecItem(entry.key, entry.value!))
                  .expand((widget) => [widget, const Divider(height: 0.5, indent: 16, endIndent: 16)]) // Añadir divisores
                  .toList()..removeLast(), // Quitar el último divisor
            )
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildReviewsTabContent(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildReviewSummaryCard(context), // Card con rating promedio y botón
        if (_showReviewForm) ...[ // Mostrar/ocultar formulario
          const SizedBox(height: 16),
          _buildReviewFormCard(context),
        ],
        const SizedBox(height: 24),
        Padding( // Título para la lista de reseñas
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text('Reseñas de Clientes', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        _buildReviewsList(context), // FutureBuilder para la lista
      ],
    );
  }

  Widget _buildReviewSummaryCard(BuildContext context) {
    final theme = Theme.of(context);
    final hasRating = widget.product.averageRating != null && widget.product.averageRating! > 0;
    final rating = widget.product.averageRating ?? 0.0;
    final reviewCount = widget.product.reviewCount ?? 0;

    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasRating ? rating.toStringAsFixed(1) : '0.0',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: hasRating ? Colors.amber.shade800 : Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '$reviewCount ${reviewCount == 1 ? 'reseña' : 'reseñas'}',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      RatingBar.builder(
                        initialRating: rating,
                        minRating: 0,
                        direction: Axis.horizontal,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemSize: 24,
                        ignoreGestures: true,
                        itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber.shade700),
                        onRatingUpdate: (_) {},
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasRating ? 'Valoración de los clientes' : 'Sin reseñas todavía',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _showReviewForm = !_showReviewForm);
                },
                child: Text(_showReviewForm ? 'Cancelar' : 'Escribir una reseña'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewFormCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu Valoración',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Center(
              child: RatingBar.builder(
                initialRating: _userRating,
                minRating: 0,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemSize: 40,
                itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber.shade700),
                onRatingUpdate: (rating) {
                  if (mounted) setState(() => _userRating = rating);
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tu Comentario (opcional)',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Comparte tu experiencia con este producto...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitReview,
                child: const Text('Enviar Reseña'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsList(BuildContext context) {
    final productService = context.read<ProductService>();
    final theme = Theme.of(context);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: productService.getProductReviews(widget.product.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.message_outlined, color: Colors.grey, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Aún no hay reseñas para este producto',
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() => _showReviewForm = true);
                  },
                  child: const Text('Sé el primero en opinar'),
                ),
              ],
            ),
          );
        }

        // Lista de reseñas
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final review = snapshot.data![index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.grey.shade200,
                              child: const Icon(Icons.person_outline),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              review['userName'] ?? 'Usuario',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          review['date'] ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    RatingBar.builder(
                      initialRating: (review['rating'] ?? 0).toDouble(),
                      minRating: 0,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      itemSize: 16,
                      ignoreGestures: true,
                      itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber.shade700),
                      onRatingUpdate: (_) {},
                    ),
                    const SizedBox(height: 8),
                    Text(review['comment'] ?? ''),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Widgets Reutilizables Menores ---
  Widget _buildSectionCard(BuildContext context, {required String title, required IconData icon, required Widget content}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: theme.primaryColor),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))
            ]),
            const Divider(height: 24),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildSpecItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey.shade900)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Precio Total
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total', style: TextStyle(color: Colors.grey)),
              Text(
                '\$${(widget.product.salePrice * _quantity).toStringAsFixed(2)}',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Botón Añadir
          Expanded(
            child: AnimatedAddButton(
              onPressed: _addToCart,
              isLoading: _isAddingToCart,
              quantity: _quantity,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildOutOfStockBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Producto sin stock disponible',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              // Opción para notificar cuando esté disponible (implementar según necesidad)
              _showFeedbackSnackbar('Te notificaremos cuando esté disponible', isSuccess: true);
            },
            child: const Text('Notificarme cuando esté disponible'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomQuantityButton() {
    return ElevatedButton.icon(
      onPressed: _showQuantityInputBottomSheet,
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Personalizar Cantidad'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildUnitsPerBoxInfo(BuildContext context, int unitsPerBox) {
    final boxesCount = (_quantity / unitsPerBox).ceil();
    final remainingUnits = _quantity % unitsPerBox;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, color: Colors.purple.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Información de Embalaje',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Este producto viene en cajas de $unitsPerBox unidades.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            remainingUnits == 0
                ? 'Tu pedido actual son exactamente $boxesCount ${boxesCount == 1 ? 'caja' : 'cajas'} completas.'
                : 'Tu pedido actual son $boxesCount ${boxesCount == 1 ? 'caja' : 'cajas'} ($remainingUnits ${remainingUnits == 1 ? 'unidad suelta' : 'unidades sueltas'}).',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    // Asignar iconos según la categoría
    final lowerCategory = category.toLowerCase();
    if (lowerCategory.contains('split') || lowerCategory.contains('aire')) return Icons.ac_unit;
    if (lowerCategory.contains('ventana')) return Icons.window;
    if (lowerCategory.contains('portátil')) return Icons.move_to_inbox;
    if (lowerCategory.contains('deshumidificador')) return Icons.water_drop_outlined;
    if (lowerCategory.contains('congelador')) return Icons.kitchen;
    if (lowerCategory.contains('protector')) return Icons.electrical_services;
    if (lowerCategory.contains('mantenimiento')) return Icons.build;
    return Icons.category; // Icono por defecto
  }
}

// --- Clase _SliverTabBarDelegate (Sin cambios) ---
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
        height: 55, // Altura incluyendo indicador
        decoration: BoxDecoration(
          color: Theme.of(context).canvasColor,
          border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1.0)),
        ),
        child: tabBar
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}