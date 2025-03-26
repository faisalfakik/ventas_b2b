// catalog_screen.dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/catalog_model.dart';
import '../services/catalog_service.dart';
import '../services/auth_service.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({Key? key}) : super(key: key);

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final CatalogService _catalogService = CatalogService();
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  List<CatalogDocument> _catalogs = [];

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
  }

  Future<void> _loadCatalogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener el rol del usuario actual
      final userRole = _authService.currentUser?.role.toString().split('.').last ?? 'client';

      // Cargar catálogos visibles para este rol
      final catalogs = await _catalogService.getAvailableCatalogs(role: userRole);

      setState(() {
        _catalogs = catalogs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error al cargar catálogos: $e');

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar catálogos: $e')),
      );
    }
  }

  Future<void> _shareCatalog(CatalogDocument catalog, String method) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Descargar el catálogo a un archivo local
      final String localPath = await _catalogService.downloadCatalog(catalog.id);
      final XFile xFile = XFile(localPath);

      if (method == 'whatsapp') {
        // Compartir vía WhatsApp
        final message = 'Catálogo ${catalog.name}: ${catalog.description}';
        final whatsappUrl = Uri.parse('whatsapp://send?text=$message');

        if (await canLaunchUrl(whatsappUrl)) {
          await launchUrl(whatsappUrl);
          // WhatsApp no soporta adjuntos directamente desde URL, así que compartimos el archivo después
          await Share.shareXFiles([xFile], text: message);
        } else {
          throw 'No se pudo abrir WhatsApp';
        }
      } else {
        // Compartir vía email u otro método
        await Share.shareXFiles(
          [xFile],
          subject: 'Catálogo ${catalog.name}',
          text: 'Adjunto encontrará el catálogo ${catalog.name}.\n\n${catalog.description}',
        );
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir catálogo: $e')),
      );
    }
  }

  Future<void> _viewCatalog(CatalogDocument catalog) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Descargar el catálogo a un archivo local
      final String localPath = await _catalogService.downloadCatalog(catalog.id);

      // Abrir el archivo
      final Uri uri = Uri.file(localPath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'No se pudo abrir el archivo';
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir catálogo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogos y Ofertas'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCatalogs,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _catalogs.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay catálogos disponibles',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _catalogs.length,
        itemBuilder: (context, index) {
          final catalog = _catalogs[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Miniatura del catálogo
                catalog.thumbnailUrl.isNotEmpty
                    ? Image.network(
                  catalog.thumbnailUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 120,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                      ),
                    );
                  },
                )
                    : Container(
                  height: 120,
                  color: Colors.grey.shade200,
                  child: Center(
                    child: Icon(
                      catalog.type == CatalogType.pdf
                          ? Icons.picture_as_pdf
                          : Icons.image,
                      size: 48,
                      color: Colors.grey,
                    ),
                  ),
                ),

                // Información del catálogo
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              catalog.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          if (catalog.type == CatalogType.offer)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'OFERTA',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        catalog.description,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (catalog.expiryDate != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Válido hasta: ${catalog.expiryDate!.day}/${catalog.expiryDate!.month}/${catalog.expiryDate!.year}',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Botones de acción
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.visibility),
                            label: const Text('Ver'),
                            onPressed: () => _viewCatalog(catalog),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.chat, color: Colors.green), // O cualquier otro icono disponible
                            label: const Text('WhatsApp'),
                            onPressed: () => _shareCatalog(catalog, 'whatsapp'),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.share),
                            label: const Text('Compartir'),
                            onPressed: () => _shareCatalog(catalog, 'other'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
