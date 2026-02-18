import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/agreement_pdf_service.dart';
import '../../services/auth_service.dart';

class PropertyAgreementHelper {
  final AgreementPdfService _pdfService = AgreementPdfService();
  final AuthService _authService = AuthService();

  // ⭐ SUPABASE CONFIGURATION
  static const String supabaseUrl = 'https://sysgayeogkjjulqkzaee.supabase.co';   // ⭐ REPLACE
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN5c2dheWVvZ2tqanVscWt6YWVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzMTQ3ODQsImV4cCI6MjA4Njg5MDc4NH0.T2NHV4iX7ih2rqzMX35HPeKFSeplKSzDI2PuByXuWGU';                // ⭐ REPLACE
  static const String bucketName = 'rentify-files';                      // ⭐ your bucket name

  /// Generate agreement for a property and upload to Supabase
  Future<String?> generateAndUploadAgreement({
    required String propertyId,
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
    try {
      print('📄 Starting agreement generation for property: $propertyTitle');

      // Step 1: Generate PDF
      print('📝 Generating PDF...');
      final pdfFile = await _pdfService.generateAgreement(
        ownerName: ownerName,
        ownerSignatureUrl: ownerSignatureUrl,
        propertyTitle: propertyTitle,
        propertyAddress: propertyAddress,
        city: city,
        state: state,
        zipCode: zipCode,
        propertyType: propertyType,
        bhkOrBeds: bhkOrBeds,
        monthlyRent: monthlyRent,
        securityDeposit: securityDeposit,
        ownerId: ownerId,
        ownerPanCard: ownerPanCard,
        ownerAadhar: ownerAadhar,
      );

      print('✅ PDF generated: ${pdfFile.path}');

      // Step 2: Upload to Supabase
      print('☁️ Uploading to Supabase...');
      final agreementUrl = await _uploadToSupabase(pdfFile, propertyId);

      if (agreementUrl == null) {
        print('❌ Failed to upload to Supabase');
        return null;
      }

      print('✅ Uploaded to Supabase: $agreementUrl');

      // Step 3: Update property with agreement URL
      print('💾 Updating property with agreement URL...');
      final updated = await _updatePropertyAgreement(propertyId, agreementUrl);

      if (!updated) {
        print('⚠️ Failed to update property with agreement URL');
        return agreementUrl;
      }

      print('✅ Property updated with agreement URL');

      // Step 4: Clean up local file
      try {
        await pdfFile.delete();
        print('🗑️ Local PDF file deleted');
      } catch (e) {
        print('⚠️ Could not delete local file: $e');
      }

      return agreementUrl;
    } catch (e, stackTrace) {
      print('❌ Error generating agreement: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Upload PDF to Supabase Storage
  Future<String?> _uploadToSupabase(File pdfFile, String propertyId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'agreement_${propertyId}_$timestamp.pdf';
      final storagePath = '$fileName'; // or 'agreements/$fileName' if you want a subfolder

      print('📤 Uploading to Supabase Storage...');
      print('   Bucket: $bucketName');
      print('   Path: $storagePath');
      print('   File size: ${await pdfFile.length()} bytes');

      final uploadUrl = Uri.parse(
        '$supabaseUrl/storage/v1/object/$bucketName/$storagePath',
      );

      final bytes = await pdfFile.readAsBytes();

      final response = await http.post(
        uploadUrl,
        headers: {
          'Authorization': 'Bearer $supabaseAnonKey',
          'Content-Type': 'application/pdf',
          'x-upsert': 'true', // overwrite if same name exists
        },
        body: bytes,
      ).timeout(const Duration(seconds: 60));

      print('📥 Supabase Response Status: ${response.statusCode}');
      print('📥 Supabase Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Build the public URL
        final publicUrl =
            '$supabaseUrl/storage/v1/object/public/$bucketName/$storagePath';

        print('✅ PDF uploaded successfully: $publicUrl');
        return publicUrl;
      } else {
        print('❌ Upload failed with status: ${response.statusCode}');
        print('   Body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Error uploading to Supabase: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Update property with agreement URL
  Future<bool> _updatePropertyAgreement(String propertyId, String agreementUrl) async {
    try {
      final url = _authService.getUpdatePropertyUrl(propertyId);
      print('📡 Update URL: $url');

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'agreementUrl': agreementUrl,
        }),
      ).timeout(const Duration(seconds: 30));

      print('📥 Update Response Status: ${response.statusCode}');
      print('📥 Update Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == false) {
          print('❌ Backend returned success: false');
          return false;
        }
        return true;
      } else {
        print('❌ Update failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Error updating property: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Regenerate agreement for an existing property
  Future<String?> regenerateAgreement(Map<String, dynamic> property) async {
    try {
      print('🔄 Regenerating agreement for property: ${property['_id']}');

      final propertyId = property['_id']?.toString() ?? '';
      final propertyTitle = property['title']?.toString() ?? 'Unnamed Property';
      final propertyType = property['type']?.toString() ?? 'Flat';
      final address = property['address']?.toString() ?? '';
      final city = property['city']?.toString() ?? '';
      final state = property['state']?.toString() ?? '';
      final zipCode = property['zipCode']?.toString() ?? '';
      final monthlyRent = (property['monthlyRent'] as num?)?.toDouble() ?? 0;
      final securityDeposit = (property['securityDeposit'] as num?)?.toDouble() ?? 0;
      final ownerId = property['ownerId']?.toString() ?? '';

      String bhkOrBeds;
      if (propertyType == 'PG') {
        final beds = property['beds']?.toString() ?? '1';
        bhkOrBeds = '$beds Beds';
      } else {
        bhkOrBeds = property['bhk']?.toString() ?? '1 BHK';
      }

      final ownerName = property['ownerName']?.toString() ?? 'Property Owner';
      final ownerSignatureUrl = property['ownerSignatureUrl']?.toString() ?? '';
      final ownerPanCard = property['ownerPanCard']?.toString();
      final ownerAadhar = property['ownerAadhar']?.toString();

      return await generateAndUploadAgreement(
        propertyId: propertyId,
        ownerName: ownerName,
        ownerSignatureUrl: ownerSignatureUrl,
        propertyTitle: propertyTitle,
        propertyAddress: address,
        city: city,
        state: state,
        zipCode: zipCode,
        propertyType: propertyType,
        bhkOrBeds: bhkOrBeds,
        monthlyRent: monthlyRent,
        securityDeposit: securityDeposit,
        ownerId: ownerId,
        ownerPanCard: ownerPanCard,
        ownerAadhar: ownerAadhar,
      );
    } catch (e, stackTrace) {
      print('❌ Error regenerating agreement: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
}