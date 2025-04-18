import 'package:cloud_firestore/cloud_firestore.dart';

class SerialValidationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Verifica si un serial es válido para un producto específico
  ///
  /// Retorna true si el serial existe en la base de datos y no ha sido utilizado
  /// Si [checkUsed] es true (por defecto), también verifica que el serial no esté usado
  Future<bool> isSerialValid(String serial, String productId, {bool checkUsed = true}) async {
    try {
      // Construir la consulta base
      Query query = _firestore
          .collection('valid_serials')
          .where('serial', isEqualTo: serial)
          .where('productId', isEqualTo: productId);

      // Si debemos verificar si está usado, añadir el filtro
      if (checkUsed) {
        query = query.where('used', isEqualTo: false);
      }

      // Ejecutar la consulta
      final snapshot = await query.get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error validando serial: $e');
      return false;
    }
  }

  /// Marca un serial como utilizado en una venta específica
  Future<bool> markSerialAsUsed(String serial, String saleId) async {
    try {
      // Primero verificamos que el serial exista y no esté usado
      final snapshot = await _firestore
          .collection('valid_serials')
          .where('serial', isEqualTo: serial)
          .where('used', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) {
        return false; // Serial no encontrado o ya usado
      }

      final docId = snapshot.docs.first.id;

      // Actualizar el documento
      await _firestore.collection('valid_serials').doc(docId).update({
        'used': true,
        'saleId': saleId,
        'usedDate': FieldValue.serverTimestamp(),
      });

      return true; // Operación exitosa
    } catch (e) {
      print('Error marcando serial como usado: $e');
      return false;
    }
  }

  /// Verifica la disponibilidad de seriales para un producto específico
  Future<Map<String, dynamic>> getSerialStats(String productId) async {
    try {
      // Contar seriales disponibles
      final availableSnapshot = await _firestore
          .collection('valid_serials')
          .where('productId', isEqualTo: productId)
          .where('used', isEqualTo: false)
          .count()
          .get();

      // Contar seriales utilizados
      final usedSnapshot = await _firestore
          .collection('valid_serials')
          .where('productId', isEqualTo: productId)
          .where('used', isEqualTo: true)
          .count()
          .get();

      // Total de seriales
      final totalSnapshot = await _firestore
          .collection('valid_serials')
          .where('productId', isEqualTo: productId)
          .count()
          .get();

      return {
        'available': availableSnapshot.count,
        'used': usedSnapshot.count,
        'total': totalSnapshot.count,
      };
    } catch (e) {
      print('Error obteniendo estadísticas de seriales: $e');
      return {
        'available': 0,
        'used': 0,
        'total': 0,
        'error': e.toString(),
      };
    }
  }

  /// Carga individual de un serial
  Future<Map<String, dynamic>> addSerial(String serial, String productId) async {
    try {
      // Verificar si el serial ya existe
      final existingSnapshot = await _firestore
          .collection('valid_serials')
          .where('serial', isEqualTo: serial)
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'El serial ya existe en la base de datos',
        };
      }

      // Añadir el nuevo serial
      await _firestore.collection('valid_serials').add({
        'serial': serial,
        'productId': productId,
        'used': false,
        'addedDate': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Serial añadido correctamente',
      };
    } catch (e) {
      print('Error añadiendo serial: $e');
      return {
        'success': false,
        'message': 'Error al añadir el serial: $e',
      };
    }
  }

  /// Método para cargar seriales en lote usando operaciones batch
  ///
  /// Acepta una lista de seriales o una lista de mapas con datos adicionales
  Future<Map<String, dynamic>> uploadSerialsBatch(
      List<dynamic> serialsData, String productId) async {
    try {
      final batch = _firestore.batch();

      int added = 0;
      int duplicates = 0;
      List<String> errors = [];

      // Verificar duplicados primero
      for (var data in serialsData) {
        String serial;
        Map<String, dynamic> additionalData = {};

        // Determinar si es un string simple o un mapa con datos
        if (data is String) {
          serial = data.trim();
        } else if (data is Map<String, dynamic>) {
          serial = data['serial']?.toString().trim() ?? '';
          // Eliminar el campo serial para evitar duplicidad
          data.remove('serial');
          additionalData = Map<String, dynamic>.from(data);
        } else {
          errors.add('Formato de datos inválido: $data');
          continue;
        }

        if (serial.isEmpty) continue;

        try {
          // Verificar si el serial ya existe
          final existingSnapshot = await _firestore
              .collection('valid_serials')
              .where('serial', isEqualTo: serial)
              .get();

          if (existingSnapshot.docs.isEmpty) {
            // Añadir nuevo serial al batch
            final docRef = _firestore.collection('valid_serials').doc();
            batch.set(docRef, {
              'serial': serial,
              'productId': productId,
              'used': false,
              'addedDate': FieldValue.serverTimestamp(),
              ...additionalData,
            });
            added++;
          } else {
            duplicates++;
          }
        } catch (e) {
          errors.add('Error procesando serial $serial: $e');
        }
      }

      // Ejecutar el batch si hay documentos para añadir
      if (added > 0) {
        await batch.commit();
      }

      return {
        'success': errors.isEmpty,
        'added': added,
        'duplicates': duplicates,
        'total': serialsData.length,
        'errors': errors,
      };
    } catch (e) {
      print('Error en carga de seriales: $e');
      return {
        'success': false,
        'added': 0,
        'duplicates': 0,
        'total': serialsData.length,
        'errors': ['Error general: $e'],
      };
    }
  }

  /// Valida un serial usado para una venta específica
  Future<bool> validateSaleSerial(String serial, String saleId) async {
    try {
      final snapshot = await _firestore
          .collection('valid_serials')
          .where('serial', isEqualTo: serial)
          .where('saleId', isEqualTo: saleId)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error validando serial de venta: $e');
      return false;
    }
  }

  /// Verifica la existencia de un serial sin importar su estado
  Future<Map<String, dynamic>> getSerialInfo(String serial) async {
    try {
      final snapshot = await _firestore
          .collection('valid_serials')
          .where('serial', isEqualTo: serial)
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'exists': false,
          'message': 'Serial no encontrado',
        };
      }

      final data = snapshot.docs.first.data();
      final bool isUsed = data['used'] ?? false;

      return {
        'exists': true,
        'used': isUsed,
        'productId': data['productId'],
        'saleId': data['saleId'],
        'usedDate': data['usedDate'],
        'data': data,
      };
    } catch (e) {
      print('Error obteniendo información del serial: $e');
      return {
        'exists': false,
        'error': e.toString(),
      };
    }
  }
}