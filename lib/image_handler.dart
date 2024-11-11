// lib/chat/image_message_handler.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';

/// Exception thrown when there are issues with image handling
class ImageHandlingException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  ImageHandlingException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'ImageHandlingException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Class to handle image data across platforms
class ImageData {
  final Uint8List bytes;
  final String path;
  final String name;
  final File? file; // Optional, will be null on web
  final String mimeType;

  ImageData({
    required this.bytes,
    required this.path,
    required this.name,
    required this.mimeType,
    this.file,
  });

  /// Get size in MB
  double get sizeInMb => bytes.length / (1024 * 1024);

  /// Check if image size is within limits
  bool isWithinSizeLimit(double maxSizeMb) => sizeInMb <= maxSizeMb;

  /// Get file extension
  String get extension => name.split('.').last.toLowerCase();

  /// Check if image format is supported
  bool get isSupportedFormat {
    final supportedFormats = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    return supportedFormats.contains(extension);
  }

  /// Convert to base64
  String toBase64() => base64Encode(bytes);

  /// Create base64 data URL
  String toBase64Url() => 'data:image/$mimeType;base64,${toBase64()}';
}

class ImageMessageHandler {
  static final ImagePicker _picker = ImagePicker();

  // Configuration
  static const double _defaultMaxWidth = 2048;
  static const double _defaultMaxHeight = 2048;
  static const int _defaultQuality = 80;
  static const double _maxSizeMb = 20;

  /// Check if storage permission is granted on mobile platforms
  static Future<bool> _checkAndRequestPermission() async {
    if (kIsWeb) return true;

    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (status.isGranted) return true;

      final result = await Permission.storage.request();
      return result.isGranted;
    }

    if (Platform.isIOS) {
      final status = await Permission.photos.status;
      if (status.isGranted) return true;

      final result = await Permission.photos.request();
      return result.isGranted;
    }

    return true;
  }

  /// Determine MIME type from image bytes
  static String _getMimeType(Uint8List bytes) {
    if (bytes.length < 4) return 'image/jpeg';

    final signature = bytes.sublist(0, 4);

    if (signature[0] == 0xFF && signature[1] == 0xD8) {
      return 'image/jpeg';
    } else if (signature[0] == 0x89 && signature[1] == 0x50) {
      return 'image/png';
    } else if (signature[0] == 0x47 && signature[1] == 0x49) {
      return 'image/gif';
    } else if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }

    return 'image/jpeg';
  }

  /// Validate image data
  static void _validateImage(ImageData image) {
    if (!image.isWithinSizeLimit(_maxSizeMb)) {
      throw ImageHandlingException(
        'Image size exceeds maximum limit of ${_maxSizeMb}MB',
        code: 'size_exceeded',
      );
    }

    if (!image.isSupportedFormat) {
      throw ImageHandlingException(
        'Unsupported image format. Please use JPG, PNG, GIF, or WEBP',
        code: 'invalid_format',
      );
    }
  }

  /// Pick an image with full error handling and validation
  static Future<ImageData?> pickImage({
    ImageSource source = ImageSource.gallery,
    double maxWidth = _defaultMaxWidth,
    double maxHeight = _defaultMaxHeight,
    int imageQuality = _defaultQuality,
    bool validateImage = true,
  }) async {
    try {
      // Check permissions first
      if (!await _checkAndRequestPermission()) {
        throw ImageHandlingException(
          'Permission to access images was denied',
          code: 'permission_denied',
        );
      }

      final XFile? pickedImage = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );

      if (pickedImage == null) {
        return null; // User cancelled the picker
      }

      final bytes = await pickedImage.readAsBytes();
      final mimeType = _getMimeType(bytes);

      final imageData = ImageData(
        bytes: bytes,
        path: pickedImage.path,
        name: pickedImage.name,
        mimeType: mimeType,
        file: kIsWeb ? null : File(pickedImage.path),
      );

      if (validateImage) {
        _validateImage(imageData);
      }

      return imageData;

    } on ImageHandlingException {
      rethrow;
    } catch (e) {
      throw ImageHandlingException(
        'Failed to pick image',
        code: 'pick_error',
        originalError: e,
      );
    }
  }

  /// Compress image if needed
  static Future<ImageData> compressIfNeeded(
      ImageData imageData, {
        double maxSizeMb = _maxSizeMb,
        int minQuality = 60,
      }) async {
    if (imageData.isWithinSizeLimit(maxSizeMb)) {
      return imageData;
    }

    int quality = _defaultQuality;
    XFile? compressed;

    while (quality >= minQuality) {
      compressed = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _defaultMaxWidth,
        maxHeight: _defaultMaxHeight,
        imageQuality: quality,
      );

      if (compressed == null) {
        throw ImageHandlingException(
          'Failed to compress image',
          code: 'compression_failed',
        );
      }

      final bytes = await compressed.readAsBytes();
      if (bytes.length / (1024 * 1024) <= maxSizeMb) {
        return ImageData(
          bytes: bytes,
          path: compressed.path,
          name: compressed.name,
          mimeType: _getMimeType(bytes),
          file: kIsWeb ? null : File(compressed.path),
        );
      }

      quality -= 10;
    }

    throw ImageHandlingException(
      'Could not compress image to meet size requirements',
      code: 'compression_limit_reached',
    );
  }

  /// Get base64 string from ImageData
  static String getImageBase64(ImageData imageData) {
    return imageData.toBase64();
  }

  /// Get base64 data URL from ImageData
  static String getImageBase64Url(ImageData imageData) {
    return imageData.toBase64Url();
  }
}