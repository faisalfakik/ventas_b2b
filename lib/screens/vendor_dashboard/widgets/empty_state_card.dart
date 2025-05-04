import 'package:flutter/material.dart';

class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Obtener tema dentro del build
    return Card(
      elevation: 0,
      // Usar colores del tema para consistencia
      color: theme.cardColor.withOpacity(0.5),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          // Borde sutil usando color del tema
          side: BorderSide(color: theme.dividerColor)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 54, color: theme.disabledColor), // Color deshabilitado del tema
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.hintColor), // Color de pista del tema
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}