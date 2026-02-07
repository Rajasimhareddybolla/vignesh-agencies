import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// A centralized image compression service for optimizing images before upload.
/// Uses flutter_image_compress for native-speed compression.
class ImageCompressionService {
  // Singleton pattern
  static final ImageCompressionService _instance =
      ImageCompressionService._internal();
  factory ImageCompressionService() => _instance;
  ImageCompressionService._internal();

  /// Compression quality presets
  static const int qualityHigh = 85;
  static const int qualityMedium = 70;
  static const int qualityLow = 50;
  static const int qualityThumbnail = 30;

  /// Max dimensions for different use cases
  static const int maxDimensionProduct = 800;
  static const int maxDimensionProfile = 400;
  static const int maxDimensionEvidence = 1000;
  static const int maxDimensionBill = 1200;
  static const int maxDimensionThumbnail = 200;

  /// Compress an XFile with optimized settings for different use cases.
  /// Returns a new XFile with the compressed image, or the original if compression fails.
  Future<XFile> compressForProduct(XFile file) async {
    return await _compressImage(
      file: file,
      maxDimension: maxDimensionProduct,
      quality: qualityMedium,
      prefix: 'product_',
    );
  }

  Future<XFile> compressForProfile(XFile file) async {
    return await _compressImage(
      file: file,
      maxDimension: maxDimensionProfile,
      quality: qualityMedium,
      prefix: 'profile_',
    );
  }

  Future<XFile> compressForEvidence(XFile file) async {
    return await _compressImage(
      file: file,
      maxDimension: maxDimensionEvidence,
      quality: qualityLow,
      prefix: 'evidence_',
    );
  }

  Future<XFile> compressForBill(XFile file) async {
    return await _compressImage(
      file: file,
      maxDimension: maxDimensionBill,
      quality: qualityMedium,
      prefix: 'bill_',
    );
  }

  /// Compress multiple images in parallel for faster processing.
  Future<List<XFile>> compressMultiple(
    List<XFile> files, {
    int maxDimension = maxDimensionEvidence,
    int quality = qualityLow,
  }) async {
    debugPrint(
      'ImageCompressionService: compressMultiple called with ${files.length} files',
    );

    // Process in batches of 3 to avoid memory issues
    final List<XFile> results = [];
    const batchSize = 3;

    for (var i = 0; i < files.length; i += batchSize) {
      final end = (i + batchSize).clamp(0, files.length);
      final batch = files.sublist(i, end);
      debugPrint(
        'ImageCompressionService: Processing batch ${i ~/ batchSize + 1}',
      );

      final batchResults = await Future.wait(
        batch.map(
          (file) => _compressImage(
            file: file,
            maxDimension: maxDimension,
            quality: quality,
            prefix: 'batch_',
          ),
        ),
      );
      results.addAll(batchResults);
      debugPrint(
        'ImageCompressionService: Batch complete, ${results.length} files processed',
      );
    }

    debugPrint(
      'ImageCompressionService: compressMultiple complete, returning ${results.length} files',
    );
    return results;
  }

  /// Core compression method using flutter_image_compress for native-speed
  /// image resizing and quality reduction.
  Future<XFile> _compressImage({
    required XFile file,
    required int maxDimension,
    required int quality,
    required String prefix,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      final originalFile = File(file.path);
      final originalSize = await originalFile.length();

      // If file is already small enough (< 100KB), return as-is
      if (originalSize < 100 * 1024) {
        debugPrint(
          'Image already small (${originalSize ~/ 1024}KB), skipping compression',
        );
        return file;
      }

      // Calculate target quality based on file size
      // Larger files get more aggressive compression
      int targetQuality = quality;
      if (originalSize > 2 * 1024 * 1024) {
        targetQuality = (quality * 0.7).round(); // Very large files
      } else if (originalSize > 1 * 1024 * 1024) {
        targetQuality = (quality * 0.85).round(); // Large files
      }

      // Get temp directory for output
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/${prefix}${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Compress using native APIs via flutter_image_compress
      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        minWidth: maxDimension,
        minHeight: maxDimension,
        quality: targetQuality,
        format: CompressFormat.jpeg,
      );

      stopwatch.stop();

      if (result != null) {
        final compressedSize = await File(result.path).length();
        final savings = ((1 - compressedSize / originalSize) * 100)
            .toStringAsFixed(1);
        debugPrint(
          'Compression: ${originalSize ~/ 1024}KB → ${compressedSize ~/ 1024}KB '
          '($savings% saved) in ${stopwatch.elapsedMilliseconds}ms',
        );
        return result;
      }

      debugPrint('Compression returned null, using original');
      return file;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return file; // Return original on error
    }
  }

  /// Get the estimated file size after compression.
  /// Useful for showing users expected upload sizes.
  Future<int> getEstimatedCompressedSize(XFile file, int quality) async {
    try {
      final originalSize = await File(file.path).length();

      // Estimate based on quality ratio
      // This is approximate - actual compression varies by image content
      final ratio = quality / 100.0;
      return (originalSize * ratio * 0.6).round(); // Conservative estimate
    } catch (e) {
      return 0;
    }
  }

  /// Check if an image needs compression based on size threshold.
  Future<bool> needsCompression(XFile file, {int thresholdKB = 500}) async {
    try {
      final size = await File(file.path).length();
      return size > thresholdKB * 1024;
    } catch (e) {
      return false;
    }
  }

  /// Generate a thumbnail version of an image.
  Future<XFile?> generateThumbnail(XFile file) async {
    try {
      return await _compressImage(
        file: file,
        maxDimension: maxDimensionThumbnail,
        quality: qualityThumbnail,
        prefix: 'thumb_',
      );
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }

  /// Clean up temporary compressed files.
  /// Call this when done with batch processing.
  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();

      for (final file in files) {
        if (file is File &&
            (file.path.contains('product_') ||
                file.path.contains('profile_') ||
                file.path.contains('evidence_') ||
                file.path.contains('bill_') ||
                file.path.contains('batch_') ||
                file.path.contains('thumb_'))) {
          try {
            await file.delete();
          } catch (e) {
            // Ignore deletion errors
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up temp files: $e');
    }
  }
}
