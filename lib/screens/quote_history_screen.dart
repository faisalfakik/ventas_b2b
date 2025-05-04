import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quote_model.dart';
import '../models/customer_model.dart' as cust;
import '../services/quote_service.dart';
import '../services/customer_service.dart';
import 'quote_screen.dart';

class QuoteHistoryScreen extends StatefulWidget {
  final String? vendorId;
  final String? clientId;

  const QuoteHistoryScreen({
    Key? key,
    this.vendorId,
    this.clientId,
  }) : super(key: key);

  @override
  _QuoteHistoryScreenState createState() => _QuoteHistoryScreenState();
}

class _QuoteHistoryScreenState extends State<QuoteHistoryScreen> {
  final QuoteService _quoteService = QuoteService();
  final CustomerService _customerService = CustomerService();
  final TextEditingController _searchController = TextEditingController();

  List<Quote> _allQuotes = [];
  List<Quote> _filteredQuotes = [];
  Map<String, cust.Customer> _clientsMap = {};
  List<cust.Customer> _allClients = [];

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // Filtros
  String? _selectedCustomerId;
  String _searchQuery = '';
  String _selectedPeriod = 'all';

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.clientId;

    if (widget.vendorId == null || widget.vendorId!.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'ID de vendedor no disponible';
        _isLoading = false;
      });
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (widget.vendorId == null || widget.vendorId!.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'ID de vendedor no disponible';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    print("DEBUG: Cargando cotizaciones para vendorId: ${widget.vendorId}");

    try {
      final clients = await _customerService.getAllClients();
      final clientsMap = {for (var client in clients) client.id: client};
      print("DEBUG: Cargados ${clients.length} clientes");

      List<Quote> quotes = [];

      if (_selectedCustomerId != null && _selectedCustomerId!.isNotEmpty) {
        quotes = await _quoteService.getQuotesByCustomer(_selectedCustomerId!);
        print("DEBUG: Cargadas ${quotes.length} cotizaciones para cliente $_selectedCustomerId");
      } else {
        quotes = await _quoteService.getQuotesByVendor(widget.vendorId!);
        print("DEBUG: Cargadas ${quotes.length} cotizaciones para vendedor ${widget.vendorId}");
      }

      if (quotes.isEmpty) {
        print("DEBUG: No se encontraron cotizaciones. Verificando consulta en Firestore...");
        try {
          final querySnapshot = await FirebaseFirestore.instance
              .collection('quotes')
              .where('vendorId', isEqualTo: widget.vendorId)
              .get();

          print("DEBUG: Consulta directa a Firestore devolvió ${querySnapshot.docs.length} documentos");
          for (var doc in querySnapshot.docs) {
            print("DEBUG: Documento encontrado: ${doc.id}");
          }
        } catch (e) {
          print("DEBUG: Error en consulta directa a Firestore: $e");
        }
      }

      if (mounted) {
        setState(() {
          _allQuotes = quotes;
          _clientsMap = clientsMap;
          _allClients = clients;
          _isLoading = false;
        });

        _applyFilters();
      }
    } catch (e) {
      print('ERROR al cargar datos: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Error al cargar datos: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    List<Quote> filtered = List.from(_allQuotes);

    if (_selectedCustomerId != null && _selectedCustomerId!.isNotEmpty) {
      filtered = filtered.where((quote) => quote.clientId == _selectedCustomerId).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((quote) {
        final client = _clientsMap[quote.clientId];
        if (client == null) return false;

        return client.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (client.businessName?.toLowerCase() ?? '').contains(_searchQuery.toLowerCase()) ||
            quote.id.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (_selectedPeriod != 'all') {
      final now = DateTime.now();
      DateTime startDate;

      switch (_selectedPeriod) {
        case 'month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'quarter':
          final quarterStartMonth = (now.month - 1) ~/ 3 * 3 + 1;
          startDate = DateTime(now.year, quarterStartMonth, 1);
          break;
        case 'year':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = DateTime(1900);
      }

      filtered = filtered.where((quote) => quote.createdAt.isAfter(startDate)).toList();
    }

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    setState(() {
      _filteredQuotes = filtered;
    });
  }

  // Agrupar cotizaciones por mes
  Map<String, List<Quote>> _groupQuotesByMonth() {
    return groupBy(_filteredQuotes, (Quote quote) {
      final dateFormat = DateFormat('MMMM yyyy');
      return dateFormat.format(quote.createdAt);
    });
  }

  Future<void> _viewQuote(Quote quote) async {
    // Navegar a la pantalla de cotización en modo edición
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuoteScreen(
          vendorId: widget.vendorId,
          clientId: quote.clientId,
          quoteId: quote.id,
        ),
      ),
    );

    // Recargar datos al regresar
    _loadData();
  }

  // Método para mostrar el modal de búsqueda de clientes
  void _showSearchModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Para que pueda ocupar más espacio
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Filtramos la lista de clientes basados en la búsqueda
            List<cust.Customer> filteredClients = _allClients.where((client) {
              String searchLower = _searchQuery.toLowerCase();
              return client.name.toLowerCase().contains(searchLower) ||
                  client.businessName.toLowerCase().contains(searchLower);
            }).toList();

            return Container(
              padding: EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                children: [
                  Text(
                    'Seleccionar Cliente',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar cliente...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: filteredClients.isEmpty
                        ? Center(
                      child: Text('No se encontraron clientes'),
                    )
                        : ListView.builder(
                      itemCount: filteredClients.length,
                      itemBuilder: (context, index) {
                        cust.Customer client = filteredClients[index];
                        return ListTile(
                          title: Text(client.name),
                          subtitle: Text(client.businessName),
                          onTap: () {
                            setState(() {
                              _selectedCustomerId = client.id;
                              _searchQuery = client.name;
                              _searchController.text = client.name;
                            });
                            _applyFilters();
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial de Cotizaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _hasError
          ? _buildErrorState()
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _filteredQuotes.isEmpty
                ? _buildEmptyState()
                : _buildQuotesList(),
          ),
        ],
      ),
      floatingActionButton: (!_hasError && _selectedCustomerId != null)
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuoteScreen(
                vendorId: widget.vendorId,
                clientId: _selectedCustomerId,
              ),
            ),
          ).then((_) => _loadData());
        },
        child: const Icon(Icons.add),
        tooltip: 'Nueva Cotización',
      )
          : null,
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Padding más reducido
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo de búsqueda con altura controlada
          Container(
            height: 40, // Altura fija para el TextField
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por cliente o folio...',
                prefixIcon: const Icon(Icons.search, size: 18), // Tamaño más reducido
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  icon: const Icon(Icons.clear, size: 16), // Tamaño más reducido
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                    _applyFilters();
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8), // Padding más reducido
                isDense: true, // Hace el campo más compacto
              ),
              style: TextStyle(fontSize: 13), // Fuente más pequeña
              readOnly: true, // Evita que aparezca el teclado
              onTap: () {
                // Muestra el modal de búsqueda en lugar del teclado
                _showSearchModal();
              },
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _applyFilters();
              },
            ),
          ),
          const SizedBox(height: 4), // Espacio aún más reducido

          // Reduce el tamaño de los dropdowns
          Container(
            height: 45, // Altura fija para la fila de dropdowns
            child: Row(
              children: [
                // Selector de Cliente
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    isExpanded: true, // Evita desbordamiento de texto
                    decoration: InputDecoration(
                      labelText: 'Cliente',
                      labelStyle: TextStyle(fontSize: 12), // Etiqueta más pequeña
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Padding más reducido
                      border: OutlineInputBorder(),
                      isDense: true, // Hacer el campo más compacto
                    ),
                    value: _selectedCustomerId,
                    onChanged: (newValue) {
                      setState(() {
                        _selectedCustomerId = newValue;
                      });
                      _applyFilters();
                    },
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todos los clientes', style: TextStyle(fontSize: 12)),
                      ),
                      ..._allClients.map((client) => DropdownMenuItem<String?>(
                        value: client.id,
                        child: Text(
                          client.businessName.isNotEmpty
                              ? client.businessName
                              : client.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12), // Texto más pequeño
                        ),
                      )).toList(),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Selector de Período
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Período',
                      labelStyle: TextStyle(fontSize: 12),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    value: _selectedPeriod,
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedPeriod = newValue;
                        });
                        _applyFilters();
                      }
                    },
                    items: [
                      DropdownMenuItem<String>(
                        value: 'all',
                        child: Text('Todos los periodos', // Sin tilde en "periodos"
                            style: TextStyle(fontFamily: 'Roboto', fontSize: 12)),
                      ),
                      DropdownMenuItem<String>(
                        value: 'month',
                        child: Text('Este mes',
                            style: TextStyle(fontFamily: 'Roboto', fontSize: 12)),
                      ),
                      DropdownMenuItem<String>(
                        value: 'quarter',
                        child: Text('Este trimestre',
                            style: TextStyle(fontFamily: 'Roboto', fontSize: 12)),
                      ),
                      DropdownMenuItem<String>(
                        value: 'year',
                        child: Text('Este año',
                            style: TextStyle(fontFamily: 'Roboto', fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Estadísticas de cotizaciones
          Container(
            height: 24, // Altura fija para estadísticas
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mostrando ${_filteredQuotes.length} de ${_allQuotes.length} cotizaciones',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                if (_filteredQuotes.isNotEmpty)
                  Text(
                    'Total: \$${_calculateTotalAmount().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotalAmount() {
    return _filteredQuotes.fold(0, (sum, quote) => sum + quote.total);
  }

  Widget _buildQuotesList() {
    final groupedQuotes = _groupQuotesByMonth();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedQuotes.length,
      itemBuilder: (context, index) {
        final monthYear = groupedQuotes.keys.elementAt(index);
        final quotesInMonth = groupedQuotes[monthYear]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado del mes
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    monthYear,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${quotesInMonth.length} cotizaciones',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Total: \$${_calculateMonthTotal(quotesInMonth).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Tarjetas de cotizaciones del mes
            ...quotesInMonth.map((quote) => _buildQuoteCard(quote)).toList(),

            // Separador entre meses
            if (index < groupedQuotes.length - 1)
              Divider(height: 32, thickness: 1, color: Colors.grey.shade300),
          ],
        );
      },
    );
  }

  double _calculateMonthTotal(List<Quote> quotes) {
    return quotes.fold(0, (sum, quote) => sum + quote.total);
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            onPressed: _loadData,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedCustomerId != null
                ? 'No hay cotizaciones para este cliente'
                : _searchQuery.isNotEmpty
                ? 'No se encontraron resultados para "$_searchQuery"'
                : 'No hay cotizaciones',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedCustomerId != null
                ? 'Crea una nueva cotización usando el botón +'
                : 'Las cotizaciones que generes aparecerán aquí',
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          if (_selectedCustomerId != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Nueva Cotización'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QuoteScreen(
                      vendorId: widget.vendorId,
                      clientId: _selectedCustomerId,
                    ),
                  ),
                ).then((_) => _loadData());
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuoteCard(Quote quote) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final formattedDate = dateFormat.format(quote.createdAt);
    final clientName = _getClientName(quote.clientId);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _viewQuote(quote),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera con fecha e ID
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cotización #${quote.id.length > 8 ? quote.id.substring(0, 8) : quote.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(quote.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getStatusText(quote.status),
                      style: TextStyle(
                        color: _getStatusColor(quote.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Fecha y cliente
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade700),
                  const SizedBox(width: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.business, size: 14, color: Colors.grey.shade700),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      clientName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Detalles sobre productos y total
              Row(
                children: [
                  Icon(Icons.shopping_cart, size: 14, color: Colors.grey.shade700),
                  const SizedBox(width: 4),
                  Text(
                    '${quote.items.length} productos',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Total:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '\$${quote.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),

              // Botones de acción
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Editar'),
                    onPressed: () => _viewQuote(quote),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('Generar PDF'),
                    onPressed: () async {
                      try {
                        // Mostrar un indicador de carga
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Generando PDF...'),
                            duration: Duration(seconds: 1),
                          ),
                        );

                        // Obtener datos necesarios
                        final client = _clientsMap[quote.clientId];

                        if (client == null) {
                          throw Exception('Cliente no encontrado');
                        }

                        // Cargar información del vendedor (si es necesario)
                        // Esta parte dependería de cómo manejas la información del vendedor

                        // Por ahora, mostraremos un mensaje de que la función está en desarrollo
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('La generación de PDF estará disponible próximamente'),
                          ),
                        );

                        // En una versión completa, generarías y compartirías el PDF
                        // final pdfPath = await _quoteService.generateQuotePdf(quote, client, vendor);
                        // await _quoteService.shareQuoteViaWhatsApp(pdfPath, client);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getClientName(String clientId) {
    final client = _clientsMap[clientId];
    if (client == null) return 'Cliente desconocido';

    return client.businessName.isNotEmpty
        ? client.businessName
        : client.name;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pendiente';
      case 'approved':
        return 'Aprobada';
      case 'rejected':
        return 'Rechazada';
      case 'expired':
        return 'Expirada';
      default:
        return 'Pendiente';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}