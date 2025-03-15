import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../models/cart_model.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({Key? key, required this.product}) : super(key: key);

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int quantity = 1;

  @override
  void initState() {
    super.initState();
    // Verifica si el producto ya está en el carrito
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cart = Provider.of<Cart>(context, listen: false);
      final cartItem = cart.items[widget.product.id];
      if (cartItem != null) {
        setState(() {
          quantity = cartItem.quantity;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del producto
            SizedBox(
              width: double.infinity,
              height: 250,
              child: Image.network(
                widget.product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.image, size: 80, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre y precio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.product.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (widget.product.discountPercentage != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${widget.product.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '\$${widget.product.salePrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          '\$${widget.product.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Categoría y stock
                  Row(
                    children: [
                      Chip(
                        label: Text(widget.product.category),
                        backgroundColor: Colors.blue.shade100,
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          'Stock: ${widget.product.stock}',
                          style: TextStyle(
                            color: widget.product.isInStock ? Colors.black : Colors.white,
                          ),
                        ),
                        backgroundColor: widget.product.isInStock
                            ? Colors.green.shade100
                            : Colors.red.shade300,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Descripción
                  const Text(
                    'Descripción',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.description,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // SECCIÓN NUEVA: Cantidad y agregado al carrito
                  const Text(
                    'Cantidad:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botones de cantidad predefinida
                  Row(
                    children: [
                      _buildQuantityButton(1),
                      _buildQuantityButton(5),
                      _buildQuantityButton(10),
                      _buildQuantityButton(50),
                      // Campo para ingresar cantidad personalizada
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Personalizada',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                final newQuantity = int.tryParse(value);
                                if (newQuantity != null && newQuantity > 0) {
                                  setState(() {
                                    quantity = newQuantity;
                                  });
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Control de cantidad más grande
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        iconSize: 32,
                        onPressed: quantity > 1
                            ? () {
                          setState(() {
                            quantity--;
                          });
                        }
                            : null,
                      ),
                      Container(
                        width: 80,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          quantity.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        iconSize: 32,
                        onPressed: () {
                          setState(() {
                            quantity++;
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Total del producto
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${((widget.product.discountPercentage != null ? widget.product.salePrice : widget.product.price) * quantity).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Botón de agregar al carrito
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: widget.product.isInStock
                          ? () {
                        // Añadir al carrito con la cantidad seleccionada
                        final cart = Provider.of<Cart>(context, listen: false);
                        // Limpiar el carrito para este producto y agregar con nueva cantidad
                        cart.removeItem(widget.product.id);
                        for (var i = 0; i < quantity; i++) {
                          cart.addProduct(widget.product);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${quantity} unidades de ${widget.product.name} añadidas al carrito'),
                            duration: const Duration(seconds: 2),
                            action: SnackBarAction(
                              label: 'Ver Carrito',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const CartScreen()),
                                );
                              },
                            ),
                          ),
                        );
                      }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Agregar al Carrito',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildQuantityButton(int value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            quantity = value;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: quantity == value ? Colors.green.shade700 : Colors.white,
          foregroundColor: quantity == value ? Colors.white : Colors.green.shade700,
          side: BorderSide(color: Colors.green.shade700),
        ),
        child: Text('$value'),
      ),
    );
  }
}