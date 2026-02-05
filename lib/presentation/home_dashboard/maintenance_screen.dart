import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import '../../core/app_export.dart';
import '../../services/cloudinary_service.dart';
import '../../services/maintenance_service.dart';
import '../../services/mongodb_service.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

class MaintenanceRequestScreen extends StatefulWidget {
  final String? propertyId;
  final String? tenantId;
  final String? tenantName;
  final String? tenantEmail;
  final String? tenantPhone;

  const MaintenanceRequestScreen({
    Key? key,
    this.propertyId,
    this.tenantId,
    this.tenantName,
    this.tenantEmail,
    this.tenantPhone,
  }) : super(key: key);

  @override
  State<MaintenanceRequestScreen> createState() => _MaintenanceRequestScreenState();
}

class _MaintenanceRequestScreenState extends State<MaintenanceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final CloudinaryService _cloudinaryService = CloudinaryService();
  final MaintenanceService _maintenanceService = MaintenanceService();
  final ImagePicker _picker = ImagePicker();
  final String baseUrl = 'https://rentify-backend-cdaj.onrender.com';

  String _selectedCategory = 'Plumbing';
  String _selectedPriority = 'Medium';
  List<String> _uploadedImages = [];
  bool _isSubmitting = false;
  bool _isLoading = true;
  String? _propertyId;
  String? _tenantId;
  String? _errorMessage;
  Map<String, dynamic>? _activeBooking;

  final List<String> categories = [
    'Plumbing',
    'Electrical',
    'Appliance',
    'Carpentry',
    'Painting',
    'Other',
  ];

  final List<String> priorities = [
    'Low',
    'Medium',
    'High',
    'Emergency',
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // Get user data from provider
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Pre-fill user contact info
      _nameController.text = widget.tenantName ?? userProvider.userName;
      _emailController.text = widget.tenantEmail ?? userProvider.userEmail;
      _phoneController.text = widget.tenantPhone ?? userProvider.userPhone;

      _tenantId = widget.tenantId ?? userProvider.userEmail;

      // If propertyId not provided, fetch from active booking
      if (widget.propertyId == null || widget.propertyId!.isEmpty) {
        print('🔍 Property ID not provided, fetching from active booking...');
        await _fetchActiveBooking();
      } else {
        _propertyId = widget.propertyId;
        print('✅ Property ID provided: $_propertyId');
      }

      setState(() {
        _isLoading = false;
      });

      if (_propertyId == null || _propertyId!.isEmpty) {
        setState(() {
          _errorMessage = 'No active booking found. Please book a property first.';
        });
      }
    } catch (e) {
      print('❌ Error initializing data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load booking information: $e';
      });
    }
  }

  Future<void> _fetchActiveBooking() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final tenantEmail = userProvider.userEmail;

      if (tenantEmail.isEmpty) {
        print('⚠️ No tenant email found');
        return;
      }

      print('🔍 Fetching active booking for: $tenantEmail');

      final response = await http.get(
        Uri.parse('$baseUrl/api/bookings/tenant/$tenantEmail'),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      print('📥 Booking response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && (data['bookings'] as List).isNotEmpty) {
          _activeBooking = data['bookings'].first;
          _propertyId = _activeBooking!['propertyId']?.toString();

          print('✅ Active booking found!');
          print('   Property ID: $_propertyId');
          print('   Property Title: ${_activeBooking!['propertyTitle']}');
        } else {
          print('⚠️ No active bookings found');
          _errorMessage = 'No active booking found. Please book a property first.';
        }
      } else if (response.statusCode == 404) {
        print('⚠️ Booking API returned 404');
        _errorMessage = 'No active booking found. Please book a property first.';
      } else {
        print('❌ API error: ${response.statusCode}');
        _errorMessage = 'Failed to fetch booking information.';
      }
    } catch (e) {
      print('❌ Error fetching booking: $e');
      _errorMessage = 'Failed to fetch booking information: $e';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 3.w),
                Text('Uploading image...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );

        final file = File(image.path);
        final uploadedUrl = await _cloudinaryService.uploadImage(file);

        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (uploadedUrl != null) {
          setState(() {
            _uploadedImages.add(uploadedUrl);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate required data
    if (_propertyId == null || _propertyId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No active booking found. Please book a property first to submit maintenance requests.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_tenantId == null || _tenantId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User information is missing. Please log in and try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _maintenanceService.createMaintenanceRequest(
        propertyId: _propertyId!,
        tenantId: _tenantId!,
        tenantName: _nameController.text.trim(),
        tenantEmail: _emailController.text.trim(),
        tenantPhone: _phoneController.text.trim(),
        category: _selectedCategory,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _selectedPriority,
        imageUrls: _uploadedImages,
        notes: _notesController.text.trim(),
      );

      setState(() {
        _isSubmitting = false;
      });

      if (result != null && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20.w,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  'Request Submitted!',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  'Your maintenance request has been submitted successfully. Our team will contact you soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11.sp,
                  ),
                ),
                SizedBox(height: 3.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryLight,
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit maintenance request. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });

      print('Error submitting maintenance request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppTheme.textPrimaryLight),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Maintenance Request',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryLight),
              SizedBox(height: 2.h),
              Text(
                'Loading your property information...',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Show error state if no property found
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppTheme.textPrimaryLight),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Maintenance Request',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.home_outlined,
                  size: 20.w,
                  color: Colors.grey,
                ),
                SizedBox(height: 3.h),
                Text(
                  'No Active Booking',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 3.h),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.arrow_back),
                  label: Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 1.8.h,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimaryLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Maintenance Request',
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(4.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Property Info (if available)
              if (_activeBooking != null)
                Container(
                  padding: EdgeInsets.all(3.w),
                  margin: EdgeInsets.only(bottom: 3.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryLight.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.home,
                        color: AppTheme.primaryLight,
                        size: 6.w,
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _activeBooking!['propertyTitle'] ?? 'Your Property',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryLight,
                              ),
                            ),
                            if (_activeBooking!['propertyAddress'] != null)
                              Text(
                                _activeBooking!['propertyAddress'],
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Contact Information
              Text(
                'Contact Information',
                style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.h),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Your name',
                  labelText: 'Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 2.h),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'your.email@example.com',
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              SizedBox(height: 2.h),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Your phone number',
                  labelText: 'Phone',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 3.h),

              // Category Selection
              Text(
                'Category',
                style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.h),
              Wrap(
                spacing: 2.w,
                runSpacing: 1.h,
                children: categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    selectedColor: AppTheme.primaryLight,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 3.h),

              // Title
              Text(
                'Issue Title',
                style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.h),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'e.g., Leaking faucet in kitchen',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              SizedBox(height: 3.h),

              // Description
              Text(
                'Description',
                style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.h),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Describe the issue in detail...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              SizedBox(height: 3.h),

              // Priority
              Text(
                'Priority',
                style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.h),
              Row(
                children: priorities.map((priority) {
                  final isSelected = _selectedPriority == priority;
                  Color priorityColor = Colors.grey;

                  if (priority == 'Emergency') priorityColor = Colors.red;
                  if (priority == 'High') priorityColor = Colors.orange;
                  if (priority == 'Medium') priorityColor = Colors.yellow.shade700;
                  if (priority == 'Low') priorityColor = Colors.green;

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: priority != priorities.last ? 2.w : 0),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedPriority = priority;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 1.5.h),
                          decoration: BoxDecoration(
                            color: isSelected ? priorityColor.withOpacity(0.2) : Colors.white,
                            border: Border.all(
                              color: isSelected ? priorityColor : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            priority,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected ? priorityColor : Colors.grey,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 10.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 3.h),

              // Upload Photos
              Text(
                'Photos (Optional)',
                style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.h),
              InkWell(
                onTap: _pickImage,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 4.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppTheme.primaryLight, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, color: AppTheme.primaryLight),
                      SizedBox(width: 2.w),
                      Text(
                        'Add Photos',
                        style: TextStyle(
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 2.h),

              // Display uploaded images
              if (_uploadedImages.isNotEmpty)
                Wrap(
                  spacing: 2.w,
                  runSpacing: 1.h,
                  children: _uploadedImages.map((url) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 20.w,
                            height: 20.w,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _uploadedImages.remove(url);
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.all(1.w),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 4.w,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              SizedBox(height: 3.h),

              // Additional Notes
              Text(
                'Additional Notes (Optional)',
                style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.h),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Any additional information...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              SizedBox(height: 4.h),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    'Submit Request',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}