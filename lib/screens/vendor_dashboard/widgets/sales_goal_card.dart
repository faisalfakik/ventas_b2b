import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ventas_b2b/models/sales_goal_model.dart'; // Modelo correcto
import 'package:ventas_b2b/utils/helpers.dart'; // Para formatCurrency


class SalesGoalCard extends StatelessWidget {
  final SalesGoal currentGoal;
  const SalesGoalCard({super.key, required this.currentGoal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Lógica de cálculo de porcentaje y color
    final percentComplete = currentGoal.completionPercentage;
    final formattedCurrent = formatCurrency(currentGoal.currentAmount); // Usa helper
    final formattedTarget = formatCurrency(currentGoal.targetAmount); // Usa helper

    // Define colores basados en progreso y tema
    Color progressColor = theme.colorScheme.secondary; // Color secundario por defecto
    if (percentComplete < 30) {
      progressColor = theme.colorScheme.error; // Color de error del tema
    } else if (percentComplete < 70) {
      progressColor = Colors.orange.shade600; // Naranja (puedes ponerlo en el tema si quieres)
    } else {
      progressColor = Colors.green.shade600; // Verde (puedes ponerlo en el tema)
    }

    return Card(
      elevation: 1.5, // Elevación sutil
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias, // Para asegurar que el borde redondeado recorte el contenido
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Objetivo Mensual', style: textTheme.titleMedium),
                Text(
                  // Formatea la fecha con mes y año en español
                  DateFormat('MMMM yyyy', 'es').format(DateTime(currentGoal.year, currentGoal.month)),
                  style: textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Barra de progreso estilizada
            LinearProgressIndicator(
              value: percentComplete / 100,
              backgroundColor: theme.dividerColor.withOpacity(0.5),
              color: progressColor,
              minHeight: 12, // Grosor
              borderRadius: BorderRadius.circular(6), // Bordes redondeados
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$formattedCurrent / $formattedTarget',
                  style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${percentComplete.toStringAsFixed(1)}%',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}