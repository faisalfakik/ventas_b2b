import 'package:flutter/material.dart';

// Indicador de carga simple (usado al final de listas paginadas)
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
          child: SizedBox(
              width: 24, // Tamaño definido
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3))), // Grosor definido
    );
  }
}

// Botón para cargar más elementos en listas paginadas
class LoadMoreButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  const LoadMoreButton({super.key, required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: OutlinedButton( // Usar OutlinedButton para menos énfasis que ElevatedButton
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );
  }
}