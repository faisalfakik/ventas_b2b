// lib/screens/vendor_dashboard/widgets/stat_card.dart

import 'package:flutter/material.dart';
import 'package:ventas_b2b/utils/helpers.dart'; // ✅ Para formatCurrency

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool formatAsCurrency; // ✅ Nuevo parámetro

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.formatAsCurrency = false, // ✅ Por defecto, no formatea
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final Color iconColor = theme.colorScheme.primary;

    // ✅ Aplica formatCurrency solo si es numérico y se solicita
    final String displayedValue = formatAsCurrency
        ? formatCurrency(double.tryParse(value))
        : value;

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 6),
            Text(
              displayedValue,
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
