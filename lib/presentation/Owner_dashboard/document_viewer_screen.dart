import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../core/app_export.dart';

class DocumentViewerScreen extends StatelessWidget {
  final String documentUrl;
  final String documentName;

  const DocumentViewerScreen({
    Key? key,
    required this.documentUrl,
    required this.documentName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Extract URL - handle both string and nested map
    String urlToLoad = documentUrl;
    
    if (documentUrl.contains('{') && documentUrl.contains('url')) {
      try {
        final dynamic parsed = json.decode(documentUrl);
        if (parsed is Map<String, dynamic>) {
          urlToLoad = parsed['url']?.toString() ?? documentUrl;
        }
      } catch (e) {
        print('Could not parse URL as JSON, using as-is');
      }
    }
    
    print('🔍 DocumentViewerScreen initialized');
    print('📎 Original URL: $documentUrl');
    print('📎 Processed URL: $urlToLoad');
    print('📝 Name: $documentName');

    // Check if it's an image or PDF
    final isImage = _isImageFile(documentName) || _isImageFile(urlToLoad);
    final isPdf = _isPdfFile(documentName) || _isPdfFile(urlToLoad);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          documentName,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.open_in_browser, color: Colors.white),
            onPressed: () => _openInBrowser(urlToLoad),
            tooltip: 'Open in Browser',
          ),
        ],
      ),
      body: isPdf
          ? _buildPdfViewer(context, urlToLoad)
          : isImage
              ? _buildImageViewer(context, urlToLoad)
              : _buildGenericViewer(context, urlToLoad),
    );
  }

  // Check if file is an image
  bool _isImageFile(String filename) {
    final ext = filename.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.webp') ||
        ext.contains('image/');
  }

  // Check if file is a PDF
  bool _isPdfFile(String filename) {
    final ext = filename.toLowerCase();
    return ext.endsWith('.pdf') || ext.contains('application/pdf');
  }

  // Build PDF viewer with download option
  Widget _buildPdfViewer(BuildContext context, String url) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withOpacity(0.5), width: 2),
                ),
                child: Icon(
                  Icons.picture_as_pdf,
                  color: Colors.red,
                  size: 25.w,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                'PDF Document',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                documentName,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11.sp,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 6.w),
                    SizedBox(height: 1.h),
                    Text(
                      'You can download this PDF document or open it in your browser',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10.sp,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 4.h),
              
              // Download Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _downloadDocument(context, url, documentName),
                  icon: Icon(Icons.download, size: 6.w),
                  label: Text(
                    'Download PDF',
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 2.h),
              
              // Open in Browser Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openInBrowser(url),
                  icon: Icon(Icons.open_in_browser, size: 5.w),
                  label: Text(
                    'Open in Browser',
                    style: TextStyle(fontSize: 11.sp),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white70),
                    padding: EdgeInsets.symmetric(vertical: 1.5.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 2.h),
              
              // Go Back Button
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, size: 5.w),
                label: Text(
                  'Go Back',
                  style: TextStyle(fontSize: 11.sp),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white30),
                  padding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 6.w),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              SizedBox(height: 3.h),
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'URL: $url',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 8.sp,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build image viewer
  Widget _buildImageViewer(BuildContext context, String url) {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              print('✅ Image loaded successfully');
              return child;
            }
            
            final progress = loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null;
            
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    color: Colors.white,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    progress != null
                        ? 'Loading ${(progress * 100).toStringAsFixed(0)}%'
                        : 'Loading image...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('❌ Image load error: $error');
            return _buildErrorView(context, url, error.toString());
          },
        ),
      ),
    );
  }

  // Build generic viewer (for unknown file types)
  Widget _buildGenericViewer(BuildContext context, String url) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.insert_drive_file,
                color: Colors.grey,
                size: 25.w,
              ),
              SizedBox(height: 3.h),
              Text(
                'Document Preview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                documentName,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11.sp,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.h),
              Text(
                'This document type cannot be previewed in the app.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11.sp,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 3.h),
              
              // Download Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _downloadDocument(context, url, documentName),
                  icon: Icon(Icons.download),
                  label: Text('Download Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                  ),
                ),
              ),
              
              SizedBox(height: 2.h),
              
              // Open in Browser Button
              OutlinedButton.icon(
                onPressed: () => _openInBrowser(url),
                icon: Icon(Icons.open_in_browser),
                label: Text('Open in Browser'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white30),
                ),
              ),
              
              SizedBox(height: 2.h),
              
              // Go Back Button
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back),
                label: Text('Go Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white30),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build error view
  Widget _buildErrorView(BuildContext context, String url, String error) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 20.w,
              ),
              SizedBox(height: 2.h),
              Text(
                'Failed to Load Document',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.h),
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  error.contains('401')
                      ? 'Authentication Required\n\nThe document URL requires authorization. Try opening in browser.'
                      : 'Error: $error',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 9.sp,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 3.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back, size: 5.w),
                      label: Text('Go Back'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      ),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openInBrowser(url),
                      icon: Icon(Icons.open_in_browser, size: 5.w),
                      label: Text('Open'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryLight,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'URL: $url',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 8.sp,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openInBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        print('✅ Opened URL in browser: $url');
      } else {
        print('❌ Could not launch URL: $url');
      }
    } catch (e) {
      print('❌ Error opening browser: $e');
    }
  }

  Future<void> _downloadDocument(BuildContext context, String url, String fileName) async {
    try {
      print('📥 Attempting to download: $url');
      
      // On iOS/Android, launch the URL which will trigger download
      final uri = Uri.parse(url);
      
      // Try to launch with download mode
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        print('✅ Download initiated for: $fileName');
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download started! Check your downloads folder.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        print('❌ Could not launch download URL: $url');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start download. Try opening in browser.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error downloading document: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}