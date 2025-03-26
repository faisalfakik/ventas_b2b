import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math'; // Para la función min()
import '../models/product_model.dart';
import '../models/client_model.dart';
import '../models/quote_item.dart';
import '../services/product_service.dart';
import '../services/client_service.dart';
import '../services/price_service.dart';

enum LoadingState { idle, searching, generatingPdf, saving }

class QuoteScreen extends StatefulWidget {
  final String? vendorId;
  final String? clientId;
  final String? quoteId;

  const QuoteScreen({
    Key? key,
    this.vendorId,
    this.clientId,
    this.quoteId,
  }) : super(key: key);

  @override
  _QuoteScreenState createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  final ProductService _productService = ProductService();
  final ClientService _clientService = ClientService();
  final PriceService _priceService = PriceService();

  final List<QuoteItem> _quoteItems = [];
  Client? _selectedClient;
  LoadingState _loadingState = LoadingState.idle;

  String _searchQuery = '';
  List<Product> _searchResults = [];
  final Map<String, List<Product>> _searchCache = {};

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _validityController = TextEditingController(text: '30');
  final TextEditingController _deliveryTimeController = TextEditingController(text: '15');
  final TextEditingController _paymentTermsController = TextEditingController(text: 'Contado');
  final TextEditingController _notesController = TextEditingController();

  Timer? _debounceTimer;
  bool _isClientHeaderCollapsed = false;
  final ScrollController _scrollController = ScrollController();

  void _setLoadingState(LoadingState state) {
    if (mounted) {
      setState(() {
        _loadingState = state;
      });
    }
  }

  Future<List<Product>> _getCachedSearchResults(String query) async {
    // Convertir a minúsculas para una búsqueda sin distinción entre mayúsculas y minúsculas
    String normalizedQuery = query.toLowerCase();

    // Comprobar si ya tenemos estos resultados en caché
    if (_searchCache.containsKey(normalizedQuery)) {
      return _searchCache[normalizedQuery]!;
    }

    // Obtener todos los productos y filtrar localmente
    List<Product> allProducts = await _productService.getAllProducts();

    // Filtrar los productos basados en la consulta
    List<Product> filteredProducts = allProducts.where((product) {
      return product.name.toLowerCase().contains(normalizedQuery) ||
          product.description.toLowerCase().contains(normalizedQuery) ||
          product.category.toLowerCase().contains(normalizedQuery);
    }).toList();

    // Guardar en caché los resultados
    _searchCache[normalizedQuery] = filteredProducts;

    return filteredProducts;
  }

  @override
  void initState() {
    super.initState();
    _initializeData();

    // Añadir listener para detectar scroll y colapsar el header
    _scrollController.addListener(_onScroll);

    // Debug logging for vendorId
    print("DEBUG: QuoteScreen inicializado con vendorId: ${widget.vendorId}");

    // Verificar Firestore
    if (widget.vendorId != null) {
      try {
        FirebaseFirestore.instance
            .collection('vendors')
            .doc(widget.vendorId)
            .get()
            .then((doc) {
          print("DEBUG: Datos del vendedor: ${doc.data()}");
        }).catchError((e) {
          print("DEBUG: Error al obtener datos del vendedor: $e");
        });
      } catch (e) {
        print("DEBUG: Error con Firestore: $e");
      }
    } else {
      print("DEBUG: No se proporcionó un vendorId");
    }

    // Asegurarnos de que existan datos de clientes de ejemplo
    _clientService.migrateExampleDataToFirestore();

    // Cargamos algunos productos iniciales al cargar la pantalla
    _loadInitialProducts();
  }

  Future<void> _initializeData() async {
    try {
      _setLoadingState(LoadingState.searching);

      // Cargar cliente si se proporcionó ID
      if (widget.clientId != null) {
        final client = await _clientService.getClientById(widget.clientId!);
        if (mounted) {
          setState(() {
            _selectedClient = client;
          });
        }
      }

      // Cargar cotización existente si se proporcionó ID
      if (widget.quoteId != null) {
        try {
          final quoteDoc = await FirebaseFirestore.instance
              .collection('quotes')
              .doc(widget.quoteId)
              .get();

          if (quoteDoc.exists) {
            print("DEBUG: Cargando cotización existente con ID: ${widget.quoteId}");
            final data = quoteDoc.data() as Map<String, dynamic>;

            // Cargar cliente si no se cargó antes
            if (_selectedClient == null && data['clientId'] != null) {
              final client = await _clientService.getClientById(data['clientId']);
              if (mounted && client != null) {
                setState(() {
                  _selectedClient = client;
                });
              }
            }

            // Cargar items
            List<QuoteItem> quoteItems = [];
            if (data['items'] != null) {
              for (var itemData in data['items']) {
                final product = await _productService.getProductById(itemData['productId']);
                if (product != null) {
                  quoteItems.add(QuoteItem(
                    product: product,
                    quantity: itemData['quantity'] ?? 1,
                    price: (itemData['price'] ?? 0).toDouble(),
                    discount: (itemData['discount'] ?? 0).toDouble(),
                  ));
                }
              }
            }

            // Cargar datos adicionales
            if (mounted) {
              setState(() {
                _quoteItems.clear();
                _quoteItems.addAll(quoteItems);
                _validityController.text = (data['validityDays'] ?? 30).toString();
                _deliveryTimeController.text = (data['deliveryDays'] ?? 15).toString();
                _paymentTermsController.text = data['paymentTerms'] ?? 'Contado';
                _notesController.text = data['notes'] ?? '';
              });
            }
          } else {
            print("DEBUG: La cotización con ID ${widget.quoteId} no existe");
          }
        } catch (e) {
          print("DEBUG: Error al cargar la cotización: $e");
          _handleError('Error al cargar la cotización', e);
        }
      }
    } catch (e) {
      _handleError('Error al inicializar datos', e);
    } finally {
      _setLoadingState(LoadingState.idle);
    }
  }

  Future<void> _loadInitialProducts() async {
    // Esperar un momento para que la UI termine de dibujarse
    await Future.delayed(Duration(milliseconds: 300));

    if (mounted) {
      _searchProducts(''); // Buscar con una cadena vacía cargará todos los productos
    }
  }

  void _onScroll() {
    // Colapsar el header cuando el usuario hace scroll hacia abajo
    if (_scrollController.offset > 50 && !_isClientHeaderCollapsed && _selectedClient != null) {
      setState(() {
        _isClientHeaderCollapsed = true;
      });
    } else if (_scrollController.offset <= 50 && _isClientHeaderCollapsed) {
      setState(() {
        _isClientHeaderCollapsed = false;
      });
    }
  }

  void _addProductToQuote(Product product) {
    // Verificar si el producto ya está en la cotización
    final existingItemIndex = _quoteItems.indexWhere((item) => item.product.id == product.id);

    if (existingItemIndex >= 0) {
      setState(() {
        _quoteItems[existingItemIndex].quantity += 1;

        // Verificar si hay un precio especial aplicable con la nueva cantidad
        if (_selectedClient != null) {
          final specialPrice = _priceService.getSpecialPriceForClientAndProduct(
            _selectedClient!.id,
            product.id,
            quantity: _quoteItems[existingItemIndex].quantity,
          );

          if (specialPrice != null) {
            _quoteItems[existingItemIndex].price = specialPrice.price;
            _quoteItems[existingItemIndex].discount = specialPrice.discountPercentage ?? 0;
          }
        }
      });
    } else {
      // Verificar si hay un precio especial aplicable para este cliente y producto
      double price = product.price;
      double discount = 0;

      if (_selectedClient != null) {
        final specialPrice = _priceService.getSpecialPriceForClientAndProduct(
          _selectedClient!.id,
          product.id,
        );

        if (specialPrice != null) {
          price = specialPrice.price;
          discount = specialPrice.discountPercentage ?? 0;
        }
      }

      setState(() {
        _quoteItems.add(QuoteItem(
          product: product,
          quantity: 1,
          price: price,
          discount: discount,
        ));
      });
    }

    // Limpiar búsqueda
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
    });

    // Mostrar notificación
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Producto agregado a la cotización'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Ver Carrito',
          onPressed: () {
            // Scroll hacia el final para ver los productos agregados
          },
        ),
      ),
    );
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      setState(() {
        _quoteItems.removeAt(index);
      });
      return;
    }

    setState(() {
      _quoteItems[index].quantity = newQuantity;

      // Verificar si hay un precio especial por volumen
      if (_selectedClient != null) {
        final specialPrice = _priceService.getSpecialPriceForClientAndProduct(
          _selectedClient!.id,
          _quoteItems[index].product.id,
          quantity: newQuantity,
        );

        if (specialPrice != null) {
          _quoteItems[index].price = specialPrice.price;
          _quoteItems[index].discount = specialPrice.discountPercentage ?? 0;
        }
      }
    });
  }

  void _updatePrice(int index, double newPrice) {
    setState(() {
      _quoteItems[index].price = newPrice;
    });
  }

  void _updateDiscount(int index, double newDiscount) {
    setState(() {
      _quoteItems[index].discount = newDiscount;
    });
  }

  double _calculateItemSubtotal(QuoteItem item) {
    return item.price * item.quantity * (1 - item.discount / 100);
  }

  double _calculateSubtotal() {
    double subtotal = 0;
    for (var item in _quoteItems) {
      subtotal += _calculateItemSubtotal(item);
    }
    return subtotal;
  }

  double _calculateTotal() {
    return _calculateSubtotal();
  }

  Future<void> _generatePdf() async {
    if (!_validateQuoteData()) return;

    setState(() {
      _loadingState = LoadingState.generatingPdf;
    });

    try {
      // 1. Primero, guardar la cotización en Firestore
      final quoteData = {
      'clientId': _selectedClient!.id,
      'vendorId': widget.vendorId,
      'items': _quoteItems.map((item) => {
      'productId': item.product.id,
      'quantity': item.quantity,
      'price': item.price,
      'discount': item.discount,
      }).toList(),
      'createdAt': Timestamp.now(),
      'status': 'pending',
      'subtotal': _calculateSubtotal(),
      'tax': 0, // O calcula el impuesto según tu lógica
      'total': _calculateTotal(),
      'validityDays': int.tryParse(_validityController.text) ?? 30,
      'deliveryDays': int.tryParse(_deliveryTimeController.text) ?? 15,
      'paymentTerms': _paymentTermsController.text,
      'notes': _notesController.text,
      };

      // Guardar en Firestore
      String savedQuoteId;
      if (widget.quoteId != null) {
        // Si es una cotización existente, actualizar
        await FirebaseFirestore.instance
            .collection('quotes')
            .doc(widget.quoteId)
            .update(quoteData);
        savedQuoteId = widget.quoteId!;
        print("DEBUG: Cotización actualizada con ID: $savedQuoteId");
      } else {
        // Si es una nueva cotización, crear
        final docRef = await FirebaseFirestore.instance
            .collection('quotes')
            .add(quoteData);
        savedQuoteId = docRef.id;
        print("DEBUG: Cotización creada con ID: $savedQuoteId");
      }

      await _performAsyncOperation(() async {
        final pdf = pw.Document();

        // No cargamos fuentes personalizadas
        // No cargamos logo personalizado

        // Agregar página con cotización
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(40),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Encabezado
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'COTIZACIÓN',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green800,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            'Fecha: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                            style: const pw.TextStyle(
                              fontSize: 12,
                            ),
                          ),
                          pw.Text(
                            'Folio: COT-${savedQuoteId.substring(0, min(savedQuoteId.length, 8))}',
                            style: const pw.TextStyle(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'GTRONIC',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green800,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'contacto@gtronic.com',
                            style: const pw.TextStyle(
                              fontSize: 10,
                            ),
                          ),
                          pw.Text(
                            'Tel: +52 (123) 456-7890',
                            style: const pw.TextStyle(
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 30),

                  // Datos del cliente
                  pw.Container(
                    padding: const pw.EdgeInsets.all(15),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'CLIENTE',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                            color: PdfColors.green800,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          _selectedClient != null
                              ? _selectedClient!.name
                              : 'Cliente general',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        if (_selectedClient != null) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            _selectedClient!.email,
                            style: const pw.TextStyle(
                              fontSize: 10,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            _selectedClient!.phone,
                            style: const pw.TextStyle(
                              fontSize: 10,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            _selectedClient!.address,
                            style: const pw.TextStyle(
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Tabla de productos
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(0.5), // #
                      1: const pw.FlexColumnWidth(3.5),  // Producto
                      2: const pw.FlexColumnWidth(1),    // Cantidad
                      3: const pw.FlexColumnWidth(1.5),  // Precio Unitario
                      4: const pw.FlexColumnWidth(1),    // Descuento
                      5: const pw.FlexColumnWidth(1.5),  // Subtotal
                    },
                    children: [
                      // Encabezados
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.green800,
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '#',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Producto',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Cant.',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Precio Unit.',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Desc.',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Subtotal',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      // Filas de productos
                      for (int i = 0; i < _quoteItems.length; i++)
                        pw.TableRow(
                          decoration: i % 2 == 0
                              ? const pw.BoxDecoration(color: PdfColors.grey100)
                              : null,
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                '${i + 1}',
                                style: const pw.TextStyle(),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    _quoteItems[i].product.name,
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    _quoteItems[i].product.description.length > 50
                                        ? '${_quoteItems[i].product.description.substring(0, 50)}...'
                                        : _quoteItems[i].product.description,
                                    style: const pw.TextStyle(
                                      fontSize: 8,
                                      color: PdfColors.grey700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                '${_quoteItems[i].quantity}',
                                style: const pw.TextStyle(),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                '\$${_quoteItems[i].price.toStringAsFixed(2)}',
                                style: const pw.TextStyle(),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                _quoteItems[i].discount > 0
                                    ? '${_quoteItems[i].discount.toStringAsFixed(1)}%'
                                    : '-',
                                style: const pw.TextStyle(),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                '\$${_calculateItemSubtotal(_quoteItems[i]).toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 20),

                  // Totales
                  pw.Container(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text(
                              'Subtotal:',
                              style: const pw.TextStyle(
                                fontSize: 12,
                              ),
                            ),
                            pw.SizedBox(width: 50),
                            pw.Container(
                              width: 100,
                              child: pw.Text(
                                '\$${_calculateSubtotal().toStringAsFixed(2)}',
                                style: const pw.TextStyle(
                                  fontSize: 12,
                                ),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 5),
                        pw.Divider(color: PdfColors.grey300),
                        pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text(
                              'Total:',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            pw.SizedBox(width: 50),
                            pw.Container(
                              width: 100,
                              child: pw.Text(
                                '\$${_calculateTotal().toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 16,
                                  color: PdfColors.green800,
                                ),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 30),

                  // Información adicional
                  pw.Container(
                    padding: const pw.EdgeInsets.all(15),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'INFORMACIÓN ADICIONAL',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                            color: PdfColors.green800,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'Validez de la oferta:',
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    '${_validityController.text} días',
                                    style: const pw.TextStyle(
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'Tiempo de entrega:',
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    '${_deliveryTimeController.text} días',
                                    style: const pw.TextStyle(
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'Términos de pago:',
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    _paymentTermsController.text,
                                    style: const pw.TextStyle(
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_notesController.text.isNotEmpty) ...[
                          pw.SizedBox(height: 10),
                          pw.Text(
                            'Notas:',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            _notesController.text,
                            style: const pw.TextStyle(
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 30),

                  // Firma y sello
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        children: [
                          pw.Container(
                            width: 150,
                            height: 0.5,
                            color: PdfColors.black,
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            'Firma del cliente',
                            style: const pw.TextStyle(
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Container(
                            width: 150,
                            height: 0.5,
                            color: PdfColors.black,
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            'Sello y firma',
                            style: const pw.TextStyle(
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Pie de página
                  pw.SizedBox(height: 30),
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'Gracias por su preferencia',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Para cualquier duda o aclaración, contáctenos en contacto@gtronic.com',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );

        // Guardar PDF en archivo temporal
        final output = await getTemporaryDirectory();
        final file = File('${output.path}/cotizacion_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await file.writeAsBytes(await pdf.save());

        // Compartir PDF
        await Share.shareFiles(
          [file.path],
          subject: 'Cotización GTRONIC',
          text: 'Adjunto encontrará la cotización solicitada. Gracias por su interés en nuestros productos.',
        );

        // Alternativamente, abrir el PDF para previsualización
        // await Printing.layoutPdf(
        //   onLayout: (PdfPageFormat format) async => pdf.save(),
        // );
      });
    } catch (e) {
      _handleError('Error al generar PDF', e);
    } finally {
      if (mounted) {
        setState(() {
          _loadingState = LoadingState.idle;
        });
      }
    }
  }

  Future<void> _searchProducts(String query) async {
    setState(() {
      _searchQuery = query;
      _loadingState = LoadingState.searching;
    });

    try {
      List<Product> products;

      if (query.isEmpty) {
        // Si la consulta está vacía, mostrar todos los productos
        products = await _productService.getAllProducts(); // Asegúrate de tener este método implementado
      } else {
        // Realizar búsqueda con la consulta
        products = await _getCachedSearchResults(query);
      }

      if (mounted) {
        setState(() {
          _searchResults = products;
          _loadingState = LoadingState.idle;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al buscar productos: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _loadingState = LoadingState.idle;
        });
      }
    }
  }

  void _handleError(String message, dynamic error) {
    print('Error: $message - $error');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  bool _validateQuoteData() {
    if (_quoteItems.isEmpty) {
      _handleError('La cotización debe contener al menos un producto', null);
      return false;
    }

    if (_selectedClient == null) {
      _handleError('Debe seleccionar un cliente', null);
      return false;
    }

    if (_validityController.text.isEmpty || int.tryParse(_validityController.text) == null) {
      _handleError('La validez debe ser un número válido', null);
      return false;
    }

    if (_deliveryTimeController.text.isEmpty || int.tryParse(_deliveryTimeController.text) == null) {
      _handleError('El tiempo de entrega debe ser un número válido', null);
      return false;
    }

    if (_paymentTermsController.text.isEmpty) {
      _handleError('Debe especificar los términos de pago', null);
      return false;
    }

    return true;
  }

  Future<void> _performAsyncOperation(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (e) {
      _handleError('Error en la operación', e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Evita que el teclado empuje el contenido
      appBar: AppBar(
        title: const Text('Crear Cotización'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_quoteItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Limpiar cotización',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('¿Limpiar cotización?'),
                    content: const Text('Se eliminarán todos los productos de la cotización actual.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _quoteItems.clear();
                          });
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Limpiar'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Sección de cliente con animación para colapsar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isClientHeaderCollapsed && _selectedClient != null
                ? 60 // Altura colapsada
                : _selectedClient == null ? 100 : 120, // Altura expandida
            padding: EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: _isClientHeaderCollapsed && _selectedClient != null ? 8.0 : 16.0
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _selectedClient == null
                ? _buildClientSelectionWidget()
                : _buildSelectedClientWidget(),
          ),

          // Búsqueda de productos - Minimizada cuando hay un cliente seleccionado
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _selectedClient != null ? 60 : 80,
            padding: EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: _selectedClient != null ? 8.0 : 12.0
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: _selectedClient != null ? [] : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar productos',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _searchProducts('');
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: _selectedClient != null
                    ? const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0)
                    : null,
              ),
              onChanged: _searchProducts,
            ),
          ),

          // Resultados de búsqueda
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: BoxConstraints(
                maxHeight: _searchResults.length > 3 ? 200 : 130,
              ),
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 4,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final product = _searchResults[index];
                    return ListTile(
                      leading: product.imageUrl.isNotEmpty
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          product.imageUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 40,
                              height: 40,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_not_supported, size: 20, color: Colors.grey),
                            );
                          },
                        ),
                      )
                          : Container(
                        width: 40,
                        height: 40,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.inventory_2_outlined, size: 20, color: Colors.grey),
                      ),
                      title: Text(product.name),
                      subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        onPressed: () {
                          _addProductToQuote(product);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

          // Lista de productos en cotización
          Expanded(
            child: _quoteItems.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay productos en la cotización',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Busca y agrega productos para comenzar',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _quoteItems.length,
              itemBuilder: (context, index) {
                final item = _quoteItems[index];
                final subtotal = item.price * item.quantity * (1 - item.discount / 100);

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Miniatura del producto
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                                image: DecorationImage(
                                  image: NetworkImage(item.product.imageUrl),
                                  fit: BoxFit.cover,
                                  onError: (_, __) {},
                                ),
                              ),
                              child: item.product.imageUrl.isEmpty
                                  ? const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              )
                                  : null,
                            ),
                            const SizedBox(width: 12),

                            // Información del producto
                            // Control de cantidad
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Cantidad',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () => _updateQuantity(index, item.quantity - 1),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Icon(Icons.remove, size: 16),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _showQuantityDialog(index, item.quantity),
                                        child: Container(
                                          width: 40,
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.shade300),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${item.quantity}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _updateQuantity(index, item.quantity + 1),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Icon(Icons.add, size: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Cantidades predefinidas para ventas al mayor - versión mejorada
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 24, // Altura fija para los botones
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: [5, 10, 25, 50, 100].map((qty) =>
                                          Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: InkWell(
                                              onTap: () => _updateQuantity(index, qty),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  border: Border.all(color: Colors.green.shade200),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '$qty',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.green.shade800,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                      ).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Precio unitario
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Precio unitario',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () {
                                      _showEditPriceDialog(index, item.price);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '\$${item.price.toStringAsFixed(2)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.edit, size: 14),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Descuento
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Descuento (%)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () {
                                      _showEditDiscountDialog(index, item.discount);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${item.discount.toStringAsFixed(1)}%',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.edit, size: 14),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Subtotal: ',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              '\$${subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Panel inferior con totales y botón de generar PDF - Versión mejorada más compacta
      bottomNavigationBar: _quoteItems.isEmpty
          ? null
          : _buildCompactBottomBar(),
    );
  }

  // Widget para el panel inferior con la opción de expandir/colapsar
  Widget _buildCompactBottomBar() {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -3),
            blurRadius: 6,
          ),
        ],
      ),
      // Este padding asegura que el contenido no quede oculto por el teclado
      margin: EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Totales - Más compacto
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '\$${_calculateTotal().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Parámetros de cotización en una fila
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _validityController,
                  decoration: const InputDecoration(
                    labelText: 'Validez (días)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _deliveryTimeController,
                  decoration: const InputDecoration(
                    labelText: 'Entrega (días)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _paymentTermsController,
                  decoration: const InputDecoration(
                    labelText: 'Términos',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas adicionales',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: _loadingState == LoadingState.generatingPdf ? null : _generatePdf,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    icon: _loadingState == LoadingState.generatingPdf
                        ? Container(
                      width: 16,
                      height: 16,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(Icons.picture_as_pdf, size: 16),
                    label: Text(
                      _loadingState == LoadingState.generatingPdf ? 'Generando...' : 'Generar PDF',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _selectClient(Client client) {
    setState(() {
      _selectedClient = client;
      _isClientHeaderCollapsed = true;

      // Actualizar precios si ya hay productos en la cotización
      if (_quoteItems.isNotEmpty) {
        for (int i = 0; i < _quoteItems.length; i++) {
          final item = _quoteItems[i];
          final specialPrice = _priceService.getSpecialPriceForClientAndProduct(
            client.id,
            item.product.id,
            quantity: item.quantity,
          );

          if (specialPrice != null) {
            _quoteItems[i].price = specialPrice.price;
            _quoteItems[i].discount = specialPrice.discountPercentage ?? 0;
          }
        }
      }
    });
  }

// Widget para seleccionar cliente
  Widget _buildClientSelectionWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Cliente',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 30,
          child: ElevatedButton.icon(
            onPressed: () async {
              // Mostrar un indicador de carga mientras se preparan los datos
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text('Cargando clientes...'),
                    ],
                  ),
                  duration: Duration(seconds: 1),
                ),
              );

              // Asegurar que haya datos de clientes disponibles
              await _clientService.migrateExampleDataToFirestore();

              if (context.mounted) {
                // Eliminar el snackbar anterior si sigue visible
                ScaffoldMessenger.of(context).hideCurrentSnackBar();

                final client = await showModalBottomSheet<Client>(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => const ClientSearchSheet(),
                );
                if (client != null && mounted) {
                  _selectClient(client);
                }
              }
            },
            icon: const Icon(Icons.person_add, size: 16),
            label: const Text('Seleccionar Cliente', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
              minimumSize: const Size(100, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }

  // Widget para mostrar cliente seleccionado (versión normal o colapsada)
  Widget _buildSelectedClientWidget() {
    if (_isClientHeaderCollapsed) {
      // Versión compacta
      return Row(
        children: [
          const Icon(Icons.person, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_selectedClient!.name} (${_selectedClient!.businessName})',
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () {
              setState(() {
                _selectedClient = null;
                _isClientHeaderCollapsed = false;
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      );
    } else {
      // Versión expandida
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Cliente',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text(_selectedClient!.name),
              subtitle: Text(_selectedClient!.email),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedClient = null;
                  });
                },
              ),
            ),
          ),
        ],
      );
    }
  }

  void _showQuantityDialog(int index, int currentQuantity) {
    final controller = TextEditingController(text: currentQuantity.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar cantidad'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Cantidad',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final newQuantity = int.tryParse(controller.text);
              if (newQuantity != null && newQuantity > 0) {
                _updateQuantity(index, newQuantity);
              }
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditPriceDialog(int index, double currentPrice) {
    final controller = TextEditingController(text: currentPrice.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar precio'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Precio',
            prefixText: '\$',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final newPrice = double.tryParse(controller.text);
              if (newPrice != null) {
                _updatePrice(index, newPrice);
              }
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditDiscountDialog(int index, double currentDiscount) {
    final controller = TextEditingController(text: currentDiscount.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar descuento'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Descuento',
            suffixText: '%',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final newDiscount = double.tryParse(controller.text);
              if (newDiscount != null) {
                _updateDiscount(index, newDiscount);
              }
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _validityController.dispose();
    _deliveryTimeController.dispose();
    _paymentTermsController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ClientSearchSheet extends StatefulWidget {
  const ClientSearchSheet({super.key});

  @override
  State<ClientSearchSheet> createState() => _ClientSearchSheetState();
}

class _ClientSearchSheetState extends State<ClientSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  final ClientService _clientService = ClientService();
  List<Client> _clients = [];
  List<Client> _filteredClients = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeClientData();
  }

  Future<void> _initializeClientData() async {
    try {
      // Intentar migrar datos primero
      await _clientService.migrateExampleDataToFirestore();
      // Después cargar los clientes
      await _loadClients();
    } catch (e) {
      print("DEBUG: Error inicializando datos de clientes: $e");
    }
  }

  void _filterClients(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredClients = _clients;
      } else {
        _filteredClients = _clients.where((client) {
          return client.name.toLowerCase().contains(_searchQuery) ||
              client.businessName.toLowerCase().contains(_searchQuery) ||
              client.email.toLowerCase().contains(_searchQuery);
        }).toList();
      }
    });
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    try {
      // Añadir un log de debug para ver si se está llamando correctamente
      print("DEBUG: Cargando clientes desde ClientSearchSheet");

      final clients = await _clientService.getClients();

      // Añadir un log para verificar cuántos clientes se obtuvieron
      print("DEBUG: Se obtuvieron ${clients.length} clientes");

      setState(() {
        _clients = clients;
        _filteredClients = clients;
        _isLoading = false;
      });
    } catch (e) {
      print("DEBUG: Error al cargar clientes: $e");
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar clientes: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calcular altura dinámica para que ocupe aproximadamente 70% de la pantalla
    final screenHeight = MediaQuery.of(context).size.height;
    final modalHeight = screenHeight * 0.7;

    return Container(
      height: modalHeight,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de título con botón de cierre
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Seleccionar Cliente',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Campo de búsqueda
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar cliente...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _filterClients('');
                },
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: _filterClients,
          ),
          const SizedBox(height: 16),

          // Lista de clientes
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_filteredClients.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_off,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty
                          ? 'No hay clientes disponibles'
                          : 'No se encontraron resultados para "$_searchQuery"',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _filteredClients.length,
                itemBuilder: (context, index) {
                  final client = _filteredClients[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade100,
                        child: Text(
                          client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        client.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(client.businessName),
                          Text(
                            client.email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.check_circle_outline),
                        color: Colors.green,
                        onPressed: () {
                          Navigator.pop(context, client);
                        },
                      ),
                      onTap: () {
                        Navigator.pop(context, client);
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}