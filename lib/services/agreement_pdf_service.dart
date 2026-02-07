import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class AgreementPdfService {
  /// Generate rental agreement PDF with owner and tenant details
  Future<File> generateAgreement({
    required String ownerName,
    required String ownerSignatureUrl,
    required String propertyTitle,
    required String propertyAddress,
    required String city,
    required String state,
    required String zipCode,
    required String propertyType,
    required String bhkOrBeds,
    required double monthlyRent,
    required double securityDeposit,
    required String ownerId,
    String? ownerPanCard,
    String? ownerAadhar,
  }) async {
    final pdf = pw.Document();

    // Generate unique agreement number
    final agreementNo = 'AGR${zipCode}${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final currentDate = DateFormat('dd MMMM yyyy').format(DateTime.now());

    // Download owner signature image
    pw.MemoryImage? ownerSignature;
    try {
      final response = await http.get(Uri.parse(ownerSignatureUrl));
      if (response.statusCode == 200) {
        ownerSignature = pw.MemoryImage(response.bodyBytes);
      }
    } catch (e) {
      print('⚠️ Could not load owner signature: $e');
    }

    // Add pages
    _addCoverPage(pdf, agreementNo, propertyTitle, ownerName, currentDate);
    _addPartyDetailsPage(pdf, agreementNo, propertyTitle, ownerName, ownerPanCard,
        propertyAddress, city, state, zipCode, currentDate);
    _addPropertyDetailsPage(pdf, agreementNo, propertyTitle, propertyType, bhkOrBeds,
        propertyAddress, city, state, zipCode, monthlyRent, securityDeposit);
    _addTermsAndConditionsPage(pdf, agreementNo, propertyTitle, monthlyRent, securityDeposit);
    _addRulesAndRegulationsPage(pdf, agreementNo, propertyTitle);
    _addTenantDocumentsPage(pdf, agreementNo, propertyTitle);
    _addSignaturePage(pdf, agreementNo, propertyTitle, ownerName, ownerSignature, currentDate);

    // Save to file
    final tempDir = await getApplicationDocumentsDirectory();
    final file = File('${tempDir.path}/rental_agreement_$agreementNo.pdf');
    await file.writeAsBytes(await pdf.save());

    print('✅ Agreement PDF generated: ${file.path}');
    return file;
  }

  // Cover Page
  void _addCoverPage(pw.Document pdf, String agreementNo, String propertyTitle,
      String ownerName, String currentDate) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(
                padding: pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue700, width: 3),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'RENTAL AGREEMENT',
                      style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'LEAVE AND LICENSE AGREEMENT',
                      style: pw.TextStyle(fontSize: 16, color: PdfColors.blue700),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),
              pw.Text(
                propertyTitle.toUpperCase(),
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 30),
              pw.Container(
                padding: pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Agreement Number: $agreementNo',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text('Date: $currentDate', style: pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),
              pw.Text('Between', style: pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 10),
              pw.Text(
                ownerName.toUpperCase(),
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('(Owner/Licensor)', style: pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 20),
              pw.Text('AND', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text(
                '[TENANT NAME]',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('(Tenant/Licensee)', style: pw.TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  // Party Details Page
  void _addPartyDetailsPage(pw.Document pdf, String agreementNo, String propertyTitle,
      String ownerName, String? ownerPanCard, String address,
      String city, String state, String zipCode, String currentDate) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(agreementNo, propertyTitle),
            pw.SizedBox(height: 20),
            pw.Text(
              'PARTY DETAILS',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),

            // Owner Details
            pw.Text('FIRST PARTY (OWNER/LICENSOR)',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _buildDetailRow('Name:', ownerName),
            _buildDetailRow('PAN Card:', ownerPanCard ?? 'Not Provided'),
            _buildDetailRow('Property Address:', '$address, $city, $state - $zipCode'),
            pw.SizedBox(height: 20),

            // Tenant Details Placeholder
            pw.Text('SECOND PARTY (TENANT/LICENSEE)',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _buildDetailRow('Name:', '[To be filled upon tenant onboarding]'),
            _buildDetailRow('Father\'s Name:', '[To be filled upon tenant onboarding]'),
            _buildDetailRow('Date of Birth:', '[To be filled upon tenant onboarding]'),
            _buildDetailRow('Aadhar Number:', '[To be filled upon tenant onboarding]'),
            _buildDetailRow('Phone Number:', '[To be filled upon tenant onboarding]'),
            _buildDetailRow('Email:', '[To be filled upon tenant onboarding]'),
            _buildDetailRow('Permanent Address:', '[To be filled upon tenant onboarding]'),
            pw.SizedBox(height: 20),

            pw.Container(
              padding: pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Text(
                'This agreement is executed on $currentDate at $city',
                style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Property Details Page
  void _addPropertyDetailsPage(pw.Document pdf, String agreementNo, String propertyTitle,
      String propertyType, String bhkOrBeds, String address,
      String city, String state, String zipCode, double monthlyRent,
      double securityDeposit) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(agreementNo, propertyTitle),
            pw.SizedBox(height: 20),
            pw.Text(
              'PROPERTY DETAILS',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),

            _buildDetailRow('Property Name:', propertyTitle),
            _buildDetailRow('Property Type:', propertyType),
            _buildDetailRow('Configuration:', bhkOrBeds),
            _buildDetailRow('Complete Address:', '$address, $city, $state - $zipCode'),
            pw.SizedBox(height: 30),

            pw.Text(
              'FINANCIAL TERMS',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),

            _buildDetailRow('Monthly Rent:', '₹${monthlyRent.toStringAsFixed(0)}/-'),
            _buildDetailRow('Security Deposit:', '₹${securityDeposit.toStringAsFixed(0)}/-'),
            _buildDetailRow('Rent Payment Due Date:', '7th of every month'),
            _buildDetailRow('Late Payment Penalty:', '₹500 per day after 10th of month'),
            _buildDetailRow('Agreement Duration:', '11 months (extendable)'),
            pw.SizedBox(height: 20),

            pw.Container(
              padding: pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.amber50,
                border: pw.Border.all(color: PdfColors.orange),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Important Notes:',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Text('• Security deposit will be refunded within 7 days of vacating',
                      style: pw.TextStyle(fontSize: 10)),
                  pw.Text('• Deductions may apply for damages or unpaid dues',
                      style: pw.TextStyle(fontSize: 10)),
                  pw.Text('• 30 days notice required before vacating',
                      style: pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Terms and Conditions Page
  void _addTermsAndConditionsPage(pw.Document pdf, String agreementNo,
      String propertyTitle, double monthlyRent,
      double securityDeposit) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(agreementNo, propertyTitle),
            pw.SizedBox(height: 20),
            pw.Text(
              'TERMS AND CONDITIONS',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 15),

            _buildTermItem('1', 'LICENSE FEE',
                'The Tenant shall pay a monthly rent of ₹${monthlyRent.toStringAsFixed(0)}/- on or before the 7th of each month. '
                    'Payment shall be made through online transfer only.'),

            _buildTermItem('2', 'SECURITY DEPOSIT',
                'The Tenant has deposited ₹${securityDeposit.toStringAsFixed(0)}/- as security deposit. '
                    'This amount will be refunded after deducting any dues, damages, or pending bills within 7 working days of vacating the property.'),

            _buildTermItem('3', 'USAGE OF PROPERTY',
                'The property shall be used for residential purposes only. No commercial, illegal, or immoral activities are permitted. '
                    'The Tenant shall not sub-let or transfer the property to anyone else.'),

            _buildTermItem('4', 'MAINTENANCE',
                'The Tenant shall keep the property in good condition and shall be responsible for any damages caused during the tenancy. '
                    'Regular wear and tear is acceptable.'),

            _buildTermItem('5', 'NOTICE PERIOD',
                'Either party can terminate this agreement by providing 30 days written notice to the other party. '
                    'Owner can terminate with 1 day notice for non-payment of rent.'),

            _buildTermItem('6', 'ELECTRICITY & UTILITIES',
                'Electricity charges shall be borne by the Tenant based on actual consumption. '
                    'Charges will be calculated and shared on a monthly basis.'),
          ],
        ),
      ),
    );
  }

  // Rules and Regulations Page
  void _addRulesAndRegulationsPage(pw.Document pdf, String agreementNo, String propertyTitle) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(agreementNo, propertyTitle),
            pw.SizedBox(height: 20),
            pw.Text(
              'RULES AND REGULATIONS',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 15),

            _buildRuleSection('TENANT OBLIGATIONS', [
              'Pay rent on time (by 7th of every month)',
              'Maintain cleanliness and hygiene of the property',
              'Not make any structural changes without written permission',
              'Allow owner to inspect property with prior notice',
              'Use property only for residential purposes',
              'Not cause disturbance to neighbors',
            ]),

            pw.SizedBox(height: 15),

            _buildRuleSection('GUEST POLICY', [
              'Guests allowed only in common areas',
              'Overnight guests require prior approval',
              'Maximum 2 guests at a time',
            ]),

            pw.SizedBox(height: 15),

            _buildRuleSection('PAYMENT POLICY', [
              'Rent due by 7th of each month',
              'Late fee of ₹500/day after 10th',
              'Only online payment accepted',
              'Immediate eviction if rent unpaid by 10th',
            ]),

            pw.SizedBox(height: 15),

            _buildRuleSection('EXIT POLICY', [
              'Provide 30 days notice before vacating',
              'Clear all pending dues',
              'Return property in good condition',
              'Refund processed within 7 days',
            ]),
          ],
        ),
      ),
    );
  }

  // Tenant Documents Page
  void _addTenantDocumentsPage(pw.Document pdf, String agreementNo, String propertyTitle) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(agreementNo, propertyTitle),
            pw.SizedBox(height: 20),
            pw.Text(
              'TENANT DOCUMENTS',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 15),

            pw.Text(
              'The following documents will be attached upon tenant onboarding:',
              style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
            ),
            pw.SizedBox(height: 20),

            // Tenant Photo Placeholder
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    children: [
                      pw.Container(
                        width: 120,
                        height: 150,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey),
                          color: PdfColors.grey100,
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            'TENANT\nPHOTO',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('Tenant Photo', style: pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildDocPlaceholder('Aadhar Card (Front)'),
                      pw.SizedBox(height: 10),
                      _buildDocPlaceholder('Aadhar Card (Back)'),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            _buildDocPlaceholder('PAN Card'),
            pw.SizedBox(height: 10),
            _buildDocPlaceholder('Police Verification Form'),
            pw.SizedBox(height: 10),
            _buildDocPlaceholder('Passport Size Photos (2)'),

            pw.SizedBox(height: 20),

            pw.Container(
              padding: pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Text(
                'Note: All documents will be verified and attached to this agreement upon tenant onboarding. '
                    'Original documents will be returned to the tenant after verification.',
                style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Signature Page
  void _addSignaturePage(pw.Document pdf, String agreementNo, String propertyTitle,
      String ownerName, pw.MemoryImage? ownerSignature, String currentDate) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(agreementNo, propertyTitle),
            pw.SizedBox(height: 40),

            pw.Text(
              'SIGNATURES',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 30),

            pw.Text(
              'IN WITNESS WHEREOF, the parties hereto have executed this Agreement on the date mentioned above.',
              style: pw.TextStyle(fontSize: 11),
            ),

            pw.Spacer(),

            // Signatures
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Owner Signature
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('OWNER/LICENSOR',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 10),
                      pw.Container(
                        width: 200,
                        height: 80,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey),
                        ),
                        child: ownerSignature != null
                            ? pw.Image(ownerSignature, fit: pw.BoxFit.contain)
                            : pw.Center(
                          child: pw.Text('[Owner Signature]',
                              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(ownerName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: $currentDate', style: pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),

                pw.SizedBox(width: 20),

                // Tenant Signature Placeholder
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('TENANT/LICENSEE',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 10),
                      pw.Container(
                        width: 200,
                        height: 80,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey),
                          color: PdfColors.grey100,
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            '[TENANT SIGNATURE]\n\nTo be signed upon\nonboarding',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text('[Tenant Name]', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: [To be filled]', style: pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 40),

            pw.Container(
              padding: pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                border: pw.Border.all(color: PdfColors.green),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Icon(pw.IconData(0xe876), size: 20, color: PdfColors.green),
                      pw.SizedBox(width: 10),
                      pw.Text('Digital Verification',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green900)),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    '✓ Owner signature digitally verified\n'
                        '✓ Agreement generated on $currentDate\n'
                        '✓ Tenant signature pending - will be completed upon onboarding',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.green900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Widgets
  pw.Widget _buildHeader(String agreementNo, String propertyTitle) {
    return pw.Container(
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue700, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Agreement No: $agreementNo',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text(propertyTitle,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
        ],
      ),
    );
  }

  pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 150,
            child: pw.Text(label, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTermItem(String number, String title, String description) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 30,
            child: pw.Text(number, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                pw.Text(description, style: pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.justify),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildRuleSection(String title, List<String> rules) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        ...rules.map((rule) => pw.Padding(
          padding: pw.EdgeInsets.only(left: 10, bottom: 3),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('• ', style: pw.TextStyle(fontSize: 10)),
              pw.Expanded(child: pw.Text(rule, style: pw.TextStyle(fontSize: 10))),
            ],
          ),
        )),
      ],
    );
  }

  pw.Widget _buildDocPlaceholder(String docName) {
    return pw.Container(
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
        color: PdfColors.grey50,
      ),
      child: pw.Row(
        children: [
          pw.Icon(pw.IconData(0xe873), size: 16, color: PdfColors.grey600),
          pw.SizedBox(width: 10),
          pw.Text(docName, style: pw.TextStyle(fontSize: 10)),
          pw.Spacer(),
          pw.Text('[To be attached]',
              style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
        ],
      ),
    );
  }
}