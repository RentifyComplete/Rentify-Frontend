import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import '../../core/app_export.dart';
import '../../services/property_service.dart';
import '../../services/payment_service.dart';
import '../../providers/user_provider.dart';
import 'property_payment_screen.dart';

class EditPropertyScreen extends StatefulWidget {
  final Map<String, dynamic> property;

  const EditPropertyScreen({
    super.key,
    required this.property,
  });

  @override
  State<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends State<EditPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final PropertyService _propertyService = PropertyService();
  final PaymentService _paymentService = PaymentService();

  // Controllers
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _priceController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _zipCodeController;
  late TextEditingController _descriptionController;
  late TextEditingController _bedsController;
  late TextEditingController _bhkController;

  String _selectedType = 'PG';
  bool _isVerified = false;
  bool _isOccupied = false;
  List<String> _selectedAmenities = [];
  bool _isSaving = false;

  // ⭐ STORE ORIGINAL VALUES TO DETECT CHANGES (PG ONLY)
  int _originalBeds = 0;
  String _originalType = '';

  final List<String> _propertyTypes = ['PG', 'Flat']; // Only PG and Flat
  final List<String> _availableAmenities = [
    'WiFi',
    'AC',
    'Parking',
    'Gym',
    'Swimming Pool',
    'Laundry',
    'Security',
    'Power Backup',
    'Lift',
    'Water Supply',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final property = widget.property;

    _titleController = TextEditingController(text: property['title'] ?? '');
    _locationController = TextEditingController(text: property['location'] ?? '');
    _priceController = TextEditingController(
      text: property['price']?.toString().replaceAll('₹', '').replaceAll(',', '') ?? '',
    );
    _addressController = TextEditingController(text: property['address'] ?? '');
    _cityController = TextEditingController(text: property['city'] ?? '');
    _stateController = TextEditingController(text: property['state'] ?? '');
    _zipCodeController = TextEditingController(text: property['zipCode'] ?? '');
    _descriptionController = TextEditingController(text: property['description'] ?? '');
    _bedsController = TextEditingController(text: property['beds']?.toString() ?? '2');
    _bhkController = TextEditingController(text: property['bhk'] ?? '1 BHK');

    _selectedType = property['type'] ?? 'PG';
    _isVerified = property['isVerified'] ?? false;
    _isOccupied = property['isOccupied'] ?? false;

    // ⭐ STORE ORIGINAL VALUES (ONLY FOR PG)
    _originalType = _selectedType;
    _originalBeds = int.tryParse(_bedsController.text) ?? 2;

    if (property['amenities'] != null) {
      _selectedAmenities = List<String>.from(property['amenities']);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _descriptionController.dispose();
    _bedsController.dispose();
    _bhkController.dispose();
    super.dispose();
  }

  // ⭐ CALCULATE ADDITIONAL CHARGE FOR PG BEDS INCREASE ONLY
  Map<String, dynamic> _calculateAdditionalCharge() {
    int additionalCharge = 0;
    int newMonthlyCharge = 0;
    String reason = '';

    // ⭐ ONLY CHECK IF CURRENT TYPE IS PG
    if (_selectedType == 'PG') {
      final newBeds = int.tryParse(_bedsController.text) ?? _originalBeds;

      // ⭐ ONLY CHARGE IF BEDS INCREASED
      if (newBeds > _originalBeds) {
        int additionalBeds = newBeds - _originalBeds;
        additionalCharge = additionalBeds * 18;
        reason = 'Added $additionalBeds bed(s)';
      }

      newMonthlyCharge = newBeds * 18;
    }

    return {
      'additionalCharge': additionalCharge,
      'newMonthlyCharge': newMonthlyCharge,
      'reason': reason,
    };
  }

  // ⭐ SHOW CONFIRMATION DIALOG FOR ADDITIONAL CHARGES
  Future<bool> _showChargeConfirmationDialog(int amount, String reason) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.payment, color: AppTheme.primaryLight),
            SizedBox(width: 2.w),
            Text('Additional Charge Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are increasing the PG capacity:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 1.h),
            Text('• $reason'),
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryLight),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('One-time charge:', style: TextStyle(fontSize: 11.sp)),
                      Text(
                        '₹$amount',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryLight,
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 2.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('New monthly charge:', style: TextStyle(fontSize: 11.sp)),
                      Text(
                        '₹${_calculateAdditionalCharge()['newMonthlyCharge']}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Do you want to proceed with payment?',
              style: TextStyle(
                fontSize: 10.sp,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
            ),
            child: Text('Proceed to Payment'),
          ),
        ],
      ),
    ) ?? false;
  }

  // ⭐ PROCESS ADDITIONAL CHARGE PAYMENT
  Future<bool> _processAdditionalChargePayment(int amount) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final chargeInfo = _calculateAdditionalCharge();

    // Navigate to payment screen
    final paymentResult = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyPaymentScreen(
          propertyData: {
            'title': _titleController.text.trim(),
            'type': _selectedType,
            'beds': int.tryParse(_bedsController.text) ?? 2,
            'bhk': _bhkController.text.trim(),
            'location': _locationController.text.trim(),
            'price': '₹${_priceController.text.trim()}',
            'ownerId': userProvider.userId,
            'propertyId': widget.property['_id'] ?? widget.property['id'],
            'propertyTitle': _titleController.text.trim(),
            'amenities': _selectedAmenities,
            'address': _addressController.text.trim(),
            'city': _cityController.text.trim(),
            'state': _stateController.text.trim(),
            'zipCode': _zipCodeController.text.trim(),
            'description': _descriptionController.text.trim(),
            'images': widget.property['images'] ?? [],
            'additionalCharge': amount, // ⭐ Pass calculated charge
            'newMonthlyCharge': chargeInfo['newMonthlyCharge'], // ⭐ Pass new monthly charge
          },
          paymentMode: 'capacity_increase', // ⭐ NEW PAYMENT MODE
        ),
      ),
    );

    return paymentResult == true;
  }

  Future<void> _saveProperty() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // ⭐ ONLY CHECK FOR CAPACITY INCREASE IF TYPE IS PG
    final chargeInfo = _calculateAdditionalCharge();
    final additionalCharge = chargeInfo['additionalCharge'] as int;

    if (_selectedType == 'PG' && additionalCharge > 0) {
      // Show confirmation dialog
      final confirmed = await _showChargeConfirmationDialog(
        additionalCharge,
        chargeInfo['reason'] as String,
      );

      if (!confirmed) {
        return; // User cancelled
      }

      // Process payment
      final paymentSuccess = await _processAdditionalChargePayment(additionalCharge);

      if (!paymentSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment required to increase number of beds'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return; // Payment failed or cancelled
      }
    }

    // ⭐ PROCEED WITH UPDATE AFTER PAYMENT (OR IF NO ADDITIONAL CHARGE)
    setState(() {
      _isSaving = true;
    });

    try {
      final propertyId = widget.property['_id'] ?? widget.property['id'];

      final updatedProperty = {
        'title': _titleController.text.trim(),
        'location': _locationController.text.trim(),
        'price': '₹${_priceController.text.trim()}',
        'type': _selectedType,
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'zipCode': _zipCodeController.text.trim(),
        'description': _descriptionController.text.trim(),
        'amenities': _selectedAmenities,
        'isVerified': _isVerified,
        'isOccupied': _isOccupied,
        'beds': int.tryParse(_bedsController.text) ?? 2,
        'bhk': _bhkController.text.trim(),
      };

      // ⭐ ONLY UPDATE SERVICE CHARGE FOR PG
      if (_selectedType == 'PG') {
        updatedProperty['monthlyServiceCharge'] = chargeInfo['newMonthlyCharge'];
      }

      print('🔄 Updating property: $propertyId');
      final result = await _propertyService.updateProperty(propertyId, updatedProperty);

      if (!mounted) return;

      if (result['success'] == true) {
        print('✅ Property updated successfully');

        final message = additionalCharge > 0
            ? 'Property updated! Paid ₹$additionalCharge for ${chargeInfo['reason']}.'
            : 'Property updated successfully!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        print('❌ Failed to update: ${result['message']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error updating property: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
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
          'Edit Property',
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
            // ⭐ WARNING BANNER IF PG BEDS INCREASE DETECTED
            if (_selectedType == 'PG' && _calculateAdditionalCharge()['additionalCharge'] > 0)
              Container(
                margin: EdgeInsets.only(bottom: 2.h),
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        'Additional charge of ₹${_calculateAdditionalCharge()['additionalCharge']} will be required for increasing beds',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            _buildTextField(
              controller: _titleController,
              label: 'Property Title',
              icon: Icons.home,
              validator: (value) =>
              value?.isEmpty ?? true ? 'Please enter a title' : null,
            ),
            SizedBox(height: 2.h),
            _buildTextField(
              controller: _locationController,
              label: 'Location',
              icon: Icons.location_on,
              validator: (value) =>
              value?.isEmpty ?? true ? 'Please enter location' : null,
            ),
            SizedBox(height: 2.h),
            _buildTextField(
              controller: _priceController,
              label: 'Monthly Rent (₹)',
              icon: Icons.attach_money,
              keyboardType: TextInputType.number,
              validator: (value) =>
              value?.isEmpty ?? true ? 'Please enter rent amount' : null,
            ),
            SizedBox(height: 2.h),
            _buildDropdown(),
            SizedBox(height: 2.h),

            // ⭐ SHOW BEDS FIELD ONLY FOR PG
            if (_selectedType == 'PG') ...[
              _buildTextField(
                controller: _bedsController,
                label: 'Number of Beds',
                icon: Icons.bed,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter number of beds';
                  final beds = int.tryParse(value!);
                  if (beds == null || beds < 1) return 'Must be at least 1';
                  return null;
                },
              ),
              SizedBox(height: 2.h),
            ],

            // ⭐ SHOW BHK FIELD ONLY FOR FLAT
            if (_selectedType == 'Flat') ...[
              _buildTextField(
                controller: _bhkController,
                label: 'BHK (e.g., 2 BHK)',
                icon: Icons.meeting_room,
                validator: (value) =>
                value?.isEmpty ?? true ? 'Please enter BHK' : null,
              ),
              SizedBox(height: 2.h),
            ],

            _buildTextField(
              controller: _addressController,
              label: 'Address',
              icon: Icons.location_city,
              maxLines: 2,
            ),
            SizedBox(height: 2.h),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _cityController,
                    label: 'City',
                    icon: Icons.location_city,
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: _buildTextField(
                    controller: _stateController,
                    label: 'State',
                    icon: Icons.map,
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            _buildTextField(
              controller: _zipCodeController,
              label: 'ZIP Code',
              icon: Icons.pin_drop,
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 2.h),
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              icon: Icons.description,
              maxLines: 4,
            ),
            SizedBox(height: 2.h),
            _buildAmenitiesSection(),
            SizedBox(height: 2.h),
            _buildSwitchTile(
              title: 'Verified Property',
              value: _isVerified,
              onChanged: (value) => setState(() => _isVerified = value),
              icon: Icons.verified,
            ),
            _buildSwitchTile(
              title: 'Currently Occupied',
              value: _isOccupied,
              onChanged: (value) => setState(() => _isOccupied = value),
              icon: Icons.people,
            ),
            SizedBox(height: 3.h),
            _buildSaveButton(),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      onChanged: (_) {
        // ⭐ REBUILD TO SHOW/HIDE WARNING BANNER (ONLY IF PG)
        if (mounted && _selectedType == 'PG') setState(() {});
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryLight),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedType,
      decoration: InputDecoration(
        labelText: 'Property Type',
        prefixIcon: Icon(Icons.home_work, color: AppTheme.primaryLight),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      items: _propertyTypes.map((type) {
        return DropdownMenuItem(
          value: type,
          child: Text(type),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedType = value;
          });
        }
      },
    );
  }

  Widget _buildAmenitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amenities',
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        Wrap(
          spacing: 2.w,
          runSpacing: 1.h,
          children: _availableAmenities.map((amenity) {
            final isSelected = _selectedAmenities.contains(amenity);
            return FilterChip(
              label: Text(amenity),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedAmenities.add(amenity);
                  } else {
                    _selectedAmenities.remove(amenity);
                  }
                });
              },
              selectedColor: AppTheme.primaryLight.withOpacity(0.2),
              checkmarkColor: AppTheme.primaryLight,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.primaryLight : Colors.grey.shade700,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return Card(
      child: SwitchListTile(
        title: Text(title),
        secondary: Icon(icon, color: AppTheme.primaryLight),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryLight,
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveProperty,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.accentLight,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 2.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isSaving
          ? SizedBox(
        height: 2.5.h,
        width: 2.5.h,
        child: const CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      )
          : Text(
        'Save Changes',
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}