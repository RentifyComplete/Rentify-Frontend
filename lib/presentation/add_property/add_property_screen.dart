import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import '../../providers/user_provider.dart';
import '../Owner_dashboard/property_payment_screen.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final AuthService _authService = AuthService();

  List<File> _propertyImages = [];

  // Property type selection
  String _selectedPropertyType = 'Flat';

  // For PG
  int _numberOfBeds = 1;
  int _numberOfRooms = 1;

  // For Flat
  String _selectedBHK = '1 BHK';
  final List<String> _bhkOptions = ['1 BHK', '2 BHK', '3 BHK', '4 BHK', '5+ BHK'];

  // Form controllers
  final TextEditingController _propertyNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();
  final TextEditingController _rentController = TextEditingController();

  // Selected amenities
  final Map<String, bool> _amenities = {
    'WiFi': false,
    'Parking': false,
    'Air Conditioning': false,
    'Heating': false,
    'Kitchen': false,
    'Washing Machine': false,
    'TV': false,
    'Gym': false,
    'Swimming Pool': false,
    'Garden': false,
    'Balcony': false,
    'Pet Friendly': false,
  };

  bool _isSubmitting = false;

  @override
  void dispose() {
    _propertyNameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _rentController.dispose();
    _cleanupImages();
    super.dispose();
  }

  void _cleanupImages() async {
    for (var file in _propertyImages) {
      try {
        if (await file.exists()) {
          await file.delete();
          print('🗑️ Cleanup on dispose: ${file.path}');
        }
      } catch (e) {
        print('⚠️ Could not delete temp file on dispose: $e');
      }
    }
  }

  Future<void> _pickImages() async {
    if (_propertyImages.length >= 10) {
      _showSnackBar('Maximum 10 images allowed', Colors.orange);
      return;
    }

    try {
      final List<XFile> pickedImages = await _picker.pickMultiImage();
      if (pickedImages.isEmpty) return;

      print('📸 Picked ${pickedImages.length} images, copying to persistent storage...');

      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/property_images_temp');

      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      List<File> newPersistentFiles = [];

      for (int i = 0; i < pickedImages.length; i++) {
        final xfile = pickedImages[i];
        final originalFile = File(xfile.path);

        if (await originalFile.exists()) {
          final extension = path.extension(xfile.path);
          final newFileName = 'temp_${timestamp}_${_propertyImages.length + i}$extension';
          final newPath = '${imagesDir.path}/$newFileName';
          final copiedFile = await originalFile.copy(newPath);
          newPersistentFiles.add(copiedFile);
          print('✅ Copied: ${xfile.name} -> $newFileName');
        } else {
          print('⚠️ File not found: ${xfile.path}');
        }
      }

      if (newPersistentFiles.isNotEmpty) {
        setState(() {
          int remainingSlots = 10 - _propertyImages.length;
          _propertyImages.addAll(newPersistentFiles.take(remainingSlots));
        });
        print('✅ Added ${newPersistentFiles.length} images to list (total: ${_propertyImages.length})');
        _showSnackBar('${newPersistentFiles.length} image(s) added', Colors.green);
      } else {
        _showSnackBar('Failed to add images', Colors.red);
      }
    } catch (e) {
      print('❌ Error picking images: $e');
      _showSnackBar('Error picking images: $e', Colors.red);
    }
  }

  void _removeImage(int index) async {
    final fileToDelete = _propertyImages[index];
    setState(() {
      _propertyImages.removeAt(index);
    });

    try {
      if (await fileToDelete.exists()) {
        await fileToDelete.delete();
        print('🗑️ Deleted: ${fileToDelete.path}');
      }
    } catch (e) {
      print('⚠️ Could not delete file: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitProperty() async {
    print('🔵 Submit property button clicked');

    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation FAILED');
      _showSnackBar('Please fill all required fields', Colors.red);
      return;
    }

    if (_propertyImages.isEmpty) {
      print('❌ No images selected');
      _showSnackBar('Please add at least one property image', Colors.red);
      return;
    }

    print('✅ Form validation passed');

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = await _authService.getCurrentUserId();

      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('User not logged in. Please login again.');
      }

      print('👤 Current Owner ID: $currentUserId');

      print('🔍 Verifying ${_propertyImages.length} images...');
      for (var img in _propertyImages) {
        if (!await img.exists()) {
          throw Exception('Image file missing. Please re-add images.');
        }
      }
      print('✅ All images verified and ready');

      List<String> selectedAmenities = _amenities.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      // ⭐⭐⭐ CRITICAL PAYMENT CALCULATION LOGIC ⭐⭐⭐
      // For PG properties:
      // - 'rooms' = Total number of rooms (INFORMATIONAL ONLY - shown in UI)
      // - 'beds' = Total number of beds (USED FOR PAYMENT CALCULATION)
      // - Payment formula: beds × ₹18 per month
      // 
      // For Flat properties:
      // - 'bhk' = Number of bedrooms (e.g., "2 BHK")
      // - Payment formula: Extract number from bhk × ₹18 per month
      //   Example: "2 BHK" → 2 × ₹18 = ₹36

      print('');
      print('⭐⭐⭐ PROPERTY DATA PREPARATION ⭐⭐⭐');
      print('Property Type: $_selectedPropertyType');
      
      if (_selectedPropertyType == 'PG') {
        print('🏠 Rooms (informational): $_numberOfRooms');
        print('🛏️ Beds (for payment): $_numberOfBeds');
        print('💰 Payment calculation: $_numberOfBeds beds × ₹18 = ₹${_numberOfBeds * 18}');
      } else {
        print('🏢 BHK: $_selectedBHK');
        final bhkNumber = int.tryParse(_selectedBHK.split(' ')[0]) ?? 1;
        print('💰 Payment calculation: $bhkNumber × ₹18 = ₹${bhkNumber * 18}');
      }
      print('⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐');
      print('');

      final propertyData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': _propertyNameController.text.trim(),
        'price': '₹${_rentController.text.trim()}',
        'location': '${_cityController.text.trim()}, ${_stateController.text.trim()}',
        'description': _descriptionController.text.trim(),
        'ownerId': currentUserId,
        'type': _selectedPropertyType,
        'bhk': _selectedPropertyType == 'Flat' ? _selectedBHK : null,
        'beds': _selectedPropertyType == 'PG' ? _numberOfBeds : null,   // ⭐ PAYMENT CALCULATION
        'rooms': _selectedPropertyType == 'PG' ? _numberOfRooms : null, // ⭐ INFORMATIONAL ONLY
        'amenities': selectedAmenities,
        'images': _propertyImages,
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'zipCode': _zipCodeController.text.trim(),
      };

      print('✅ Property data prepared for payment screen');

      print('🚀 Navigating to PropertyPaymentScreen...');

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PropertyPaymentScreen(
            propertyData: propertyData,
            paymentMode: 'initial', // Initial property upload
          ),
        ),
      );

      print('📥 Returned from payment screen: $result');

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        if (result == true) {
          print('✅ Payment successful! Property added.');
          print('🧹 Cleaning up temporary images...');
          for (var file in _propertyImages) {
            try {
              if (await file.exists()) {
                await file.delete();
                print('🗑️ Deleted: ${file.path}');
              }
            } catch (e) {
              print('⚠️ Could not delete temp file: $e');
            }
          }
          Navigator.pop(context, true);
        } else {
          print('❌ Payment failed or cancelled');
          _showSnackBar('Payment was not completed', Colors.orange);
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error preparing property: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        _showSnackBar('Error: $e', Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.primaryLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add New Property',
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(4.w),
          children: [
            _buildPropertyTypeSelection(),
            SizedBox(height: 3.h),
            _buildImageSection(),
            SizedBox(height: 3.h),
            _buildPropertyNameField(),
            SizedBox(height: 2.h),
            _buildDescriptionField(),
            SizedBox(height: 2.h),
            _buildRentField(),
            SizedBox(height: 3.h),
            if (_selectedPropertyType == 'PG') ...[
              _buildRoomsSelection(),
              SizedBox(height: 2.h),
              _buildBedsSelection(),
              SizedBox(height: 2.h),
              _buildPaymentInfoCard(), // ⭐ NEW: Shows payment calculation
            ] else ...[
              _buildBHKSelection(),
              SizedBox(height: 2.h),
              _buildPaymentInfoCard(), // ⭐ NEW: Shows payment calculation
            ],
            SizedBox(height: 3.h),
            _buildSectionTitle('Location'),
            SizedBox(height: 1.h),
            _buildAddressField(),
            SizedBox(height: 2.h),
            Row(
              children: [
                Expanded(child: _buildCityField()),
                SizedBox(width: 3.w),
                Expanded(child: _buildStateField()),
              ],
            ),
            SizedBox(height: 2.h),
            _buildZipCodeField(),
            SizedBox(height: 3.h),
            _buildSectionTitle('Amenities'),
            SizedBox(height: 1.h),
            _buildAmenitiesGrid(),
            SizedBox(height: 4.h),
            _buildSubmitButton(),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }

  // ⭐ NEW: Payment info card to show calculation
  Widget _buildPaymentInfoCard() {
    int calculatedCharge = 0;
    String breakdown = '';

    if (_selectedPropertyType == 'PG') {
      calculatedCharge = _numberOfBeds * 18;
      breakdown = '$_numberOfBeds beds × ₹18 = ₹$calculatedCharge/month';
    } else {
      final bhkNumber = int.tryParse(_selectedBHK.split(' ')[0]) ?? 1;
      calculatedCharge = bhkNumber * 18;
      breakdown = '$bhkNumber BHK × ₹18 = ₹$calculatedCharge/month';
    }

    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 6.w),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Service Charge',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  breakdown,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Property Type *'),
        SizedBox(height: 1.h),
        Row(
          children: [
            Expanded(
              child: _buildPropertyTypeCard('Flat', Icons.apartment, _selectedPropertyType == 'Flat'),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: _buildPropertyTypeCard('PG', Icons.meeting_room, _selectedPropertyType == 'PG'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPropertyTypeCard(String type, IconData icon, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPropertyType = type;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 4.w),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLight.withOpacity(0.1) : AppTheme.lightTheme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryLight : AppTheme.borderLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 10.w,
              color: isSelected ? AppTheme.primaryLight : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: 1.h),
            Text(
              type,
              style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppTheme.primaryLight : AppTheme.lightTheme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Property Images * (Max 10)'),
        SizedBox(height: 1.h),
        Text(
          '${_propertyImages.length}/10 images',
          style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
            color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 2.h),
        if (_propertyImages.isNotEmpty)
          SizedBox(
            height: 20.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _propertyImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: 40.w,
                      margin: EdgeInsets.only(right: 3.w),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(_propertyImages[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 1.h,
                      right: 4.w,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: EdgeInsets.all(1.w),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close, color: Colors.white, size: 5.w),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        SizedBox(height: 2.h),
        ElevatedButton.icon(
          onPressed: _pickImages,
          icon: Icon(Icons.add_photo_alternate),
          label: Text('Add Images'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryLight,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 6.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyNameField() {
    return TextFormField(
      controller: _propertyNameController,
      decoration: InputDecoration(
        labelText: 'Property Name *',
        hintText: 'e.g., Cozy 2BHK Apartment',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter property name';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: 'Description *',
        hintText: 'Describe your property...',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter description';
        }
        return null;
      },
    );
  }

  Widget _buildRentField() {
    return TextFormField(
      controller: _rentController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Monthly Rent (₹) *',
        hintText: 'e.g., 15000',
        prefixText: '₹ ',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter monthly rent';
        }
        if (int.tryParse(value.trim()) == null) {
          return 'Please enter a valid number';
        }
        return null;
      },
    );
  }

  Widget _buildRoomsSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionTitle('Number of Rooms *'),
            SizedBox(width: 2.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Info only',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 1.h),
        Row(
          children: [
            IconButton(
              onPressed: () {
                if (_numberOfRooms > 1) {
                  setState(() => _numberOfRooms--);
                }
              },
              icon: Icon(Icons.remove_circle_outline),
              color: AppTheme.primaryLight,
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_numberOfRooms',
                style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() => _numberOfRooms++);
              },
              icon: Icon(Icons.add_circle_outline),
              color: AppTheme.primaryLight,
            ),
            SizedBox(width: 2.w),
            Text(
              'Room${_numberOfRooms > 1 ? 's' : ''}',
              style: AppTheme.lightTheme.textTheme.bodyLarge,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBedsSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionTitle('Number of Beds *'),
            SizedBox(width: 2.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'For payment',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 1.h),
        Row(
          children: [
            IconButton(
              onPressed: () {
                if (_numberOfBeds > 1) {
                  setState(() => _numberOfBeds--);
                }
              },
              icon: Icon(Icons.remove_circle_outline),
              color: AppTheme.primaryLight,
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_numberOfBeds',
                style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() => _numberOfBeds++);
              },
              icon: Icon(Icons.add_circle_outline),
              color: AppTheme.primaryLight,
            ),
            SizedBox(width: 2.w),
            Text(
              'Bed${_numberOfBeds > 1 ? 's' : ''}',
              style: AppTheme.lightTheme.textTheme.bodyLarge,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBHKSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('BHK Type *'),
        SizedBox(height: 1.h),
        Wrap(
          spacing: 2.w,
          runSpacing: 1.h,
          children: _bhkOptions.map((bhk) {
            final isSelected = _selectedBHK == bhk;
            return ChoiceChip(
              label: Text(bhk),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedBHK = bhk);
                }
              },
              selectedColor: AppTheme.primaryLight,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.lightTheme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAddressField() {
    return TextFormField(
      controller: _addressController,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: 'Street Address *',
        hintText: 'e.g., 123 Main Street',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter address';
        }
        return null;
      },
    );
  }

  Widget _buildCityField() {
    return TextFormField(
      controller: _cityController,
      decoration: InputDecoration(
        labelText: 'City *',
        hintText: 'e.g., Mumbai',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter city';
        }
        return null;
      },
    );
  }

  Widget _buildStateField() {
    return TextFormField(
      controller: _stateController,
      decoration: InputDecoration(
        labelText: 'State *',
        hintText: 'e.g., Maharashtra',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter state';
        }
        return null;
      },
    );
  }

  Widget _buildZipCodeField() {
    return TextFormField(
      controller: _zipCodeController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'ZIP Code *',
        hintText: 'e.g., 400001',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter ZIP code';
        }
        return null;
      },
    );
  }

  Widget _buildAmenitiesGrid() {
    return Wrap(
      spacing: 2.w,
      runSpacing: 1.h,
      children: _amenities.keys.map((amenity) {
        return FilterChip(
          label: Text(amenity),
          selected: _amenities[amenity]!,
          onSelected: (selected) {
            setState(() => _amenities[amenity] = selected);
          },
          selectedColor: AppTheme.primaryLight.withOpacity(0.2),
          checkmarkColor: AppTheme.primaryLight,
          labelStyle: TextStyle(
            color: _amenities[amenity]! ? AppTheme.primaryLight : AppTheme.lightTheme.colorScheme.onSurface,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : _submitProperty,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryLight,
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, 7.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: _isSubmitting
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 5.w,
                  height: 5.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 3.w),
            Text('Processing...'),
          ],
        )
      : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, size: 6.w),
            SizedBox(width: 2.w),
            Text(
              'Proceed to Payment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
);
}
}