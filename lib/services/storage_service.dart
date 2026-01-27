import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  // Upload bill/warranty image
  Future<String?> uploadBillImage({
    required String userId,
    required XFile imageFile,
  }) async {
    try {
      String extension = imageFile.path.split('.').last.toLowerCase();
      // Fallback if extension is missing or too long (likely not an extension)
      if (extension == imageFile.path.toLowerCase() || extension.length > 4) {
        extension = 'jpg';
      }
      
      final fileName = '${_uuid.v4()}.$extension';
      final ref = _storage.ref().child('bills/$userId/$fileName');

      final uploadTask = await ref.putFile(
        File(imageFile.path),
        SettableMetadata(
          contentType: 'image/$extension',
          customMetadata: {
            'uploadedBy': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading bill image: $e');
      return null;
    }
  }

  // Upload product image (Admin)
  Future<String?> uploadProductImage({required XFile imageFile}) async {
    try {
      final fileName = '${_uuid.v4()}.${imageFile.path.split('.').last}';
      final ref = _storage.ref().child('products/$fileName');

      final uploadTask = await ref.putFile(
        File(imageFile.path),
        SettableMetadata(
          contentType: 'image/${imageFile.path.split('.').last}',
          customMetadata: {
            'uploadedBy': 'ADMIN',
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading product image: $e');
      return null;
    }
  }

  // Upload service request evidence image
  Future<String?> uploadEvidenceImage({
    required String userId,
    required String requestId,
    required XFile imageFile,
  }) async {
    try {
      final file = File(imageFile.path);
      if (!await file.exists()) {
        throw Exception('Source file does not exist: ${imageFile.path}');
      }

      String extension = imageFile.path.split('.').last.toLowerCase();
      if (extension == imageFile.path.toLowerCase() || extension.length > 4) {
        extension = 'jpg';
      }

      final fileName = '${_uuid.v4()}.$extension';
      final ref = _storage.ref().child('evidence/$requestId/$fileName');

      final uploadTask = await ref.putFile(
        File(imageFile.path),
        SettableMetadata(
          contentType: 'image/$extension',
          customMetadata: {
            'uploadedBy': userId,
            'requestId': requestId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading evidence image: $e');
      // If it's a storage exception, print code
      if (e is FirebaseException) {
        print('Firebase Exception Code: ${e.code}');
        print('Firebase Exception Message: ${e.message}');
      }
      rethrow;
    }
  }

  // Upload audio recording
  Future<String?> uploadAudioRecording({
    required String userId,
    required String requestId,
    required String filePath,
  }) async {
    try {
       final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Source audio file does not exist: $filePath');
      }

      final fileName = '${_uuid.v4()}.m4a';
      final ref = _storage.ref().child('audio/$requestId/$fileName');

      final uploadTask = await ref.putFile(
        File(filePath),
        SettableMetadata(
          contentType: 'audio/mp4',
          customMetadata: {
            'uploadedBy': userId,
            'requestId': requestId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading audio: $e');
      if (e is FirebaseException) {
         print('Firebase Exception: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  // Upload multiple evidence images
  Future<List<String>> uploadMultipleImages({
    required String userId,
    required String requestId,
    required List<XFile> imageFiles,
  }) async {
    final urls = <String>[];

    for (final file in imageFiles) {
      try {
        final url = await uploadEvidenceImage(
          userId: userId,
          requestId: requestId,
          imageFile: file,
        );
        if (url != null) {
          urls.add(url);
        }
      } catch (e) {
        print('One image failed to upload: $e');
        // If one fails, we should probably stop and notify the user
        // or we could continue. Given the "systematic" instruction, let's fail fast.
        throw e;
      }
    }

    return urls;
  }

  // Delete a file by URL
  Future<bool> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
      return true;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  // Get upload progress stream
  Stream<TaskSnapshot> uploadWithProgress({
    required String path,
    required File file,
    SettableMetadata? metadata,
  }) {
    final ref = _storage.ref().child(path);
    final uploadTask = ref.putFile(file, metadata);
    return uploadTask.snapshotEvents;
  }
}
