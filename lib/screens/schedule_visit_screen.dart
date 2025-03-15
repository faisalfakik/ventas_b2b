import 'package:flutter/material.dart';
import '../models/vendor_models.dart';

class ScheduleVisitScreen extends StatelessWidget {
  final String vendorId;

  const ScheduleVisitScreen({
    Key? key,
    required this.vendorId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Programar Visita', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Text('Pantalla para programar visita para el vendedor $vendorId'),
      ),
    );
  }
}