import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../../../theme/app_theme.dart';
import '../../../services/cloudinary_service.dart';

class DocumentUploadWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onNext;
  final VoidCallback onBack;
  final Map<String, dynamic>? initialData;

  const DocumentUploadWidget({
    super.key,
    required this.onNext,
    required this.onBack,
    this.initialData,
  });

  @override
  State<DocumentUploadWidget> createState() => _DocumentUploadWidgetState();
}

class _DocumentUploadWidgetState extends State<DocumentUploadWidget> {
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _picker = ImagePicker();
  
  bool _aadharUploaded = false;
  bool _panUploaded = false;
  bool _addressProofUploaded = false;
  bool _photoUploaded = false;

  String? _aadharFileName;
  String? _panFileName;
  String? _addressProofFileName;
  String? _photoFileName;

  String? _aadharUrl;
  String? _panUrl;
  String? _addressProofUrl;
  String? _photoUrl;

  bool _isPickingFile = false;
  String? _currentUploadingDoc;

  @override
  void initState() {
    super.initState();
    _loadSavedDocuments();
    if (widget.initialData != null) {
      _aadharUploaded = widget.initialData!['aadharUploaded'] ?? false;
      _panUploaded = widget.initialData!['panUploaded'] ?? false;
      _addressProofUploaded = widget.initialData!['addressProofUploaded'] ?? false;
      _photoUploaded = widget.initialData!['photoUploaded'] ?? false;
      
      _aadharFileName = widget.initialData!['aadharFileName'];
      _panFileName = widget.initialData!['panFileName'];
      _addressProofFileName = widget.initialData!['addressProofFileName'];
      _photoFileName = widget.initialData!['photoFileName'];

      _aadharUrl = widget.initialData!['aadharUrl'];
      _panUrl = widget.initialData!['panUrl'];
      _addressProofUrl = widget.initialData!['addressProofUrl'];
      _photoUrl = widget.initialData!['photoUrl'];
    }
  }

  Future<void> _loadSavedDocuments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? documentsJson = prefs.getString('verification_documents');

      if (documentsJson != null && documentsJson.isNotEmpty) {
        final docs = json.decode(documentsJson) as Map<String, dynamic>;
        
        setState(() {
          if (docs['aadhar'] != null) {
            _aadharUploaded = true;
            _aadharFileName = docs['aadhar']['name'];
            _aadharUrl = docs['aadhar']['url'];
          }
          if (docs['pan'] != null) {
            _panUploaded = true;
            _panFileName = docs['pan']['name'];
            _panUrl = docs['pan']['url'];
          }
          if (docs['addressProof'] != null) {
            _addressProofUploaded = true;
            _addressProofFileName = docs['addressProof']['name'];
            _addressProofUrl = docs['addressProof']['url'];
          }
          if (docs['photo'] != null) {
            _photoUploaded = true;
            _photoFileName = docs['photo']['name'];
            _photoUrl = docs['photo']['url'];
          }
        });
        print('✅ Loaded verification documents from storage');
      }
    } catch (e) {
      print('❌ Error loading documents: $e');
    }
  }

  Future<void> _saveDocuments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final docs = {
        'aadhar': _aadharUploaded ? {'name': _aadharFileName, 'url': _aadharUrl} : null,
        'pan': _panUploaded ? {'name': _panFileName, 'url': _panUrl} : null,
        'addressProof': _addressProofUploaded ? {'name': _addressProofFileName, 'url': _addressProofUrl} : null,
        'photo': _photoUploaded ? {'name': _photoFileName, 'url': _photoUrl} : null,
      };
      
      await prefs.setString('verification_documents', json.encode(docs));
      print('✅ Saved verification documents to storage');
      print('📄 Saved data: ${json.encode(docs)}');
    } catch (e) {
      print('❌ Error saving documents: $e');
    }
  }

  Future<void> _pickDocument(String documentType) async {
    if (_isPickingFile) return;

    setState(() {
      _isPickingFile = true;
      _currentUploadingDoc = documentType;
    });

    try {
      XFile? pickedFile;
      String fileName = '';
      
      if (documentType == 'photo') {
        pickedFile = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
      } else {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
          allowMultiple: false,
        );
        
        if (result != null && result.files.isNotEmpty) {
          final filePath = result.files.first.path;
          if (filePath != null) {
            pickedFile = XFile(filePath);
          }
        }
      }

      if (pickedFile == null) {
        setState(() {
          _isPickingFile = false;
          _currentUploadingDoc = null;
        });
        return;
      }

      fileName = pickedFile.name;
      final file = File(pickedFile.path);
      final fileSize = await file.length();
      
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File size must be less than 5MB'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() {
          _isPickingFile = false;
          _currentUploadingDoc = null;
        });
        return;
      }

      print('📤 Uploading $documentType: $fileName');
      
      // ⭐ FIXED: Handle Map response from CloudinaryService
      final uploadResponse = await _cloudinaryService.uploadDocument(file);

      if (uploadResponse == null) {
        throw Exception('Upload failed - no response from Cloudinary');
      }

      print('📊 Upload response type: ${uploadResponse.runtimeType}');
      print('📊 Upload response: $uploadResponse');
      
      // ⭐ Extract URL from Map response
      final String uploadedUrl = uploadResponse['url']?.toString() ?? '';
      
      if (uploadedUrl.isEmpty) {
        throw Exception('Upload failed - no URL in response');
      }

      print('✅ Final URL: $uploadedUrl');

      if (mounted) {
        setState(() {
          switch (documentType) {
            case 'aadhar':
              _aadharUploaded = true;
              _aadharFileName = fileName;
              _aadharUrl = uploadedUrl;
              break;
            case 'pan':
              _panUploaded = true;
              _panFileName = fileName;
              _panUrl = uploadedUrl;
              break;
            case 'addressProof':
              _addressProofUploaded = true;
              _addressProofFileName = fileName;
              _addressProofUrl = uploadedUrl;
              break;
            case 'photo':
              _photoUploaded = true;
              _photoFileName = fileName;
              _photoUrl = uploadedUrl;
              break;
          }
        });
      }

      await _saveDocuments();

      HapticFeedback.lightImpact();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document uploaded successfully! ✅'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      print('✅ $documentType uploaded successfully');
    } catch (e) {
      print('❌ Error uploading document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading file: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        _isPickingFile = false;
        _currentUploadingDoc = null;
      });
    }
  }

  void _removeDocument(String documentType) {
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
              Navigator.pop(context);
              
              setState(() {
                switch (documentType) {
                  case 'aadhar':
                    _aadharUploaded = false;
                    _aadharFileName = null;
                    _aadharUrl = null;
                    break;
                  case 'pan':
                    _panUploaded = false;
                    _panFileName = null;
                    _panUrl = null;
                    break;
                  case 'addressProof':
                    _addressProofUploaded = false;
                    _addressProofFileName = null;
                    _addressProofUrl = null;
                    break;
                  case 'photo':
                    _photoUploaded = false;
                    _photoFileName = null;
                    _photoUrl = null;
                    break;
                }
              });

              await _saveDocuments();
              HapticFeedback.selectionClick();
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Document removed'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _handleNext() {
    if (!_aadharUploaded || !_panUploaded || !_photoUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please upload all required documents (Aadhar, PAN, Photo)'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    
    final data = {
      'aadharUploaded': _aadharUploaded,
      'panUploaded': _panUploaded,
      'addressProofUploaded': _addressProofUploaded,
      'photoUploaded': _photoUploaded,
      'aadharFileName': _aadharFileName,
      'panFileName': _panFileName,
      'addressProofFileName': _addressProofFileName,
      'photoFileName': _photoFileName,
      'aadharUrl': _aadharUrl,
      'panUrl': _panUrl,
      'addressProofUrl': _addressProofUrl,
      'photoUrl': _photoUrl,
    };

    widget.onNext(data);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(6.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Document Upload',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.lightTheme.primaryColor,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Upload required verification documents',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 3.h),

          _buildDocumentCard(
            title: 'Aadhar Card',
            subtitle: 'Government ID proof',
            icon: Icons.badge_outlined,
            isUploaded: _aadharUploaded,
            fileName: _aadharFileName,
            isUploading: _currentUploadingDoc == 'aadhar',
            isRequired: true,
            onUpload: () => _pickDocument('aadhar'),
            onRemove: () => _removeDocument('aadhar'),
          ),
          SizedBox(height: 2.h),

          _buildDocumentCard(
            title: 'PAN Card',
            subtitle: 'Income tax ID proof',
            icon: Icons.credit_card_outlined,
            isUploaded: _panUploaded,
            fileName: _panFileName,
            isUploading: _currentUploadingDoc == 'pan',
            isRequired: true,
            onUpload: () => _pickDocument('pan'),
            onRemove: () => _removeDocument('pan'),
          ),
          SizedBox(height: 2.h),

          _buildDocumentCard(
            title: 'Address Proof',
            subtitle: 'Utility bill, bank statement, etc.',
            icon: Icons.receipt_long_outlined,
            isUploaded: _addressProofUploaded,
            fileName: _addressProofFileName,
            isUploading: _currentUploadingDoc == 'addressProof',
            isRequired: false,
            onUpload: () => _pickDocument('addressProof'),
            onRemove: () => _removeDocument('addressProof'),
          ),
          SizedBox(height: 2.h),

          _buildDocumentCard(
            title: 'Profile Photo',
            subtitle: 'Clear passport-size photograph',
            icon: Icons.photo_camera_outlined,
            isUploaded: _photoUploaded,
            fileName: _photoFileName,
            isUploading: _currentUploadingDoc == 'photo',
            isRequired: true,
            onUpload: () => _pickDocument('photo'),
            onRemove: () => _removeDocument('photo'),
          ),

          SizedBox(height: 3.h),

          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    'Ensure all documents are clear and readable. Supported formats: PDF, JPG, PNG (Max 5MB)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 4.h),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.lightTheme.primaryColor,
                    side: BorderSide(
                      color: AppTheme.lightTheme.primaryColor,
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_back, size: 20),
                      SizedBox(width: 2.w),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isPickingFile ? null : _handleNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.lightTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isUploaded,
    required String? fileName,
    required bool isUploading,
    required bool isRequired,
    required VoidCallback onUpload,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUploaded ? Colors.green : Colors.grey[300]!,
          width: isUploaded ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUploaded
                      ? Colors.green[50]
                      : AppTheme.lightTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isUploaded
                      ? Colors.green[700]
                      : AppTheme.lightTheme.primaryColor,
                  size: 24,
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
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (isRequired) ...[
                          SizedBox(width: 1.w),
                          Text(
                            '*',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isUploaded)
                Icon(Icons.check_circle, color: Colors.green, size: 28),
            ],
          ),
          if (isUploaded && fileName != null) ...[
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file, color: Colors.green[700], size: 20),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[900],
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red, size: 20),
                    onPressed: onRemove,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 2.h),
          SizedBox(
            width: double.infinity,
            child: isUploading
                ? ElevatedButton.icon(
                    onPressed: null,
                    icon: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    label: Text('Uploading...'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.lightTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                : isUploaded
                    ? OutlinedButton.icon(
                        onPressed: onUpload,
                        icon: Icon(Icons.refresh, size: 18),
                        label: Text('Replace Document'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.lightTheme.primaryColor,
                          side: BorderSide(
                            color: AppTheme.lightTheme.primaryColor,
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: onUpload,
                        icon: Icon(Icons.upload_file, size: 18),
                        label: Text('Upload Document'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.lightTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}