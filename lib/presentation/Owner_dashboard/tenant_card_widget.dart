import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/app_export.dart';
import 'tenant_documents_viewer_screen.dart';

class TenantCardWidget extends StatelessWidget {
  final Map<String, dynamic> tenant;
  final VoidCallback onEditRent;
  final VoidCallback onDelete;
  final VoidCallback onCall;
  final VoidCallback onEmail;
  final VoidCallback? onDuesUpdated; // ⭐ NEW: callback to refresh parent

  // ⭐ Agreement URL from property
  final String? agreementUrl;

  const TenantCardWidget({
    Key? key,
    required this.tenant,
    required this.onEditRent,
    required this.onDelete,
    required this.onCall,
    required this.onEmail,
    this.agreementUrl,
    this.onDuesUpdated, // ⭐ Optional refresh callback
  }) : super(key: key);

  final String _baseUrl = 'https://rentify-backend-cdaj.onrender.com';

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

  // ⭐⭐⭐ NEW: Show Add Dues Dialog ⭐⭐⭐
  void _showAddDuesDialog(BuildContext context) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    final TextEditingController dueDateController = TextEditingController();
    DateTime? selectedDueDate;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.add_circle_outline,
                      color: Colors.orange.shade700,
                      size: 6.w,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Dues',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          tenant['name'] as String,
                          style: TextStyle(
                            fontSize: 9.sp,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount Field
                    Text(
                      'Amount (₹) *',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g. 5000',
                        prefixIcon: Icon(Icons.currency_rupee, color: AppTheme.primaryLight),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 3.w,
                          vertical: 1.5.h,
                        ),
                      ),
                    ),
                    SizedBox(height: 2.h),

                    // Reason / Description Field
                    Text(
                      'Reason / Description *',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g. Maintenance charges, Water bill, etc.',
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 2.h),
                          child: Icon(Icons.description_outlined, color: AppTheme.primaryLight),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 3.w,
                          vertical: 1.5.h,
                        ),
                      ),
                    ),
                    SizedBox(height: 2.h),

                    // Due Date Field
                    Text(
                      'Due Date',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: AppTheme.primaryLight,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDueDate = picked;
                            dueDateController.text =
                            '${picked.day}/${picked.month}/${picked.year}';
                          });
                        }
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          controller: dueDateController,
                          decoration: InputDecoration(
                            hintText: 'Select due date (optional)',
                            prefixIcon: Icon(Icons.calendar_today, color: AppTheme.primaryLight),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 3.w,
                              vertical: 1.5.h,
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 2.h),

                    // Info banner
                    Container(
                      padding: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 4.w),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: Text(
                              'This due will appear as a Pending payment in the tenant\'s Payment History.',
                              style: TextStyle(
                                fontSize: 9.sp,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                    // Validate inputs
                    final amountText = amountController.text.trim();
                    final reason = reasonController.text.trim();

                    if (amountText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter an amount'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final amount = int.tryParse(amountText);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid amount'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (reason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a reason for the due'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setDialogState(() => isLoading = true);

                    await _submitDues(
                      context: dialogContext,
                      amount: amount,
                      reason: reason,
                      dueDate: selectedDueDate,
                      onSuccess: () {
                        Navigator.pop(dialogContext);
                        onDuesUpdated?.call();
                      },
                      onError: () {
                        setDialogState(() => isLoading = false);
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                  ),
                  child: isLoading
                      ? SizedBox(
                    width: 4.w,
                    height: 4.w,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    'Add Due',
                    style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ⭐⭐⭐ NEW: Submit dues to backend API ⭐⭐⭐
  Future<void> _submitDues({
    required BuildContext context,
    required int amount,
    required String reason,
    DateTime? dueDate,
    required VoidCallback onSuccess,
    required VoidCallback onError,
  }) async {
    try {
      final tenantEmail = tenant['email'] as String? ?? '';
      final tenantName = tenant['name'] as String? ?? '';
      final propertyId = tenant['propertyId'] as String? ?? '';
      final bookingId = tenant['bookingId'] as String? ?? tenant['id'] as String? ?? '';

      print('💳 Adding dues for tenant: $tenantEmail, amount: ₹$amount');

      final body = {
        'tenantEmail': tenantEmail,
        'tenantName': tenantName,
        'amount': amount,
        'reason': reason,
        'status': 'Pending',
        'month': _getCurrentMonthLabel(),
        'dueDate': dueDate?.toIso8601String() ??
            DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        if (propertyId.isNotEmpty) 'propertyId': propertyId,
        if (bookingId.isNotEmpty) 'bookingId': bookingId,
      };

      final response = await http
          .post(
        Uri.parse('$_baseUrl/api/payments/add-dues'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 30));

      print('📥 Add Dues Response: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ Dues added successfully');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '₹$amount due added for ${tenant['name']}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
          onSuccess();
          return;
        }
      }

      // Handle non-success responses
      String errorMsg = 'Failed to add due. Please try again.';
      try {
        final data = jsonDecode(response.body);
        errorMsg = data['message'] ?? errorMsg;
      } catch (_) {}

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      onError();
    } catch (e) {
      print('❌ Error adding dues: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      onError();
    }
  }

  String _getCurrentMonthLabel() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[now.month - 1]} ${now.year}';
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
            offset: const Offset(0, 4),
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
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    _makePhoneCall(tenant['phone'] as String);
                    onCall();
                  },
                ),
              if (tenant['email'] != null && (tenant['email'] as String).isNotEmpty)
                IconButton(
                  icon: Icon(Icons.email, color: Colors.blue, size: 5.w),
                  padding: EdgeInsets.all(2.w),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    _sendEmail(tenant['email'] as String);
                    onEmail();
                  },
                ),
              // ⭐ UPDATED: PopupMenu with Add Dues option
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade700, size: 5.w),
                padding: EdgeInsets.all(2.w),
                onSelected: (value) {
                  if (value == 'edit_rent') {
                    onEditRent();
                  } else if (value == 'delete') {
                    onDelete();
                  } else if (value == 'add_dues') {
                    _showAddDuesDialog(context);
                  }
                },
                itemBuilder: (context) => [
                  // ⭐ NEW: Add Dues option
                  PopupMenuItem(
                    value: 'add_dues',
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline,
                            color: Colors.orange.shade700, size: 5.w),
                        SizedBox(width: 2.w),
                        Text(
                          'Add Dues',
                          style: TextStyle(color: Colors.orange.shade700),
                        ),
                      ],
                    ),
                  ),
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

          // ── RENTAL AGREEMENT SECTION ──
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
                      padding:
                      EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
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
                      offset: const Offset(0, 4),
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
              const Spacer(),
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