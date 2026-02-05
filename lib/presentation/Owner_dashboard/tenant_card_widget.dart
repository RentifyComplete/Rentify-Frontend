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

  const TenantCardWidget({
    Key? key,
    required this.tenant,
    required this.onEditRent,
    required this.onDelete,
    required this.onCall,
    required this.onEmail,
  }) : super(key: key);

  /// ⭐ Launch phone dialer
  Future<void> _makePhoneCall(String phoneNumber) async {
    // Clean phone number (remove spaces, dashes, etc.)
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: cleanNumber,
    );
    try {
      print('📞 Attempting to launch: $launchUri');
      await launchUrl(
        launchUri,
        mode: LaunchMode.externalApplication,
      );
      print('✅ Phone dialer launched successfully');
    } catch (e) {
      print('❌ Error launching phone dialer: $e');
    }
  }

  /// ⭐ Launch email client
  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Regarding Your Tenancy', // Optional: Add default subject
    );
    try {
      print('📧 Attempting to launch: $launchUri');
      await launchUrl(
        launchUri,
        mode: LaunchMode.externalApplication,
      );
      print('✅ Email client launched successfully');
    } catch (e) {
      print('❌ Error launching email client: $e');
    }
  }

  /// ⭐ FIXED: Convert camelCase keys to snake_case for viewer compatibility
  Map<String, dynamic> _normalizeDocuments(Map<String, dynamic> docs) {
    final Map<String, dynamic> normalized = {};
    
    // Mapping from camelCase (upload) to snake_case (viewer)
    final Map<String, String> keyMapping = {
      'idProof': 'id_proof',
      'addressProof': 'address_proof',
      'incomeProof': 'income_proof',
      'employmentLetter': 'employment_letter',
      'bankStatement': 'bank_statement',
      'other': 'other',
      // Also support if already in snake_case
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

    print('📋 Normalized documents:');
    print('   Input: $docs');
    print('   Output: $normalized');
    
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    print('═══════════════════════════════════════════════════════');
    print('🔍 TENANT CARD - Building card for: ${tenant['name']}');
    
    final dues = (tenant['pendingDues'] as num? ?? 0).toDouble();
    final underNotice = tenant['underNotice'] as bool? ?? false;
    
    // Get documents from tenant data
    Map<String, dynamic> rawDocuments = {};
    
    if (tenant['documents'] != null) {
      if (tenant['documents'] is Map) {
        rawDocuments = Map<String, dynamic>.from(tenant['documents']);
        print('✅ Found documents: ${rawDocuments.keys.toList()}');
      } else {
        print('⚠️ documents field is not a Map: ${tenant['documents'].runtimeType}');
      }
    } else {
      print('⚠️ No documents field found');
    }
    
    // ⭐ Normalize document keys for viewer compatibility
    final documents = _normalizeDocuments(rawDocuments);
    
    // Count valid documents
    int uploadedDocsCount = 0;
    documents.forEach((key, value) {
      if (value != null) {
        final valueStr = value.toString().trim();
        if (valueStr.isNotEmpty && 
            valueStr != 'null' && 
            valueStr.length > 10 &&
            (valueStr.startsWith('http://') || valueStr.startsWith('https://'))) {
          uploadedDocsCount++;
          print('✅ Valid document "$key": ${valueStr.substring(0, 50)}...');
        } else {
          print('❌ Invalid document "$key": $valueStr');
        }
      }
    });
    
    print('📈 RESULT: $uploadedDocsCount valid documents');
    print('═══════════════════════════════════════════════════════');

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
          // Tenant Header
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
              // Phone Icon - ⭐ UPDATED to launch dialer
              if (tenant['phone'] != null && (tenant['phone'] as String).isNotEmpty)
                IconButton(
                  icon: Icon(Icons.phone, color: Colors.green, size: 5.w),
                  padding: EdgeInsets.all(2.w),
                  constraints: BoxConstraints(),
                  onPressed: () {
                    final phone = tenant['phone'] as String;
                    print('📞 Launching phone dialer for: $phone');
                    _makePhoneCall(phone);
                    onCall(); // Keep original callback if needed
                  },
                ),
              // Email Icon - ⭐ UPDATED to launch email client
              if (tenant['email'] != null && (tenant['email'] as String).isNotEmpty)
                IconButton(
                  icon: Icon(Icons.email, color: Colors.blue, size: 5.w),
                  padding: EdgeInsets.all(2.w),
                  constraints: BoxConstraints(),
                  onPressed: () {
                    final email = tenant['email'] as String;
                    print('📧 Launching email client for: $email');
                    _sendEmail(email);
                    onEmail(); // Keep original callback if needed
                  },
                ),
              // More Menu
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade700, size: 5.w),
                padding: EdgeInsets.all(2.w),
                onSelected: (value) {
                  if (value == 'edit_rent') {
                    onEditRent();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit_rent',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: AppTheme.primaryLight, size: 5.w),
                        SizedBox(width: 2.w),
                        Text(
                          'Edit Rent',
                          style: TextStyle(color: AppTheme.primaryLight),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 5.w),
                        SizedBox(width: 2.w),
                        Text(
                          'Remove Tenant',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 2.h),

          // Property Info
          // Property Info with Room Number & Occupancy
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Property Title
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

                // ⭐ NEW: Room Number & Occupancy Type
                if ((tenant['roomNumber'] != null && tenant['roomNumber'].toString().isNotEmpty) ||
                    (tenant['occupancyType'] != null && tenant['occupancyType'].toString().isNotEmpty)) ...[
                  SizedBox(height: 1.h),
                  Divider(height: 1, color: Colors.grey.shade300),
                  SizedBox(height: 1.h),
                  Row(
                    children: [
                      // Room Number
                      if (tenant['roomNumber'] != null && tenant['roomNumber'].toString().isNotEmpty)
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(1.5.w),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.meeting_room,
                                  color: Colors.blue.shade700,
                                  size: 4.w,
                                ),
                              ),
                              SizedBox(width: 2.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Room',
                                      style: TextStyle(
                                        fontSize: 8.sp,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      tenant['roomNumber'].toString(),
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Spacer if both exist
                      if (tenant['roomNumber'] != null &&
                          tenant['roomNumber'].toString().isNotEmpty &&
                          tenant['occupancyType'] != null &&
                          tenant['occupancyType'].toString().isNotEmpty)
                        SizedBox(width: 3.w),

                      // Occupancy Type
                      if (tenant['occupancyType'] != null && tenant['occupancyType'].toString().isNotEmpty)
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(1.5.w),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.people,
                                  color: Colors.green.shade700,
                                  size: 4.w,
                                ),
                              ),
                              SizedBox(width: 2.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Occupancy',
                                      style: TextStyle(
                                        fontSize: 8.sp,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      tenant['occupancyType'].toString(),
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
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

          // ⭐ FIXED: Documents Section with normalized keys
          InkWell(
            onTap: () {
              print('👆 Documents tapped - Navigating with $uploadedDocsCount documents');
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TenantDocumentsViewerScreen(
                    tenantName: tenant['name'] as String,
                    tenantEmail: tenant['email'] as String,
                    documents: documents, // ⭐ Pass normalized documents
                  ),
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: uploadedDocsCount > 0 
                    ? Colors.blue.shade50 
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: uploadedDocsCount > 0 
                      ? Colors.blue.shade200 
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description,
                    color: uploadedDocsCount > 0 ? Colors.blue : Colors.grey.shade600,
                    size: 5.w,
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          uploadedDocsCount > 0 
                              ? 'Documents: $uploadedDocsCount uploaded'
                              : 'No Documents',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: uploadedDocsCount > 0 
                                ? Colors.blue.shade800 
                                : Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          uploadedDocsCount > 0
                              ? 'Tap to view documents'
                              : 'No documents uploaded yet',
                          style: TextStyle(
                            fontSize: 9.sp,
                            color: uploadedDocsCount > 0
                                ? Colors.blue.shade600
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 4.w,
                    color: uploadedDocsCount > 0 ? Colors.blue : Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          // Pending Dues Section
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

          // Under Notice Section
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

          // Lease Info
          SizedBox(height: 1.h),
          Row(
            children: [
              Icon(Icons.event, color: Colors.grey.shade600, size: 4.w),
              SizedBox(width: 2.w),
              Text(
                'Move-in: ${tenant['moveInDate']}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 9.sp,
                ),
              ),
              Spacer(),
              Text(
                '${tenant['leaseDuration']} months lease',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 9.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}