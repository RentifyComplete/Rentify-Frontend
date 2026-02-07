import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/agreement_pdf_service.dart';
import '../../services/auth_service.dart';

class PropertyAgreementHelper {
  final AgreementPdfService _pdfService = AgreementPdfService();
  final AuthService _authService = AuthService();

  // ⭐⭐⭐ CLOUDINARY CONFIGURATION - UPDATE THESE VALUES ⭐⭐⭐
  //
  // Option 1: Use your existing Cloudinary config if you already have one
  // Option 2: Create a new unsigned upload preset (see instructions below)
  //
  // TO GET YOUR CLOUDINARY CREDENTIALS:
  // 1. Go to https://cloudinary.com/console
  // 2. Your Cloud Name is shown at the top (e.g., "dxxxxx")
  // 3. Go to Settings → Upload → Upload presets
  // 4. Create an unsigned preset or use an existing one

  static const String cloudName = 'dojen4kyp';  // ⭐ REPLACE THIS
  static const String uploadPreset = 'rental_agreements_unsigned';  // ⭐ REPLACE THIS

  // Alternative: If you want to use signed uploads with API key and secret
  // Uncomment and use these instead:
  // static const String apiKey = 'YOUR_API_KEY';
  // static const String apiSecret = 'YOUR_API_SECRET';

  /// Generate agreement for a property and upload to Cloudinary
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

      // Step 2: Upload to Cloudinary
      print('☁️ Uploading to Cloudinary...');
      final agreementUrl = await _uploadToCloudinary(pdfFile);

      if (agreementUrl == null) {
        print('❌ Failed to upload to Cloudinary');
        return null;
      }

      print('✅ Uploaded to Cloudinary: $agreementUrl');

      // Step 3: Update property with agreement URL
      print('💾 Updating property with agreement URL...');
      final updated = await _updatePropertyAgreement(propertyId, agreementUrl);

      if (!updated) {
        print('⚠️ Failed to update property with agreement URL');
        // Return URL anyway, as the PDF was generated and uploaded successfully
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

  /// Upload PDF to Cloudinary
  Future<String?> _uploadToCloudinary(File pdfFile) async {
    try {
      // Validate configuration
      if (cloudName == 'YOUR_CLOUD_NAME' || uploadPreset == 'YOUR_UPLOAD_PRESET') {
        print('❌ CLOUDINARY NOT CONFIGURED!');
        print('   Please update cloudName and uploadPreset in property_agreement_helper.dart');
        throw Exception('Cloudinary credentials not configured. Please update cloudName and uploadPreset.');
      }

      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/upload');

      var request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'rental_agreements';
      request.fields['resource_type'] = 'raw'; // For PDF files

      // Add the PDF file
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        pdfFile.path,
      ));

      print('📤 Sending request to Cloudinary...');
      print('   Cloud Name: $cloudName');
      print('   Upload Preset: $uploadPreset');
      print('   File Size: ${await pdfFile.length()} bytes');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Cloudinary Response Status: ${response.statusCode}');
      print('📥 Cloudinary Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final secureUrl = data['secure_url'] as String?;

        if (secureUrl != null) {
          print('✅ PDF uploaded successfully: $secureUrl');
          return secureUrl;
        } else {
          print('❌ No secure_url in response');
          return null;
        }
      } else if (response.statusCode == 401) {
        print('❌ CLOUDINARY AUTHENTICATION FAILED');
        print('   This usually means:');
        print('   1. Invalid upload preset name');
        print('   2. Upload preset is not set to "Unsigned"');
        print('   3. Cloud name is incorrect');
        print('   Please check your Cloudinary dashboard settings');
        return null;
      } else {
        print('❌ Upload failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Error uploading to Cloudinary: $e');
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

      // Extract property details
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

      // Determine BHK or Beds
      String bhkOrBeds;
      if (propertyType == 'PG') {
        final beds = property['beds']?.toString() ?? '1';
        bhkOrBeds = '$beds Beds';
      } else {
        bhkOrBeds = property['bhk']?.toString() ?? '1 BHK';
      }

      // Get owner details - you may need to fetch this from AuthService or pass it
      final ownerName = property['ownerName']?.toString() ?? 'Property Owner';
      final ownerSignatureUrl = property['ownerSignatureUrl']?.toString() ?? '';
      final ownerPanCard = property['ownerPanCard']?.toString();
      final ownerAadhar = property['ownerAadhar']?.toString();

      // Generate and upload
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