import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'image_compression_service.dart';

class StorageService {
  /// Use the Mumbai (asia-south1) bucket for lower latency in India.
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'gs://freelancing-mumbai',
  );
  final _uuid = const Uuid();
  final _compressionService = ImageCompressionService();

  /// Retry helper with exponential backoff for transient upload failures.
  /// Retries up to [maxRetries] times with delays of 1s, 2s, 4s, etc.
  Future<T> _retryUpload<T>(
    Future<T> Function() action, {
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await action();
      } catch (e) {
        attempt++;
        final isRetryable =
            e is FirebaseException &&
            (e.code == 'unknown' ||
                e.code == 'canceled' ||
                e.code == 'retry-limit-exceeded' ||
                e.code == 'unavailable' ||
                e.code == 'deadline-exceeded');
        final isNetworkError =
            e is SocketException || e.toString().contains('SocketException');

        if ((isRetryable || isNetworkError) && attempt < maxRetries) {
          final delay = Duration(seconds: 1 << (attempt - 1)); // 1s, 2s, 4s
          debugPrint(
            'Upload attempt $attempt failed, retrying in ${delay.inSeconds}s...',
          );
          await Future.delayed(delay);
          continue;
        }
        rethrow;
      }
    }
  }

  // Upload bill/warranty image with compression
  Future<String?> uploadBillImage({
    required String userId,
    required XFile imageFile,
  }) async {
    try {
      // Compress the image before upload
      final compressStopwatch = Stopwatch()..start();
      final compressedFile = await _compressionService.compressForBill(
        imageFile,
      );
      compressStopwatch.stop();
      debugPrint(
        'Bill image compressed in ${compressStopwatch.elapsedMilliseconds}ms',
      );

      String extension = compressedFile.path.split('.').last.toLowerCase();
      // Fallback if extension is missing or too long (likely not an extension)
      if (extension == compressedFile.path.toLowerCase() ||
          extension.length > 4) {
        extension = 'jpg';
      }

      final fileName = '${_uuid.v4()}.$extension';
      final ref = _storage.ref().child('bills/$userId/$fileName');

      final uploadStopwatch = Stopwatch()..start();
      final uploadTask = await _retryUpload(
        () => ref.putFile(
          File(compressedFile.path),
          SettableMetadata(
            contentType: 'image/$extension',
            customMetadata: {
              'uploadedBy': userId,
              'uploadedAt': DateTime.now().toIso8601String(),
            },
          ),
        ),
      );
      uploadStopwatch.stop();
      debugPrint(
        'Bill image uploaded in ${uploadStopwatch.elapsedMilliseconds}ms',
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading bill image: $e');
      if (e is FirebaseException) {
        debugPrint('Firebase Exception: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  // Upload warranty card image with compression
  Future<String?> uploadWarrantyCard({
    required String userId,
    required XFile imageFile,
  }) async {
    try {
      // Compress the image before upload
      final compressedFile = await _compressionService.compressForBill(
        imageFile,
      );
      debugPrint('Warranty card image prepared for upload');

      String extension = compressedFile.path.split('.').last.toLowerCase();
      // Fallback if extension is missing or too long (likely not an extension)
      if (extension == compressedFile.path.toLowerCase() ||
          extension.length > 4) {
        extension = 'jpg';
      }

      final fileName = '${_uuid.v4()}.$extension';
      final ref = _storage.ref().child('warranty_cards/$userId/$fileName');

      final uploadTask = await _retryUpload(
        () => ref.putFile(
          File(compressedFile.path),
          SettableMetadata(
            contentType: 'image/$extension',
            customMetadata: {
              'uploadedBy': userId,
              'uploadedAt': DateTime.now().toIso8601String(),
            },
          ),
        ),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading warranty card: $e');
      if (e is FirebaseException) {
        debugPrint('Firebase Exception: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  // Upload profile image (User & Admin) with compression
  Future<String?> uploadProfileImage({
    required String userId,
    required XFile imageFile,
  }) async {
    try {
      // Compress the image before upload
      final compressedFile = await _compressionService.compressForProfile(
        imageFile,
      );
      debugPrint('Profile image prepared for upload');

      String extension = compressedFile.path.split('.').last.toLowerCase();
      // Fallback if extension is missing or too long (likely not an extension)
      if (extension == compressedFile.path.toLowerCase() ||
          extension.length > 4) {
        extension = 'jpg';
      }

      final fileName = '${_uuid.v4()}.$extension';
      // Store in profiles/{userId}/{fileName}
      final ref = _storage.ref().child('profiles/$userId/$fileName');

      final uploadTask = await _retryUpload(
        () => ref.putFile(
          File(compressedFile.path),
          SettableMetadata(
            contentType: 'image/$extension',
            customMetadata: {
              'uploadedBy': userId,
              'uploadedAt': DateTime.now().toIso8601String(),
              'type': 'profile_picture',
            },
          ),
        ),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      if (e is FirebaseException) {
        debugPrint('Firebase Exception: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  // Upload product image (Admin) with compression
  Future<String?> uploadProductImage({required XFile imageFile}) async {
    try {
      // Compress the image before upload
      final compressedFile = await _compressionService.compressForProduct(
        imageFile,
      );
      debugPrint('Product image prepared for upload');

      final fileName = '${_uuid.v4()}.${compressedFile.path.split('.').last}';
      final ref = _storage.ref().child('products/$fileName');

      final uploadTask = await _retryUpload(
        () => ref.putFile(
          File(compressedFile.path),
          SettableMetadata(
            contentType: 'image/${compressedFile.path.split('.').last}',
            customMetadata: {
              'uploadedBy': 'ADMIN',
              'uploadedAt': DateTime.now().toIso8601String(),
            },
          ),
        ),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading product image: $e');
      if (e is FirebaseException) {
        debugPrint('Firebase Exception: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  // Upload service request evidence image with compression
  Future<String?> uploadEvidenceImage({
    required String userId,
    required String requestId,
    required XFile imageFile,
  }) async {
    try {
      // Compress the image before upload
      final compressedFile = await _compressionService.compressForEvidence(
        imageFile,
      );
      debugPrint('Evidence image prepared for upload');

      final file = File(compressedFile.path);
      if (!await file.exists()) {
        throw Exception('Source file does not exist: ${compressedFile.path}');
      }

      String extension = compressedFile.path.split('.').last.toLowerCase();
      if (extension == compressedFile.path.toLowerCase() ||
          extension.length > 4) {
        extension = 'jpg';
      }

      final fileName = '${_uuid.v4()}.$extension';
      final ref = _storage.ref().child('evidence/$requestId/$fileName');

      final uploadTask = await _retryUpload(
        () => ref.putFile(
          File(compressedFile.path),
          SettableMetadata(
            contentType: 'image/$extension',
            customMetadata: {
              'uploadedBy': userId,
              'requestId': requestId,
              'uploadedAt': DateTime.now().toIso8601String(),
            },
          ),
        ),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading evidence image: $e');
      // If it's a storage exception, print code
      if (e is FirebaseException) {
        debugPrint('Firebase Exception Code: ${e.code}');
        debugPrint('Firebase Exception Message: ${e.message}');
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

      final uploadStopwatch = Stopwatch()..start();
      final uploadTask = await _retryUpload(
        () => ref.putFile(
          File(filePath),
          SettableMetadata(
            contentType: 'audio/mp4',
            customMetadata: {
              'uploadedBy': userId,
              'requestId': requestId,
              'uploadedAt': DateTime.now().toIso8601String(),
            },
          ),
        ),
      );
      uploadStopwatch.stop();
      final fileSize = await file.length();
      debugPrint(
        'Audio uploaded: ${fileSize ~/ 1024}KB in ${uploadStopwatch.elapsedMilliseconds}ms',
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading audio: $e');
      if (e is FirebaseException) {
        debugPrint('Firebase Exception: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  // Upload admin voice note (Admin to Agent)
  Future<String?> uploadAdminVoiceNote({
    required String requestId,
    required String filePath,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Source audio file does not exist: $filePath');
      }

      final fileName =
          'admin_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      // Store in admin_audio/{requestId}/{fileName}
      final ref = _storage.ref().child('admin_audio/$requestId/$fileName');

      final uploadTask = await _retryUpload(
        () => ref.putFile(
          File(filePath),
          SettableMetadata(
            contentType: 'audio/mp4',
            customMetadata: {
              'uploadedBy': 'ADMIN',
              'requestId': requestId,
              'uploadedAt': DateTime.now().toIso8601String(),
              'type': 'admin_instruction',
            },
          ),
        ),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading admin voice note: $e');
      if (e is FirebaseException) {
        debugPrint('Firebase Exception: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  // Upload multiple evidence images with parallel compression
  Future<List<String>> uploadMultipleImages({
    required String userId,
    required String requestId,
    required List<XFile> imageFiles,
  }) async {
    final urls = <String>[];

    // Compress all images in parallel first for faster processing
    final compressionStopwatch = Stopwatch()..start();
    debugPrint('Compressing ${imageFiles.length} images in parallel...');
    final compressedFiles = await _compressionService.compressMultiple(
      imageFiles,
    );
    compressionStopwatch.stop();
    debugPrint(
      'Compression complete in ${compressionStopwatch.elapsedMilliseconds}ms, uploading in parallel...',
    );

    // Upload all images in parallel instead of sequentially
    final uploadStopwatch = Stopwatch()..start();
    final uploadFutures =
        compressedFiles.map((file) {
          return _uploadEvidenceImageDirect(
            userId: userId,
            requestId: requestId,
            imageFile: file,
          );
        }).toList();

    final results = await Future.wait(uploadFutures);
    uploadStopwatch.stop();

    urls.addAll(results.whereType<String>());
    debugPrint(
      'Uploaded ${urls.length}/${compressedFiles.length} images in ${uploadStopwatch.elapsedMilliseconds}ms',
    );

    // Cleanup temp files after upload
    await _compressionService.cleanupTempFiles();

    return urls;
  }

  // Internal method to upload evidence image without compression (for already compressed files)
  Future<String?> _uploadEvidenceImageDirect({
    required String userId,
    required String requestId,
    required XFile imageFile,
  }) async {
    try {
      debugPrint(
        '_uploadEvidenceImageDirect: Starting upload for ${imageFile.path}',
      );
      final file = File(imageFile.path);

      if (!await file.exists()) {
        debugPrint('_uploadEvidenceImageDirect: ERROR - File does not exist');
        throw Exception('Source file does not exist: ${imageFile.path}');
      }

      final fileSize = await file.length();
      debugPrint(
        '_uploadEvidenceImageDirect: File exists, size: ${fileSize ~/ 1024} KB',
      );

      String extension = imageFile.path.split('.').last.toLowerCase();
      if (extension == imageFile.path.toLowerCase() || extension.length > 4) {
        extension = 'jpg';
      }

      final fileName = '${_uuid.v4()}.$extension';
      final ref = _storage.ref().child('evidence/$requestId/$fileName');
      debugPrint(
        '_uploadEvidenceImageDirect: Uploading to evidence/$requestId/$fileName',
      );

      final uploadTask = await _retryUpload(
        () => ref.putFile(
          file,
          SettableMetadata(
            contentType: 'image/$extension',
            customMetadata: {
              'uploadedBy': userId,
              'requestId': requestId,
              'uploadedAt': DateTime.now().toIso8601String(),
            },
          ),
        ),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint(
        '_uploadEvidenceImageDirect: Upload complete, URL: $downloadUrl',
      );
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading evidence image: $e');
      if (e is FirebaseException) {
        debugPrint('Firebase Exception Code: ${e.code}');
        debugPrint('Firebase Exception Message: ${e.message}');
      }
      rethrow;
    }
  }

  // Delete a file by URL
  Future<bool> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting file: $e');
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
