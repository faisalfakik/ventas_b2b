import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_model.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<Cart>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrito de Compras'),
        actions: [
          if (cart.itemCount > 0)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('¿Vaciar carrito?'),
                    content: const Text('Esta acción eliminará todos los productos del carrito.'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () {
                          cart.clear();
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Aceptar', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: cart.itemCount == 0
          ? const Center(
        child: Text(
          'El carrito está vacío',
          style: TextStyle(fontSize: 18),
        ),
      )
          : Column(
        children: [
          // Resumen del pedido
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Productos: ${cart.uniqueItemCount}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Unidades: ${cart.itemCount}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                Text(
                  'Total: \$${cart.totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          // Lista de productos
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cart.items.length,
              itemBuilder: (ctx, index) {
                final cartItem = cart.items.values.elementAt(index);
                return _buildCartItem(context, cartItem, cart);
              },
            ),
          ),
          // Botón de checkout
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: cart.itemCount > 0
                  ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CheckoutScreen(),
                  ),
                );
              }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Continuar compra',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, CartItem cartItem, Cart cart) {
    final price = cartItem.discountPercentage != null
        ? cartItem.price * (1 - (cartItem.discountPercentage! / 100))
        : cartItem.price;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image: NetworkImage(cartItem.imageUrl),
                  onError: (_, __) => const Icon(Icons.image, size: 40),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Detalles
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cartItem.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (cartItem.discountPercentage != null)
                    Row(
                      children: [
                        Text(
                          '\$${cartItem.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '\$${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '-${cartItem.discountPercentage!.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      '\$${price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Control de cantidad
                  Row(
                    children: [
                      _buildQuantityButton(
                        icon: Icons.remove,
                        onPressed: () {
                          cart.removeSingleItem(cartItem.id);
                        },
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        width: 50,
                        child: Text(
                          '${cartItem.quantity}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildQuantityButton(
                        icon: Icons.add,
                        onPressed: () {
                          cart.updateItemQuantity(cartItem.id, cartItem.quantity + 1);
                        },
                      ),
                      const Spacer(),
                      // Eliminar ítem
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          cart.removeItem(cartItem.id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Precio total
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '\$${cartItem.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.green.shade700,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }
}