import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
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
    print('🔍 DocumentViewerScreen initialized');
    print('📎 URL: $documentUrl');
    print('📝 Name: $documentName');

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
            icon: Icon(Icons.share, color: Colors.white),
            onPressed: () => _shareDocument(context),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            documentUrl,
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
              
              print('⏳ Loading: ${(progress ?? 0 * 100).toStringAsFixed(0)}%');
              
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
                          : 'Loading document...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              print('❌ Image load error: $error');
              print('📍 Error details: ${error.toString()}');
              print('Stack trace: $stackTrace');

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
                            'Error: ${error.toString()}',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 9.sp,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'URL: $documentUrl',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 8.sp,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 3.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.arrow_back),
                              label: Text('Go Back'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryLight,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _openInBrowser(documentUrl),
                              icon: Icon(Icons.open_in_browser),
                              label: Text('Open in Browser'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: EdgeInsets.symmetric(vertical: 1.h, horizontal: 4.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pinch, color: Colors.grey, size: 5.w),
            SizedBox(width: 2.w),
            Text(
              'Pinch to zoom',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 10.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareDocument(BuildContext context) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Preparing to share...'),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: AppTheme.primaryLight,
        ),
      );

      // Download the image to temporary directory
      final response = await http.get(Uri.parse(documentUrl));
      
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$documentName');
        await file.writeAsBytes(bytes);

        // Share the file
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Sharing: $documentName',
        );

        print('✅ Document shared successfully');
      } else {
        throw Exception('Failed to download document: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error sharing document: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share document. You can try opening in browser.'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () => _openInBrowser(documentUrl),
          ),
        ),
      );
    }
  }

  Future<void> _openInBrowser(String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } else {
        print('❌ Could not launch URL: $url');
      }
    } catch (e) {
      print('❌ Error opening browser: $e');
    }
  }
}