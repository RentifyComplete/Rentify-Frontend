import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/app_export.dart';
import 'document_viewer_screen.dart';

class MyDocumentsScreen extends StatefulWidget {
  const MyDocumentsScreen({super.key});

  @override
  State<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends State<MyDocumentsScreen> {
  List<Map<String, dynamic>> documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  // ⭐ FIXED: Load ONLY verification documents (from owner registration)
  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? documentsJson = prefs.getString('verification_documents');

      print('📂 Loading verification documents from SharedPreferences...');
      print('📄 JSON data: $documentsJson');

      List<Map<String, dynamic>> loadedDocs = [];

      if (documentsJson != null && documentsJson.isNotEmpty) {
        try {
          final Map<String, dynamic> docs = json.decode(documentsJson);
          
          // Extract only uploaded documents
          if (docs['aadhar'] != null) {
            final url = _extractUrl(docs['aadhar']);
            final name = _extractName(docs['aadhar']);
            if (url.isNotEmpty && name.isNotEmpty) {
              loadedDocs.add({
                'documentType': 'Aadhar Card',
                'name': name,
                'url': url,
                'size': 0,
                'uploadDate': DateTime.now().toIso8601String(),
                'isRequired': true,
              });
            }
          }
          
          if (docs['pan'] != null) {
            final url = _extractUrl(docs['pan']);
            final name = _extractName(docs['pan']);
            if (url.isNotEmpty && name.isNotEmpty) {
              loadedDocs.add({
                'documentType': 'PAN Card',
                'name': name,
                'url': url,
                'size': 0,
                'uploadDate': DateTime.now().toIso8601String(),
                'isRequired': true,
              });
            }
          }
          
          if (docs['addressProof'] != null) {
            final url = _extractUrl(docs['addressProof']);
            final name = _extractName(docs['addressProof']);
            if (url.isNotEmpty && name.isNotEmpty) {
              loadedDocs.add({
                'documentType': 'Address Proof',
                'name': name,
                'url': url,
                'size': 0,
                'uploadDate': DateTime.now().toIso8601String(),
                'isRequired': false,
              });
            }
          }
          
          if (docs['photo'] != null) {
            final url = _extractUrl(docs['photo']);
            final name = _extractName(docs['photo']);
            if (url.isNotEmpty && name.isNotEmpty) {
              loadedDocs.add({
                'documentType': 'Profile Photo',
                'name': name,
                'url': url,
                'size': 0,
                'uploadDate': DateTime.now().toIso8601String(),
                'isRequired': true,
              });
            }
          }
          
          print('✅ Loaded ${loadedDocs.length} verification documents');
          for (var doc in loadedDocs) {
            print('  📄 ${doc['documentType']}: ${doc['name']}');
            print('     URL: ${doc['url']}');
          }
        } catch (e) {
          print('❌ Error decoding documents: $e');
        }
      } else {
        print('📭 No verification documents found');
      }

      setState(() {
        documents = loadedDocs;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading documents: $e');
      setState(() {
        documents = [];
        _isLoading = false;
      });
    }
  }

  // ⭐ FIXED: Extract URL from both string and Map formats with better error handling
  String _extractUrl(dynamic value) {
    if (value == null) return '';
    
    if (value is String) {
      return value;
    } else if (value is Map) {
      final map = value as Map<String, dynamic>;
      final url = map['url'];
      if (url is String) {
        return url;
      } else if (url is Map) {
        // Handle nested url structure
        final nestedMap = url as Map<String, dynamic>;
        return nestedMap['url']?.toString() ?? '';
      }
    }
    return '';
  }

  // ⭐ NEW: Extract name from document data
  String _extractName(dynamic value) {
    if (value == null) return '';
    
    if (value is Map) {
      final map = value as Map<String, dynamic>;
      return map['name']?.toString() ?? '';
    }
    return '';
  }

  IconData _getDocumentIcon(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('aadhar') || lowerType.contains('id')) {
      return Icons.badge_outlined;
    } else if (lowerType.contains('pan')) {
      return Icons.credit_card_outlined;
    } else if (lowerType.contains('address')) {
      return Icons.receipt_long_outlined;
    } else if (lowerType.contains('photo') || lowerType.contains('profile')) {
      return Icons.photo_camera_outlined;
    }
    return Icons.description_outlined;
  }

  Color _getDocumentColor(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('aadhar') || lowerType.contains('id')) {
      return Colors.blue;
    } else if (lowerType.contains('pan')) {
      return Colors.orange;
    } else if (lowerType.contains('address')) {
      return Colors.purple;
    } else if (lowerType.contains('photo') || lowerType.contains('profile')) {
      return Colors.green;
    }
    return Colors.grey;
  }

  String _getFormattedDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  // ⭐ FIXED: Improved preview with better error handling and null safety
  void _previewDocument(Map<String, dynamic> document) {
    print('📂 Previewing document: ${document['documentType']}');
    
    // Extract URL safely
    final urlValue = document['url'];
    String url = '';
    
    if (urlValue is String) {
      url = urlValue;
    } else if (urlValue is Map) {
      url = _extractUrl(urlValue);
    } else {
      url = urlValue?.toString() ?? '';
    }

    print('📎 Extracted URL: $url');

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document URL not available'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Extract name safely
    final nameValue = document['name'];
    String name = '';
    
    if (nameValue is String) {
      name = nameValue;
    } else {
      name = document['documentType']?.toString() ?? 'Document';
    }

    print('📎 Document name: $name');

    // Navigate to DocumentViewerScreen
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentViewerScreen(
            documentUrl: url,
            documentName: name,
          ),
        ),
      );
    } catch (e) {
      print('❌ Navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening document viewer'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _viewDocumentDetails(Map<String, dynamic> document) {
    // Extract URL safely
    String url = _extractUrl(document['url']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(document['documentType']?.toString() ?? 'Document'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('File Name', document['name']?.toString() ?? 'Unknown'),
              _buildDetailRow('File Size', _formatFileSize(document['size'] as int? ?? 0)),
              _buildDetailRow('Uploaded', _getFormattedDate(document['uploadDate']?.toString() ?? '')),
              _buildDetailRow('Category', document['documentCategory']?.toString() ?? 'General'),
              if (url.isNotEmpty)
                _buildDetailRow('URL', url.length > 50 ? '${url.substring(0, 50)}...' : url),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _previewDocument(document);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
            ),
            child: Text('Preview'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12.sp,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12.sp),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _deleteDocument(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Document'),
        content: Text('Are you sure you want to delete this document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        documents.removeAt(index);
      });

      // Save updated list to SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final String documentsJson = json.encode(documents);
        await prefs.setString('uploaded_documents', documentsJson);
        print('✅ Document deleted and saved');
      } catch (e) {
        print('❌ Error saving after deletion: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: AppTheme.primaryLight),
        ),
        title: Text(
          'My Documents',
          style: TextStyle(
            color: AppTheme.primaryLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadDocuments,
            icon: Icon(Icons.refresh, color: AppTheme.primaryLight),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryLight,
              ),
            )
          : documents.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadDocuments,
                  color: AppTheme.primaryLight,
                  child: ListView(
                    padding: EdgeInsets.all(4.w),
                    children: [
                      _buildInfoCard(),
                      SizedBox(height: 3.h),
                      Text(
                        'Uploaded Documents',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryLight,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      ...documents.asMap().entries.map((entry) {
                        int index = entry.key;
                        Map<String, dynamic> document = entry.value;
                        return _buildDocumentCard(document, index);
                      }).toList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryLight,
            AppTheme.primaryLight.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryLight.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.folder_outlined, color: Colors.white, size: 6.w),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Documents',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.sp,
                      ),
                    ),
                    Text(
                      '${documents.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> document, int index) {
    final documentColor = _getDocumentColor(document['documentType']?.toString() ?? 'Document');
    final fileName = document['name']?.toString() ?? 'Unknown';
    final fileSize = _formatFileSize(document['size'] as int? ?? 0);
    final uploadDate = _getFormattedDate(document['uploadDate']?.toString() ?? '');

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewDocumentDetails(document),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(3.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(2.w),
                      decoration: BoxDecoration(
                        color: documentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getDocumentIcon(document['documentType']?.toString() ?? 'Document'),
                        color: documentColor,
                        size: 6.w,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            document['documentType']?.toString() ?? 'Document',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 0.3.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 1.5.w,
                              vertical: 0.3.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, color: Colors.white, size: 2.5.w),
                                SizedBox(width: 0.5.w),
                                Text(
                                  'Uploaded',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 5.w),
                      onSelected: (value) {
                        if (value == 'preview') {
                          _previewDocument(document);
                        } else if (value == 'delete') {
                          _deleteDocument(index);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'preview',
                          child: Row(
                            children: [
                              Icon(Icons.visibility, size: 4.w),
                              SizedBox(width: 2.w),
                              Text('Preview', style: TextStyle(fontSize: 10.sp)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 4.w),
                              SizedBox(width: 2.w),
                              Text('Delete', style: TextStyle(color: Colors.red, fontSize: 10.sp)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Divider(color: Colors.grey[300], thickness: 1),
                SizedBox(height: 1.h),
                
                // Info Grid
                Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description, size: 3.w, color: Colors.grey[500]),
                        SizedBox(width: 1.w),
                        Expanded(
                          child: Text(
                            fileName,
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 0.7.h),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 3.w, color: Colors.grey[500]),
                        SizedBox(width: 1.w),
                        Expanded(
                          child: Text(
                            'Uploaded: $uploadDate',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 0.7.h),
                    Row(
                      children: [
                        Icon(Icons.storage, size: 3.w, color: Colors.grey[500]),
                        SizedBox(width: 1.w),
                        Text(
                          fileSize,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 20.w,
              color: Colors.grey[400],
            ),
            SizedBox(height: 2.h),
            Text(
              'No Documents Yet',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Your uploaded documents will appear here',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}