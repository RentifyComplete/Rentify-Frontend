// ========================================
// SUPABASE STORAGE SERVICE
// File: lib/services/supabase_storage_service.dart
// ✅ Upload PDFs, signatures, documents, images
// ✅ Files open directly in browser (no download)
// ✅ Public URLs - no auth needed
// ========================================

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';

class SupabaseStorageService {
  static const String _supabaseUrl = 'https://sysgayeogkjjulqkzaee.supabase.co';

  // ✅ FIXED: Correct JWT anon key
  static const String _supabaseKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN5c2dheWVvZ2tqanVscWt6YWVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzMTQ3ODQsImV4cCI6MjA4Njg5MDc4NH0.T2NHV4iX7ih2rqzMX35HPeKFSeplKSzDI2PuByXuWGU';

  static const String _bucketName = 'rentify-files';

  // ========================================
  // UPLOAD ANY FILE
  // ========================================
  static Future<String> uploadFile({
    required File file,
    required String folder,
    String? customFileName,
  }) async {
    try {
      final ext = path.extension(file.path);
      final fileName = customFileName ??
          '${DateTime.now().millisecondsSinceEpoch}$ext';

      final filePath = '$folder/$fileName';

      print('📤 Uploading to Supabase...');
      print('   Folder: $folder');
      print('   File: $fileName');

      final bytes = await file.readAsBytes();
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

      print('   MIME type: $mimeType');
      print('   Size: ${bytes.length} bytes');

      final response = await http.post(
        Uri.parse('$_supabaseUrl/storage/v1/object/$_bucketName/$filePath'),
        headers: {
          'Authorization': 'Bearer $_supabaseKey',
          'Content-Type': mimeType,
          'x-upsert': 'true',
        },
        body: bytes,
      );

      print('   Response status: ${response.statusCode}');
      print('   Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final publicUrl =
            '$_supabaseUrl/storage/v1/object/public/$_bucketName/$filePath';
        print('✅ Upload successful!');
        print('   Public URL: $publicUrl');
        return publicUrl;
      } else {
        throw Exception(
            'Upload failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Supabase upload error: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  // ========================================
  // UPLOAD PDF (Agreement)
  // ========================================
  static Future<String> uploadAgreementPDF({
    required File pdfFile,
    required String propertyId,
  }) async {
    final fileName =
        'agreement_${propertyId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    return await uploadFile(
      file: pdfFile,
      folder: 'rental_agreements',
      customFileName: fileName,
    );
  }

  // ========================================
  // UPLOAD SIGNATURE IMAGE
  // ========================================
  static Future<String> uploadSignature({
    required File imageFile,
    required String userId,
  }) async {
    final ext = path.extension(imageFile.path);
    final fileName =
        'signature_${userId}_${DateTime.now().millisecondsSinceEpoch}$ext';
    return await uploadFile(
      file: imageFile,
      folder: 'signatures',
      customFileName: fileName,
    );
  }

  // ========================================
  // UPLOAD PROPERTY IMAGE
  // ========================================
  static Future<String> uploadPropertyImage({
    required File imageFile,
    required String ownerId,
    required int index,
  }) async {
    final ext = path.extension(imageFile.path);
    final fileName =
        'property_${ownerId}_${DateTime.now().millisecondsSinceEpoch}_$index$ext';
    return await uploadFile(
      file: imageFile,
      folder: 'property_images',
      customFileName: fileName,
    );
  }

  // ========================================
  // UPLOAD TENANT DOCUMENT
  // ========================================
  static Future<String> uploadTenantDocument({
    required File file,
    required String documentType,
    required String tenantId,
  }) async {
    final ext = path.extension(file.path);
    final fileName =
        '${documentType}_${tenantId}_${DateTime.now().millisecondsSinceEpoch}$ext';
    return await uploadFile(
      file: file,
      folder: 'tenant_documents',
      customFileName: fileName,
    );
  }

  // ========================================
  // UPLOAD MULTIPLE IMAGES
  // ========================================
  static Future<List<String>> uploadMultipleImages({
    required List<File> images,
    required String ownerId,
  }) async {
    final List<String> urls = [];
    for (int i = 0; i < images.length; i++) {
      try {
        print('📸 Uploading image ${i + 1}/${images.length}...');
        final url = await uploadPropertyImage(
          imageFile: images[i],
          ownerId: ownerId,
          index: i,
        );
        urls.add(url);
        print('✅ Image ${i + 1} uploaded');
      } catch (e) {
        print('❌ Failed to upload image ${i + 1}: $e');
      }
    }
    return urls;
  }

  // ========================================
  // DELETE FILE
  // ========================================
  static Future<void> deleteFile(String publicUrl) async {
    try {
      final uri = Uri.parse(publicUrl);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf(_bucketName);
      if (bucketIndex == -1) throw Exception('Invalid Supabase URL');

      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
      await http.delete(
        Uri.parse('$_supabaseUrl/storage/v1/object/$_bucketName/$filePath'),
        headers: {'Authorization': 'Bearer $_supabaseKey'},
      );
      print('✅ File deleted successfully');
    } catch (e) {
      print('❌ Delete error: $e');
    }
  }

  // ========================================
  // GET PUBLIC URL
  // ========================================
  static String getPublicUrl(String filePath) {
    return '$_supabaseUrl/storage/v1/object/public/$_bucketName/$filePath';
  }
}