// catalog_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../models/catalog_model.dart';

class CatalogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'catalogs';

  // Obtener todos los catálogos disponibles
  Future<List<CatalogDocument>> getAvailableCatalogs({String? role}) async {
    try {
      QuerySnapshot snapshot;

      if (role != null) {
        // Filtrar por rol si se proporciona
        snapshot = await _firestore
            .collection(_collection)
            .where('isActive', isEqualTo: true)
            .where('visibleToRoles', arrayContains: role.toLowerCase())
            .orderBy('createdAt', descending: true)
            .get();
      } else {
        // Todos los catálogos activos
        snapshot = await _firestore
            .collection(_collection)
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .get();
      }

      return snapshot.docs
          .map((doc) => CatalogDocument.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .where((catalog) => !catalog.isExpired())
          .toList();
    } catch (e) {
      print('Error al obtener catálogos: $e');
      return [];
    }
  }

  // Obtener un catálogo específico
  Future<CatalogDocument?> getCatalogById(String id) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collection).doc(id).get();

      if (doc.exists) {
        return CatalogDocument.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('Error al obtener catálogo $id: $e');
      return null;
    }
  }

  // Subir un nuevo catálogo
  Future<String?> uploadCatalog({
    required String name,
    required String description,
    required File file,
    required CatalogType type,
    File? thumbnail,
    DateTime? expiryDate,
    List<String> visibleToRoles = const ['admin', 'vendor'],
  }) async {
    try {
      // 1. Generar un ID único para el catálogo
      final String catalogId = _firestore.collection(_collection).doc().id;

      // 2. Subir el archivo principal al Storage
      final String fileExtension = _getFileExtension(file.path);
      final Reference fileRef = _storage.ref().child('catalogs/$catalogId/file.$fileExtension');
      await fileRef.putFile(file);
      final String fileUrl = await fileRef.getDownloadURL();

      // 3. Subir la miniatura si se proporciona, o usar la misma URL
      String thumbnailUrl = fileUrl;
      if (thumbnail != null) {
        final String thumbExtension = _getFileExtension(thumbnail.path);
        final Reference thumbRef = _storage.ref().child('catalogs/$catalogId/thumbnail.$thumbExtension');
        await thumbRef.putFile(thumbnail);
        thumbnailUrl = await thumbRef.getDownloadURL();
      }

      // 4. Crear el documento en Firestore
      final CatalogDocument catalogDoc = CatalogDocument(
        id: catalogId,
        name: name,
        description: description,
        fileUrl: fileUrl,
        thumbnailUrl: thumbnailUrl,
        type: type,
        createdAt: DateTime.now(),
        expiryDate: expiryDate,
        isActive: true,
        visibleToRoles: visibleToRoles,
      );

      await _firestore.collection(_collection).doc(catalogId).set(catalogDoc.toMap());

      return catalogId;
    } catch (e) {
      print('Error al subir catálogo: $e');
      return null;
    }
  }

  // Descargar un catálogo a un archivo local
  Future<String> downloadCatalog(String catalogId) async {
    try {
      // 1. Obtener el documento del catálogo
      final CatalogDocument? catalog = await getCatalogById(catalogId);
      if (catalog == null) {
        throw Exception('Catálogo no encontrado');
      }

      // 2. Obtener la URL del archivo
      final String fileUrl = catalog.fileUrl;

      // 3. Descargar el archivo
      final http.Response response = await http.get(Uri.parse(fileUrl));

      // 4. Determinar la extensión del archivo
      String extension = 'pdf';
      if (catalog.type == CatalogType.image) {
        extension = 'jpg';
      }

      // 5. Guardar en el directorio temporal
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/${catalog.name}.$extension';
      final File file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      return filePath;
    } catch (e) {
      print('Error al descargar catálogo: $e');
      throw e;
    }
  }

  // Eliminar un catálogo
  Future<bool> deleteCatalog(String catalogId) async {
    try {
      // 1. Eliminar archivos del Storage
      await _storage.ref().child('catalogs/$catalogId').listAll().then((result) {
        for (var ref in result.items) {
          ref.delete();
        }
      });

      // 2. Eliminar documento de Firestore
      await _firestore.collection(_collection).doc(catalogId).delete();

      return true;
    } catch (e) {
      print('Error al eliminar catálogo: $e');
      return false;
    }
  }

  // Actualizar un catálogo existente
  Future<bool> updateCatalog(CatalogDocument catalog) async {
    try {
      await _firestore.collection(_collection).doc(catalog.id).update(catalog.toMap());
      return true;
    } catch (e) {
      print('Error al actualizar catálogo: $e');
      return false;
    }
  }

  // Obtener extensión del archivo
  String _getFileExtension(String path) {
    return path.split('.').last.toLowerCase();
  }
}