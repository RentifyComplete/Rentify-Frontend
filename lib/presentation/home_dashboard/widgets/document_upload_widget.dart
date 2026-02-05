import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import '../../../core/app_export.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/auth_service.dart';
import '../document_viewer_screen.dart';

class DocumentUploadWidget extends StatefulWidget {
  final String? bookingId;
  
  const DocumentUploadWidget({
    Key? key,
    this.bookingId,
  }) : super(key: key);

  @override
  State<DocumentUploadWidget> createState() => _DocumentUploadWidgetState();
}

class _DocumentUploadWidgetState extends State<DocumentUploadWidget> {
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  Map<String, dynamic> _uploadedDocuments = {};
  String? _currentBookingId;
  bool _bookingSaveEnabled = true;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeBooking();
  }

  // ✅ FIXED: Enhanced initialization with comprehensive debugging
  Future<void> _initializeBooking() async {
    print('🔄 ========== INITIALIZING BOOKING ==========');
    
    setState(() {
      _isInitializing = true;
    });

    try {
      // ✅ DEBUG: Check all SharedPreferences first
      await _debugSharedPreferences();

      if (widget.bookingId != null && widget.bookingId!.isNotEmpty) {
        setState(() {
          _currentBookingId = widget.bookingId;
          _bookingSaveEnabled = true;
        });
        print('✅ Using provided booking ID: $_currentBookingId');
        await _loadDocumentsFromBooking();
      } else {
        print('🔍 No booking ID provided, loading user\'s active booking...');
        
        // ✅ CRITICAL: Get and verify email
        final userEmail = await _getUserEmailWithFallback();
        
        if (userEmail == null || userEmail.isEmpty) {
          print('❌ CRITICAL: No user email available!');
          setState(() {
            _bookingSaveEnabled = false;
            _isInitializing = false;
          });
          return;
        }
        
        print('✅ User email verified: $userEmail');
        await _loadCurrentUserBooking(userEmail);
      }
      
      await _loadSavedDocuments();
      
      print('✅ ========== INITIALIZATION COMPLETE ==========');
      print('   Booking ID: $_currentBookingId');
      print('   Save Enabled: $_bookingSaveEnabled');
      print('   Documents: ${_uploadedDocuments.length}');
    } catch (e, stackTrace) {
      print('❌ INITIALIZATION ERROR: $e');
      print('Stack trace: $stackTrace');
      setState(() => _bookingSaveEnabled = false);
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  // ✅ NEW: Debug SharedPreferences to see what's actually stored
  Future<void> _debugSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      print('🔍 ========== SHARED PREFERENCES DEBUG ==========');
      final allKeys = prefs.getKeys();
      print('📋 Total keys: ${allKeys.length}');
      
      for (var key in allKeys) {
        final value = prefs.get(key);
        print('   $key: $value');
      }
      
      print('================================================');
    } catch (e) {
      print('❌ Error debugging SharedPreferences: $e');
    }
  }

  // ✅ NEW: Get user email with multiple fallback strategies
  Future<String?> _getUserEmailWithFallback() async {
    try {
      print('📧 Attempting to get user email...');
      
      // Strategy 1: Use AuthService method
      String? email = await _authService.getUserEmail();
      if (email != null && email.isNotEmpty) {
        print('✅ Got email from AuthService: $email');
        return email;
      }
      
      // Strategy 2: Direct SharedPreferences check
      final prefs = await SharedPreferences.getInstance();
      email = prefs.getString('user_email');
      if (email != null && email.isNotEmpty) {
        print('✅ Got email from SharedPreferences (user_email): $email');
        return email;
      }
      
      // Strategy 3: Try alternative keys
     final alternativeKeys = ['email', 'userEmail', 'tenant_email', 'tenantEmail'];
      for (var key in alternativeKeys) {
        email = prefs.getString(key);
        if (email != null && email.isNotEmpty) {
          print('✅ Got email from alternative key ($key): $email');
          return email;
        }
      }
      
      print('❌ No email found in any location');
      return null;
    } catch (e) {
      print('❌ Error getting user email: $e');
      return null;
    }
  }

  // ✅ FIXED: Load booking with explicit email parameter
  Future<void> _loadCurrentUserBooking(String userEmail) async {
    try {
      print('🔍 ========== LOADING USER BOOKING ==========');
      print('📧 Email: $userEmail');

      final url = _authService.getBookingsByTenantUrl(userEmail);
      print('📡 API Endpoint: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⏱️ Request timeout (30s)');
          throw Exception('Request timeout');
        },
      );

      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response Body: ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}');

      if (response.statusCode != 200) {
        print('❌ Failed to fetch bookings: ${response.statusCode}');
        setState(() => _bookingSaveEnabled = false);
        return;
      }

      final data = json.decode(response.body);
      
      // Handle different response structures
      final bookings = (data['bookings'] as List? ?? 
                       data['data'] as List? ?? 
                       (data is List ? data : []));
      
      print('📋 Total bookings: ${bookings.length}');

      if (bookings.isEmpty) {
        print('⚠️ No bookings found');
        setState(() => _bookingSaveEnabled = false);
        return;
      }

      // Find active booking
      Map<String, dynamic>? activeBooking;
      
      for (var i = 0; i < bookings.length; i++) {
        final booking = bookings[i] as Map<String, dynamic>;
        final status = booking['status']?.toString().toLowerCase() ?? '';
        final bookingId = booking['_id']?.toString() ?? '';
        final tenantEmail = booking['tenantEmail']?.toString().toLowerCase() ?? '';
        
        print('📄 Booking #${i + 1}:');
        print('   ID: $bookingId');
        print('   Status: $status');
        print('   Tenant Email: $tenantEmail');
        print('   Expected Email: ${userEmail.toLowerCase()}');
        print('   Match: ${tenantEmail == userEmail.toLowerCase() && status == 'active'}');
        
        if (status == 'active' && tenantEmail == userEmail.toLowerCase()) {
          activeBooking = booking;
          print('✅ FOUND ACTIVE BOOKING!');
          break;
        }
      }

      if (activeBooking != null) {
        final bookingId = activeBooking['_id']?.toString() ?? '';
        
        setState(() {
          _currentBookingId = bookingId;
          _bookingSaveEnabled = true;
        });
        
        print('✅ Active booking set: $_currentBookingId');
        
        final tenantDocuments = activeBooking['tenantDocuments'];
        if (tenantDocuments != null && tenantDocuments is Map) {
          _loadExistingDocumentsFromBooking(
            Map<String, dynamic>.from(tenantDocuments)
          );
        }
      } else {
        print('⚠️ No active booking found for: $userEmail');
        setState(() => _bookingSaveEnabled = false);
      }
    } catch (e, stackTrace) {
      print('❌ Error loading booking: $e');
      print('Stack trace: $stackTrace');
      setState(() => _bookingSaveEnabled = false);
    }
  }

  Future<void> _loadDocumentsFromBooking() async {
    if (_currentBookingId == null || _currentBookingId!.isEmpty) {
      print('⚠️ No booking ID to load documents from');
      return;
    }

    try {
      final url = '${AuthService.baseUrl}${AuthService.bookingsEndpoint}/$_currentBookingId';
      print('📡 Fetching booking from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      print('📥 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final booking = data['booking'] ?? data['data'] ?? data;
        
        if (booking != null) {
          final tenantDocuments = booking['tenantDocuments'];
          if (tenantDocuments != null && tenantDocuments is Map) {
            _loadExistingDocumentsFromBooking(
              Map<String, dynamic>.from(tenantDocuments)
            );
          } else {
            print('ℹ️ No tenant documents found');
          }
        }
      } else {
        print('⚠️ Failed to fetch booking: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('❌ Error loading documents: $e');
      print('Stack trace: $stackTrace');
    }
  }

  void _loadExistingDocumentsFromBooking(Map<String, dynamic> tenantDocuments) {
    print('📥 Loading documents from booking: $tenantDocuments');
    
    final validDocuments = <String, dynamic>{};
    
    tenantDocuments.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty && value.toString() != 'null') {
        validDocuments[key] = value.toString();
      }
    });
    
    if (validDocuments.isNotEmpty) {
      setState(() {
        _uploadedDocuments = validDocuments;
      });
      print('✅ Loaded ${_uploadedDocuments.length} documents');
    } else {
      print('ℹ️ No valid documents found');
    }
  }

  Future<void> _loadSavedDocuments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? documentsJson = prefs.getString('tenant_documents');

      if (documentsJson != null && documentsJson.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(documentsJson);
        
        if (_uploadedDocuments.isEmpty) {
          setState(() {
            _uploadedDocuments = decoded;
          });
          print('✅ Loaded ${_uploadedDocuments.length} documents from local storage');
        } else {
          print('ℹ️ Skipping local load (have ${_uploadedDocuments.length} from booking)');
        }
      } else {
        print('ℹ️ No local documents');
      }
    } catch (e) {
      print('❌ Error loading local documents: $e');
    }
  }

  Future<void> _saveDocuments() async {
    try {
      // Always save locally
      final prefs = await SharedPreferences.getInstance();
      final String documentsJson = json.encode(_uploadedDocuments);
      await prefs.setString('tenant_documents', documentsJson);
      print('✅ Saved ${_uploadedDocuments.length} documents locally');
      
      // Save to booking if available
      if (_bookingSaveEnabled && _currentBookingId != null && _currentBookingId!.isNotEmpty) {
        final success = await _saveDocumentsToBooking();
        if (success) {
          print('✅ Documents synced to booking');
        } else {
          print('⚠️ Failed to sync to booking');
        }
      } else {
        print('ℹ️ No active booking, saved locally only');
      }
    } catch (e) {
      print('❌ Error saving documents: $e');
    }
  }

  Future<bool> _saveDocumentsToBooking() async {
    if (!_bookingSaveEnabled || _currentBookingId == null || _currentBookingId!.isEmpty) {
      print('❌ Save blocked: enabled=$_bookingSaveEnabled, id=$_currentBookingId');
      return false;
    }

    try {
      final url = _authService.getUpdateBookingUrl(_currentBookingId!);
      print('📡 Updating booking: $url');
      print('📄 Documents: $_uploadedDocuments');

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'tenantDocuments': _uploadedDocuments,
        }),
      ).timeout(const Duration(seconds: 30));

      print('📥 Save Status: ${response.statusCode}');
      print('📥 Save Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] != false) {
          print('✅ Documents saved to booking');
          return true;
        }
      }
      
      print('⚠️ Failed to save: ${response.statusCode}');
      return false;
    } catch (e, stackTrace) {
      print('❌ Error saving to booking: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<void> _showPickerOptions() async {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12.w,
              height: 0.5.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              'Upload Document',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 3.h),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.camera_alt, color: AppTheme.primaryLight),
              ),
              title: Text('Take Photo'),
              subtitle: Text('Capture document with camera'),
              onTap: () {
                Navigator.pop(context);
                _showDocumentTypeDialog(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.photo_library, color: Colors.green),
              ),
              title: Text('Choose from Gallery'),
              subtitle: Text('Select image from gallery'),
              onTap: () {
                Navigator.pop(context);
                _showDocumentTypeDialog(ImageSource.gallery);
              },
            ),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }

  Future<void> _showDocumentTypeDialog(ImageSource source) async {
    final documentTypes = [
      {'key': 'id_proof', 'name': 'ID Proof'},
      {'key': 'address_proof', 'name': 'Address Proof'},
      {'key': 'income_proof', 'name': 'Income Proof'},
      {'key': 'employment_letter', 'name': 'Employment Letter'},
      {'key': 'bank_statement', 'name': 'Bank Statement'},
      {'key': 'other', 'name': 'Other Document'},
    ];

    final selectedType = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Document Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: documentTypes.map((type) {
            final isUploaded = _uploadedDocuments.containsKey(type['key']);
            return ListTile(
              title: Text(type['name']!),
              trailing: isUploaded 
                ? Icon(Icons.check_circle, color: Colors.green, size: 5.w) 
                : null,
              onTap: () => Navigator.pop(context, type),
            );
          }).toList(),
        ),
      ),
    );

    if (selectedType != null) {
      await _pickDocument(source, selectedType['key']!, selectedType['name']!);
    }
  }

  Future<void> _pickDocument(
    ImageSource source,
    String documentKey,
    String documentName,
  ) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFile == null) {
        print('📄 No file selected');
        return;
      }

      setState(() => _isUploading = true);

      print('📤 Uploading $documentName: ${pickedFile.name}');

      final file = File(pickedFile.path);

      final result = await _cloudinaryService.uploadDocument(
        file,
        folder: 'tenant_documents',
        documentType: documentKey,
        metadata: {
          'document_name': documentName,
          'uploaded_at': DateTime.now().toIso8601String(),
        },
      );

      if (result != null && result['url'] != null) {
        final cloudinaryUrl = result['url'].toString();
        
        print('✅ Upload successful!');
        print('   Type: $documentName');
        print('   Key: $documentKey');
        print('   URL: $cloudinaryUrl');

        setState(() {
          _uploadedDocuments[documentKey] = cloudinaryUrl;
        });

        await _saveDocuments();

        _showSuccessSnackbar('$documentName uploaded successfully!');
      } else {
        _showErrorSnackbar('Failed to upload document');
      }
    } catch (e, stackTrace) {
      print('❌ Upload error: $e');
      print('Stack trace: $stackTrace');
      _showErrorSnackbar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 5.w),
            SizedBox(width: 2.w),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white, size: 5.w),
            SizedBox(width: 2.w),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getDocumentDisplayName(String key) {
    final names = {
      'id_proof': 'ID Proof',
      'address_proof': 'Address Proof',
      'income_proof': 'Income Proof',
      'employment_letter': 'Employment Letter',
      'bank_statement': 'Bank Statement',
      'other': 'Other Document',
    };
    return names[key] ?? key.replaceAll('_', ' ').toUpperCase();
  }

  IconData _getDocumentIcon(String key) {
    final icons = {
      'id_proof': Icons.badge,
      'address_proof': Icons.home,
      'income_proof': Icons.account_balance_wallet,
      'employment_letter': Icons.work,
      'bank_statement': Icons.account_balance,
      'other': Icons.insert_drive_file,
    };
    return icons[key] ?? Icons.description;
  }

  Color _getDocumentColor(String key) {
    final colors = {
      'id_proof': Colors.blue,
      'address_proof': Colors.green,
      'income_proof': Colors.orange,
      'employment_letter': Colors.purple,
      'bank_statement': Colors.teal,
      'other': Colors.grey,
    };
    return colors[key] ?? Colors.grey;
  }

  void _deleteDocument(String key) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Document'),
        content: Text('Are you sure you want to delete ${_getDocumentDisplayName(key)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                _uploadedDocuments.remove(key);
              });

              await _saveDocuments();

              Navigator.pop(context);
              _showSuccessSnackbar('Document deleted');
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Container(
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
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryLight),
              SizedBox(height: 2.h),
              Text(
                'Loading booking information...',
                style: TextStyle(color: AppTheme.textSecondaryLight),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Uploaded Documents',
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_uploadedDocuments.length} docs',
                  style: TextStyle(
                    color: AppTheme.primaryLight,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          if (!_bookingSaveEnabled) ...[
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 4.w),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      'No active booking found. Documents saved locally only.',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 9.sp,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      print('🔄 Manual refresh');
                      await _initializeBooking();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_bookingSaveEnabled 
                                ? 'Booking found!' 
                                : 'Still no active booking'),
                            backgroundColor: _bookingSaveEnabled ? Colors.green : Colors.orange,
                          ),
                        );
                      }
                    },
                    child: Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 4.w),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      _currentBookingId != null && _currentBookingId!.length >= 8
                          ? 'Syncing with booking: ${_currentBookingId!.substring(0, 8)}...'
                          : 'Syncing with booking',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 9.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          SizedBox(height: 3.h),

          InkWell(
            onTap: _isUploading ? null : _showPickerOptions,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 4.w),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isUploading ? Colors.grey.shade300 : AppTheme.primaryLight,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
                color: _isUploading
                    ? Colors.grey.shade50
                    : AppTheme.primaryLight.withOpacity(0.05),
              ),
              child: _isUploading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 5.w,
                          height: 5.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryLight,
                          ),
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          'Uploading...',
                          style: TextStyle(
                            color: AppTheme.primaryLight,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined, color: AppTheme.primaryLight, size: 6.w),
                        SizedBox(width: 2.w),
                        Text(
                          'Upload Document',
                          style: TextStyle(
                            color: AppTheme.primaryLight,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          SizedBox(height: 1.h),

          Center(
            child: Text(
              'Take photo or choose from gallery',
              style: TextStyle(
                color: AppTheme.textSecondaryLight,
                fontSize: 9.sp,
              ),
            ),
          ),
          SizedBox(height: 3.h),

          if (_uploadedDocuments.isEmpty)
            Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.folder_open, color: Colors.grey, size: 12.w),
                  SizedBox(height: 2.h),
                  Text(
                    'No documents uploaded yet',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    'Upload your ID proof, address proof, or other documents',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 9.sp,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _uploadedDocuments.length,
              separatorBuilder: (context, index) => SizedBox(height: 2.h),
              itemBuilder: (context, index) {
                final entry = _uploadedDocuments.entries.elementAt(index);
                return _buildDocumentItem(entry.key, entry.value);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(String documentKey, dynamic documentUrl) {
    final displayName = _getDocumentDisplayName(documentKey);
    final icon = _getDocumentIcon(documentKey);
    final color = _getDocumentColor(documentKey);
    final url = documentUrl.toString();

    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 6.w),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryLight,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  'Tap to view',
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.open_in_new, size: 5.w),
            color: AppTheme.primaryLight,
            onPressed: () {
              if (url.isNotEmpty && url.startsWith('http')) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DocumentViewerScreen(
                      documentUrl: url,
                      documentName: displayName,
                    ),
                  ),
                );
              } else {
                _showErrorSnackbar('Invalid document URL');
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 5.w),
            color: Colors.red,
            onPressed: () => _deleteDocument(documentKey),
          ),
        ],
      ),
    );
  }
}