import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path/path.dart' as path;

class CloudinaryService {
  // ✅ Your Cloudinary account details
  final String cloudName = "dojen4kyp";
  final String uploadPreset = "unsigned_preset";
  
  // Optional: If you have a signed upload, add your API key and secret
  final String? apiKey;
  final String? apiSecret;

  CloudinaryService({
    this.apiKey,
    this.apiSecret,
  });

  /// Upload a single image to Cloudinary with proper formatting
  /// 
  /// Parameters:
  /// - imageFile: The image file to upload
  /// - folder: Optional folder path in Cloudinary (e.g., 'users/profile_pictures')
  /// - publicId: Optional custom public ID (filename without extension)
  /// - tags: Optional list of tags for organization
  Future<String?> uploadImage(
    File imageFile, {
    String? folder,
    String? publicId,
    List<String>? tags,
    Map<String, dynamic>? context,
  }) async {
    try {
      final uri = Uri.parse(
          "https://api.cloudinary.com/v1_1/$cloudName/image/upload");

      print("📤 Uploading image to Cloudinary...");
      print("   File: ${path.basename(imageFile.path)}");
      print("   Folder: ${folder ?? 'root'}");

      var request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      // Add optional folder structure
      if (folder != null && folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }

      // Add custom public ID (filename)
      if (publicId != null && publicId.isNotEmpty) {
        request.fields['public_id'] = publicId;
      }

      // Add tags for organization
      if (tags != null && tags.isNotEmpty) {
        request.fields['tags'] = tags.join(',');
      }

      // Add context metadata
      if (context != null && context.isNotEmpty) {
        request.fields['context'] = context.entries
            .map((e) => '${e.key}=${e.value}')
            .join('|');
      }

      // Add transformation options for optimization
      request.fields['quality'] = 'auto';
      request.fields['fetch_format'] = 'auto';

      var response = await request.send();

      if (response.statusCode == 200) {
        final resStr = await response.stream.bytesToString();
        final data = json.decode(resStr);
        
        print("✅ Image uploaded successfully!");
        print("   URL: ${data['secure_url']}");
        print("   Public ID: ${data['public_id']}");
        print("   Format: ${data['format']}");
        print("   Size: ${_formatBytes(data['bytes'])}");
        
        return data['secure_url'];
      } else {
        print("❌ Upload failed with status: ${response.statusCode}");
        final resStr = await response.stream.bytesToString();
        print("Response: $resStr");
        return null;
      }
    } catch (e) {
      print("❌ Error uploading image: $e");
      return null;
    }
  }

  /// Upload a document (PDF, DOC, images, etc.) with proper formatting
  /// 
  /// Parameters:
  /// - documentFile: The document file to upload
  /// - folder: Folder path (e.g., 'users/documents/id_proofs')
  /// - documentType: Type of document (e.g., 'id_proof', 'address_proof')
  /// - userId: Optional user ID for organization
  /// - tags: Optional tags for categorization
  Future<Map<String, dynamic>?> uploadDocument(
      File documentFile, {
        String? folder,
        String? documentType,
        String? userId,
        List<String>? tags,
        Map<String, dynamic>? metadata,
      }) async {
    try {
      // Get file info
      final fileName = path.basenameWithoutExtension(documentFile.path);
      final extension = path.extension(documentFile.path).toLowerCase();
      final fileSize = await documentFile.length();

      // Determine resource type
      String resourceType = _getResourceType(extension);

      // Build folder path - simplified to avoid deep nesting
      String finalFolder = folder ?? 'documents';

      // Build public ID with timestamp for uniqueness
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final publicId = '${fileName}_$timestamp';

      // Build tags list
      List<String> finalTags = tags ?? [];
      if (documentType != null && !finalTags.contains(documentType)) {
        finalTags.add(documentType);
      }

      final uri = Uri.parse(
          "https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload");

      print("📤 Uploading document to Cloudinary...");
      print("   File: ${path.basename(documentFile.path)}");
      print("   Size: ${_formatBytes(fileSize)}");
      print("   Type: $resourceType");
      print("   Folder: $finalFolder");
      print("   Public ID: $publicId");
      print("   Upload Preset: $uploadPreset");

      var request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = finalFolder
        ..fields['public_id'] = publicId
        ..files.add(await http.MultipartFile.fromPath('file', documentFile.path));

      // Add tags
      if (finalTags.isNotEmpty) {
        request.fields['tags'] = finalTags.join(',');
      }

      // Add context metadata
      Map<String, dynamic> contextData = {
        'uploaded_at': DateTime.now().toIso8601String(),
        'original_filename': path.basename(documentFile.path),
        'file_size': fileSize.toString(),
      };

      if (documentType != null) {
        contextData['document_type'] = documentType;
      }

      if (metadata != null) {
        contextData.addAll(metadata);
      }

      request.fields['context'] = contextData.entries
          .map((e) => '${e.key}=${e.value}')
          .join('|');

      // For images, add quality optimization
      if (resourceType == 'image') {
        request.fields['quality'] = 'auto';
        request.fields['fetch_format'] = 'auto';
      }

      print("🚀 Sending upload request...");
      var response = await request.send();

      if (response.statusCode == 200) {
        final resStr = await response.stream.bytesToString();
        final data = json.decode(resStr);

        print("✅ Document uploaded successfully!");
        print("   URL: ${data['secure_url']}");
        print("   Public ID: ${data['public_id']}");
        print("   Format: ${data['format']}");
        print("   Resource Type: ${data['resource_type']}");

        // Return comprehensive data with guaranteed url field
        return {
          'url': data['secure_url'],
          'public_id': data['public_id'],
          'format': data['format'],
          'resource_type': data['resource_type'],
          'bytes': data['bytes'],
          'width': data['width'],
          'height': data['height'],
          'created_at': data['created_at'],
          'folder': finalFolder,
          'tags': finalTags,
          'original_filename': path.basename(documentFile.path),
        };
      } else {
        print("❌ Upload failed with status: ${response.statusCode}");
        final resStr = await response.stream.bytesToString();
        print("❌ Error response: $resStr");

        // Try to parse error message
        try {
          final errorData = json.decode(resStr);
          print("❌ Error details: ${errorData['error']}");
        } catch (e) {
          print("❌ Could not parse error response");
        }

        return null;
      }
    } catch (e) {
      print("❌ Error uploading document: $e");
      print("❌ Stack trace: ${StackTrace.current}");
      return null;
    }
  }

  /// Upload profile picture with specific formatting
  Future<String?> uploadProfilePicture(
    File imageFile,
    String userId,
  ) async {
    return await uploadImage(
      imageFile,
      folder: 'users/profile_pictures',
      publicId: 'user_${userId}_${DateTime.now().millisecondsSinceEpoch}',
      tags: ['profile_picture', userId],
      context: {
        'type': 'profile_picture',
        'user_id': userId,
      },
    );
  }

  /// Upload property images with proper organization
  Future<List<String>> uploadPropertyImages(
    List<File> imageFiles,
    String propertyId,
  ) async {
    List<String> uploadedUrls = [];
    
    for (int i = 0; i < imageFiles.length; i++) {
      final url = await uploadImage(
        imageFiles[i],
        folder: 'properties/$propertyId',
        publicId: 'property_${propertyId}_image_${i + 1}_${DateTime.now().millisecondsSinceEpoch}',
        tags: ['property', propertyId, 'gallery'],
        context: {
          'property_id': propertyId,
          'image_index': (i + 1).toString(),
        },
      );
      
      if (url != null) {
        uploadedUrls.add(url);
      }
    }
    
    return uploadedUrls;
  }

  /// Upload verification documents (ID proof, address proof, etc.)
  Future<Map<String, dynamic>?> uploadVerificationDocument(
    File documentFile,
    String userId,
    String documentType, // 'id_proof', 'address_proof', etc.
  ) async {
    return await uploadDocument(
      documentFile,
      folder: 'users/documents',
      documentType: documentType,
      userId: userId,
      tags: ['verification', documentType, userId],
      metadata: {
        'verification_status': 'pending',
        'uploaded_by': userId,
      },
    );
  }

  /// Upload lease agreement
  Future<Map<String, dynamic>?> uploadLeaseAgreement(
    File documentFile,
    String propertyId,
    String userId,
  ) async {
    return await uploadDocument(
      documentFile,
      folder: 'properties/$propertyId/agreements',
      documentType: 'lease_agreement',
      userId: userId,
      tags: ['lease', 'agreement', propertyId, userId],
      metadata: {
        'property_id': propertyId,
        'tenant_id': userId,
        'agreement_type': 'lease',
      },
    );
  }

  /// Upload multiple images with progress tracking
  Future<List<String>> uploadImages(
    List<File> imageFiles, {
    String? folder,
    List<String>? tags,
    Function(int current, int total)? onProgress,
  }) async {
    List<String> uploadedUrls = [];
    
    for (int i = 0; i < imageFiles.length; i++) {
      if (onProgress != null) {
        onProgress(i + 1, imageFiles.length);
      }
      
      final url = await uploadImage(
        imageFiles[i],
        folder: folder,
        tags: tags,
      );
      
      if (url != null) {
        uploadedUrls.add(url);
      }
    }
    
    return uploadedUrls;
  }

  /// Upload multiple documents with progress tracking
  Future<List<Map<String, dynamic>>> uploadDocuments(
    List<File> documentFiles, {
    String? folder,
    String? documentType,
    String? userId,
    List<String>? tags,
    Function(int current, int total)? onProgress,
  }) async {
    List<Map<String, dynamic>> uploadedDocuments = [];
    
    for (int i = 0; i < documentFiles.length; i++) {
      if (onProgress != null) {
        onProgress(i + 1, documentFiles.length);
      }
      
      final result = await uploadDocument(
        documentFiles[i],
        folder: folder,
        documentType: documentType,
        userId: userId,
        tags: tags,
      );
      
      if (result != null) {
        uploadedDocuments.add(result);
      }
    }
    
    return uploadedDocuments;
  }

  /// Delete a file from Cloudinary (requires signed upload)
  Future<bool> deleteFile(String publicId, {String resourceType = 'image'}) async {
    if (apiKey == null || apiSecret == null) {
      print("❌ API key and secret required for deletion");
      return false;
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final signature = _generateSignature(publicId, timestamp);

      final uri = Uri.parse(
          "https://api.cloudinary.com/v1_1/$cloudName/$resourceType/destroy");

      final response = await http.post(
        uri,
        body: {
          'public_id': publicId,
          'api_key': apiKey!,
          'timestamp': timestamp.toString(),
          'signature': signature,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("✅ File deleted: $publicId");
        return data['result'] == 'ok';
      } else {
        print("❌ Delete failed: ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Error deleting file: $e");
      return false;
    }
  }

  /// Generate signature for signed uploads (requires API secret)
  String _generateSignature(String publicId, int timestamp) {
    // This is a simplified version - in production, use crypto package
    // for proper SHA-256 HMAC signature generation
    return '$timestamp$publicId$apiSecret';
  }

  /// Determine resource type based on file extension
  String _getResourceType(String extension) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg'];
    final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm'];
    
    if (imageExtensions.contains(extension)) {
      return 'image';
    } else if (videoExtensions.contains(extension)) {
      return 'video';
    } else {
      return 'raw'; // For PDFs, DOCs, and other files
    }
  }

  /// Format bytes to human-readable format
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Get optimized image URL with transformations
  String getOptimizedImageUrl(
    String publicId, {
    int? width,
    int? height,
    String quality = 'auto',
    String format = 'auto',
    String crop = 'fill',
  }) {
    List<String> transformations = [];
    
    if (width != null) transformations.add('w_$width');
    if (height != null) transformations.add('h_$height');
    transformations.add('q_$quality');
    transformations.add('f_$format');
    transformations.add('c_$crop');
    
    final transformation = transformations.join(',');
    return 'https://res.cloudinary.com/$cloudName/image/upload/$transformation/$publicId';
  }

  /// Get thumbnail URL
  String getThumbnailUrl(String publicId, {int size = 200}) {
    return getOptimizedImageUrl(
      publicId,
      width: size,
      height: size,
      crop: 'thumb',
      quality: 'auto',
    );
  }
}