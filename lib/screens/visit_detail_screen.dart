import 'package:flutter/material.dart';
import '../models/vendor_models.dart';

class VisitDetailScreen extends StatelessWidget {
  final String visitId;

  const VisitDetailScreen({
    Key? key,
    required this.visitId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles de Visita', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Text('Detalles de la visita $visitId'),
      ),
    );
  }
}