import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

class BackendService {
  final String baseUrl = 'https://rentify-backend-cdaj.onrender.com';

  // ⭐ FIXED: Changed endpoint from /api/users/ to /api/auth/owner/
  // ⭐ Also handles phone from personalDetails object
  // ⭐ MINIMAL FIX: Just change lines 27-28 to check for 'owner' field
  Future<Map<String, dynamic>> getOwnerDetails(String ownerId) async {
    try {
      print('🔍 Fetching owner details for ID: $ownerId');

      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/owner/$ownerId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 30),
      );

      print('📡 Owner API Response Status: ${response.statusCode}');
      print('📡 Owner API Raw Response: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        
        Map<String, dynamic> ownerData;
        
        // ⭐ FIX: Check for 'owner' field first, then 'data'
        if (jsonResponse is Map && jsonResponse.containsKey('owner')) {
          ownerData = jsonResponse['owner'] as Map<String, dynamic>;
          print('✅ Found owner in response.owner');
        } else if (jsonResponse is Map && jsonResponse.containsKey('data')) {
          ownerData = jsonResponse['data'] as Map<String, dynamic>;
          print('✅ Found owner in response.data');
        } else if (jsonResponse is Map) {
          ownerData = jsonResponse as Map<String, dynamic>;
          print('✅ Using entire response as owner data');
        } else {
          throw Exception('Unexpected response format');
        }

        print('✅ Owner details fetched: ${ownerData['name']}');
        
        // ⭐ Extract phone from various possible fields (order matters!)
        String? phoneNumber = 
          ownerData['phoneNumber'] ??
          ownerData['phone'] ??
          ownerData['mobileNumber'] ??
          ownerData['mobile'] ??
          ownerData['contactNumber'] ??
          ownerData['contact'];
        
        print('📞 Owner phone: $phoneNumber');
        print('📋 Owner Data Fields:');
        ownerData.forEach((key, value) {
          print('   $key: $value');
        });

        // ⭐ Ensure phone is normalized at root level
        if (phoneNumber != null && phoneNumber.isNotEmpty && phoneNumber != 'null') {
          ownerData['phoneNumber'] = phoneNumber;
          ownerData['phone'] = phoneNumber;
        }

        return ownerData;
      } else if (response.statusCode == 404) {
        print('⚠️ Owner not found (404)');
        return {};
      } else {
        print('❌ Failed to fetch owner: ${response.statusCode}');
        print('Response: ${response.body}');
        return {};
      }
    } catch (e) {
      print('❌ Error fetching owner details: $e');
      return {};
    }
  }

  // ⭐ FIXED: Added 'rooms' parameter for PG properties
  Future<Map<String, dynamic>> uploadProperty({
    required String title,
    required String price,
    required String location,
    required String description,
    required String ownerId,
    required String type,
    String? bhk,
    int? beds,
    int? rooms,  // ⭐ ADDED: For PG room count (informational only)
    required List<String> amenities,
    required List<File> images,
    String? address,
    String? city,
    String? state,
    String? zipCode,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/api/properties');
      var request = http.MultipartRequest('POST', uri);

      // Add text fields
      request.fields['title'] = title;
      request.fields['price'] = price;
      request.fields['location'] = location;
      request.fields['description'] = description;
      request.fields['ownerId'] = ownerId;
      request.fields['type'] = type;

      if (bhk != null) request.fields['bhk'] = bhk;
      if (beds != null) request.fields['beds'] = beds.toString();
      if (rooms != null) request.fields['rooms'] = rooms.toString();  // ⭐ ADDED
      if (address != null) request.fields['address'] = address;
      if (city != null) request.fields['city'] = city;
      if (state != null) request.fields['state'] = state;
      if (zipCode != null) request.fields['zipCode'] = zipCode;

      request.fields['amenities'] = jsonEncode(amenities);

      // Add image files with explicit MIME type
      for (var image in images) {
        String fileName = basename(image.path);
        String? mimeType = lookupMimeType(fileName);

        if (mimeType == null || !mimeType.startsWith('image/')) {
          mimeType = 'image/jpeg';
          print('⚠️ Could not determine MIME type for $fileName, using image/jpeg');
        }

        print('📎 Adding image: $fileName (MIME: $mimeType)');

        request.files.add(await http.MultipartFile.fromPath(
          'images',
          image.path,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ));
      }

      print('🔵 Uploading property to backend...');
      print('📤 Total images: ${images.length}');
      if (rooms != null) print('🏠 Rooms (PG): $rooms');
      if (beds != null) print('🛏️ Beds (PG): $beds');

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      print('📥 Response Status: ${response.statusCode}');
      print('📦 Response Body: $responseBody');

      var jsonResponse = jsonDecode(responseBody);

      if (response.statusCode == 201) {
        print('✅ Property uploaded successfully');
        return jsonResponse;
      } else {
        print('❌ Failed to upload: ${jsonResponse['message']}');
        return {
          'success': false,
          'message': jsonResponse['message'] ?? 'Upload failed',
        };
      }
    } catch (e) {
      print('❌ Error uploading property: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  Future<List<Map<String, dynamic>>> getAllProperties() async {
    try {
      print('🔄 Fetching all properties from: $baseUrl/api/properties');

      var response = await http.get(
        Uri.parse('$baseUrl/api/properties'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout - Backend may be waking up from sleep');
        },
      );

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        print('✅ Fetched ${jsonResponse['data'].length} properties');
        return List<Map<String, dynamic>>.from(jsonResponse['data']);
      } else if (response.statusCode == 404) {
        print('❌ 404 Error - Properties endpoint not found');
        print('💡 Backend may not have this route configured');
        throw Exception('Properties API endpoint not found (404). Please check your backend configuration.');
      } else {
        print('❌ Failed to fetch properties: ${response.statusCode}');
        print('📦 Response Body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching properties: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getPropertyById(String propertyId) async {
    try {
      print('🔍 Fetching property by ID: $propertyId');

      final response = await http.get(
        Uri.parse('$baseUrl/api/properties/$propertyId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        Map<String, dynamic> propertyData;

        if (jsonResponse is Map && jsonResponse.containsKey('data')) {
          propertyData = jsonResponse['data'] as Map<String, dynamic>;
        } else if (jsonResponse is Map) {
          propertyData = jsonResponse as Map<String, dynamic>;
        } else {
          throw Exception('Unexpected response format');
        }

        print('✅ Property fetched: ${propertyData['title']}');

        // ⭐ METHOD 1: Try to get phone from property directly
        String? phoneFromProperty = 
          propertyData['ownerPhone']?.toString() ??
          propertyData['phone']?.toString() ??
          propertyData['contactPhone']?.toString() ??
          propertyData['ownerMobile']?.toString();

        if (phoneFromProperty != null && phoneFromProperty.isNotEmpty) {
          propertyData['ownerPhone'] = phoneFromProperty;
          print('✅ Owner phone found in property data: $phoneFromProperty');
          return propertyData;
        }

        // ⭐ METHOD 2: Try to fetch from owner endpoint (if available)
        if (propertyData['ownerId'] != null && propertyData['ownerId'].toString().isNotEmpty) {
          try {
            final ownerDetails = await getOwnerDetails(propertyData['ownerId'].toString());
            
            if (ownerDetails.isNotEmpty) {
              // ⭐ Extract phone from response (backend handles personalDetails extraction)
              String? phoneNumber = 
                ownerDetails['phoneNumber']?.toString() ??
                ownerDetails['phone']?.toString() ??
                ownerDetails['mobileNumber']?.toString() ??
                ownerDetails['mobile']?.toString() ??
                ownerDetails['contactNumber']?.toString() ??
                ownerDetails['contact']?.toString();

              if (phoneNumber != null && phoneNumber.isNotEmpty && phoneNumber != 'null') {
                propertyData['ownerPhone'] = phoneNumber;
                propertyData['ownerName'] = ownerDetails['name'] ?? 'Property Owner';
                print('✅ Owner phone found from user endpoint: $phoneNumber');
                return propertyData;
              } else {
                print('⚠️ Owner details found but no phone field detected');
                print('   Available fields: ${ownerDetails.keys.toList()}');
                propertyData['ownerPhone'] = '';  // Empty string, not null
                propertyData['ownerName'] = ownerDetails['name'] ?? 'Property Owner';
              }
            } else {
              print('⚠️ No owner details returned from endpoint');
              propertyData['ownerPhone'] = '';  // Empty string, not null
            }
          } catch (e) {
            print('⚠️ Error fetching owner details: $e');
            print('   Continuing without owner phone...');
            propertyData['ownerPhone'] = '';  // Empty string, not null
          }
        } else {
          print('⚠️ No owner ID in property data');
          propertyData['ownerPhone'] = '';  // Empty string, not null
        }

        return propertyData;
      } else if (response.statusCode == 404) {
        throw Exception('Property not found');
      } else {
        throw Exception('Failed to fetch property: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching property by ID: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPropertiesByOwner(String ownerId) async {
    try {
      print('🔍 Fetching properties for owner: $ownerId');

      final response = await http.get(
        Uri.parse('$baseUrl/api/properties/owner/$ownerId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        List<Map<String, dynamic>> properties =
        List<Map<String, dynamic>>.from(jsonResponse['data']);
        print('✅ Fetched ${properties.length} properties for owner');
        return properties;
      } else {
        print('❌ Failed to fetch owner properties: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching owner properties: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> updateProperty({
    required String propertyId,
    String? title,
    String? price,
    String? description,
    List<String>? amenities,
    String? address,
    String? city,
    String? state,
  }) async {
    try {
      print('🔄 Updating property: $propertyId');

      Map<String, dynamic> body = {};
      if (title != null) body['title'] = title;
      if (price != null) body['price'] = price;
      if (description != null) body['description'] = description;
      if (amenities != null) body['amenities'] = amenities;
      if (address != null) body['address'] = address;
      if (city != null) body['city'] = city;
      if (state != null) body['state'] = state;

      final response = await http.put(
        Uri.parse('$baseUrl/api/properties/$propertyId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        print('✅ Property updated successfully');
        return jsonResponse;
      } else {
        throw Exception('Failed to update property: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error updating property: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  Future<bool> deleteProperty(String propertyId) async {
    try {
      print('🗑️ Deleting property: $propertyId');

      final response = await http.delete(
        Uri.parse('$baseUrl/api/properties/$propertyId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        print('✅ Property deleted successfully');
        return true;
      } else {
        print('❌ Failed to delete property: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error deleting property: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> searchProperties({
    String? query,
    String? city,
    String? type,
    int? minPrice,
    int? maxPrice,
  }) async {
    try {
      print('🔍 Searching properties...');

      Map<String, String> queryParams = {};
      if (query != null) queryParams['q'] = query;
      if (city != null) queryParams['city'] = city;
      if (type != null) queryParams['type'] = type;
      if (minPrice != null) queryParams['minPrice'] = minPrice.toString();
      if (maxPrice != null) queryParams['maxPrice'] = maxPrice.toString();

      final uri = Uri.parse('$baseUrl/api/properties/search')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        List<Map<String, dynamic>> properties =
        List<Map<String, dynamic>>.from(jsonResponse['data']);
        print('✅ Found ${properties.length} properties');
        return properties;
      } else {
        print('❌ Search failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error searching properties: $e');
      return [];
    }
  }
}