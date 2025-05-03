import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'product_catalog_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'store_seller_screen.dart';
import 'package:provider/provider.dart';
import 'package:your_app/providers/cart.dart';
import 'package:your_app/models/product.dart';

class RouterScreen extends StatefulWidget {
  const RouterScreen({Key? key}) : super(key: key);

  @override
  _RouterScreenState createState() => _RouterScreenState();
}

class _RouterScreenState extends State<RouterScreen> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [
    const HomeScreen(),
    const ProductCatalogScreen(isAdmin: false),  // Vista de cliente
    const CartScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Método para navegar a la pantalla de vendedor de tienda
  void navigateToStoreSeller(String storeId, String sellerId, String storeName, String sellerName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoreSellerScreen(
          storeId: storeId,
          sellerId: sellerId,
          storeName: storeName,
          sellerName: sellerName,
        ),
      ),
    );
  }

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

  void _addToCart(Product product) {
    final cart = Provider.of<Cart>(context, listen: false);
    if (cart != null) {
      cart.addProduct(product);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PRUEBA APPBAR MINIMO')), // NUEVO APPBAR SIMPLE
      body: const Center(child: Text('PRUEBA CUERPO MINIMO')), // Mantenemos cuerpo simple
      floatingActionButton: FloatingActionButton.extended(
        // ... código del FAB ...
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Catálogo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Carrito',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        onTap: _onItemTapped,
      ),
    );
  }
}