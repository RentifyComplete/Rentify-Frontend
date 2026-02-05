import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class DocumentUploadWidget extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final Function(Map<String, dynamic>) onDataChanged;
  final VoidCallback onNext;

  const DocumentUploadWidget({
    super.key,
    required this.bookingData,
    required this.onDataChanged,
    required this.onNext,
  });

  @override
  State<DocumentUploadWidget> createState() => _DocumentUploadWidgetState();
}

class _DocumentUploadWidgetState extends State<DocumentUploadWidget> {
  List<Map<String, dynamic>> _uploadedDocuments = [];

  final List<Map<String, dynamic>> _requiredDocuments = [
    {
      "id": "id_proof",
      "title": "Government ID Proof",
      "description": "Aadhaar Card, Passport, or Driving License",
      "icon": "badge",
      "required": true,
      "uploaded": false,
    },
    {
      "id": "address_proof",
      "title": "Address Proof",
      "description": "Utility bill or bank statement",
      "icon": "home",
      "required": true,
      "uploaded": false,
    },
    {
      "id": "employment_proof",
      "title": "Employment Proof",
      "description": "Salary slip or employment letter",
      "icon": "work",
      "required": true,
      "uploaded": false,
    },
    {
      "id": "photo",
      "title": "Recent Photograph",
      "description": "Passport size photo",
      "icon": "photo_camera",
      "required": false,
      "uploaded": false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _uploadedDocuments = List.from(widget.bookingData["documents"] ?? []);
    _updateDocumentStatus();
  }

  void _updateDocumentStatus() {
    for (var doc in _requiredDocuments) {
      doc["uploaded"] =
          _uploadedDocuments.any((uploaded) => uploaded["type"] == doc["id"]);
    }
  }

  void _simulateDocumentUpload(Map<String, dynamic> documentType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: AppTheme.lightTheme.colorScheme.primary,
            ),
            SizedBox(height: 2.h),
            Text(
              'Uploading ${documentType["title"]}...',
              style: AppTheme.lightTheme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    // Simulate upload delay
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pop();

      setState(() {
        _uploadedDocuments
            .removeWhere((doc) => doc["type"] == documentType["id"]);
        _uploadedDocuments.add({
          "type": documentType["id"],
          "title": documentType["title"],
          "fileName":
              "${documentType["id"]}_${DateTime.now().millisecondsSinceEpoch}.pdf",
          "uploadDate": DateTime.now(),
          "size": "2.3 MB",
        });
        _updateDocumentStatus();
      });

      widget.onDataChanged({"documents": _uploadedDocuments});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${documentType["title"]} uploaded successfully'),
          backgroundColor: AppTheme.successLight,
        ),
      );
    });
  }

  void _removeDocument(String documentId) {
    setState(() {
      _uploadedDocuments.removeWhere((doc) => doc["type"] == documentId);
      _updateDocumentStatus();
    });
    widget.onDataChanged({"documents": _uploadedDocuments});
  }

  bool _canProceed() {
    return _requiredDocuments
        .where((doc) => doc["required"] as bool)
        .every((doc) => doc["uploaded"] as bool);
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
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 1.h),

          Text(
            'Upload required documents for verification',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
          ),

          SizedBox(height: 3.h),

          // Upload Progress
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.primary
                  .withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.primary
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: 'upload_file',
                  color: AppTheme.lightTheme.colorScheme.primary,
                  size: 24,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Progress',
                        style:
                            AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${_uploadedDocuments.length} of ${_requiredDocuments.where((doc) => doc["required"] as bool).length} required documents uploaded',
                        style:
                            AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                          color:
                              AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: _canProceed()
                        ? AppTheme.successLight.withValues(alpha: 0.1)
                        : AppTheme.lightTheme.colorScheme.tertiary
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _canProceed() ? 'Complete' : 'Pending',
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: _canProceed()
                          ? AppTheme.successLight
                          : AppTheme.lightTheme.colorScheme.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 3.h),

          // Document List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _requiredDocuments.length,
            separatorBuilder: (context, index) => SizedBox(height: 2.h),
            itemBuilder: (context, index) {
              final document = _requiredDocuments[index];
              return _buildDocumentCard(document);
            },
          ),

          SizedBox(height: 3.h),

          // Upload Guidelines
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.tertiary
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.tertiary
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'info',
                      color: AppTheme.lightTheme.colorScheme.tertiary,
                      size: 20,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Upload Guidelines',
                      style:
                          AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.lightTheme.colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  '• Documents should be clear and readable\n• Accepted formats: PDF, JPG, PNG\n• Maximum file size: 5MB per document\n• All personal information should be visible\n• Documents will be verified within 24 hours',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 4.h),

          // Continue Button
          SizedBox(
            width: double.infinity,
            height: 6.h,
            child: ElevatedButton(
              onPressed: _canProceed() ? widget.onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canProceed()
                    ? AppTheme.lightTheme.colorScheme.primary
                    : AppTheme.lightTheme.colorScheme.outline,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue',
                    style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                      color: _canProceed()
                          ? AppTheme.lightTheme.colorScheme.onPrimary
                          : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  CustomIconWidget(
                    iconName: 'arrow_forward',
                    color: _canProceed()
                        ? AppTheme.lightTheme.colorScheme.onPrimary
                        : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> document) {
    final bool isUploaded = document["uploaded"] as bool;
    final bool isRequired = document["required"] as bool;

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUploaded
              ? AppTheme.successLight.withValues(alpha: 0.3)
              : AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.3),
          width: isUploaded ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: isUploaded
                      ? AppTheme.successLight.withValues(alpha: 0.1)
                      : AppTheme.lightTheme.colorScheme.primary
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CustomIconWidget(
                  iconName: document["icon"] as String,
                  color: isUploaded
                      ? AppTheme.successLight
                      : AppTheme.lightTheme.colorScheme.primary,
                  size: 20,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            document["title"] as String,
                            style: AppTheme.lightTheme.textTheme.titleMedium
                                ?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isRequired) ...[
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 2.w, vertical: 0.5.h),
                            decoration: BoxDecoration(
                              color: AppTheme.lightTheme.colorScheme.error
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Required',
                              style: AppTheme.lightTheme.textTheme.bodySmall
                                  ?.copyWith(
                                color: AppTheme.lightTheme.colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      document["description"] as String,
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          if (isUploaded) ...[
            // Show uploaded document info
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: AppTheme.successLight.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'check_circle',
                    color: AppTheme.successLight,
                    size: 16,
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Document uploaded successfully',
                          style:
                              AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.successLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_uploadedDocuments
                            .any((doc) => doc["type"] == document["id"])) ...[
                          Text(
                            _uploadedDocuments.firstWhere((doc) =>
                                doc["type"] == document["id"])["fileName"],
                            style: AppTheme.lightTheme.textTheme.bodySmall
                                ?.copyWith(
                              color: AppTheme
                                  .lightTheme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _removeDocument(document["id"]),
                    child: Text(
                      'Remove',
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Show upload button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _simulateDocumentUpload(document),
                icon: CustomIconWidget(
                  iconName: 'upload',
                  color: AppTheme.lightTheme.colorScheme.primary,
                  size: 16,
                ),
                label: Text('Upload Document'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
