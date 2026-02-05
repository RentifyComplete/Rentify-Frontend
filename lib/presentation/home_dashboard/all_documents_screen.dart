import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/app_export.dart';
import 'document_viewer_screen.dart';

class AllDocumentsScreen extends StatefulWidget {
  const AllDocumentsScreen({Key? key}) : super(key: key);

  @override
  State<AllDocumentsScreen> createState() => _AllDocumentsScreenState();
}

class _AllDocumentsScreenState extends State<AllDocumentsScreen> {
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  // ⭐ IMPROVED: Load documents with better error handling and validation
  Future<void> _loadDocuments() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print('📂 Loading documents from SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      final String? documentsJson = prefs.getString('uploaded_documents');

      if (documentsJson != null && documentsJson.isNotEmpty) {
        print('📄 Found document data: ${documentsJson.length} characters');
        
        final List<dynamic> decoded = json.decode(documentsJson);
        final List<Map<String, dynamic>> loadedDocs = decoded
            .map((doc) => Map<String, dynamic>.from(doc))
            .toList();
        
        // Validate each document has required fields
        final validDocs = loadedDocs.where((doc) {
          final hasRequiredFields = doc['id'] != null && 
                                   doc['name'] != null && 
                                   doc['url'] != null;
          if (!hasRequiredFields) {
            print('⚠️ Invalid document found: $doc');
          }
          return hasRequiredFields;
        }).toList();
        
        setState(() {
          _documents = validDocs;
          _isLoading = false;
        });
        
        print('✅ Loaded ${_documents.length} valid document(s)');
        
        // Log document details for debugging
        for (var doc in _documents) {
          print('  📄 ${doc['documentType'] ?? 'Unknown'}: ${doc['name']}');
        }
      } else {
        setState(() {
          _documents = [];
          _isLoading = false;
        });
        print('📭 No documents found in storage');
      }
    } catch (e, stackTrace) {
      print('❌ Error loading documents: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _documents = [];
      });
    }
  }

  // ⭐ IMPROVED: Save documents with validation
  Future<void> _saveDocuments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_documents.isEmpty) {
        await prefs.remove('uploaded_documents');
        print('✅ Cleared all documents from storage');
      } else {
        final String documentsJson = json.encode(_documents);
        final bool success = await prefs.setString('uploaded_documents', documentsJson);
        
        if (success) {
          print('✅ Saved ${_documents.length} document(s) to storage');
        } else {
          throw Exception('Failed to save to SharedPreferences');
        }
      }
    } catch (e) {
      print('❌ Error saving documents: $e');
      _showErrorSnackbar('Failed to save changes: ${e.toString()}');
      rethrow;
    }
  }

  // ⭐ IMPROVED: Delete with confirmation and better feedback
  Future<void> _deleteDocument(int index) async {
    try {
      final docName = _documents[index]['name'] ?? 'document';
      print('🗑️ Deleting document: $docName');
      
      setState(() {
        _documents.removeAt(index);
      });
      
      await _saveDocuments();
      
      if (mounted) {
        _showSuccessSnackbar('Document deleted successfully');
      }
    } catch (e) {
      print('❌ Error deleting document: $e');
      _showErrorSnackbar('Failed to delete document');
      // Reload to restore state
      await _loadDocuments();
    }
  }

  // ⭐ IMPROVED: Clear all with proper cleanup
  Future<void> _clearAllDocuments() async {
    try {
      print('🗑️ Clearing all documents...');
      
      setState(() {
        _documents.clear();
      });
      
      await _saveDocuments();
      
      if (mounted) {
        _showSuccessSnackbar('All documents cleared');
      }
    } catch (e) {
      print('❌ Error clearing documents: $e');
      _showErrorSnackbar('Failed to clear documents');
      // Reload to restore state
      await _loadDocuments();
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
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimaryLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'All Documents',
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_documents.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep, color: Colors.red),
              onPressed: () => _showClearAllDialog(),
              tooltip: 'Clear all documents',
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.primaryLight),
            onPressed: _loadDocuments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryLight),
            SizedBox(height: 2.h),
            Text(
              'Loading documents...',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(8.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 20.w, color: Colors.red),
              SizedBox(height: 2.h),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.sp, color: Colors.grey),
              ),
              SizedBox(height: 2.h),
              ElevatedButton.icon(
                onPressed: _loadDocuments,
                icon: Icon(Icons.refresh),
                label: Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_documents.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      color: AppTheme.primaryLight,
      child: ListView.builder(
        padding: EdgeInsets.all(4.w),
        itemCount: _documents.length,
        itemBuilder: (context, index) {
          final doc = _documents[index];
          return _buildDocumentCard(doc, index);
        },
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
              size: 30.w,
              color: Colors.grey.shade300,
            ),
            SizedBox(height: 3.h),
            Text(
              'No Documents Yet',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Upload your documents from the profile section to see them here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.grey.shade500,
              ),
            ),
            SizedBox(height: 3.h),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.upload_file),
              label: Text('Go to Upload'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryLight,
                side: BorderSide(color: AppTheme.primaryLight),
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc, int index) {
    final fileType = doc['type'] ?? 'unknown';
    final fileName = doc['name'] ?? 'Unknown file';
    final fileSize = doc['size'] ?? 0;
    final documentType = doc['documentType'] ?? 'Document';
    final documentDescription = doc['documentDescription'];
    
    DateTime uploadDate;
    try {
      uploadDate = DateTime.parse(doc['uploadDate']);
    } catch (e) {
      uploadDate = DateTime.now();
    }
    
    final formattedDate =
        '${uploadDate.day}/${uploadDate.month}/${uploadDate.year} at ${uploadDate.hour}:${uploadDate.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document Type Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              documentType,
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryLight,
              ),
            ),
          ),
          SizedBox(height: 2.h),
          
          // Main Content
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: _getFileColor(fileType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getFileIcon(fileType),
                  color: _getFileColor(fileType),
                  size: 8.w,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryLight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (documentDescription != null) ...[
                      SizedBox(height: 0.5.h),
                      Text(
                        documentDescription,
                        style: TextStyle(
                          fontSize: 9.sp,
                          color: AppTheme.textSecondaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 1.h),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 3.w,
                          color: AppTheme.textSecondaryLight,
                        ),
                        SizedBox(width: 1.w),
                        Expanded(
                          child: Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: AppTheme.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      _formatFileSize(fileSize),
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: AppTheme.textSecondaryLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Divider(color: Colors.grey.shade200, thickness: 1),
          SizedBox(height: 1.h),
          
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _viewDocument(doc),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 1.5.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.open_in_new,
                          color: AppTheme.primaryLight,
                          size: 4.w,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          'View',
                          style: TextStyle(
                            color: AppTheme.primaryLight,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: InkWell(
                  onTap: () => _showDeleteDialog(index),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 1.5.h),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 4.w,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _viewDocument(Map<String, dynamic> doc) {
    final url = doc['url'] as String?;
    final name = doc['name'] as String? ?? 'Document';
    
    if (url == null || url.isEmpty) {
      _showErrorSnackbar('Document URL not available');
      return;
    }
    
    print('📂 Opening document: $name');
    
    // Navigate to full-screen DocumentViewerScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(
          documentUrl: url,
          documentName: name,
        ),
      ),
    );
  }

  void _showDeleteDialog(int index) {
    final docName = _documents[index]['name'] ?? 'this document';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Document'),
        content: Text('Are you sure you want to delete "$docName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteDocument(index);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear All Documents'),
        content: Text(
            'Are you sure you want to delete all ${_documents.length} document(s)? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearAllDocuments();
            },
            child: Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
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
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
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
        duration: Duration(seconds: 3),
      ),
    );
  }
}