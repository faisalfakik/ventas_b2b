import 'package:flutter/material.dart';
import 'dart:async';

/// Enum para definir los posibles estados visuales del botón.
enum ButtonState { idle, loading, success, error }

class AnimatedAddButton extends StatefulWidget {
  final VoidCallback onPressed;
  final int quantity;
  final bool isLoading; // Controlado por el padre: ¿Está la operación en curso?
  final bool showSuccess; // Controlado por el padre: ¿Debe mostrar éxito?
  final bool showError; // Controlado por el padre: ¿Debe mostrar error?
  final String idleText; // Texto cuando no está cargando
  final String loadingText;
  final String successText;
  final String errorText;
  final IconData idleIcon;
  final IconData successIcon;
  final IconData errorIcon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color loadingColor;
  final Color successColor;
  final Color errorColor;
  final Duration animationDuration;
  final Duration successDuration; // Cuánto tiempo mostrar éxito/error antes de volver a idle

  const AnimatedAddButton({
    Key? key,
    required this.onPressed,
    required this.quantity,
    this.isLoading = false,
    this.showSuccess = false,
    this.showError = false,
    this.idleText = 'AGREGAR {qty} AL CARRITO', // Placeholder para cantidad
    this.loadingText = 'AGREGANDO...',
    this.successText = '¡AGREGADO!',
    this.errorText = 'ERROR',
    this.idleIcon = Icons.add_shopping_cart,
    this.successIcon = Icons.check_circle_outline,
    this.errorIcon = Icons.error_outline,
    this.backgroundColor = Colors.green, // Color por defecto
    this.foregroundColor = Colors.white,
    this.loadingColor = Colors.white, // Color del spinner
    this.successColor = Colors.white, // Color icono/texto éxito
    this.errorColor = Colors.white, // Color icono/texto error
    this.animationDuration = const Duration(milliseconds: 300),
    this.successDuration = const Duration(seconds: 2),
  }) : super(key: key);

  @override
  _AnimatedAddButtonState createState() => _AnimatedAddButtonState();
}

class _AnimatedAddButtonState extends State<AnimatedAddButton> {
  ButtonState _currentState = ButtonState.idle;
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    _updateStateFromProps();
  }

  @override
  void didUpdateWidget(covariant AnimatedAddButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateStateFromProps(oldWidget: oldWidget);
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  /// Actualiza el estado interno basado en las propiedades recibidas del widget padre.
  void _updateStateFromProps({AnimatedAddButton? oldWidget}) {
    // Prioridad: Error > Success > Loading > Idle
    ButtonState newState;
    if (widget.showError) {
      newState = ButtonState.error;
    } else if (widget.showSuccess) {
      newState = ButtonState.success;
    } else if (widget.isLoading) {
      newState = ButtonState.loading;
    } else {
      newState = ButtonState.idle;
    }

    // Si el estado cambió, actualizar
    if (_currentState != newState) {
      if (mounted) {
        setState(() {
          _currentState = newState;
        });
      }

      // Si el nuevo estado es éxito o error, programar reseteo a idle
      if (newState == ButtonState.success || newState == ButtonState.error) {
        _resetTimer?.cancel(); // Cancelar timer anterior
        _resetTimer = Timer(widget.successDuration, () {
          // Volver a idle *solo si* el estado actual sigue siendo success/error
          // (el padre podría haber cambiado isLoading mientras tanto)
          if ((_currentState == ButtonState.success && !widget.showSuccess && !widget.isLoading) ||
              (_currentState == ButtonState.error && !widget.showError && !widget.isLoading)) {
            if (mounted) {
              setState(() {
                _currentState = ButtonState.idle;
              });
            }
          }
        });
      } else {
        // Cancelar timer si pasamos a loading o idle directamente
        _resetTimer?.cancel();
      }
    }

    // Si la cantidad cambió mientras está en idle, actualizar el estado para reflejarlo
    // (esto es un caso borde, usualmente el texto se actualiza por el build directo)
    if (oldWidget != null && oldWidget.quantity != widget.quantity && _currentState == ButtonState.idle) {
      if (mounted) setState(() {});
    }
  }


  /// Determina el color de fondo basado en el estado actual.
  Color _getBackgroundColor(BuildContext context) {
    switch (_currentState) {
      case ButtonState.loading:
      // Un color ligeramente diferente o igual al idle pero deshabilitado visualmente
        return widget.backgroundColor.withOpacity(0.7);
      case ButtonState.success:
      // Usar un verde estándar si no se provee color específico
        return Colors.green.shade600;
      case ButtonState.error:
      // Usar un rojo estándar si no se provee color específico
        return Colors.red.shade600;
      case ButtonState.idle:
      default:
        return widget.backgroundColor;
    }
  }

  /// Determina el color del contenido (texto/icono) basado en el estado.
  Color _getForegroundColor() {
    switch(_currentState) {
      case ButtonState.success: return widget.successColor;
      case ButtonState.error: return widget.errorColor;
      case ButtonState.loading: // Puede ser el mismo que idle o uno específico
      case ButtonState.idle:
      default:
        return widget.foregroundColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reemplazar placeholder de cantidad en el texto idle
    final String idleButtonText = widget.idleText.replaceAll('{qty}', widget.quantity.toString());

    return AnimatedContainer( // Animar cambios de color/tamaño del contenedor
      duration: widget.animationDuration,
      curve: Curves.easeInOut,
      width: double.infinity, // Opcional: Animar width si cambia entre estados
      height: 50, // Altura fija
      decoration: BoxDecoration(
        color: _getBackgroundColor(context),
        borderRadius: BorderRadius.circular(25), // Mantener bordes redondeados
        boxShadow: _currentState != ButtonState.loading ? [ // Quitar sombra al cargar
          BoxShadow(
            color: _getBackgroundColor(context).withOpacity(0.3),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ] : [],
      ),
      child: ElevatedButton(
        onPressed: (_currentState == ButtonState.idle) ? widget.onPressed : null, // Deshabilitar si no está idle
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, // El color lo da el AnimatedContainer
          foregroundColor: _getForegroundColor(), // Color del texto/icono
          shadowColor: Colors.transparent, // Sin sombra propia
          elevation: 0, // Sin elevación propia
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Padding interno
        ),
        child: AnimatedSwitcher( // Animar el contenido del botón
          duration: widget.animationDuration,
          transitionBuilder: (child, animation) {
            // Usar Fade y Scale para una transición suave
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: animation,
                child: child,
              ),
            );
          },
          child: _buildButtonContent(idleButtonText), // Construir contenido según estado
        ),
      ),
    );
  }

  /// Construye el contenido interno del botón según el estado actual.
  Widget _buildButtonContent(String idleButtonText) {
    // Usar una Key asegura que AnimatedSwitcher detecte el cambio de widget
    switch (_currentState) {
      case ButtonState.loading:
        return KeyedSubtree(
          key: const ValueKey('loading'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20, height: 20, // Tamaño del spinner
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(widget.loadingColor),
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(width: 12),
              Text(widget.loadingText, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        );
      case ButtonState.success:
        return KeyedSubtree(
          key: const ValueKey('success'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.successIcon, color: widget.successColor),
              const SizedBox(width: 8),
              Text(widget.successText, style: TextStyle(fontWeight: FontWeight.bold, color: widget.successColor)),
            ],
          ),
        );
      case ButtonState.error:
        return KeyedSubtree(
          key: const ValueKey('error'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.errorIcon, color: widget.errorColor),
              const SizedBox(width: 8),
              Text(widget.errorText, style: TextStyle(fontWeight: FontWeight.bold, color: widget.errorColor)),
            ],
          ),
        );
      case ButtonState.idle:
      default:
        return KeyedSubtree(
          key: const ValueKey('idle'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.idleIcon),
              const SizedBox(width: 8),
              // Usar Flexible para que el texto no se desborde si es muy largo
              Flexible(child: Text(idleButtonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
            ],
          ),
        );
    }
  }
}