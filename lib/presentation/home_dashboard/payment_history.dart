// lib/presentation/home_dashboard/payment_history_screen.dart
// ⭐ UPDATED: Uses real payment data from backend API
// Removes/hides sections when no data is available

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_export.dart';
import '../../providers/user_provider.dart';

// ─── pubspec.yaml additions ───────────────────────────────────────────────────
//   pdf: ^3.10.8
//   path_provider: ^2.1.2
//   share_plus: ^7.2.2
// ─────────────────────────────────────────────────────────────────────────────

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({Key? key}) : super(key: key);

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All';
  final String baseUrl = 'https://rentify-backend-cdaj.onrender.com';

  // ⭐ Real data from API
  List<Map<String, dynamic>> _allPayments = [];
  bool _isLoading = true;
  String? _errorMessage;

  // ⭐ NEW: track which receipts are currently being generated
  final Set<String> _generatingReceipts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPaymentHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ⭐ Load payment history from backend
  Future<void> _loadPaymentHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final tenantEmail = userProvider.userEmail;

      if (tenantEmail == null || tenantEmail.isEmpty) {
        print('⚠️ No tenant email found');
        setState(() {
          _isLoading = false;
          _errorMessage = 'User email not found';
        });
        return;
      }

      // ⭐ Convert to lowercase for case-insensitive matching
      final emailLower = tenantEmail.trim().toLowerCase();

      print('🔍 Loading payment history for: $tenantEmail');

      final response = await http.get(
        Uri.parse('$baseUrl/api/payments/tenant/$tenantEmail'),
      ).timeout(const Duration(seconds: 30));

      print('📥 Payment History Response: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          _allPayments = List<Map<String, dynamic>>.from(
              (data['payments'] ?? []).map((payment) {
                return {
                  'id': payment['_id'] ?? payment['id'] ?? 'N/A',
                  'amount': _parseToInt(payment['amount'], 0),
                  'date': payment['date'] ?? payment['createdAt'] ?? DateTime.now().toIso8601String(),
                  'status': _parseToString(payment['status'], 'Unknown'),
                  'method': payment['method'] ?? payment['paymentMethod'],
                  'transactionId': payment['transactionId'] ?? payment['razorpayPaymentId'],
                  'month': payment['month'] ?? _formatMonth(payment['date'] ?? payment['createdAt']),
                  'dueDate': payment['dueDate'] ?? payment['date'],
                  'paidOn': payment['paidOn'] ?? payment['date'],
                  'lateFee': _parseToInt(payment['lateFee'], 0),
                  'bookingId': payment['bookingId'],
                  'propertyId': payment['propertyId'],
                  'propertyTitle': payment['propertyTitle'],     // ⭐ for receipt
                  'propertyAddress': payment['propertyAddress'], // ⭐ for receipt
                  'reason': payment['reason'],
                  'addedByOwner': payment['addedByOwner'] ?? false,
                };
              })
          );

          print('✅ Loaded ${_allPayments.length} payment records');
        } else {
          print('⚠️ API returned success: false');
          _allPayments = [];
        }
      } else if (response.statusCode == 404) {
        print('⚠️ Payment history endpoint not found (404)');
        _allPayments = [];
      } else {
        print('❌ Payment API error: ${response.statusCode}');
        _allPayments = [];
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('❌ Error loading payment history: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
        _allPayments = [];
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  int _parseToInt(dynamic value, int defaultValue) {
    try {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return defaultValue;
        return int.tryParse(trimmed) ?? defaultValue;
      }
      return defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  String _parseToString(dynamic value, String defaultValue) {
    try {
      if (value == null) return defaultValue;
      return value.toString();
    } catch (e) {
      return defaultValue;
    }
  }

  String _formatMonth(String? dateStr) {
    try {
      if (dateStr == null) return 'Unknown';
      final date = DateTime.parse(dateStr);
      return DateFormat('MMMM yyyy').format(date);
    } catch (e) {
      return 'Unknown';
    }
  }

  List<Map<String, dynamic>> _getFilteredPayments(String filter) {
    if (filter == 'All') return _allPayments;
    return _allPayments.where((payment) => payment['status'] == filter).toList();
  }

  Map<String, dynamic> _calculateStats() {
    final paidPayments = _allPayments
        .where((p) => p['status'] == 'Paid' || p['status'] == 'paid')
        .toList();
    final totalPaid = paidPayments.fold<int>(0, (sum, p) => sum + (p['amount'] as int));
    final totalLateFees = paidPayments.fold<int>(0, (sum, p) => sum + (p['lateFee'] as int));

    return {
      'totalPaid': totalPaid,
      'totalPayments': paidPayments.length,
      'totalLateFees': totalLateFees,
      'onTimePayments': paidPayments.where((p) => p['lateFee'] == 0).length,
    };
  }

  // =========================================================================
  // ⭐ NEW: Fetch full booking details for receipt (tenant + owner info)
  // Uses GET /api/bookings/tenant/:email  — already exists in your backend
  // =========================================================================
  Future<Map<String, dynamic>> _fetchBookingDetails(String? bookingId, String? tenantEmail) async {
    try {
      if (tenantEmail == null || tenantEmail.isEmpty) return {};

      final response = await http.get(
        Uri.parse('$baseUrl/api/bookings/tenant/$tenantEmail'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final bookings = data['bookings'] as List? ?? [];

        // Find the matching booking
        Map<String, dynamic>? match;
        if (bookingId != null && bookingId.isNotEmpty) {
          match = bookings.firstWhere(
                (b) => b['_id']?.toString() == bookingId,
            orElse: () => bookings.isNotEmpty ? bookings.first : {},
          );
        } else if (bookings.isNotEmpty) {
          match = bookings.first;
        }

        if (match != null && match.isNotEmpty) {
          return {
            'tenantName': match['tenantName'] ?? '',
            'tenantPhone': match['tenantPhone'] ?? '',
            'tenantEmail': match['tenantEmail'] ?? tenantEmail,
            'ownerName': match['ownerName'] ?? '',
            'propertyTitle': match['propertyTitle'] ?? '',
            'propertyAddress': match['propertyAddress'] ?? '',
            'monthlyRent': match['monthlyRent'] ?? 0,
          };
        }
      }
    } catch (e) {
      print('⚠️ Could not fetch booking details for receipt: $e');
    }
    return {};
  }

  // =========================================================================
  // ⭐ NEW: Generate & share PDF receipt
  // =========================================================================
  Future<void> _downloadReceipt(Map<String, dynamic> payment) async {
    final paymentId = payment['id']?.toString() ?? '';
    if (_generatingReceipts.contains(paymentId)) return;

    setState(() => _generatingReceipts.add(paymentId));

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final tenantEmail = userProvider.userEmail ?? '';

      // ── Fetch richer booking details (tenantName, ownerName, phone…) ──
      final booking = await _fetchBookingDetails(
        payment['bookingId']?.toString(),
        tenantEmail,
      );

      // ── Resolve field values — prefer booking > payment > fallback ──────
      final propertyTitle = (booking['propertyTitle']?.toString().isNotEmpty == true
          ? booking['propertyTitle']
          : payment['propertyTitle']?.toString().isNotEmpty == true
          ? payment['propertyTitle']
          : 'Property')
          .toString();

      final propertyAddress =
      (booking['propertyAddress']?.toString().isNotEmpty == true
          ? booking['propertyAddress']
          : payment['propertyAddress'] ?? '')
          .toString();

      final tenantName = booking['tenantName']?.toString() ?? '';
      final tenantPhone = booking['tenantPhone']?.toString() ?? '';
      final resolvedEmail = booking['tenantEmail']?.toString().isNotEmpty == true
          ? booking['tenantEmail'].toString()
          : tenantEmail;
      final ownerName = booking['ownerName']?.toString() ?? '';

      final amount = (payment['amount'] as num?)?.toInt() ?? 0;
      final lateFee = (payment['lateFee'] as num?)?.toInt() ?? 0;
      final grandTotal = amount + lateFee;
      final monthLabel = payment['month']?.toString() ?? '—';
      final payMethod = payment['method']?.toString() ?? 'Online';
      final receiptNo = payment['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();
      final transactionId = payment['transactionId']?.toString() ?? '';
      final reason = payment['reason']?.toString() ?? '';
      final isPending =
      (payment['status']?.toString().toLowerCase() == 'pending');
      final fmt = NumberFormat('#,##,###');

      String timestamp = '—';
      if (payment['paidOn'] != null) {
        try {
          timestamp = DateFormat('dd MMM yyyy | HH:mm:ss')
              .format(DateTime.parse(payment['paidOn'].toString()));
        } catch (_) {}
      }

      // ── Colours ───────────────────────────────────────────────────────
      final headerBlue = PdfColor.fromHex('#1A3A8F');
      final accentBlue = PdfColor.fromHex('#2756C5');
      final tableGrey  = PdfColor.fromHex('#F2F2F2');
      final borderGrey = PdfColor.fromHex('#DDDDDD');
      final bodyBlack  = PdfColor.fromHex('#1A1A1A');
      final labelGrey  = PdfColor.fromHex('#555555');
      final redAmt     = PdfColor.fromHex('#CC0000');
      final greenAmt   = PdfColor.fromHex('#1A8C1A');
      final bgLight    = PdfColor.fromHex('#F7F7F7');

      // ── Build PDF ─────────────────────────────────────────────────────
      final pdf = pw.Document();

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [

            // ══ 1. BLUE HEADER ════════════════════════════════════════
            pw.Container(
              color: headerBlue,
              padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 44, height: 44,
                    decoration: pw.BoxDecoration(
                        color: PdfColors.white, shape: pw.BoxShape.circle),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      propertyTitle[0].toUpperCase(),
                      style: pw.TextStyle(
                          color: headerBlue, fontSize: 22,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(propertyTitle.toUpperCase(),
                          style: pw.TextStyle(
                              color: PdfColors.white, fontSize: 20,
                              fontWeight: pw.FontWeight.bold)),
                      if (propertyAddress.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(propertyAddress,
                            style: pw.TextStyle(
                                color: PdfColors.white, fontSize: 10)),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ══ 2. BILLED TO / BILLED BY ══════════════════════════════
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Billed To — tenant details
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Billed To',
                            style: pw.TextStyle(color: accentBlue, fontSize: 12,
                                fontWeight: pw.FontWeight.bold)),
                        pw.Container(height: 1, color: borderGrey,
                            margin: const pw.EdgeInsets.symmetric(vertical: 6)),
                        pw.SizedBox(height: 4),
                        if (tenantName.isNotEmpty)
                          _receiptBillRow('Name', tenantName, labelGrey, bodyBlack),
                        if (tenantName.isNotEmpty) pw.SizedBox(height: 5),
                        if (resolvedEmail.isNotEmpty)
                          _receiptBillRow('Email', resolvedEmail, labelGrey, bodyBlack),
                        if (resolvedEmail.isNotEmpty) pw.SizedBox(height: 5),
                        if (tenantPhone.isNotEmpty)
                          _receiptBillRow('Phone', tenantPhone, labelGrey, bodyBlack),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  // Billed By — owner / property details
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Billed By',
                            style: pw.TextStyle(color: accentBlue, fontSize: 12,
                                fontWeight: pw.FontWeight.bold)),
                        pw.Container(height: 1, color: borderGrey,
                            margin: const pw.EdgeInsets.symmetric(vertical: 6)),
                        pw.SizedBox(height: 4),
                        _receiptBillRow('Property', propertyTitle, labelGrey, bodyBlack),
                        if (propertyAddress.isNotEmpty) ...[
                          pw.SizedBox(height: 5),
                          _receiptBillRow('Address', propertyAddress, labelGrey, bodyBlack),
                        ],
                        if (ownerName.isNotEmpty) ...[
                          pw.SizedBox(height: 5),
                          _receiptBillRow('Owner', ownerName, labelGrey, bodyBlack),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ══ 3. RECEIPT NO + TIMESTAMP BAR ═════════════════════════
            pw.Container(
              color: bgLight,
              padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'Receipt No :  ',
                        style: pw.TextStyle(fontSize: 10, color: labelGrey)),
                    pw.TextSpan(text: receiptNo,
                        style: pw.TextStyle(fontSize: 10,
                            fontWeight: pw.FontWeight.bold, color: bodyBlack)),
                  ])),
                  pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'Payment timestamp :  ',
                        style: pw.TextStyle(fontSize: 10, color: labelGrey)),
                    pw.TextSpan(text: timestamp,
                        style: pw.TextStyle(fontSize: 10,
                            fontWeight: pw.FontWeight.bold, color: bodyBlack)),
                  ])),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // ══ 4. PAYMENT TABLE ══════════════════════════════════════
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 28),
              child: pw.Column(children: [

                // Header
                pw.Container(
                  color: tableGrey,
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: pw.Row(children: [
                    pw.Expanded(flex: 4, child: pw.Text('Payment Details',
                        style: pw.TextStyle(fontSize: 10,
                            fontWeight: pw.FontWeight.bold, color: bodyBlack))),
                    pw.Expanded(flex: 2, child: pw.Text('Dues Amount',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 10,
                            fontWeight: pw.FontWeight.bold, color: bodyBlack))),
                    pw.Expanded(flex: 2, child: pw.Text('Paid Amount',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 10,
                            fontWeight: pw.FontWeight.bold, color: bodyBlack))),
                    pw.Expanded(flex: 2, child: pw.Text('Net Balance',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 10,
                            fontWeight: pw.FontWeight.bold, color: bodyBlack))),
                  ]),
                ),

                // Main row
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: borderGrey))),
                  child: pw.Row(children: [
                    pw.Expanded(flex: 4, child: pw.Text(
                        isPending ? 'Due for $monthLabel' : 'Rent for $monthLabel',
                        style: pw.TextStyle(fontSize: 10, color: bodyBlack))),
                    pw.Expanded(flex: 2, child: pw.Text('Rs ${fmt.format(amount)}',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 10,
                            fontWeight: pw.FontWeight.bold, color: redAmt))),
                    pw.Expanded(flex: 2, child: pw.Text(
                        isPending ? 'Rs 0.00' : 'Rs ${fmt.format(amount)}',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: isPending ? labelGrey : greenAmt))),
                    pw.Expanded(flex: 2, child: pw.Text(
                        isPending ? 'Rs ${fmt.format(amount)}' : 'Rs 0.00',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 10, color: bodyBlack))),
                  ]),
                ),

                // Late fee row (only if > 0)
                if (lateFee > 0)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: borderGrey))),
                    child: pw.Row(children: [
                      pw.Expanded(flex: 4, child: pw.Text('Late Fee',
                          style: pw.TextStyle(fontSize: 10, color: bodyBlack))),
                      pw.Expanded(flex: 2, child: pw.Text('Rs ${fmt.format(lateFee)}',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontSize: 10,
                              fontWeight: pw.FontWeight.bold, color: redAmt))),
                      pw.Expanded(flex: 2, child: pw.Text('Rs ${fmt.format(lateFee)}',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontSize: 10,
                              fontWeight: pw.FontWeight.bold, color: greenAmt))),
                      pw.Expanded(flex: 2, child: pw.Text('Rs 0.00',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontSize: 10, color: bodyBlack))),
                    ]),
                  ),

                // Subtotal
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: borderGrey))),
                  child: pw.Row(children: [
                    pw.Expanded(flex: 6, child: pw.Text('Amount paid by tenant',
                        style: pw.TextStyle(fontSize: 10, color: bodyBlack))),
                    pw.Expanded(flex: 4, child: pw.Text(
                        isPending ? 'Rs 0.00' : 'Rs ${fmt.format(grandTotal)}',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 10,
                            fontWeight: pw.FontWeight.bold, color: bodyBlack))),
                  ]),
                ),

                pw.SizedBox(height: 4),

                // Grand total
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: pw.Row(children: [
                    pw.Expanded(flex: 6, child: pw.Text('GRAND TOTAL',
                        style: pw.TextStyle(fontSize: 12,
                            fontWeight: pw.FontWeight.bold, color: bodyBlack))),
                    pw.Expanded(flex: 4, child: pw.Text(
                        'Rs ${fmt.format(grandTotal)}.00',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 15,
                            fontWeight: pw.FontWeight.bold, color: bodyBlack))),
                  ]),
                ),

                pw.SizedBox(height: 8),

                // Payment mode / TXN / Reason
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.RichText(text: pw.TextSpan(children: [
                        pw.TextSpan(text: 'Payment mode :  ',
                            style: pw.TextStyle(fontSize: 10, color: bodyBlack)),
                        pw.TextSpan(text: payMethod,
                            style: pw.TextStyle(fontSize: 10,
                                fontWeight: pw.FontWeight.bold, color: bodyBlack)),
                      ])),
                      if (transactionId.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.RichText(text: pw.TextSpan(children: [
                          pw.TextSpan(text: 'Transaction ID :  ',
                              style: pw.TextStyle(fontSize: 10, color: bodyBlack)),
                          pw.TextSpan(text: transactionId,
                              style: pw.TextStyle(fontSize: 10,
                                  fontWeight: pw.FontWeight.bold, color: bodyBlack)),
                        ])),
                      ],
                      if (reason.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.RichText(text: pw.TextSpan(children: [
                          pw.TextSpan(text: 'Reason :  ',
                              style: pw.TextStyle(fontSize: 10, color: bodyBlack)),
                          pw.TextSpan(text: reason,
                              style: pw.TextStyle(fontSize: 10,
                                  fontWeight: pw.FontWeight.bold, color: bodyBlack)),
                        ])),
                      ],
                    ],
                  ),
                ),
              ]),
            ),

            pw.SizedBox(height: 24),

            // ══ 5. TERMS & CONDITIONS ══════════════════════════════════
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 28),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Terms & Conditions',
                      style: pw.TextStyle(fontSize: 13,
                          fontWeight: pw.FontWeight.bold, color: bodyBlack)),
                  pw.SizedBox(height: 10),
                  _receiptTcPoint(
                    'This is an acknowledge receipt of the payment made by the tenant '
                        'through whatsoever mode of payment for the corresponding services.',
                    labelGrey,
                  ),
                  pw.SizedBox(height: 6),
                  _receiptTcPoint(
                    'In case of failed online payments for whatsoever reason, '
                        'this receipt will be Null & Void.',
                    labelGrey,
                  ),
                  pw.SizedBox(height: 6),
                  _receiptTcPoint(
                    'No refund and/or discounts will ever be entertained against this receipt.',
                    labelGrey,
                  ),
                ],
              ),
            ),
          ],
        ),
      ));

      // ── Save & share ──────────────────────────────────────────────────
      final dir  = await getTemporaryDirectory();
      final safe = propertyTitle
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .replaceAll(' ', '_');
      final file = File('${dir.path}/Receipt_${safe}_$receiptNo.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Payment Receipt - $propertyTitle',
        text: 'Payment receipt for $propertyTitle ($monthLabel).',
      );
    } catch (e) {
      print('❌ Receipt generation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to generate receipt: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _generatingReceipts.remove(paymentId));
    }
  }

  // ── PDF label-value row ──────────────────────────────────────────────────
  pw.Widget _receiptBillRow(
      String label, String value, PdfColor lc, PdfColor vc) =>
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(
            width: 70,
            child: pw.Text(label,
                style: pw.TextStyle(fontSize: 10, color: lc))),
        pw.SizedBox(width: 6),
        pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: vc))),
      ]);

  // ── PDF terms bullet point ───────────────────────────────────────────────
  pw.Widget _receiptTcPoint(String text, PdfColor color) =>
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          width: 14, height: 14,
          margin: const pw.EdgeInsets.only(top: 1, right: 8),
          decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#2756C5'),
              shape: pw.BoxShape.circle),
          alignment: pw.Alignment.center,
          child: pw.Text('v',
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold)),
        ),
        pw.Expanded(
            child: pw.Text(text,
                style: pw.TextStyle(fontSize: 9, color: color))),
      ]);

  // =========================================================================
  // BUILD — everything below is IDENTICAL to original
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.lightTheme;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimaryLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Payment History',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_allPayments.isNotEmpty)
            IconButton(
              icon: Icon(Icons.download, color: primaryColor),
              onPressed: _downloadReport,
            ),
          if (_allPayments.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(Icons.filter_list, color: primaryColor),
              onSelected: (value) {
                setState(() => _selectedFilter = value);
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'All', child: Text('All Payments')),
                PopupMenuItem(value: 'Paid', child: Text('Paid Only')),
                PopupMenuItem(value: 'paid', child: Text('Paid Only')),
                PopupMenuItem(value: 'Pending', child: Text('Pending Only')),
                PopupMenuItem(value: 'pending', child: Text('Pending Only')),
              ],
            ),
        ],
        bottom: _isLoading || _allPayments.isEmpty
            ? null
            : TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          labelStyle: GoogleFonts.poppins(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            Tab(text: 'All (${_allPayments.length})'),
            Tab(text: 'Paid (${_getFilteredPayments('Paid').length + _getFilteredPayments('paid').length})'),
            Tab(text: 'Pending (${_getFilteredPayments('Pending').length + _getFilteredPayments('pending').length})'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryLight),
            SizedBox(height: 2.h),
            Text(
              'Loading payment history...',
              style: GoogleFonts.poppins(fontSize: 11.sp, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 15.w, color: Colors.red),
            SizedBox(height: 2.h),
            Text(
              'Failed to load payment history',
              style: GoogleFonts.poppins(
                  fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.red),
            ),
            SizedBox(height: 1.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: Text(
                _errorMessage!,
                style: GoogleFonts.poppins(fontSize: 10.sp, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 3.h),
            ElevatedButton.icon(
              onPressed: _loadPaymentHistory,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryLight,
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 1.5.h),
              ),
            ),
          ],
        ),
      );
    }

    if (_allPayments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 25.w, color: Colors.grey.shade300),
            SizedBox(height: 3.h),
            Text(
              'No Payment History',
              style: GoogleFonts.poppins(
                  fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            SizedBox(height: 1.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: Text(
                'Your payment history will appear here once you start making rent payments',
                style: GoogleFonts.poppins(
                    fontSize: 10.sp, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 3.h),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back),
              label: Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryLight,
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 1.5.h),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildStatsCard(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPaymentList(_getFilteredPayments('All')),
              _buildPaymentList([
                ..._getFilteredPayments('Paid'),
                ..._getFilteredPayments('paid'),
              ]),
              _buildPaymentList([
                ..._getFilteredPayments('Pending'),
                ..._getFilteredPayments('pending'),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    final stats = _calculateStats();
    final theme = AppTheme.lightTheme;

    if (_allPayments.isEmpty) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.all(4.w),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor,
            theme.primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Total Paid',
                  '₹${NumberFormat('#,##,###').format(stats['totalPaid'])}',
                  Icons.payments),
              Container(width: 1, height: 40, color: Colors.white30),
              _buildStatItem('Payments', '${stats['totalPayments']}',
                  Icons.receipt_long),
            ],
          ),
          SizedBox(height: 2.h),
          Divider(color: Colors.white30),
          SizedBox(height: 1.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('On Time', '${stats['onTimePayments']}',
                  Icons.check_circle),
              Container(width: 1, height: 40, color: Colors.white30),
              _buildStatItem(
                'Late Fees',
                stats['totalLateFees'] > 0
                    ? '₹${NumberFormat('#,##,###').format(stats['totalLateFees'])}'
                    : '₹0',
                Icons.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 5.w),
          SizedBox(height: 0.5.h),
          Text(value,
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
          Text(label,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 9.sp),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildPaymentList(List<Map<String, dynamic>> payments) {
    if (payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 25.w, color: Colors.grey.shade300),
            SizedBox(height: 2.h),
            Text('No Payments Found',
                style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPaymentHistory,
      color: AppTheme.primaryLight,
      child: ListView.builder(
        padding: EdgeInsets.all(4.w),
        itemCount: payments.length,
        itemBuilder: (context, index) {
          final payment = payments[index];
          return _buildPaymentCard(payment);
        },
      ),
    );
  }

  // ── Payment card — original layout preserved, Receipt button added at bottom
  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final isPaid = payment['status']?.toLowerCase() == 'paid';
    final hasLateFee = payment['lateFee'] > 0;
    final paymentId = payment['id']?.toString() ?? '';
    final isGenerating = _generatingReceipts.contains(paymentId);

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPaid
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tappable area → opens details sheet ─────────────────────
            GestureDetector(
              onTap: () => _showPaymentDetails(payment),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header — identical to original
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              payment['month'] ?? 'Payment',
                              style: GoogleFonts.poppins(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimaryLight,
                              ),
                            ),
                            SizedBox(height: 0.5.h),
                            if (payment['dueDate'] != null)
                              Text(
                                'Due: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(payment['dueDate']))}',
                                style: GoogleFonts.poppins(
                                  fontSize: 9.sp,
                                  color: AppTheme.textSecondaryLight,
                                ),
                              ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(payment['status'] ?? 'Unknown'),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Divider(color: Colors.grey.shade200),
                  SizedBox(height: 1.h),

                  // Amount — identical to original
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Amount',
                              style: GoogleFonts.poppins(
                                  fontSize: 9.sp, color: Colors.grey)),
                          Text(
                            '₹${NumberFormat('#,##,###').format(payment['amount'])}',
                            style: GoogleFonts.poppins(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: isPaid ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      if (hasLateFee)
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 2.w, vertical: 0.5.h),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red, width: 1),
                          ),
                          child: Text(
                            'Late Fee: ₹${payment['lateFee']}',
                            style: GoogleFonts.poppins(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 2.h),

                  // Paid details — identical to original
                  if (isPaid) ...[
                    Row(
                      children: [
                        if (payment['method'] != null) ...[
                          Icon(Icons.payment, size: 4.w, color: Colors.grey),
                          SizedBox(width: 2.w),
                          Text(payment['method'],
                              style: GoogleFonts.poppins(
                                  fontSize: 10.sp, color: Colors.grey.shade700)),
                          Spacer(),
                        ],
                        Icon(Icons.check_circle, size: 4.w, color: Colors.green),
                        SizedBox(width: 1.w),
                        if (payment['paidOn'] != null)
                          Text(
                            'Paid on ${DateFormat('MMM dd').format(DateTime.parse(payment['paidOn']))}',
                            style: GoogleFonts.poppins(
                                fontSize: 9.sp, color: Colors.grey),
                          ),
                      ],
                    ),
                  ],

                  // Transaction ID — identical to original
                  if (payment['transactionId'] != null &&
                      payment['transactionId'].toString().isNotEmpty) ...[
                    SizedBox(height: 1.h),
                    Row(
                      children: [
                        Icon(Icons.tag, size: 3.w, color: Colors.grey),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: Text(
                            'TXN: ${payment['transactionId']}',
                            style: GoogleFonts.poppins(
                                fontSize: 8.sp,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Reason — identical to original
                  if (payment['reason'] != null &&
                      payment['reason'].toString().isNotEmpty) ...[
                    SizedBox(height: 1.h),
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 3.5.w, color: Colors.orange.shade700),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: Text(
                            'Reason: ${payment['reason']}',
                            style: GoogleFonts.poppins(
                                fontSize: 9.sp,
                                color: Colors.orange.shade700,
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ── Pay Now — identical to original ────────────────────────
            if (!isPaid) ...[
              SizedBox(height: 2.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _payDue(payment),
                  icon: Icon(Icons.payment, size: 4.w),
                  label: Text(
                    'Pay Now  ₹${NumberFormat('#,##,###').format(payment['amount'])}',
                    style: GoogleFonts.poppins(
                        fontSize: 11.sp, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 1.5.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],

            // ── ⭐ NEW: Receipt button — sits OUTSIDE GestureDetector ──
            SizedBox(height: 1.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isGenerating ? null : () => _downloadReceipt(payment),
                icon: isGenerating
                    ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primaryLight),
                )
                    : Icon(Icons.receipt_long, size: 4.w),
                label: Text(
                  isGenerating ? 'Generating…' : 'Download Receipt',
                  style: GoogleFonts.poppins(
                      fontSize: 10.sp, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryLight,
                  side: BorderSide(color: AppTheme.primaryLight),
                  padding: EdgeInsets.symmetric(vertical: 1.2.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Status badge — identical to original ──────────────────────────────────
  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    IconData icon = Icons.info;
    String displayStatus = status;

    final statusLower = status.toLowerCase();
    if (statusLower == 'paid' || statusLower == 'success' || statusLower == 'completed') {
      color = Colors.green;
      icon = Icons.check_circle;
      displayStatus = 'Paid';
    } else if (statusLower == 'pending' || statusLower == 'processing') {
      color = Colors.orange;
      icon = Icons.schedule;
      displayStatus = 'Pending';
    } else if (statusLower == 'failed' || statusLower == 'cancelled') {
      color = Colors.red;
      icon = Icons.cancel;
      displayStatus = 'Failed';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 3.5.w, color: color),
          SizedBox(width: 1.w),
          Text(displayStatus,
              style: GoogleFonts.poppins(
                  color: color,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Payment details bottom sheet — identical to original ──────────────────
  void _showPaymentDetails(Map<String, dynamic> payment) {
    final isPaid = payment['status']?.toLowerCase() == 'paid';
    final theme = AppTheme.lightTheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 12.w,
                height: 0.5.h,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            SizedBox(height: 3.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Payment Details',
                    style: GoogleFonts.poppins(
                        fontSize: 16.sp, fontWeight: FontWeight.bold)),
                _buildStatusBadge(payment['status'] ?? 'Unknown'),
              ],
            ),
            SizedBox(height: 2.h),

            _buildDetailRow('Payment ID', payment['id'] ?? 'N/A'),
            if (payment['month'] != null)
              _buildDetailRow('Month', payment['month']),
            _buildDetailRow('Amount',
                '₹${NumberFormat('#,##,###').format(payment['amount'])}'),
            if (payment['dueDate'] != null)
              _buildDetailRow('Due Date',
                  DateFormat('MMMM dd, yyyy').format(DateTime.parse(payment['dueDate']))),

            if (isPaid) ...[
              if (payment['paidOn'] != null)
                _buildDetailRow('Paid On',
                    DateFormat('MMMM dd, yyyy').format(DateTime.parse(payment['paidOn']))),
              if (payment['method'] != null)
                _buildDetailRow('Payment Method', payment['method']),
              if (payment['transactionId'] != null &&
                  payment['transactionId'].toString().isNotEmpty)
                _buildDetailRow('Transaction ID', payment['transactionId']),
              if (payment['lateFee'] != null && payment['lateFee'] > 0)
                _buildDetailRow('Late Fee', '₹${payment['lateFee']}',
                    isHighlight: true),
            ],

            SizedBox(height: 3.h),

            // Action buttons — identical to original + receipt button
            Row(
              children: [
                if (isPaid && payment['transactionId'] != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _downloadReceipt(payment);
                      },
                      icon: Icon(Icons.download, size: 4.w),
                      label: Text('Receipt'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.primaryColor,
                        side: BorderSide(color: theme.primaryColor),
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  SizedBox(width: 3.w),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Close'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isHighlight = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(fontSize: 10.sp, color: Colors.grey)),
          SizedBox(width: 4.w),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: isHighlight ? Colors.red : AppTheme.textPrimaryLight),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ── _payDue — identical to original ──────────────────────────────────────
  Future<void> _payDue(Map<String, dynamic> due) async {
    final bookingId = due['bookingId']?.toString();

    if (bookingId == null || bookingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking info missing. Cannot process payment.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.payment, color: Colors.orange.shade600),
            SizedBox(width: 2.w),
            Text('Pay Due', style: TextStyle(fontSize: 14.sp)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amount: ₹${NumberFormat('#,##,###').format(due['amount'])}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
            ),
            if (due['reason'] != null) ...[
              SizedBox(height: 1.h),
              Text('Reason: ${due['reason']}',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 10.sp)),
            ],
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                'Payment will be processed via Razorpay.',
                style: TextStyle(color: Colors.blue.shade700, fontSize: 9.sp),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Pay Now'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.primaryLight),
                SizedBox(height: 2.h),
                Text('Creating payment order...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      final response = await http.post(
        Uri.parse('$baseUrl/api/payments/create-tenant-rent-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bookingId': bookingId,
          'propertyId': due['propertyId'] ?? '',
          'monthsDuration': 1,
          'isDuePayment': true,
          'dueAmount': due['amount'],
          'dueId': due['id'],
        }),
      ).timeout(const Duration(seconds: 30));

      if (Navigator.canPop(context)) Navigator.pop(context);

      if (response.statusCode != 200) {
        throw Exception('Failed to create payment order');
      }

      final orderData = jsonDecode(response.body);
      if (orderData['success'] != true) {
        throw Exception(orderData['message'] ?? 'Order creation failed');
      }

      final razorpay = Razorpay();
      razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS,
              (PaymentSuccessResponse payResponse) async {
            razorpay.clear();
            try {
              await http.post(
                Uri.parse('$baseUrl/api/payments/verify-due-payment'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'razorpay_order_id': payResponse.orderId,
                  'razorpay_payment_id': payResponse.paymentId,
                  'razorpay_signature': payResponse.signature,
                  'bookingId': bookingId,
                  'dueId': due['id'],
                  'amount': due['amount'],
                }),
              );

              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(3.w),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check_circle,
                              color: Colors.green, size: 20.w),
                        ),
                        SizedBox(height: 2.h),
                        Text('Payment Successful!',
                            style: TextStyle(
                                fontSize: 16.sp, fontWeight: FontWeight.bold)),
                        SizedBox(height: 1.h),
                        Text(
                          '₹${NumberFormat('#,##,###').format(due['amount'])}',
                          style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.green),
                        ),
                        SizedBox(height: 2.h),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _loadPaymentHistory();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryLight,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: EdgeInsets.symmetric(vertical: 1.5.h),
                            ),
                            child: Text('Done'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            } catch (e) {
              print('❌ Error verifying due payment: $e');
            }
          });

      razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,
              (PaymentFailureResponse failResponse) {
            razorpay.clear();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Payment failed: ${failResponse.message}'),
                backgroundColor: Colors.red,
              ));
            }
          });

      razorpay.open({
        'key': orderData['key'],
        'amount': (due['amount'] * 100).toInt(),
        'order_id': orderData['orderId'],
        'name': 'Rentify',
        'description': due['reason'] ?? 'Due Payment',
        'prefill': {
          'email': userProvider.userEmail ?? '',
          'contact': '',
          'name': userProvider.userName ?? '',
        },
        'theme': {'color': '#FF9800'},
      });
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      print('❌ Error processing due payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ── _downloadReport — identical to original ───────────────────────────────
  void _downloadReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generating payment report...'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}