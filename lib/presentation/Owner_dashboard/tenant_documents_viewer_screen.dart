import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../core/app_export.dart';

class TenantDocumentsViewerScreen extends StatefulWidget {
  final String tenantName;
  final String tenantEmail;
  final Map<String, dynamic> documents;

  const TenantDocumentsViewerScreen({
    Key? key,
    required this.tenantName,
    required this.tenantEmail,
    required this.documents,
  }) : super(key: key);

  @override
  State<TenantDocumentsViewerScreen> createState() =>
      _TenantDocumentsViewerScreenState();
}

class _TenantDocumentsViewerScreenState
    extends State<TenantDocumentsViewerScreen> {
  late Map<String, dynamic> _documents;

  final List<Map<String, dynamic>> _documentTypes = [
    {
      'id': 'id_proof',
      'name': 'ID Proof',
      'icon': Icons.badge,
      'description': 'Aadhaar Card, PAN Card, or Passport',
      'color': Colors.blue,
    },
    {
      'id': 'address_proof',
      'name': 'Address Proof',
      'icon': Icons.home,
      'description': 'Utility bill, Bank statement, or Rental agreement',
      'color': Colors.green,
    },
    {
      'id': 'income_proof',
      'name': 'Income Proof',
      'icon': Icons.receipt,
      'description': 'Salary slips, Bank statements, or ITR',
      'color': Colors.orange,
    },
    {
      'id': 'employment_letter',
      'name': 'Employment Letter',
      'icon': Icons.work,
      'description': 'Letter from employer or HR department',
      'color': Colors.purple,
    },
  ];

  @override
  void initState() {
    super.initState();
    _documents = Map<String, dynamic>.from(widget.documents);
  }

  void _viewDocumentImage(String documentUrl, String documentName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentImageViewerScreen(
          documentUrl: documentUrl,
          documentName: documentName,
        ),
      ),
    );
  }

  void _downloadDocument(String documentUrl, String documentName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.download_done, color: Colors.white),
            SizedBox(width: 2.w),
            Expanded(
              child: Text('Download feature coming soon'),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryLight,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uploadedDocsCount = _documents.values
        .where((v) => v != null && v.toString().isNotEmpty)
        .length;

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryLight,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tenant Documents',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.tenantName,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 4.w),
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                '$uploadedDocsCount/${_documentTypes.length}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tenant Info Card
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 16.w,
                    height: 16.w,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      color: AppTheme.primaryLight,
                      size: 8.w,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.tenantName,
                          style:
                              AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          widget.tenantEmail,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10.sp,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 3.h),

            // Documents Section Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Required Documents',
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (uploadedDocsCount > 0)
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '✓ $uploadedDocsCount Uploaded',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),

            SizedBox(height: 2.h),

            // Documents List
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _documentTypes.length,
              separatorBuilder: (context, index) => SizedBox(height: 2.h),
              itemBuilder: (context, index) {
                final docType = _documentTypes[index];
                final docId = docType['id'] as String;
                final docUrl = _documents[docId]?.toString();
                final isUploaded = docUrl != null && docUrl.isNotEmpty;

                return Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isUploaded
                              ? (docType['color'] as Color).withOpacity(0.3)
                              : Colors.grey.shade200,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
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
                            padding: EdgeInsets.all(3.w),
                            decoration: BoxDecoration(
                              color: isUploaded
                                  ? (docType['color'] as Color).withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              docType['icon'] as IconData,
                              color: isUploaded
                                  ? (docType['color'] as Color)
                                  : Colors.grey.shade600,
                              size: 7.w,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  docType['name'] as String,
                                  style: AppTheme.lightTheme.textTheme
                                      .titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 0.5.h),
                                Text(
                                  docType['description'] as String,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 9.sp,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isUploaded)
                            Icon(
                              Icons.check_circle,
                              color: docType['color'] as Color,
                              size: 6.w,
                            )
                          else
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange,
                              size: 6.w,
                            ),
                        ],
                      ),
                      if (isUploaded) ...[
                        SizedBox(height: 2.h),
                        Divider(),
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _viewDocumentImage(
                                  docUrl,
                                  docType['name'] as String,
                                ),
                                icon: Icon(Icons.visibility),
                                label: Text('View'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (docType['color'] as Color)
                                      .withOpacity(0.1),
                                  foregroundColor:
                                      docType['color'] as Color,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 2.w),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _downloadDocument(
                                  docUrl,
                                  docType['name'] as String,
                                ),
                                icon: Icon(Icons.download),
                                label: Text('Download'),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: (docType['color'] as Color)
                                        .withOpacity(0.5),
                                  ),
                                  foregroundColor:
                                      docType['color'] as Color,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

            SizedBox(height: 3.h),

            // Info Box
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryLight.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.security,
                    color: AppTheme.primaryLight,
                    size: 6.w,
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Document Verification',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryLight,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          'All documents are securely stored and verified',
                          style: TextStyle(
                            fontSize: 9.sp,
                            color: AppTheme.primaryLight.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }
}

// Separate screen for viewing individual document images
class DocumentImageViewerScreen extends StatelessWidget {
  final String documentUrl;
  final String documentName;

  const DocumentImageViewerScreen({
    Key? key,
    required this.documentUrl,
    required this.documentName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            documentUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;

              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
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
                      'Failed to load document',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
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
              style: TextStyle(color: Colors.grey, fontSize: 10.sp),
            ),
          ],
        ),
      ),
    );
  }
}