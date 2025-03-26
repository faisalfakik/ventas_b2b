import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class MediaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String collectionName = 'media';

  // Subir nuevo contenido multimedia
  Future<String?> uploadMedia({
    required File file,
    required String title,
    required String description,
    required String type, // 'image' o 'video'
    required String category,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      // Generar nombre único para el archivo
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final String path = '$type/$category/$fileName';

      // Subir archivo a Firebase Storage
      final ref = _storage.ref().child(path);
      await ref.putFile(file);
      final String downloadUrl = await ref.getDownloadURL();

      // Crear documento en Firestore
      final docRef = await _firestore.collection(collectionName).add({
        'title': title,
        'description': description,
        'type': type,
        'category': category,
        'url': downloadUrl,
        'path': path,
        'metadata': metadata,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'downloads': 0,
        'shares': 0,
        'isActive': true,
      });

      return docRef.id;
    } catch (e) {
      print('Error uploading media: $e');
      return null;
    }
  }

  // Obtener contenido multimedia por categoría
  Stream<List<Map<String, dynamic>>> getMediaByCategory(String category) {
    return _firestore
        .collection(collectionName)
        .where('category', isEqualTo: category)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'createdAt': (data['createdAt'] as Timestamp).toDate(),
        };
      }).toList();
    });
  }

  // Obtener contenido multimedia por tipo
  Stream<List<Map<String, dynamic>>> getMediaByType(String type) {
    return _firestore
        .collection(collectionName)
        .where('type', isEqualTo: type)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'createdAt': (data['createdAt'] as Timestamp).toDate(),
        };
      }).toList();
    });
  }

  // Actualizar estadísticas de uso
  Future<void> updateMediaStats(String mediaId, {bool isDownload = false, bool isShare = false}) async {
    try {
      final updates = <String, dynamic>{};
      if (isDownload) updates['downloads'] = FieldValue.increment(1);
      if (isShare) updates['shares'] = FieldValue.increment(1);
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection(collectionName).doc(mediaId).update(updates);
    } catch (e) {
      print('Error updating media stats: $e');
    }
  }

  // Eliminar contenido multimedia
  Future<bool> deleteMedia(String mediaId) async {
    try {
      // Obtener información del documento
      final doc = await _firestore.collection(collectionName).doc(mediaId).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      final String path = data['path'];

      // Eliminar archivo de Storage
      await _storage.ref().child(path).delete();

      // Eliminar documento de Firestore
      await _firestore.collection(collectionName).doc(mediaId).delete();

      return true;
    } catch (e) {
      print('Error deleting media: $e');
      return false;
    }
  }

  // Obtener estadísticas de uso
  Future<Map<String, dynamic>> getMediaStats() async {
    try {
      final snapshot = await _firestore.collection(collectionName).get();

      int totalDownloads = 0;
      int totalShares = 0;
      Map<String, int> categoryStats = {};
      Map<String, int> typeStats = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalDownloads += data['downloads'] ?? 0;
        totalShares += data['shares'] ?? 0;

        // Estadísticas por categoría
        final category = data['category'] as String;
        categoryStats[category] = (categoryStats[category] ?? 0) + 1;

        // Estadísticas por tipo
        final type = data['type'] as String;
        typeStats[type] = (typeStats[type] ?? 0) + 1;
      }

      return {
        'totalMedia': snapshot.docs.length,
        'totalDownloads': totalDownloads,
        'totalShares': totalShares,
        'categoryStats': categoryStats,
        'typeStats': typeStats,
      };
    } catch (e) {
      print('Error getting media stats: $e');
      return {
        'totalMedia': 0,
        'totalDownloads': 0,
        'totalShares': 0,
        'categoryStats': {},
        'typeStats': {},
      };
    }
  }

  // Buscar contenido multimedia
  Future<List<Map<String, dynamic>>> searchMedia(String query) async {
    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              ...data,
              'createdAt': (data['createdAt'] as Timestamp).toDate(),
            };
          })
          .where((media) =>
              media['title'].toString().toLowerCase().contains(query.toLowerCase()) ||
              media['description'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      print('Error searching media: $e');
      return [];
    }
  }

  // Obtener contenido destacado
  Future<List<Map<String, dynamic>>> getFeaturedMedia({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .where('isActive', isEqualTo: true)
          .orderBy('downloads', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'createdAt': (data['createdAt'] as Timestamp).toDate(),
        };
      }).toList();
    } catch (e) {
      print('Error getting featured media: $e');
      return [];
    }
  }
} 