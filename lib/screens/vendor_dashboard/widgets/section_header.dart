import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAllPressed;

  const SectionHeader(
      this.title, {
        super.key,
        this.onViewAllPressed,
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ✅ Título principal
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),

          // ✅ Botón opcional “Ver Todos”
          if (onViewAllPressed != null)
            TextButton.icon(
              onPressed: onViewAllPressed,
              icon: const Icon(Icons.arrow_forward_ios, size: 12),
              label: const Text('Ver todos'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: textTheme.bodySmall,
                foregroundColor: theme.primaryColor,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}
