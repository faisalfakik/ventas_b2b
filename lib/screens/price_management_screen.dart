import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/special_price.dart';
import '../models/product_model.dart';
import '../models/customer_model.dart' as cust;
import '../services/price_service.dart';
import '../services/product_service.dart';
import '../services/customer_service.dart';

class PriceManagementScreen extends StatefulWidget {
  const PriceManagementScreen({Key? key}) : super(key: key);

  @override
  _PriceManagementScreenState createState() => _PriceManagementScreenState();
}

class _PriceManagementScreenState extends State<PriceManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SpecialPrice> _specialPrices = [];
  List<cust.Customer> _clients = [];
  List<Product> _products = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // No llamamos a _loadData directamente aquí para evitar problemas con el contexto
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Es más seguro llamar a métodos que requieren contexto en didChangeDependencies
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Usar Provider para obtener los servicios
      final priceService = context.read<PriceService>();
      final customerService = context.read<CustomerService>();
      final productService = context.read<ProductService>();

      // Ejecutar peticiones en paralelo para mejorar rendimiento
      final futures = await Future.wait([
        // Obtener precios especiales (ahora usando Provider)
        Future.value(priceService.getAllSpecialPrices()),
        // Cargar clientes asíncronamente
        customerService.getAllClients(),
        // Cargar productos asíncronamente usando Provider
        productService.getProducts()
      ]);

      if (mounted) {
        setState(() {
          _specialPrices = futures[0] as List<SpecialPrice>;
          _clients = futures[1] as List<cust.Customer>;
          _products = futures[2] as List<Product>;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error cargando datos: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        // Mostrar error al usuario
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    }
  }


  // El resto del código permanece igual...
  void _showAddEditSpecialPriceDialog(BuildContext context, {SpecialPrice? specialPrice}) {
    final bool isEditing = specialPrice != null;

    // Controladores para los campos del formulario
    final productIdController = TextEditingController(text: isEditing ? specialPrice.productId : '');
    final clientIdController = TextEditingController(text: isEditing && specialPrice.clientId != null ? specialPrice.clientId : '');
    final priceController = TextEditingController(text: isEditing ? specialPrice.price.toString() : '');
    final discountController = TextEditingController(text: isEditing && specialPrice.discountPercentage != null ? specialPrice.discountPercentage.toString() : '');
    final minQuantityController = TextEditingController(text: isEditing && specialPrice.minQuantity != null ? specialPrice.minQuantity.toString() : '');
    final notesController = TextEditingController(text: isEditing && specialPrice.notes != null ? specialPrice.notes : '');

    // Variables para las fechas
    DateTime? startDate = isEditing ? specialPrice.startDate : null;
    DateTime? endDate = isEditing ? specialPrice.endDate : null;

    // Variables para los dropdowns
    String? selectedProductId = isEditing ? specialPrice.productId : null;
    String? selectedClientId = isEditing ? specialPrice.clientId : null;

    // Para formatear fechas
    final dateFormat = DateFormat('dd/MM/yyyy');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEditing ? 'Editar precio especial' : 'Agregar precio especial'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selección de producto
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Producto',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedProductId,
                    items: _products.map((product) {
                      return DropdownMenuItem<String>(
                        value: product.id,
                        child: Text(
                          product.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedProductId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Selección de cliente (opcional)
                  DropdownButtonFormField<String?>(
                    decoration: const InputDecoration(
                      labelText: 'Cliente (opcional)',
                      border: OutlineInputBorder(),
                      helperText: 'Dejar en blanco para aplicar a todos los clientes',
                    ),
                    value: selectedClientId,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todos los clientes'),
                      ),
                      ..._clients.map((cust.Customer customer) {
                        return DropdownMenuItem<String?>(
                          value: customer.id,
                          child: Text(
                            customer.businessName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedClientId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Precio especial
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Precio especial',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),

                  // Descuento (opcional)
                  TextField(
                    controller: discountController,
                    decoration: const InputDecoration(
                      labelText: 'Descuento (opcional)',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                      helperText: 'Porcentaje de descuento adicional',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),

                  // Cantidad mínima (opcional)
                  TextField(
                    controller: minQuantityController,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad mínima (opcional)',
                      border: OutlineInputBorder(),
                      helperText: 'Para descuentos por volumen',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // Fechas (inicio y fin)
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() {
                                startDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Fecha inicio (opcional)',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              startDate != null ? dateFormat.format(startDate!) : 'No definida',
                              style: TextStyle(
                                color: startDate != null ? Colors.black : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: endDate ?? (startDate != null ? startDate!.add(const Duration(days: 30)) : DateTime.now().add(const Duration(days: 30))),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() {
                                endDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Fecha fin (opcional)',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              endDate != null ? dateFormat.format(endDate!) : 'No definida',
                              style: TextStyle(
                                color: endDate != null ? Colors.black : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Notas (opcional)
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedProductId == null || priceController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Producto y precio son requeridos')),
                    );
                    return;
                  }

                  final price = double.tryParse(priceController.text);
                  if (price == null || price <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingrese un precio válido')),
                    );
                    return;
                  }

                  // Parsear campos opcionales
                  final discountPercentage = discountController.text.isNotEmpty
                      ? double.tryParse(discountController.text)
                      : null;
                  final minQuantity = minQuantityController.text.isNotEmpty
                      ? int.tryParse(minQuantityController.text)
                      : null;

                  // Crear o actualizar precio especial
                  final specialPriceObj = SpecialPrice(
                    id: isEditing ? specialPrice!.id : 'SP${DateTime.now().millisecondsSinceEpoch}',
                    productId: selectedProductId!,
                    clientId: selectedClientId,
                    price: price,
                    discountPercentage: discountPercentage,
                    minQuantity: minQuantity,
                    startDate: startDate,
                    endDate: endDate,
                    notes: notesController.text.isNotEmpty ? notesController.text : null,
                  );

                  if (isEditing) {
                    context.read<PriceService>().updateSpecialPrice(specialPriceObj);
                  } else {
                    context.read<PriceService>().addSpecialPrice(specialPriceObj);
                  }

                  _loadData(); // Recargar datos
                  Navigator.pop(context);
                },
                child: Text(isEditing ? 'Guardar' : 'Agregar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteSpecialPrice(SpecialPrice specialPrice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Estás seguro de que deseas eliminar este precio especial? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              context.read<PriceService>().deleteSpecialPrice(specialPrice.id);
              _loadData(); // Recargar datos
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Precios'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Por Cliente'),
            Tab(text: 'Por Producto'),
            Tab(text: 'Temporales'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          // Pestaña 1: Precios por cliente
          _buildClientPricesTab(),

          // Pestaña 2: Precios por producto
          _buildProductPricesTab(),

          // Pestaña 3: Promociones temporales
          _buildTemporaryPromotionsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditSpecialPriceDialog(context),
        child: const Icon(Icons.add),
        tooltip: 'Agregar precio especial',
      ),
    );
  }

  Widget _buildClientPricesTab() {
    // Filtrar precios específicos por cliente
    final clientSpecificPrices = _specialPrices.where((sp) => sp.clientId != null).toList();

    if (clientSpecificPrices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No hay precios específicos por cliente',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Agrega precios especiales para clientes específicos',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: clientSpecificPrices.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final specialPrice = clientSpecificPrices[index];
        final product = _products.firstWhere(
              (p) => p.id == specialPrice.productId,
          orElse: () => Product(
            id: 'unknown',
            name: 'Producto desconocido',
            price: 0,
            category: '',
            description: '',
            imageUrl: '',
            stock: 0,
          ),
        );
        final customer = _clients.firstWhere(
              (c) => c.id == specialPrice.clientId,
          orElse: () => cust.Customer(
            id: '',
            name: '',
            email: '',
            phone: '',
            address: '',
            businessName: '',
          ),
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(customer.businessName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Producto: ${product.name}'),
                Text('Precio: \$${specialPrice.price.toStringAsFixed(2)}'),
                if (specialPrice.discountPercentage != null)
                  Text('Descuento: ${specialPrice.discountPercentage}%'),
                if (specialPrice.minQuantity != null)
                  Text('Cantidad mínima: ${specialPrice.minQuantity}'),
              ],
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showAddEditSpecialPriceDialog(context, specialPrice: specialPrice),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteSpecialPrice(specialPrice),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductPricesTab() {
    // Agrupar precios por producto
    final Map<String, List<SpecialPrice>> pricesByProduct = {};

    for (final specialPrice in _specialPrices) {
      if (!pricesByProduct.containsKey(specialPrice.productId)) {
        pricesByProduct[specialPrice.productId] = [];
      }
      pricesByProduct[specialPrice.productId]!.add(specialPrice);
    }

    if (pricesByProduct.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No hay precios especiales por producto',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Agrega precios especiales para productos',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Convertir el mapa a una lista para poder usarlo con ListView.builder
    final productEntries = pricesByProduct.entries.toList();

    return ListView.builder(
      itemCount: productEntries.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final productId = productEntries[index].key;
        final prices = productEntries[index].value;

        final product = _products.firstWhere(
              (p) => p.id == productId,
          orElse: () => Product(
            id: 'unknown',
            name: 'Producto desconocido',
            price: 0,
            category: '',
            description: '',
            imageUrl: '',
            stock: 0,
          ),
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            title: Text(product.name),
            subtitle: Text('Precio regular: \$${product.price.toStringAsFixed(2)}'),
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: prices.length,
                itemBuilder: (context, i) {
                  final specialPrice = prices[i];
                  final customer = specialPrice.clientId != null
                      ? _clients.firstWhere(
                        (c) => c.id == specialPrice.clientId,
                    orElse: () => cust.Customer(
                      id: '',
                      name: '',
                      email: '',
                      phone: '',
                      address: '',
                      businessName: '',
                    ),
                  )
                      : null;

                  return ListTile(
                    title: Text(customer != null ? customer.businessName : 'Todos los clientes'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Precio: \$${specialPrice.price.toStringAsFixed(2)}'),
                        if (specialPrice.discountPercentage != null)
                          Text('Descuento: ${specialPrice.discountPercentage}%'),
                        if (specialPrice.minQuantity != null)
                          Text('Cantidad mínima: ${specialPrice.minQuantity}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showAddEditSpecialPriceDialog(context, specialPrice: specialPrice),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteSpecialPrice(specialPrice),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTemporaryPromotionsTab() {
    // Filtrar promociones temporales (con fecha de inicio o fin)
    final temporaryPromotions = _specialPrices.where(
            (sp) => sp.startDate != null || sp.endDate != null
    ).toList();

    if (temporaryPromotions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No hay promociones temporales',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Agrega promociones con fechas de inicio y fin',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Formato para fechas
    final dateFormat = DateFormat('dd/MM/yyyy');

    return ListView.builder(
      itemCount: temporaryPromotions.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final promotion = temporaryPromotions[index];
        final product = _products.firstWhere(
              (p) => p.id == promotion.productId,
          orElse: () => Product(
            id: 'unknown',
            name: 'Producto desconocido',
            price: 0,
            category: '',
            description: '',
            imageUrl: '',
            stock: 0,
          ),
        );

        // Determinar si la promoción está activa
        final now = DateTime.now();
        bool isActive = true;
        if (promotion.startDate != null && now.isBefore(promotion.startDate!)) {
          isActive = false;
        }
        if (promotion.endDate != null && now.isAfter(promotion.endDate!)) {
          isActive = false;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Row(
              children: [
                Text(product.name),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'Activa' : 'Inactiva',
                    style: TextStyle(
                      color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Precio: \$${promotion.price.toStringAsFixed(2)}'),
                if (promotion.discountPercentage != null)
                  Text('Descuento: ${promotion.discountPercentage}%'),
                Text(
                  'Vigencia: ${promotion.startDate != null ? dateFormat.format(promotion.startDate!) : 'Sin inicio'} - ${promotion.endDate != null ? dateFormat.format(promotion.endDate!) : 'Sin fin'}',
                ),
                if (promotion.notes != null && promotion.notes!.isNotEmpty)
                  Text('Notas: ${promotion.notes}'),
              ],
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showAddEditSpecialPriceDialog(context, specialPrice: promotion),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteSpecialPrice(promotion),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}