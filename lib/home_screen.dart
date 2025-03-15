import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_model.dart';
import 'cart_screen.dart';
import 'product_catalog_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GTRONIC - Catálogo B2B',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProductCatalogScreen()),
              );
            },
          ),
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner promocional
            Container(
              height: 180,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          '¡Bienvenido a GTRONIC!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Explora nuestro catálogo completo de productos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'PRODUCTOS DE CALIDAD AL MEJOR PRECIO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: ElevatedButton(
                      onPressed: () {
                        // Ver todos los productos
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProductCatalogScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Ver Todos'),
                    ),
                  ),
                ],
              ),
            ),

            // Sección de Ofertas Especiales
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🔥 Ofertas Especiales',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Ver todas las ofertas
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProductCatalogScreen(),
                            ),
                          );
                        },
                        child: const Text('Ver Todas'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildOfferCard(
                          context,
                          'MAQUINA DE CAFÉ "2 EN 1"',
                          '29.00',
                          '19.90',
                          Colors.red.shade100,
                          Colors.red,
                          Icons.coffee_maker,
                        ),
                        _buildOfferCard(
                          context,
                          'EXTRACTOR DE CITRICOS 0.7L',
                          '10.90',
                          '8.90',
                          Colors.orange.shade100,
                          Colors.orange,
                          Icons.blender,
                        ),
                        _buildOfferCard(
                          context,
                          'BALANZA DIGITAL DE COCINA',
                          '5.00',
                          '2.99',
                          Colors.green.shade100,
                          Colors.green,
                          Icons.scale,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Línea separadora
            const Divider(thickness: 1, height: 32),

            // Categorías Principales
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Categorías',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),

            // Grid de categorías
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildCategoryCard(
                    context,
                    'Aires Acondicionados',
                    Icons.ac_unit,
                    Colors.blue.shade700,
                    'SPLIT',
                  ),
                  _buildCategoryCard(
                    context,
                    'Ventiladores',
                    Icons.cyclone,
                    Colors.teal,
                    'AIRE DE VENTANA',
                  ),
                  _buildCategoryCard(
                    context,
                    'Electrodomésticos',
                    Icons.kitchen,
                    Colors.orange,
                    'MANTENIMIENTO',
                  ),
                  _buildCategoryCard(
                    context,
                    'Iluminación',
                    Icons.lightbulb,
                    Colors.amber,
                    'AIRES PORTÁTILES',
                  ),
                  _buildCategoryCard(
                    context,
                    'Protectores',
                    Icons.electrical_services,
                    Colors.purple,
                    'PROTECTORES',
                  ),
                  _buildCategoryCard(
                    context,
                    'Deshumidificadores',
                    Icons.water_drop,
                    Colors.red,
                    'DESHUMIDIFICADORES',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, String title, IconData icon, Color color, String categoryId) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductCatalogScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfferCard(
      BuildContext context,
      String title,
      String originalPrice,
      String salePrice,
      Color backgroundColor,
      Color accentColor,
      IconData icon,
      ) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Ver producto específico (implementar)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProductCatalogScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Etiqueta de oferta
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'OFERTA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Icono del producto
              Icon(icon, size: 40, color: accentColor),
              const SizedBox(height: 12),
              // Título del producto
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Precios
              Row(
                children: [
                  Text(
                    '\$$originalPrice',
                    style: TextStyle(
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '\$$salePrice',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}