import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
// Corrección 1: Import correcto para escáner
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/store_sale_model.dart';
import '../models/product_model.dart';
// Corrección 2: Añadir import del servicio de validación
import '../services/serial_validation_service.dart';
import 'dart:io';

class StoreSellerScreen extends StatefulWidget {
  final String storeId;
  final String sellerId;
  final String storeName;
  final String sellerName;

  const StoreSellerScreen({
    Key? key,
    required this.storeId,
    required this.sellerId,
    required this.storeName,
    required this.sellerName,
  }) : super(key: key);

  @override
  State<StoreSellerScreen> createState() => _StoreSellerScreenState();
}

class _StoreSellerScreenState extends State<StoreSellerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productController = TextEditingController();
  final _serialController = TextEditingController();

  File? _invoiceImage;
  File? _serialImage;
  Product? _selectedProduct;
  bool _isExpanded = false;
  bool _isLoading = false;
  List<Product> _products = [];
  List<StoreSale> _salesHistory = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadSalesHistory();
  }

  Future<void> _loadProducts() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('storeId', isEqualTo: widget.storeId)
          .get();

      setState(() {
        _products = snapshot.docs
            .map((doc) => Product.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      print('Error loading products: $e');
    }
  }

  Future<void> _loadSalesHistory() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('store_sales')
          .where('storeId', isEqualTo: widget.storeId)
          .where('sellerId', isEqualTo: widget.sellerId)
          .orderBy('saleDate', descending: true)
          .get();

      setState(() {
        _salesHistory = snapshot.docs
            .map((doc) => StoreSale.fromMap(doc.data()))
            .toList();
      });
    } catch (e) {
      print('Error loading sales history: $e');
    }
  }

  // Corrección 3: Implementación correcta del escáner
  Future<void> _scanBarcode() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Escanear Código')),
          body: MobileScanner(
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.normal,
              facing: CameraFacing.back,
              torchEnabled: false,
            ),
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  Navigator.pop(context);
                  setState(() {
                    _serialController.text = code;
                  });
                }
              }
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(bool isInvoice) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() {
        if (isInvoice) {
          _invoiceImage = File(image.path);
        } else {
          _serialImage = File(image.path);
        }
      });
    }
  }

  Future<String> _uploadImage(File image, String path) async {
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  // Método modificado con validaciones mejoradas y manejo de errores
  Future<void> _submitSale() async {
    if (!_formKey.currentState!.validate()) return;

    // Corrección 4: Validar que las imágenes necesarias estén presentes
    if (_serialImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, tome una foto del serial del producto'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String serial = _serialController.text.trim();

      // 1. Verificar si el serial ya existe en ventas anteriores
      final serialQuery = await FirebaseFirestore.instance
          .collection('store_sales')
          .where('productSerial', isEqualTo: serial)
          .get();

      if (serialQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este serial ya ha sido registrado anteriormente'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // 2. Verificar si el serial es válido contra nuestra base de datos
      // Corrección 5: Creación de instancia SerialValidationService
      final serialValidationService = SerialValidationService();
      final bool isValid = await serialValidationService.isSerialValid(
          serial,
          _selectedProduct!.id
      );

      // Estado de aprobación automática basado en la validez del serial
      final String saleStatus = isValid ? 'approved' : 'pending_review';

      // 3. Subir imágenes
      final serialImageUrl = await _uploadImage(
        _serialImage!,
        'store_sales/${widget.storeId}/${DateTime.now().millisecondsSinceEpoch}_serial.jpg',
      );

      String? invoiceImageUrl;
      if (_invoiceImage != null) {
        invoiceImageUrl = await _uploadImage(
          _invoiceImage!,
          'store_sales/${widget.storeId}/${DateTime.now().millisecondsSinceEpoch}_invoice.jpg',
        );
      }

      // 4. Calcular comisión
      final double commissionRate = _selectedProduct!.commissionRate;
      final double commissionAmount = _selectedProduct!.price * (commissionRate / 100);

      // 5. Crear objeto de venta con estado automático
      final String saleId = DateTime.now().millisecondsSinceEpoch.toString();
      final sale = StoreSale(
        id: saleId,
        storeId: widget.storeId,
        sellerId: widget.sellerId,
        productId: _selectedProduct!.id,
        productSerial: serial,
        invoiceImageUrl: invoiceImageUrl ?? '',
        serialImageUrl: serialImageUrl,
        saleDate: DateTime.now(),
        salePrice: _selectedProduct!.price,
        status: saleStatus, // Estado automático basado en validación
        productDetails: _selectedProduct!.toMap(),
        commissionRate: commissionRate,
        commissionAmount: commissionAmount,
      );

      // 6. Guardar venta en Firestore
      await FirebaseFirestore.instance
          .collection('store_sales')
          .doc(saleId)
          .set(sale.toMap());

      // 7. Si el serial es válido, marcarlo como usado
      if (isValid) {
        await serialValidationService.markSerialAsUsed(serial, saleId);
      }

      // 8. Mensaje basado en resultado de validación
      final String message = isValid
          ? 'Venta registrada y aprobada automáticamente'
          : 'Venta registrada. Pendiente de verificación';

      final Color backgroundColor = isValid ? Colors.green : Colors.orange;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
        ),
      );

      _resetForm();
      _loadSalesHistory();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar la venta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _productController.clear();
    _serialController.clear();
    setState(() {
      _selectedProduct = null;
      _invoiceImage = null;
      _serialImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Venta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showSalesHistory(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStoreInfo(),
            const SizedBox(height: 20),
            _buildSaleForm(),
            const SizedBox(height: 20),
            _buildSalesSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreInfo() {
    return Card(
      child: ExpansionTile(
        title: Text(widget.storeName),
        subtitle: Text(widget.sellerName),
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (expanded) {
          setState(() => _isExpanded = expanded);
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vendedor: ${widget.sellerName}'),
                Text('Tienda: ${widget.storeName}'),
                Text('Fecha: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _productController,
            decoration: const InputDecoration(
              labelText: 'Producto',
              border: OutlineInputBorder(),
            ),
            readOnly: true,
            onTap: () => _showProductSelector(),
            validator: (value) {
              if (_selectedProduct == null) {
                return 'Por favor seleccione un producto';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Cambio en el campo del serial para incluir botón de escaneo
          TextFormField(
            controller: _serialController,
            decoration: InputDecoration(
              labelText: 'Serial del Producto',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                tooltip: 'Escanear código',
                onPressed: _scanBarcode,
              ),
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Por favor ingrese el serial del producto';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(true),
                  icon: const Icon(Icons.receipt),
                  label: Text(_invoiceImage == null ? 'Foto de Factura' : 'Cambiar Factura'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(false),
                  icon: const Icon(Icons.qr_code),
                  label: Text(_serialImage == null ? 'Foto del Serial' : 'Cambiar Serial'),
                ),
              ),
            ],
          ),
          if (_invoiceImage != null || _serialImage != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (_invoiceImage != null)
                  Expanded(
                    child: Image.file(
                      _invoiceImage!,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (_serialImage != null)
                  Expanded(
                    child: Image.file(
                      _serialImage!,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitSale,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Registrar Venta'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesSummary() {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    final lastMonth = DateTime(now.year, now.month - 1, 1);

    final thisMonthSales = _salesHistory
        .where((sale) => sale.saleDate.isAfter(thisMonth))
        .length;
    final lastMonthSales = _salesHistory
        .where((sale) =>
    sale.saleDate.isAfter(lastMonth) &&
        sale.saleDate.isBefore(thisMonth))
        .length;

    // Corrección 6: Manejo de división por cero
    final improvement = lastMonthSales > 0
        ? ((thisMonthSales - lastMonthSales) / lastMonthSales * 100).toStringAsFixed(1)
        : '0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen de Ventas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ventas este mes: $thisMonthSales'),
                Text('Ventas mes anterior: $lastMonthSales'),
              ],
            ),
            const SizedBox(height: 8),
            Text('Mejora: $improvement%'),
            if (double.parse(improvement) > 0)
              const Text(
                '¡Felicitaciones! Has superado tus ventas del mes anterior.',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showProductSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          return ListTile(
            title: Text(product.name),
            subtitle: Text(product.description),
            trailing: Text('\$${product.price.toStringAsFixed(2)}'),
            onTap: () {
              setState(() {
                _selectedProduct = product;
                _productController.text = product.name;
              });
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  void _showSalesHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Historial de Ventas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _salesHistory.length,
                itemBuilder: (context, index) {
                  final sale = _salesHistory[index];
                  return ListTile(
                    title: Text(sale.productDetails['name'] ?? 'Producto'),
                    subtitle: Text(
                      'Serial: ${sale.productSerial}\n'
                          'Fecha: ${DateFormat('dd/MM/yyyy').format(sale.saleDate)}\n'
                          'Precio: \$${sale.salePrice.toStringAsFixed(2)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Corrección 7: Indicador de estado
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: sale.status == 'approved'
                                ? Colors.green
                                : (sale.status == 'rejected' ? Colors.red : Colors.orange),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            sale.status == 'approved'
                                ? 'Aprobado'
                                : (sale.status == 'rejected' ? 'Rechazado' : 'Pendiente'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (sale.invoiceImageUrl.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.receipt),
                            onPressed: () => _showImage(sale.invoiceImageUrl),
                          ),
                      ],
                    ),
                    onTap: () => _showSaleDetails(sale),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Corrección 8: Agregar ventana de detalles de venta
  void _showSaleDetails(StoreSale sale) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sale.productDetails['name'] ?? 'Producto',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text('Serial: ${sale.productSerial}'),
              Text('Fecha: ${DateFormat('dd/MM/yyyy').format(sale.saleDate)}'),
              Text('Precio: \$${sale.salePrice.toStringAsFixed(2)}'),
              Text('Comisión: \$${sale.commissionAmount.toStringAsFixed(2)} (${sale.commissionRate}%)'),
              Text('Estado: ${sale.status == 'approved' ? 'Aprobado' : (sale.status == 'rejected' ? 'Rechazado' : 'Pendiente')}'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () => _showImage(sale.serialImageUrl),
                    child: const Text('Ver Serial'),
                  ),
                  if (sale.invoiceImageUrl.isNotEmpty)
                    ElevatedButton(
                      onPressed: () => _showImage(sale.invoiceImageUrl),
                      child: const Text('Ver Factura'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(imageUrl),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _productController.dispose();
    _serialController.dispose();
    super.dispose();
  }
}