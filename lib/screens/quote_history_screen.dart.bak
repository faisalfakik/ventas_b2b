import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/quote_model.dart';
import '../models/client_model.dart';
import '../services/quote_service.dart';
import '../services/client_service.dart';
import 'quote_screen.dart';

<<<<<<< HEAD
class QuoteHistoryScreen extends StatefulWidget {
  final String vendorId;
  final String? clientId; // Si se proporciona, solo muestra cotizaciones para este cliente

  const QuoteHistoryScreen({
=======
class HistorialCotizacion extends StatefulWidget {
  final String vendorId;
  final String? clientId; // Si se proporciona, solo muestra cotizaciones para este cliente

  const HistorialCotizacion({
>>>>>>> c4fb3bbdc82be66a1ec1a5123efa18aba6803721
    Key? key,
    required this.vendorId,
    this.clientId,
  }) : super(key: key);

  @override
<<<<<<< HEAD
  _QuoteHistoryScreenState createState() => _QuoteHistoryScreenState();
}

class _QuoteHistoryScreenState extends State<QuoteHistoryScreen> {
=======
  _HistorialCotizacionState createState() => _HistorialCotizacionState();
}

class _HistorialCotizacionState extends State<HistorialCotizacion> {
>>>>>>> c4fb3bbdc82be66a1ec1a5123efa18aba6803721
  final QuoteService _quoteService = QuoteService();
  final ClientService _clientService = ClientService();

  List<Quote> _quotes = [];
  Map<String, Client> _clientsMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar cotizaciones
      List<Quote> quotes;
      if (widget.clientId != null) {
        // Si hay un clientId, filtrar por ese cliente
        quotes = await _quoteService.getQuotesByClient(widget.clientId!);
      } else {
        // Cargar todas las cotizaciones del vendedor
        quotes = await _quoteService.getQuotesByVendor(widget.vendorId);
      }

      // Cargar información de todos los clientes para mostrar nombres
      final clients = await _clientService.getAllClients();
      final clientsMap = {for (var client in clients) client.id: client};

      setState(() {
        _quotes = quotes;
        _clientsMap = clientsMap;
        _isLoading = false;
      });
    } catch (e) {
      print('Error al cargar datos: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e')),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.clientId != null
              ? 'Cotizaciones para ${_getClientName(widget.clientId!)}'
              : 'Historial de Cotizaciones',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _quotes.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _quotes.length,
        itemBuilder: (context, index) => _buildQuoteCard(_quotes[index]),
      ),
      floatingActionButton: widget.clientId != null
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuoteScreen(
                vendorId: widget.vendorId,
                clientId: widget.clientId,
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
            widget.clientId != null
                ? 'No hay cotizaciones para este cliente'
                : 'No hay cotizaciones',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.clientId != null
                ? 'Crea una nueva cotización usando el botón +'
                : 'Las cotizaciones que generes aparecerán aquí',
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.clientId != null) ...[
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
                      clientId: widget.clientId,
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
                    'Cotización #${quote.id.substring(0, 8)}',
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
                      color: _getStatusColor(quote.status).withValues(alpha: (0.1 * 255).toDouble()),
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
              if (widget.clientId == null) ...[
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
              ],
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
                    '\$${quote.calculateTotal().toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),

              // Botones de acción
              const SizedBox(height: 12),
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
                      // Aquí iría la lógica para generar y compartir el PDF
                      // Puedes reutilizar la función _generateAndSharePDF de QuoteScreen
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
    return _clientsMap[clientId]?.businessName ?? 'Cliente desconocido';
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
}