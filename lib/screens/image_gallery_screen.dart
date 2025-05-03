import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ImageGalleryScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String productName;
  final String productId; // <-- NECESARIO para Hero Tag consistente
  final String heroTagPrefix; // Prefijo consistente (ej: 'product_image_detail')

  const ImageGalleryScreen({
    Key? key,
    required this.images,
    required this.initialIndex,
    required this.productName,
    required this.productId, // <-- Añadido
    required this.heroTagPrefix, // <-- Añadido
  }) : super(key: key);

  @override
  _ImageGalleryScreenState createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _controlsVisible = true; // Controla visibilidad de AppBar/BottomBar

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    // Ocultar barras del sistema inicialmente
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); // Restaurar al salir
    _pageController.dispose();
    super.dispose();
  }

  void _toggleControlsVisibility() {
    if (!mounted) return;
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    // Cambiar modo de UI del sistema
    if (_controlsVisible) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Duration controlsAnimationDuration = Duration(milliseconds: 250);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Galería Principal
          GestureDetector( // Detector de toques sobre la galería para ocultar/mostrar controles
            onTap: _toggleControlsVisibility,
            child: PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (BuildContext context, int index) {
                // ** HERO TAG CONSISTENTE **
                // Usar el prefijo pasado, productId y el índice
                final heroTag = '${widget.heroTagPrefix}_${widget.productId}_$index';
                print("Galería Hero Tag: $heroTag"); // Debug: Verifica el tag

                return PhotoViewGalleryPageOptions(
                  imageProvider: CachedNetworkImageProvider(widget.images[index]),
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained * 0.8,
                  maxScale: PhotoViewComputedScale.covered * 2.5,
                  // Asegúrate que este tag coincida exactamente con el de ProductDetailScreen
                  heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
                  // Quitar onTapUp de aquí para usar el GestureDetector exterior
                  // onTapUp: (_, __, ___) => _toggleControlsVisibility(),
                );
              },
              itemCount: widget.images.length,
              loadingBuilder: (context, event) => const Center(child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white70))),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              pageController: _pageController,
              onPageChanged: (index) {
                if (mounted) setState(() => _currentIndex = index);
              },
            ),
          ),

          // --- Controles Superpuestos Animados ---
          // AppBar (Animado)
          AnimatedOpacity(
            opacity: _controlsVisible ? 1.0 : 0.0,
            duration: controlsAnimationDuration,
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: Container(
                // Gradiente sutil para mejorar legibilidad del texto/iconos
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                  ),
                ),
                child: AppBar(
                  title: Text(widget.productName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                  ),
                  systemOverlayStyle: SystemUiOverlayStyle.light, // CORRECCIÓN: Usar SystemUiOverlayStyle.light en lugar de SystemUiMode.light
                ),
              ),
            ),
          ),

          // Barra Inferior (Animada)
          AnimatedPositioned( // Animar posición para deslizar hacia arriba/abajo
            duration: controlsAnimationDuration,
            bottom: _controlsVisible ? 0 : -120, // Mover fuera de pantalla si no es visible
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: Container(
                padding: const EdgeInsets.only(bottom: 15, top: 15), // Padding ajustado
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: SafeArea( // SafeArea para la parte inferior
                  top: false, // Solo para bottom
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Indicadores de página
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.images.length, (i) => _buildPageIndicator(i == _currentIndex)),
                      ),
                      const SizedBox(height: 15),
                      // Miniaturas
                      if (widget.images.length > 1)
                        SizedBox(
                          height: 60, // Altura fija
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.images.length,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () {
                                  _pageController.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Container(
                                  width: 60,
                                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _currentIndex == index
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: CachedNetworkImage(
                                      imageUrl: widget.images[index],
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[800],
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey[800],
                                        child: const Icon(Icons.error, color: Colors.white54),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para indicadores de página en la parte inferior
  Widget _buildPageIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),  // CORRECCIÓN: Añadir el parámetro duration requerido
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 8.0,
      width: isActive ? 24.0 : 8.0,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}