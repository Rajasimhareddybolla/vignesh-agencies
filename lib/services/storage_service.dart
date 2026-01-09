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
      final fileName = '${_uuid.v4()}.${imageFile.path.split('.').last}';
      final ref = _storage.ref().child('bills/$userId/$fileName');
      
      final uploadTask = await ref.putFile(
        File(imageFile.path),
        SettableMetadata(
          contentType: 'image/${imageFile.path.split('.').last}',
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

  // Upload service request evidence image
  Future<String?> uploadEvidenceImage({
    required String userId,
    required String requestId,
    required XFile imageFile,
  }) async {
    try {
      final fileName = '${_uuid.v4()}.${imageFile.path.split('.').last}';
      final ref = _storage.ref().child('evidence/$requestId/$fileName');
      
      final uploadTask = await ref.putFile(
        File(imageFile.path),
        SettableMetadata(
          contentType: 'image/${imageFile.path.split('.').last}',
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
      return null;
    }
  }

  // Upload audio recording
  Future<String?> uploadAudioRecording({
    required String userId,
    required String requestId,
    required String filePath,
  }) async {
    try {
      final fileName = '${_uuid.v4()}.m4a';
      final ref = _storage.ref().child('audio/$requestId/$fileName');
      
      final uploadTask = await ref.putFile(
        File(filePath),
        SettableMetadata(
          contentType: 'audio/m4a',
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
      return null;
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
      final url = await uploadEvidenceImage(
        userId: userId,
        requestId: requestId,
        imageFile: file,
      );
      if (url != null) {
        urls.add(url);
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
