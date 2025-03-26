import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName = 'vendor_locations';

  // Iniciar seguimiento de ubicación
  Future<void> startLocationTracking(String vendorId) async {
    try {
      // Verificar permisos de ubicación
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permisos de ubicación denegados');
        }
      }

      // Iniciar seguimiento en segundo plano
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Actualizar cada 10 metros
        ),
      ).listen((Position position) {
        _updateVendorLocation(vendorId, position);
      });
    } catch (e) {
      print('Error starting location tracking: $e');
      rethrow;
    }
  }

  // Actualizar ubicación del vendedor
  Future<void> _updateVendorLocation(String vendorId, Position position) async {
    try {
      await _firestore.collection(collectionName).doc(vendorId).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': FieldValue.serverTimestamp(),
        'speed': position.speed,
        'heading': position.heading,
        'isOnline': true,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating vendor location: $e');
    }
  }

  // Obtener ubicación actual del vendedor
  Stream<Map<String, dynamic>> getVendorLocation(String vendorId) {
    return _firestore
        .collection(collectionName)
        .doc(vendorId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return {};
      return doc.data() ?? {};
    });
  }

  // Obtener historial de ubicaciones
  Future<List<Map<String, dynamic>>> getLocationHistory({
    required String vendorId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .doc(vendorId)
          .collection('history')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'latitude': data['latitude'],
          'longitude': data['longitude'],
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
          'accuracy': data['accuracy'],
          'speed': data['speed'],
          'heading': data['heading'],
        };
      }).toList();
    } catch (e) {
      print('Error getting location history: $e');
      return [];
    }
  }

  // Detener seguimiento de ubicación
  Future<void> stopLocationTracking(String vendorId) async {
    try {
      await _firestore.collection(collectionName).doc(vendorId).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error stopping location tracking: $e');
    }
  }

  // Obtener vendedores cercanos
  Future<List<Map<String, dynamic>>> getNearbyVendors({
    required double latitude,
    required double longitude,
    required double radiusInKm,
  }) async {
    try {
      // Obtener todos los vendedores en línea
      final snapshot = await _firestore
          .collection(collectionName)
          .where('isOnline', isEqualTo: true)
          .get();

      final List<Map<String, dynamic>> nearbyVendors = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final vendorLat = data['latitude'] as double;
        final vendorLng = data['longitude'] as double;

        // Calcular distancia
        final distance = Geolocator.distanceBetween(
          latitude,
          longitude,
          vendorLat,
          vendorLng,
        ) / 1000; // Convertir a kilómetros

        if (distance <= radiusInKm) {
          nearbyVendors.add({
            'vendorId': doc.id,
            'distance': distance,
            'latitude': vendorLat,
            'longitude': vendorLng,
            'lastUpdate': (data['timestamp'] as Timestamp).toDate(),
          });
        }
      }

      // Ordenar por distancia
      nearbyVendors.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      return nearbyVendors;
    } catch (e) {
      print('Error getting nearby vendors: $e');
      return [];
    }
  }

  // Obtener estadísticas de movimientos
  Future<Map<String, dynamic>> getMovementStats({
    required String vendorId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final history = await getLocationHistory(
        vendorId: vendorId,
        startDate: startDate,
        endDate: endDate,
      );

      double totalDistance = 0;
      double averageSpeed = 0;
      int totalPoints = history.length;

      if (totalPoints > 1) {
        for (int i = 1; i < history.length; i++) {
          totalDistance += Geolocator.distanceBetween(
            history[i - 1]['latitude'],
            history[i - 1]['longitude'],
            history[i]['latitude'],
            history[i]['longitude'],
          );
        }

        averageSpeed = history.fold(0.0, (sum, point) => sum + (point['speed'] as double)) / totalPoints;
      }

      return {
        'totalDistance': totalDistance / 1000, // Convertir a kilómetros
        'averageSpeed': averageSpeed,
        'totalPoints': totalPoints,
        'startDate': startDate,
        'endDate': endDate,
      };
    } catch (e) {
      print('Error getting movement stats: $e');
      return {
        'totalDistance': 0,
        'averageSpeed': 0,
        'totalPoints': 0,
        'startDate': startDate,
        'endDate': endDate,
      };
    }
  }
} 