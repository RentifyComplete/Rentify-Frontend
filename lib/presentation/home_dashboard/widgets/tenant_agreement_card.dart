import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../services/backend_service.dart';
import '../../../services/supabase_storage_service.dart';

class TenantAgreementCard extends StatefulWidget {
  final String propertyId;
  final BackendService backendService;
  final String baseUrl;

  const TenantAgreementCard({
    Key? key,
    required this.propertyId,
    required this.backendService,
    required this.baseUrl,
  }) : super(key: key);

  @override
  State<TenantAgreementCard> createState() => _TenantAgreementCardState();
}

class _TenantAgreementCardState extends State<TenantAgreementCard> {
  String? _agreementUrl;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadAgreementUrl();
  }

  Future<void> _loadAgreementUrl() async {
    setState(() => _isLoading = true);
    try {
      final url = await widget.backendService.getPropertyAgreementUrl(widget.propertyId); // ⭐
      setState(() {
        _agreementUrl = url;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadAgreement() async {
    try {
      // Step 1: Pick PDF or image file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      if (pickedFile.path == null) return;

      // Step 2: Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.upload_file, color: Colors.blue),
              SizedBox(width: 2.w),
              Text('Upload Agreement', style: TextStyle(fontSize: 14.sp)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Selected file:'),
              SizedBox(height: 1.h),
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.insert_drive_file, color: Colors.blue, size: 5.w),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        pickedFile.name,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2.h),
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 5.w),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        'Your signed agreement will be saved and visible to your landlord',
                        style: TextStyle(fontSize: 9.sp, color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text('Upload'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() => _isUploading = true);

      // Step 3: Upload to Supabase
      final file = File(pickedFile.path!);
      final uploadedUrl = await SupabaseStorageService.uploadFile(
        file: file,
        folder: 'tenant_agreements',
        customFileName:
        'agreement_${widget.propertyId}_${DateTime.now().millisecondsSinceEpoch}.${pickedFile.extension}',
      );

      print('✅ Uploaded to Supabase: $uploadedUrl');

      // Step 4: Save URL to backend (update property's agreementUrl)
      await _saveAgreementUrlToBackend(uploadedUrl);

      setState(() {
        _agreementUrl = uploadedUrl;
        _isUploading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 2.w),
              Text('Agreement uploaded successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      print('❌ Upload error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveAgreementUrlToBackend(String url) async {
    try {
      final response = await http.put(
        Uri.parse('${widget.baseUrl}/api/properties/${widget.propertyId}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'agreementUrl': url}),
      ).timeout(const Duration(seconds: 15));

      print('📥 Save agreement response: ${response.statusCode}');
      if (response.statusCode != 200) {
        throw Exception('Failed to save URL: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Backend save error: $e');
      throw e;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 5.w,
              height: 5.w,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 3.w),
            Text('Loading agreement...', style: TextStyle(fontSize: 10.sp)),
          ],
        ),
      );
    }

    final hasAgreement = _agreementUrl != null && _agreementUrl!.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: hasAgreement ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasAgreement ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Icon(
                Icons.description,
                color: hasAgreement ? Colors.green.shade700 : Colors.orange.shade700,
                size: 6.w,
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rental Agreement',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: hasAgreement
                            ? Colors.green.shade900
                            : Colors.orange.shade900,
                      ),
                    ),
                    Text(
                      hasAgreement
                          ? 'Signed agreement on file'
                          : 'Upload your physically signed agreement',
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: hasAgreement
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasAgreement)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 4.w),
                      SizedBox(width: 1.w),
                      Text(
                        'Uploaded',
                        style: TextStyle(
                          fontSize: 8.sp,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          SizedBox(height: 2.h),

          // Action Buttons
          if (_isUploading)
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: Colors.white,
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
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    'Uploading to secure storage...',
                    style: TextStyle(fontSize: 10.sp, color: Colors.blue),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                // Download button (only if agreement exists)
                if (hasAgreement)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(_agreementUrl!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: Icon(Icons.download, size: 4.w),
                      label: Text('View', style: TextStyle(fontSize: 10.sp)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 1.2.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),

                if (hasAgreement) SizedBox(width: 2.w),

                // Upload / Re-upload button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _uploadAgreement,
                    icon: Icon(
                      hasAgreement ? Icons.upload : Icons.upload_file,
                      size: 4.w,
                    ),
                    label: Text(
                      hasAgreement ? 'Re-upload' : 'Upload Agreement',
                      style: TextStyle(fontSize: 10.sp),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasAgreement ? Colors.orange : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 1.2.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),

          // Info hint
          if (!hasAgreement) ...[
            SizedBox(height: 1.5.h),
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 4.w),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      'Accepted formats: PDF, JPG, PNG',
                      style: TextStyle(
                        fontSize: 8.sp,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}