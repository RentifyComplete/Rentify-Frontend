import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';

import '../../../core/app_export.dart';
import '../../../services/cloudinary_service.dart';

class DocumentUploadWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onDataChanged;
  final Map<String, dynamic> initialData;

  const DocumentUploadWidget({
    super.key,
    required this.onDataChanged,
    required this.initialData,
  });

  @override
  State<DocumentUploadWidget> createState() => _DocumentUploadWidgetState();
}

class _DocumentUploadWidgetState extends State<DocumentUploadWidget> {
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _picker = ImagePicker();
  
  Map<String, Map<String, dynamic>?> _uploadedDocuments = {};
  bool _isUploading = false;
  String? _currentUploadingDoc;

  final List<Map<String, dynamic>> _requiredDocuments = [
    {
      'id': 'id_proof',
      'name': 'ID Proof',
      'description': 'Aadhaar Card, PAN Card, or Passport',
      'icon': 'badge',
      'required': true,
    },
    {
      'id': 'address_proof',
      'name': 'Address Proof',
      'description': 'Utility bill, Bank statement, or Rental agreement',
      'icon': 'home',
      'required': true,
    },
    {
      'id': 'income_proof',
      'name': 'Income Proof',
      'description': 'Salary slips, Bank statements, or ITR',
      'icon': 'receipt',
      'required': false,
    },
    {
      'id': 'employment_letter',
      'name': 'Employment Letter',
      'description': 'Letter from employer or HR department',
      'icon': 'work',
      'required': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    widget.initialData.forEach((key, value) {
      if (value is Map) {
        _uploadedDocuments[key] = Map<String, dynamic>.from(value);
      }
    });
  }

  void _updateData() {
    widget.onDataChanged(Map<String, dynamic>.from(_uploadedDocuments));
  }

  Future<void> _saveToAllDocuments(Map<String, dynamic> documentData) async {
    try {
      print('💾 Saving document to AllDocuments...');
      final prefs = await SharedPreferences.getInstance();
      final String? existingJson = prefs.getString('uploaded_documents');
      
      List<Map<String, dynamic>> allDocuments = [];
      
      if (existingJson != null && existingJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = json.decode(existingJson);
          allDocuments = decoded
              .map((doc) => Map<String, dynamic>.from(doc as Map))
              .toList();
        } catch (e) {
          print('❌ Error decoding existing documents: $e');
          allDocuments = [];
        }
      }
      
      String uniqueId = documentData['id'];
      int counter = 1;
      while (allDocuments.any((doc) => doc['id'] == uniqueId)) {
        uniqueId = '${documentData['id']}_$counter';
        counter++;
      }
      documentData['id'] = uniqueId;
      
      allDocuments.add(documentData);
      
      final String updatedJson = json.encode(allDocuments);
      final bool success = await prefs.setString('uploaded_documents', updatedJson);
      
      if (success) {
        print('✅ Successfully saved document to AllDocuments. Total: ${allDocuments.length}');
        print('📄 Document details: ${documentData['name']} (${documentData['documentType']})');
      } else {
        print('❌ Failed to save document to SharedPreferences');
        throw Exception('SharedPreferences write failed');
      }
    } catch (e) {
      print('❌ Error saving to AllDocuments: $e');
      _showErrorSnackbar('Failed to save document: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> _removeFromAllDocuments(String documentId) async {
    try {
      print('🗑️ Removing document from AllDocuments...');
      final prefs = await SharedPreferences.getInstance();
      final String? existingJson = prefs.getString('uploaded_documents');
      
      if (existingJson == null || existingJson.isEmpty) {
        print('⚠️ No documents found in storage');
        return;
      }
      
      List<Map<String, dynamic>> allDocuments = [];
      
      try {
        final List<dynamic> decoded = json.decode(existingJson);
        allDocuments = decoded
            .map((doc) => Map<String, dynamic>.from(doc as Map))
            .toList();
      } catch (e) {
        print('❌ Error decoding documents: $e');
        return;
      }
      
      final documentToRemove = _uploadedDocuments[documentId];
      if (documentToRemove != null) {
        final initialCount = allDocuments.length;
        
        allDocuments.removeWhere((doc) => 
          doc['id'] == documentToRemove['id'] || 
          doc['url'] == documentToRemove['url']
        );
        
        final removedCount = initialCount - allDocuments.length;
        
        if (allDocuments.isEmpty) {
          await prefs.remove('uploaded_documents');
          print('✅ Removed all documents from storage');
        } else {
          final String updatedJson = json.encode(allDocuments);
          await prefs.setString('uploaded_documents', updatedJson);
          print('✅ Removed $removedCount document(s). Remaining: ${allDocuments.length}');
        }
      }
    } catch (e) {
      print('❌ Error removing from AllDocuments: $e');
      _showErrorSnackbar('Failed to remove document: ${e.toString()}');
    }
  }

  Future<void> _uploadDocument(String documentId) async {
    await showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildUploadOptions(documentId),
    );
  }

  Widget _buildUploadOptions(String documentId) {
    return Container(
      padding: EdgeInsets.all(4.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12.w,
            height: 0.5.h,
            decoration: BoxDecoration(
              color: AppTheme.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Upload Document',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 3.h),
          
          ListTile(
            leading: Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomIconWidget(
                iconName: 'camera_alt',
                color: AppTheme.lightTheme.primaryColor,
                size: 6.w,
              ),
            ),
            title: Text('Take Photo'),
            subtitle: Text('Use camera to capture document'),
            onTap: () {
              Navigator.pop(context);
              _pickAndUploadDocument(documentId, ImageSource.camera);
            },
          ),
          
          ListTile(
            leading: Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomIconWidget(
                iconName: 'photo_library',
                color: AppTheme.lightTheme.primaryColor,
                size: 6.w,
              ),
            ),
            title: Text('Choose from Gallery'),
            subtitle: Text('Select from your photo gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickAndUploadDocument(documentId, ImageSource.gallery);
            },
          ),
          
          ListTile(
            leading: Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomIconWidget(
                iconName: 'description',
                color: AppTheme.lightTheme.primaryColor,
                size: 6.w,
              ),
            ),
            title: Text('Upload PDF'),
            subtitle: Text('Select PDF document'),
            onTap: () {
              Navigator.pop(context);
              _pickAndUploadPdf(documentId);
            },
          ),
          SizedBox(height: 2.h),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadDocument(String documentId, ImageSource source) async {
    try {
      print('📸 Picking document from ${source.toString()}');
      
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        print('⚠️ User cancelled selection');
        return;
      }

      print('✓ Document selected: ${pickedFile.name}');
      await _uploadToCloudinary(documentId, pickedFile.path, pickedFile.name);
    } catch (e) {
      print('❌ Error picking document: $e');
      _showErrorSnackbar('Error selecting document: $e');
    }
  }

  Future<void> _pickAndUploadPdf(String documentId) async {
    try {
      print('📄 Picking PDF document');
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowCompression: true,
      );

      if (result == null || result.files.isEmpty) {
        print('⚠️ User cancelled PDF selection');
        return;
      }

      final file = result.files.first;
      print('✓ PDF selected: ${file.name}');

      if (file.path != null) {
        await _uploadToCloudinary(documentId, file.path!, file.name);
      } else {
        _showErrorSnackbar('Invalid file path');
      }
    } catch (e) {
      print('❌ Error picking PDF: $e');
      _showErrorSnackbar('Error selecting PDF: $e');
    }
  }

  Future<void> _uploadToCloudinary(String documentId, String filePath, String fileName) async {
    try {
      setState(() {
        _isUploading = true;
        _currentUploadingDoc = documentId;
      });

      final file = File(filePath);

      if (!await file.exists()) {
        _showErrorSnackbar('File not found');
        return;
      }

      final fileSize = await file.length();
      print('📤 Uploading: $fileName (${_formatFileSize(fileSize)})');

      final docInfo = _requiredDocuments.firstWhere(
        (doc) => doc['id'] == documentId,
        orElse: () => {'name': 'Document', 'description': 'General Document'},
      );

      final userId = await _getCurrentUserId();

      final uploadedUrl = await _cloudinaryService.uploadDocument(file);

      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        _showErrorSnackbar('Upload failed - no URL returned');
        return;
      }

      print('✅ Upload successful: $uploadedUrl');

      final fileExtension = fileName.split('.').last.toLowerCase();

      final uploadResult = {
        'url': uploadedUrl,
        'public_id': 'users/documents/$documentId/$userId/${fileName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}',
        'format': fileExtension,
        'bytes': fileSize,
        'folder': 'users/documents/$documentId/$userId',
        'tags': [documentId, userId, 'verification'],
        'resource_type': _getResourceType(fileExtension),
      };

      print('   Public ID: ${uploadResult['public_id']}');
      print('   Folder: ${uploadResult['folder']}');

      final documentData = {
        'id': '${documentId}_${DateTime.now().millisecondsSinceEpoch}',
        'documentType': docInfo['name'] as String,
        'documentCategory': documentId,
        'documentDescription': docInfo['description'] as String,
        'name': fileName,
        'url': uploadResult['url'],
        'publicId': uploadResult['public_id'],
        'size': uploadResult['bytes'],
        'uploadDate': DateTime.now().toIso8601String(),
        'type': fileExtension,
        'isRequired': docInfo['required'] ?? false,
        'folder': uploadResult['folder'],
        'tags': uploadResult['tags'],
        'resourceType': uploadResult['resource_type'],
        'userId': userId,
      };

      print('📋 Created document data:');
      print('  - ID: ${documentData['id']}');
      print('  - Type: ${documentData['documentType']}');
      print('  - Folder: ${documentData['folder']}');
      print('  - Size: ${_formatFileSize(fileSize)}');

      setState(() {
        _uploadedDocuments[documentId] = documentData;
      });

      await _saveToAllDocuments(Map<String, dynamic>.from(documentData));

      _updateData();
      _showSuccessSnackbar('Document uploaded successfully!');
      print('✅ Document fully saved: $documentId');
    } catch (e, stackTrace) {
      print('❌ Error uploading document: $e');
      print('Stack trace: $stackTrace');
      _showErrorSnackbar('Upload error: ${e.toString()}');
    } finally {
      setState(() {
        _isUploading = false;
        _currentUploadingDoc = null;
      });
    }
  }

  Future<String> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      
      if (userId == null || userId.isEmpty) {
        userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('user_id', userId);
        print('📝 Generated new user ID: $userId');
      }
      
      return userId;
    } catch (e) {
      print('❌ Error getting user ID: $e');
      return 'user_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  String _getResourceType(String extension) {
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'];
    final videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
    
    if (imageExtensions.contains(extension.toLowerCase())) {
      return 'image';
    } else if (videoExtensions.contains(extension.toLowerCase())) {
      return 'video';
    } else {
      return 'raw';
    }
  }

  void _removeDocument(String documentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Document'),
        content: Text('Are you sure you want to remove this document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _removeFromAllDocuments(documentId);
              
              setState(() {
                _uploadedDocuments.remove(documentId);
              });
              _updateData();
              Navigator.pop(context);
              _showSuccessSnackbar('Document removed');
            },
            child: Text(
              'Remove',
              style: TextStyle(color: AppTheme.warningLight),
            ),
          ),
        ],
      ),
    );
  }

  void _viewDocument(String documentId) {
    final documentData = _uploadedDocuments[documentId];
    if (documentData == null || documentData['url'] == null) {
      _showErrorSnackbar('Document URL not found');
      return;
    }

    final documentUrl = documentData['url'] as String;
    final fileType = documentData['type'] as String? ?? 'unknown';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: EdgeInsets.all(4.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Document Preview',
                    style: AppTheme.lightTheme.textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: CustomIconWidget(
                      iconName: 'close',
                      color: AppTheme.textSecondaryLight,
                      size: 6.w,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              if (fileType == 'pdf')
                Column(
                  children: [
                    CustomIconWidget(
                      iconName: 'picture_as_pdf',
                      color: Colors.red,
                      size: 20.w,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      documentData['name'] ?? 'Document.pdf',
                      style: AppTheme.lightTheme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'PDF Preview not available',
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                )
              else
                CustomImageWidget(
                  imageUrl: documentUrl,
                  width: 70.w,
                  height: 40.h,
                  fit: BoxFit.contain,
                ),
              SizedBox(height: 2.h),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 2.w),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.successLight,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 2.w),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Document Upload',
            style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.lightTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Upload your documents for verification. This helps build trust with property owners.',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryLight,
            ),
          ),
          SizedBox(height: 3.h),

          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _requiredDocuments.length,
            separatorBuilder: (context, index) => SizedBox(height: 2.h),
            itemBuilder: (context, index) {
              final document = _requiredDocuments[index];
              final documentId = document['id'] as String;
              final isUploaded = _uploadedDocuments.containsKey(documentId);
              final isCurrentlyUploading = _isUploading && _currentUploadingDoc == documentId;

              return Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: AppTheme.lightTheme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUploaded
                        ? AppTheme.successLight.withValues(alpha: 0.3)
                        : AppTheme.borderLight,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(3.w),
                          decoration: BoxDecoration(
                            color: isUploaded
                                ? AppTheme.successLight.withValues(alpha: 0.1)
                                : AppTheme.lightTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CustomIconWidget(
                            iconName: document['icon'],
                            color: isUploaded
                                ? AppTheme.successLight
                                : AppTheme.lightTheme.primaryColor,
                            size: 6.w,
                          ),
                        ),
                        SizedBox(width: 3.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    document['name'],
                                    style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (document['required']) ...[
                                    SizedBox(width: 2.w),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 2.w,
                                        vertical: 0.5.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warningLight.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Required',
                                        style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                                          color: AppTheme.warningLight,
                                          fontSize: 10.sp,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              SizedBox(height: 0.5.h),
                              Text(
                                document['description'],
                                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isUploaded)
                          CustomIconWidget(
                            iconName: 'check_circle',
                            color: AppTheme.successLight,
                            size: 6.w,
                          ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    
                    if (isCurrentlyUploading) ...[
                      Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: AppTheme.lightTheme.primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 5.w,
                              height: 5.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.lightTheme.primaryColor,
                              ),
                            ),
                            SizedBox(width: 3.w),
                            Text(
                              'Uploading...',
                              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.lightTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isUploaded) ...[
                      Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: AppTheme.successLight.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            CustomIconWidget(
                              iconName: 'description',
                              color: AppTheme.successLight,
                              size: 5.w,
                            ),
                            SizedBox(width: 3.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _uploadedDocuments[documentId]!['name'] ?? 'Document',
                                    style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.successLight,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _formatFileSize(_uploadedDocuments[documentId]!['size'] ?? 0),
                                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                                      color: AppTheme.successLight.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => _viewDocument(documentId),
                              child: Text('View'),
                            ),
                            TextButton(
                              onPressed: () => _removeDocument(documentId),
                              child: Text(
                                'Remove',
                                style: TextStyle(color: AppTheme.warningLight),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isUploading ? null : () => _uploadDocument(documentId),
                          icon: CustomIconWidget(
                            iconName: 'upload',
                            color: _isUploading 
                                ? Colors.grey 
                                : AppTheme.lightTheme.primaryColor,
                            size: 5.w,
                          ),
                          label: Text('Upload Document'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          SizedBox(height: 3.h),

          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.lightTheme.primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'security',
                      color: AppTheme.lightTheme.primaryColor,
                      size: 5.w,
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      'Your Documents are Secure',
                      style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.lightTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  '• All documents are encrypted and stored securely\n• Only verified property owners can view your documents\n• You can remove documents anytime\n• We comply with data protection regulations',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}