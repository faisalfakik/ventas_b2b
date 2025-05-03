import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:cross_file/cross_file.dart';
import 'dart:io';
import 'dart:math';
import '../models/quote_model.dart';
import '../models/quote_item.dart';
import '../models/product_model.dart';
import '../models/customer_model.dart' as cust;
import '../services/product_service.dart';

class QuoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ProductService _productService = ProductService();
  final String collectionName = 'quotes';

  // Obtener todas las cotizaciones de un vendedor
  Future<List<Quote>> getQuotesByVendor(String vendorId) async {
    try {
      print("DEBUG: Buscando cotizaciones para vendorId: $vendorId");

      final querySnapshot = await _firestore
          .collection(collectionName)
          .where('vendorId', isEqualTo: vendorId)
          .orderBy('createdAt', descending: true)
          .get();

      print("DEBUG: Se encontraron ${querySnapshot.docs.length} cotizaciones para el vendedor");

      List<Quote> quotes = [];
      for (var doc in querySnapshot.docs) {
        try {
          quotes.add(await Quote.fromFirestore(doc, productService: _productService));
        } catch (e) {
          print("ERROR convirtiendo documento a Quote: $e");
        }
      }

      return quotes;
    } catch (e) {
      print("ERROR en getQuotesByVendor: $e");
      rethrow;
    }
  }

  // Obtener cotizaciones de un cliente específico
  Future<List<Quote>> getQuotesByCustomer(String clientId) async {
    try {
      print("DEBUG: Buscando cotizaciones para clientId: $clientId");

      final querySnapshot = await _firestore
          .collection(collectionName)
          .where('clientId', isEqualTo: clientId)
          .orderBy('createdAt', descending: true)
          .get();

      print("DEBUG: Se encontraron ${querySnapshot.docs.length} cotizaciones para el cliente");

      List<Quote> quotes = [];
      for (var doc in querySnapshot.docs) {
        try {
          quotes.add(await _documentToQuote(doc));
        } catch (e) {
          print("ERROR convirtiendo documento a Quote: $e");
        }
      }

      return quotes;
    } catch (e) {
      print("ERROR en getQuotesByClient: $e");
      rethrow;
    }
  }

  // Obtener una cotización por ID
  Future<Quote?> getQuoteById(String quoteId) async {
    try {
      print("DEBUG: Buscando cotización con ID: $quoteId");

      final docSnapshot = await _firestore
          .collection(collectionName)
          .doc(quoteId)
          .get();

      if (!docSnapshot.exists) {
        print("DEBUG: No se encontró cotización con ID: $quoteId");
        return null;
      }

      return await _documentToQuote(docSnapshot);
    } catch (e) {
      print("ERROR en getQuoteById: $e");
      rethrow;
    }
  }

  // Método auxiliar para convertir un documento Firestore a un objeto Quote
  Future<Quote> _documentToQuote(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    // Convertir los items de la cotización
    List<QuoteItem> quoteItems = [];
    if (data['items'] != null) {
      final items = data['items'] as List<dynamic>;

      for (var itemData in items) {
        final productId = itemData['productId'];
        Product? product = await _productService.getProductById(productId);

        if (product == null) {
          // Si no se encuentra el producto, crear uno genérico
          product = Product(
            id: productId,
            name: 'Producto no disponible',
            price: 0,
            description: '',
            category: '',
            imageUrl: '',
            stock: 0,
          );
        }

        quoteItems.add(QuoteItem(
          product: product,
          quantity: itemData['quantity'] ?? 1,
          price: (itemData['price'] ?? 0).toDouble(),
          discount: (itemData['discount'] ?? 0).toDouble(),
        ));
      }
    }

    // Crear el objeto Quote
    return Quote(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      vendorId: data['vendorId'] ?? '',
      items: quoteItems,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
      subtotal: (data['subtotal'] ?? 0).toDouble(),
      tax: (data['tax'] ?? 0).toDouble(),
      total: (data['total'] ?? 0).toDouble(),
      validityDays: data['validityDays'] ?? 30,
      deliveryDays: data['deliveryDays'] ?? 15,
      paymentTerms: data['paymentTerms'] ?? 'Contado',
      notes: data['notes'] ?? '',
    );
  }

  // Actualizar estado de cotización
  Future<bool> updateQuoteStatus(String quoteId, String newStatus) async {
    try {
      await _firestore
          .collection(collectionName)
          .doc(quoteId)
          .update({'status': newStatus});

      return true;
    } catch (e) {
      print("ERROR actualizando estado de cotización: $e");
      return false;
    }
  }

  // Eliminar una cotización
  Future<bool> deleteQuote(String quoteId) async {
    try {
      await _firestore
          .collection(collectionName)
          .doc(quoteId)
          .delete();

      print("DEBUG: Cotización eliminada con ID: $quoteId");
      return true;
    } catch (e) {
      print("ERROR eliminando cotización: $e");
      return false;
    }
  }

  // Generar PDF de cotización
  Future<String> generateQuotePdf(Quote quote, cust.Customer customer) async {
    final pdf = pw.Document();

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
                        'Fecha: ${DateFormat('dd/MM/yyyy').format(quote.createdAt)}',
                        style: const pw.TextStyle(
                          fontSize: 12,
                        ),
                      ),
                      pw.Text(
                        'Folio: COT-${quote.id.substring(0, min(quote.id.length, 8))}',
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
                      customer.name ?? 'Cliente general',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    if (customer.email?.isNotEmpty ?? false) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        customer.email ?? '',
                        style: const pw.TextStyle(
                          fontSize: 10,
                        ),
                      ),
                    ],
                    if (customer.phone?.isNotEmpty ?? false) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        customer.phone ?? '',
                        style: const pw.TextStyle(
                          fontSize: 10,
                        ),
                      ),
                    ],
                    if (customer.address?.isNotEmpty ?? false) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        customer.address ?? '',
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
                  for (int i = 0; i < quote.items.length; i++)
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
                                quote.items[i].product.name,
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                quote.items[i].product.description.length > 50
                                    ? '${quote.items[i].product.description.substring(0, 50)}...'
                                    : quote.items[i].product.description,
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
                            '${quote.items[i].quantity}',
                            style: const pw.TextStyle(),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '\$${quote.items[i].price.toStringAsFixed(2)}',
                            style: const pw.TextStyle(),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            quote.items[i].discount > 0
                                ? '${quote.items[i].discount.toStringAsFixed(1)}%'
                                : '-',
                            style: const pw.TextStyle(),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '\$${_calculateItemSubtotal(quote.items[i]).toStringAsFixed(2)}',
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
                            '\$${quote.subtotal.toStringAsFixed(2)}',
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
                            '\$${quote.total.toStringAsFixed(2)}',
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
                                '${quote.validityDays} días',
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
                                '${quote.deliveryDays} días',
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
                                quote.paymentTerms,
                                style: const pw.TextStyle(
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (quote.notes?.isNotEmpty == true) ...[
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
                        quote.notes ?? '',
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

    // Guardar PDF
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/cotizacion_${quote.id}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  // Compartir cotización por WhatsApp
  Future<void> shareQuoteViaWhatsApp(String pdfPath, cust.Customer customer) async {
    final message = '''
Hola ${customer.name},

Adjunto encontrarás la cotización solicitada. Gracias por tu interés en nuestros productos.

Para cualquier duda o aclaración, no dudes en contactarnos.

Saludos cordiales,
GTRONIC
''';

    await Share.shareXFiles(
      [XFile(pdfPath)],
      text: message,
      subject: 'Cotización GTRONIC',
    );
  }

  // Método de diagnóstico para depuración
  Future<void> debugPrintAllQuotes() async {
    try {
      final snapshot = await _firestore.collection(collectionName).get();
      print("--------- DIAGNÓSTICO DE COTIZACIONES ---------");
      print("Total de cotizaciones en Firestore: ${snapshot.docs.length}");

      for (var doc in snapshot.docs) {
        print("ID: ${doc.id}");
        print("Data: ${doc.data()}");
        print("-------------------------------");
      }
    } catch (e) {
      print("Error en diagnóstico: $e");
    }
  }

  // Método auxiliar para calcular subtotal de un item
  double _calculateItemSubtotal(QuoteItem item) {
    return item.price * item.quantity * (1 - item.discount / 100);
  }
}