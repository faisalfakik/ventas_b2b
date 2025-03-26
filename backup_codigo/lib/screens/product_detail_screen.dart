import 'package:flutter/material.dart';
import 'dart:async';
import '../models/product_model.dart';
import '../services/product_service.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({Key? key, required this.product}) : super(key: key);

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ProductService _productService = ProductService();
  int quantity = 1;
  int _cartItemCount = 0;
  int _currentImageIndex = 0;
  bool _showTechnicalInfo = false;
  late PageController _imagePageController;

  // Timer para auto-actualización del carrito
  Timer? _autoAddToCartTimer;

  @override
  void initState() {
    super.initState();
    _loadCartItemCount();
    _imagePageController = PageController();

    // Verifica si el producto ya está en el carrito
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cartQuantity = _productService.getQuantityInCart(widget.product.id);
      if (cartQuantity > 0) {
        setState(() {
          quantity = cartQuantity;
        });
      }
    });
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    _autoAddToCartTimer?.cancel(); // Cancelar el timer al salir
    super.dispose();
  }

  void _loadCartItemCount() {
    setState(() {
      _cartItemCount = _productService.getCartItems().length;
    });
  }

  // Método para actualizar la cantidad e iniciar el timer
  void _updateQuantity(int newQuantity) {
    setState(() {
      quantity = newQuantity;
    });

    // Cancelar timer anterior si existe
    _autoAddToCartTimer?.cancel();

    // Configurar nuevo timer para añadir al carrito después de 2 segundos
    _autoAddToCartTimer = Timer(const Duration(seconds: 2), () {
      _addToCart(showSnackbar: false); // Añadir sin mostrar notificación
    });
  }

  void _addToCart({bool showSnackbar = true}) {
    if (!widget.product.isInStock) return;

    try {
      // Resetear y agregar la nueva cantidad
      _productService.removeFromCart(widget.product.id);
      _productService.addToCart(widget.product, quantity: quantity);

      // Actualizar contador del carrito
      _loadCartItemCount();

      // Mostrar mensaje de confirmación solo si se solicita
      if (showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$quantity unidades de ${widget.product.name} añadidas al carrito'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            action: SnackBarAction(
              label: 'Ver Carrito',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartScreen()),
                ).then((_) => _loadCartItemCount());
              },
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDiscount = widget.product.isOnSale;
    final displayPrice = hasDiscount ? widget.product.salePrice : widget.product.price;
    final totalPrice = displayPrice * quantity;

    // Lista de imágenes (principal + adicionales)
    final List<String> images = [
      widget.product.imageUrl,
      ...(widget.product.additionalImages ?? []),
    ];

    // Determinar si el producto tiene unidades por caja
    final bool hasUnitsPerBox = widget.product.unitsPerBox != null && widget.product.unitsPerBox! > 1;
    final int unitsPerBox = widget.product.unitsPerBox ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            fontFamily: 'Myriad Pro',
          ),
        ),
        elevation: 0,
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CartScreen()),
                  ).then((_) => _loadCartItemCount());
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
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 1,
                          )
                        ]
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
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carrusel de imágenes mejorado
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Imágenes
                  PageView.builder(
                    controller: _imagePageController,
                    itemCount: images.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentImageIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return Hero(
                        tag: '${widget.product.id}_image_$index',
                        child: Image.network(
                          images[index],
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.image, size: 80, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),

                  // Indicadores de página
                  if (images.length > 1)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          images.length,
                              (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _currentImageIndex == index ? 12 : 8,
                            height: _currentImageIndex == index ? 12 : 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == index
                                  ? Colors.green.shade700
                                  : Colors.grey.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Etiqueta de descuento
                  if (hasDiscount)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '-${widget.product.discountPercentage!.round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Miniaturas de imágenes
            if (images.length > 1)
              Container(
                height: 80,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        _imagePageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        width: 60,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _currentImageIndex == index
                                ? Colors.green.shade700
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _currentImageIndex == index ? [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ] : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            images[index],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.image, color: Colors.grey),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre y precio con mejor diseño
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.product.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                            fontFamily: 'Myriad Pro',
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (hasDiscount)
                            Text(
                              '\$${widget.product.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey.shade600,
                                fontSize: 16,
                                fontFamily: 'Myriad Pro',
                              ),
                            ),
                          Text(
                            '\$${displayPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: hasDiscount ? Colors.red.shade700 : Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              fontFamily: 'Myriad Pro',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Categoría y stock con mejor diseño
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          widget.product.category,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Myriad Pro',
                          ),
                        ),
                        backgroundColor: Colors.blue.shade50,
                        side: BorderSide(color: Colors.blue.shade100),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        avatar: Icon(
                          _getCategoryIcon(widget.product.category),
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      Chip(
                        label: Text(
                          'Stock: ${widget.product.stock}',
                          style: TextStyle(
                            color: widget.product.isInStock ? Colors.black87 : Colors.white,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Myriad Pro',
                          ),
                        ),
                        backgroundColor: widget.product.isInStock
                            ? Colors.green.shade50
                            : Colors.red.shade400,
                        side: BorderSide(
                          color: widget.product.isInStock
                              ? Colors.green.shade200
                              : Colors.red.shade500,
                        ),
                        avatar: Icon(
                          widget.product.isInStock ? Icons.inventory_2 : Icons.inventory_2_outlined,
                          size: 16,
                          color: widget.product.isInStock ? Colors.green.shade700 : Colors.white,
                        ),
                      ),
                      if (hasUnitsPerBox)
                        Chip(
                          label: Text(
                            '${unitsPerBox} unid/caja',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Myriad Pro',
                            ),
                          ),
                          backgroundColor: Colors.amber.shade50,
                          side: BorderSide(color: Colors.amber.shade200),
                          avatar: Icon(
                            Icons.inventory,
                            size: 16,
                            color: Colors.amber.shade700,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Descripción con estilo mejorado
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.description_outlined, size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text(
                              'Descripción',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Myriad Pro',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.product.description,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            fontFamily: 'Myriad Pro',
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Ficha técnica (si está disponible) con diseño mejorado
                  if (widget.product.technicalInfo != null)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _showTechnicalInfo = !_showTechnicalInfo;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Icon(Icons.settings_outlined, size: 20, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Ficha Técnica',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Myriad Pro',
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: _showTechnicalInfo
                                          ? Colors.green.shade50
                                          : Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      _showTechnicalInfo
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      color: _showTechnicalInfo
                                          ? Colors.green.shade700
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedCrossFade(
                            firstChild: Container(height: 0),
                            secondChild: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                widget.product.technicalInfo!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                  fontFamily: 'Myriad Pro',
                                ),
                              ),
                            ),
                            crossFadeState: _showTechnicalInfo
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 300),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Sección de cantidad con diseño mejorado
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_bag_outlined, size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text(
                              'Cantidad:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Myriad Pro',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Botones de cantidad predefinida con diseño mejorado
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildQuantityButton(1),
                            _buildQuantityButton(5),
                            _buildQuantityButton(10),
                            _buildQuantityButton(50),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Control de cantidad con + y - (mejorado visualmente)
                        Row(
                          children: [
                            const Text(
                              "Ajustar cantidad:",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Myriad Pro',
                              ),
                            ),
                            const Spacer(),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  InkWell(
                                    onTap: quantity > 1
                                        ? () => _updateQuantity(quantity - 1)
                                        : null,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: quantity > 1
                                            ? Colors.green.shade50
                                            : Colors.grey.shade100,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(7),
                                          bottomLeft: Radius.circular(7),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.remove,
                                        size: 20,
                                        color: quantity > 1
                                            ? Colors.green.shade700
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 60,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    alignment: Alignment.center,
                                    child: Text(
                                      quantity.toString(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Myriad Pro',
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _updateQuantity(quantity + 1),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(7),
                                          bottomRight: Radius.circular(7),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.add,
                                        size: 20,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Campo para ingresar cantidad personalizada
                        TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Cantidad personalizada',
                            labelStyle: TextStyle(
                              fontFamily: 'Myriad Pro',
                              color: Colors.grey.shade700,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                            ),
                            prefixIcon: const Icon(Icons.edit),
                            hintText: 'Ingrese cantidad exacta',
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              final newQuantity = int.tryParse(value);
                              if (newQuantity != null && newQuantity > 0) {
                                _updateQuantity(newQuantity);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  // Si el producto se vende por caja, mostrar información adicional
                  if (hasUnitsPerBox) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.inventory_2, color: Colors.amber.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Este producto se vende en cajas de $unitsPerBox unidades',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Myriad Pro',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text(
                                      'Cajas completas',
                                      style: TextStyle(
                                        fontFamily: 'Myriad Pro',
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${quantity ~/ unitsPerBox}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.amber.shade800,
                                        fontFamily: 'Myriad Pro',
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  height: 40,
                                  width: 1,
                                  color: Colors.amber.shade200,
                                ),
                                Column(
                                  children: [
                                    const Text(
                                      'Unidades adicionales',
                                      style: TextStyle(
                                        fontFamily: 'Myriad Pro',
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${quantity % unitsPerBox}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.amber.shade800,
                                        fontFamily: 'Myriad Pro',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Total del producto con diseño mejorado
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Myriad Pro',
                              ),
                            ),
                            Text(
                              'Precio × Cantidad',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontFamily: 'Myriad Pro',
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '\$${totalPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                            fontFamily: 'Myriad Pro',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Espacio para evitar que el FAB tape contenido
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
      // Botón flotante mejorado y más compacto
      floatingActionButton: Container(
        height: 50,
        width: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: widget.product.isInStock
                  ? Colors.green.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: widget.product.isInStock ? _addToCart : null,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: widget.product.isInStock ? Colors.green.shade700 : Colors.grey.shade400,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          icon: const Icon(Icons.add_shopping_cart, size: 20),
          label: const Text(
            'Agregar al carrito',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFamily: 'Myriad Pro',
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // Método para obtener íconos según categoría
  IconData _getCategoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'SPLIT':
        return Icons.ac_unit;
      case 'AIRE DE VENTANA':
        return Icons.window;
      case 'AIRES PORTÁTILES':
        return Icons.straighten;
      case 'DESHUMIDIFICADORES':
        return Icons.water_drop;
      case 'CONGELADORES':
        return Icons.kitchen;
      case 'PROTECTORES':
        return Icons.security;
      case 'MANTENIMIENTO':
        return Icons.build;
      case 'COMPRESORES':
        return Icons.compress;
      case 'TARJETAS':
        return Icons.memory;
      case 'TURBINAS':
        return Icons.air;
      default:
        if (category.contains('AIRE')) return Icons.ac_unit;
        return Icons.category;
    }
  }

  Widget _buildQuantityButton(int value) {
    bool isSelected = quantity == value;
    return ElevatedButton(
      onPressed: () => _updateQuantity(value),
      style: ElevatedButton.styleFrom(
        elevation: isSelected ? 2 : 0,
        backgroundColor: isSelected ? Colors.green.shade700 : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.green.shade700,
        side: BorderSide(color: isSelected ? Colors.green.shade700 : Colors.grey.shade300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Text(
        '$value',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontFamily: 'Myriad Pro',
        ),
      ),
    );
  }
}