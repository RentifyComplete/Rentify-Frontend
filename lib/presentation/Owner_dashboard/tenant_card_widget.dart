import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_export.dart';
import 'tenant_documents_viewer_screen.dart';

class TenantCardWidget extends StatelessWidget {
  final Map<String, dynamic> tenant;
  final VoidCallback onEditRent;
  final VoidCallback onDelete;
  final VoidCallback onCall;
  final VoidCallback onEmail;

  // ⭐ NEW: Agreement URL from property
  final String? agreementUrl;

  const TenantCardWidget({
    Key? key,
    required this.tenant,
    required this.onEditRent,
    required this.onDelete,
    required this.onCall,
    required this.onEmail,
    this.agreementUrl, // ⭐ Optional - passed from PeopleScreen
  }) : super(key: key);

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanNumber);
    try {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('❌ Error launching phone dialer: $e');
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Regarding Your Tenancy',
    );
    try {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('❌ Error launching email client: $e');
    }
  }

  // ⭐ Open agreement PDF
  Future<void> _openAgreement(BuildContext context, String url) async {
    try {
      print('📄 Opening agreement: $url');
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch URL');
      }
    } catch (e) {
      print('❌ Error opening agreement: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open agreement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _normalizeDocuments(Map<String, dynamic> docs) {
    final Map<String, dynamic> normalized = {};
    final Map<String, String> keyMapping = {
      'idProof': 'id_proof',
      'addressProof': 'address_proof',
      'incomeProof': 'income_proof',
      'employmentLetter': 'employment_letter',
      'bankStatement': 'bank_statement',
      'other': 'other',
      'id_proof': 'id_proof',
      'address_proof': 'address_proof',
      'income_proof': 'income_proof',
      'employment_letter': 'employment_letter',
      'bank_statement': 'bank_statement',
    };
    docs.forEach((key, value) {
      final normalizedKey = keyMapping[key] ?? key;
      normalized[normalizedKey] = value;
    });
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    final dues = (tenant['pendingDues'] as num? ?? 0).toDouble();
    final underNotice = tenant['underNotice'] as bool? ?? false;

    Map<String, dynamic> rawDocuments = {};
    if (tenant['documents'] != null && tenant['documents'] is Map) {
      rawDocuments = Map<String, dynamic>.from(tenant['documents']);
    }
    final documents = _normalizeDocuments(rawDocuments);

    int uploadedDocsCount = 0;
    documents.forEach((key, value) {
      if (value != null) {
        final valueStr = value.toString().trim();
        if (valueStr.isNotEmpty &&
            valueStr != 'null' &&
            valueStr.length > 10 &&
            (valueStr.startsWith('http://') || valueStr.startsWith('https://'))) {
          uploadedDocsCount++;
        }
      }
    });

    // ⭐ Check if agreement URL is valid
    final hasAgreement = agreementUrl != null &&
        agreementUrl!.isNotEmpty &&
        agreementUrl!.startsWith('http');

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: underNotice ? Colors.orange.shade200 : Colors.grey.shade200,
        ),
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
          // ── Tenant Header ──
          Row(
            children: [
              Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person, color: AppTheme.primaryLight, size: 6.w),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant['name'] as String,
                      style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '₹${tenant['monthlyRent']}/month',
                      style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.primaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (tenant['phone'] != null && (tenant['phone'] as String).isNotEmpty)
                IconButton(
                  icon: Icon(Icons.phone, color: Colors.green, size: 5.w),
                  padding: EdgeInsets.all(2.w),
                  constraints: BoxConstraints(),
                  onPressed: () {
                    _makePhoneCall(tenant['phone'] as String);
                    onCall();
                  },
                ),
              if (tenant['email'] != null && (tenant['email'] as String).isNotEmpty)
                IconButton(
                  icon: Icon(Icons.email, color: Colors.blue, size: 5.w),
                  padding: EdgeInsets.all(2.w),
                  constraints: BoxConstraints(),
                  onPressed: () {
                    _sendEmail(tenant['email'] as String);
                    onEmail();
                  },
                ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade700, size: 5.w),
                padding: EdgeInsets.all(2.w),
                onSelected: (value) {
                  if (value == 'edit_rent') onEditRent();
                  else if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit_rent',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: AppTheme.primaryLight, size: 5.w),
                        SizedBox(width: 2.w),
                        Text('Edit Rent', style: TextStyle(color: AppTheme.primaryLight)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 5.w),
                        SizedBox(width: 2.w),
                        Text('Remove Tenant', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 2.h),

          // ── Property Info ──
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.home, size: 4.w, color: AppTheme.primaryLight),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        tenant['propertyTitle'] as String,
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
                if ((tenant['roomNumber'] != null &&
                    tenant['roomNumber'].toString().isNotEmpty) ||
                    (tenant['occupancyType'] != null &&
                        tenant['occupancyType'].toString().isNotEmpty)) ...[
                  SizedBox(height: 1.h),
                  Divider(height: 1, color: Colors.grey.shade300),
                  SizedBox(height: 1.h),
                  Row(
                    children: [
                      if (tenant['roomNumber'] != null &&
                          tenant['roomNumber'].toString().isNotEmpty)
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(1.5.w),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.meeting_room,
                                    color: Colors.blue.shade700, size: 4.w),
                              ),
                              SizedBox(width: 2.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Room',
                                        style: TextStyle(
                                            fontSize: 8.sp,
                                            color: Colors.grey.shade600)),
                                    Text(
                                      tenant['roomNumber'].toString(),
                                      style: TextStyle(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (tenant['occupancyType'] != null &&
                          tenant['occupancyType'].toString().isNotEmpty)
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(1.5.w),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.people,
                                    color: Colors.green.shade700, size: 4.w),
                              ),
                              SizedBox(width: 2.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Occupancy',
                                        style: TextStyle(
                                            fontSize: 8.sp,
                                            color: Colors.grey.shade600)),
                                    Text(
                                      tenant['occupancyType'].toString(),
                                      style: TextStyle(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 2.h),

          // ⭐⭐⭐ RENTAL AGREEMENT SECTION ⭐⭐⭐
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: hasAgreement ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasAgreement ? Colors.green.shade200 : Colors.orange.shade200,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: hasAgreement
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasAgreement ? Icons.description : Icons.description_outlined,
                    color: hasAgreement ? Colors.green.shade700 : Colors.orange.shade700,
                    size: 6.w,
                  ),
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
                      SizedBox(height: 0.3.h),
                      Text(
                        hasAgreement
                            ? 'Tap to view agreement'
                            : 'No agreement available',
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
                  ElevatedButton.icon(
                    onPressed: () => _openAgreement(context, agreementUrl!),
                    icon: Icon(Icons.open_in_new, size: 4.w),
                    label: Text(
                      'View',
                      style: TextStyle(fontSize: 10.sp),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                          horizontal: 3.w, vertical: 1.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 2.h),

          // ── Documents Button ──
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TenantDocumentsViewerScreen(
                      tenantName: tenant['name'] as String,
                      tenantEmail: tenant['email'] as String,
                      documents: documents,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.5.h),
                decoration: BoxDecoration(
                  gradient: uploadedDocsCount > 0
                      ? LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : LinearGradient(
                    colors: [Colors.grey.shade400, Colors.grey.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: uploadedDocsCount > 0
                      ? [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_outlined, color: Colors.white, size: 6.w),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tenant Documents',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 0.3.h),
                          Text(
                            uploadedDocsCount > 0
                                ? '$uploadedDocsCount document${uploadedDocsCount > 1 ? 's' : ''} uploaded'
                                : 'No documents yet',
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 4.5.w, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),

          // ── Dues ──
          if (dues > 0) ...[
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 4.w),
                  SizedBox(width: 2.w),
                  Text(
                    'Pending Dues: ₹${dues.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Under Notice ──
          if (underNotice) ...[
            SizedBox(height: 1.h),
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.notifications_active, color: Colors.orange, size: 4.w),
                  SizedBox(width: 2.w),
                  Text(
                    'Under Notice Period',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Lease Info ──
          SizedBox(height: 1.h),
          Row(
            children: [
              Icon(Icons.event, color: Colors.grey.shade600, size: 4.w),
              SizedBox(width: 2.w),
              Text(
                'Move-in: ${tenant['moveInDate']}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 9.sp),
              ),
              Spacer(),
              Text(
                '${tenant['leaseDuration']} months lease',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 9.sp),
              ),
            ],
          ),
        ],
      ),
    );
  }
}