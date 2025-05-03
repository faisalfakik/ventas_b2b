import 'package:flutter/material.dart';

/// Un botón de acción rápida, compacto y personalizable, ideal para tarjetas o filas.
///
/// Muestra un icono y ejecuta una acción `onPressed`. Soporta estados
/// deshabilitado y de carga.
class QuickActionButton extends StatelessWidget {
  /// El icono a mostrar.
  final IconData icon;
  /// Texto descriptivo para accesibilidad y tooltip.
  final String tooltip;
  /// La función a ejecutar cuando se presiona. Si es null, el botón se deshabilita.
  final VoidCallback? onPressed;
  /// Color del icono en estado normal. Usa el color primario del tema por defecto.
  final Color? iconColor;
  /// Color del icono cuando el botón está deshabilitado. Usa el color desactivado del tema por defecto.
  final Color? disabledIconColor;
  /// Color de fondo del botón. Transparente por defecto.
  final Color? backgroundColor;
  /// Color de fondo al presionar (splash). Usa el color del icono con opacidad por defecto.
  final Color? splashColor;
  /// Color del indicador de progreso en estado de carga. Usa el color del icono por defecto.
  final Color? loadingColor;
  /// Tamaño del icono. Por defecto es 20.0.
  final double iconSize;
  /// Padding alrededor del icono. Por defecto es `EdgeInsets.all(8.0)`.
  final EdgeInsetsGeometry padding;
  /// Radio del efecto "splash" al presionar. Por defecto es 20.0.
  final double splashRadius;
  /// Forma del botón (bordes). Por defecto es circular.
  final OutlinedBorder? shape;
  /// Si es true, muestra un indicador de progreso en lugar del icono y deshabilita el botón.
  final bool isLoading;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor,
    this.disabledIconColor,
    this.backgroundColor,
    this.splashColor,
    this.loadingColor,
    this.iconSize = 20.0, // Tamaño por defecto ligeramente más pequeño
    this.padding = const EdgeInsets.all(8.0), // Padding estándar para IconButton
    this.splashRadius = 20.0, // Radio de splash por defecto
    this.shape = const CircleBorder(), // Forma circular por defecto
    this.isLoading = false, // No está cargando por defecto
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDisabled = onPressed == null || isLoading;

    // Determina el color efectivo del icono o indicador de carga
    final Color effectiveIconColor = isDisabled
        ? (disabledIconColor ?? theme.disabledColor) // Color deshabilitado
        : (iconColor ?? theme.colorScheme.primary); // Color normal o del tema

    // Color del indicador de progreso
    final Color effectiveLoadingColor = loadingColor ?? effectiveIconColor;

    // Construye el estilo del botón usando ButtonStyle para más control
    final ButtonStyle style = IconButton.styleFrom(
      foregroundColor: effectiveIconColor, // Color del icono y splash por defecto
      backgroundColor: backgroundColor,    // Color de fondo
      disabledForegroundColor: disabledIconColor ?? theme.disabledColor, // Color icono deshabilitado
      disabledBackgroundColor: backgroundColor?.withOpacity(0.5), // Fondo deshabilitado semi-transparente
      padding: padding,
      minimumSize: Size.square(iconSize + padding.horizontal), // Tamaño mínimo basado en icono+padding
      maximumSize: Size.square(iconSize + padding.horizontal + 4), // Un poco más grande máx
      shape: shape as OutlinedBorder?,
      visualDensity: VisualDensity.compact, // Mantiene la densidad compacta
      splashFactory: InkRipple.splashFactory, // Efecto ripple estándar
    ).copyWith(
      // OverlayColor permite definir colores para diferentes estados (hover, focus, pressed)
      overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
          if (states.contains(WidgetState.pressed)) {
            // Color al presionar (splash)
            return splashColor ?? effectiveIconColor.withOpacity(0.12);
          }
          // Puedes añadir colores para hover, focus si es necesario
          return null; // Usa el foregroundColor por defecto para otros estados
        },
      ),
    );


    return IconButton(
      icon: isLoading
          ? SizedBox( // Contenedor para darle tamaño al CircularProgressIndicator
        width: iconSize,
        height: iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2.0, // Más delgado
          valueColor: AlwaysStoppedAnimation<Color>(effectiveLoadingColor),
        ),
      )
          : Icon(icon, size: iconSize), // Icono normal
      tooltip: isLoading ? 'Cargando...' : tooltip,
      // Deshabilita si onPressed es null o si está cargando
      onPressed: isDisabled ? null : onPressed,
      padding: EdgeInsets.zero, // El padding se maneja en ButtonStyle
      constraints: const BoxConstraints(), // El tamaño se maneja en ButtonStyle
      splashRadius: splashRadius,
      iconSize: iconSize, // Pasa el tamaño aunque ButtonStyle lo controle (redundancia segura)
      visualDensity: VisualDensity.compact, // Redundancia segura
      style: style, // Aplica el ButtonStyle definido
    );
  }
}