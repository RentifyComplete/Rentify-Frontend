import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class PreferenceSettingsWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onDataChanged;
  final Map<String, dynamic> initialData;

  const PreferenceSettingsWidget({
    super.key,
    required this.onDataChanged,
    required this.initialData,
  });

  @override
  State<PreferenceSettingsWidget> createState() =>
      _PreferenceSettingsWidgetState();
}

class _PreferenceSettingsWidgetState extends State<PreferenceSettingsWidget> {
  final TextEditingController _minBudgetController = TextEditingController();
  final TextEditingController _maxBudgetController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  List<String> _selectedPropertyTypes = [];
  List<String> _selectedAmenities = [];
  List<String> _preferredLocations = [];
  String? _selectedOccupancy;
  bool _petsAllowed = false;
  bool _smokingAllowed = false;

  final List<Map<String, dynamic>> _propertyTypes = [
    {'id': 'pg', 'name': 'PG/Hostel', 'icon': 'bed'},
    {'id': 'flat', 'name': 'Flat/Apartment', 'icon': 'apartment'},
    {'id': 'room', 'name': 'Single Room', 'icon': 'meeting_room'},
    {'id': 'studio', 'name': 'Studio', 'icon': 'home'},
  ];

  final List<Map<String, dynamic>> _amenities = [
    {'id': 'wifi', 'name': 'WiFi', 'icon': 'wifi'},
    {'id': 'parking', 'name': 'Parking', 'icon': 'local_parking'},
    {'id': 'gym', 'name': 'Gym', 'icon': 'fitness_center'},
    {'id': 'laundry', 'name': 'Laundry', 'icon': 'local_laundry_service'},
    {'id': 'kitchen', 'name': 'Kitchen', 'icon': 'kitchen'},
    {'id': 'ac', 'name': 'AC', 'icon': 'ac_unit'},
    {'id': 'security', 'name': 'Security', 'icon': 'security'},
    {'id': 'elevator', 'name': 'Elevator', 'icon': 'elevator'},
  ];

  final List<String> _occupancyOptions = [
    'Single Occupancy',
    'Double Occupancy',
    'Triple Occupancy',
    'Any',
  ];

  final List<String> _suggestedLocations = [
    'Koramangala, Bangalore',
    'Gurgaon, Delhi NCR',
    'Bandra, Mumbai',
    'Hitech City, Hyderabad',
    'Whitefield, Bangalore',
    'Noida, Delhi NCR',
    'Andheri, Mumbai',
    'Madhapur, Hyderabad',
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    _minBudgetController.text =
        widget.initialData['minBudget']?.toString() ?? '';
    _maxBudgetController.text =
        widget.initialData['maxBudget']?.toString() ?? '';
    _selectedPropertyTypes =
        List<String>.from(widget.initialData['propertyTypes'] ?? []);
    _selectedAmenities =
        List<String>.from(widget.initialData['amenities'] ?? []);
    _preferredLocations =
        List<String>.from(widget.initialData['locations'] ?? []);
    _selectedOccupancy = widget.initialData['occupancy'];
    _petsAllowed = widget.initialData['petsAllowed'] ?? false;
    _smokingAllowed = widget.initialData['smokingAllowed'] ?? false;
  }

  void _updateData() {
    final data = {
      'propertyTypes': _selectedPropertyTypes,
      'minBudget': double.tryParse(_minBudgetController.text),
      'maxBudget': double.tryParse(_maxBudgetController.text),
      'amenities': _selectedAmenities,
      'locations': _preferredLocations,
      'occupancy': _selectedOccupancy,
      'petsAllowed': _petsAllowed,
      'smokingAllowed': _smokingAllowed,
    };
    widget.onDataChanged(data);
  }

  void _addLocation(String location) {
    if (!_preferredLocations.contains(location)) {
      setState(() {
        _preferredLocations.add(location);
      });
      _updateData();
    }
  }

  void _removeLocation(String location) {
    setState(() {
      _preferredLocations.remove(location);
    });
    _updateData();
  }

  @override
  void dispose() {
    _minBudgetController.dispose();
    _maxBudgetController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferences',
            style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.lightTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Tell us what you\'re looking for to get personalized recommendations',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryLight,
            ),
          ),
          SizedBox(height: 3.h),

          // Property Types
          Text(
            'Property Type',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Wrap(
            spacing: 2.w,
            runSpacing: 1.h,
            children: _propertyTypes.map((type) {
              final isSelected = _selectedPropertyTypes.contains(type['id']);
              return FilterChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomIconWidget(
                      iconName: type['icon'],
                      color: isSelected
                          ? AppTheme.lightTheme.primaryColor
                          : AppTheme.textSecondaryLight,
                      size: 4.w,
                    ),
                    SizedBox(width: 2.w),
                    Text(type['name']),
                  ],
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedPropertyTypes.add(type['id']);
                    } else {
                      _selectedPropertyTypes.remove(type['id']);
                    }
                  });
                  _updateData();
                },
                backgroundColor: AppTheme.borderLight.withValues(alpha: 0.3),
                selectedColor:
                    AppTheme.lightTheme.primaryColor.withValues(alpha: 0.1),
                checkmarkColor: AppTheme.lightTheme.primaryColor,
              );
            }).toList(),
          ),
          SizedBox(height: 3.h),

          // Budget Range
          Text(
            'Budget Range (Monthly)',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _minBudgetController,
                  decoration: InputDecoration(
                    labelText: 'Min Budget',
                    hintText: '5000',
                    prefixText: '₹ ',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Min budget required';
                    }
                    return null;
                  },
                  onChanged: (_) => _updateData(),
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: TextFormField(
                  controller: _maxBudgetController,
                  decoration: InputDecoration(
                    labelText: 'Max Budget',
                    hintText: '25000',
                    prefixText: '₹ ',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Max budget required';
                    }
                    final min = double.tryParse(_minBudgetController.text) ?? 0;
                    final max = double.tryParse(value) ?? 0;
                    if (max <= min) {
                      return 'Max should be > min';
                    }
                    return null;
                  },
                  onChanged: (_) => _updateData(),
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),

          // Occupancy Preference
          Text(
            'Occupancy Preference',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          DropdownButtonFormField<String>(
            value: _selectedOccupancy,
            decoration: InputDecoration(
              hintText: 'Select occupancy preference',
              prefixIcon: Padding(
                padding: EdgeInsets.all(3.w),
                child: CustomIconWidget(
                  iconName: 'people',
                  color: AppTheme.textSecondaryLight,
                  size: 5.w,
                ),
              ),
            ),
            items: _occupancyOptions.map((String occupancy) {
              return DropdownMenuItem<String>(
                value: occupancy,
                child: Text(occupancy),
              );
            }).toList(),
            onChanged: (String? value) {
              setState(() {
                _selectedOccupancy = value;
              });
              _updateData();
            },
          ),
          SizedBox(height: 3.h),

          // Preferred Amenities
          Text(
            'Preferred Amenities',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Wrap(
            spacing: 2.w,
            runSpacing: 1.h,
            children: _amenities.map((amenity) {
              final isSelected = _selectedAmenities.contains(amenity['id']);
              return FilterChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomIconWidget(
                      iconName: amenity['icon'],
                      color: isSelected
                          ? AppTheme.lightTheme.primaryColor
                          : AppTheme.textSecondaryLight,
                      size: 4.w,
                    ),
                    SizedBox(width: 2.w),
                    Text(amenity['name']),
                  ],
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedAmenities.add(amenity['id']);
                    } else {
                      _selectedAmenities.remove(amenity['id']);
                    }
                  });
                  _updateData();
                },
                backgroundColor: AppTheme.borderLight.withValues(alpha: 0.3),
                selectedColor:
                    AppTheme.lightTheme.primaryColor.withValues(alpha: 0.1),
                checkmarkColor: AppTheme.lightTheme.primaryColor,
              );
            }).toList(),
          ),
          SizedBox(height: 3.h),

          // Preferred Locations
          Text(
            'Preferred Locations',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),

          // Selected locations
          if (_preferredLocations.isNotEmpty) ...[
            Wrap(
              spacing: 2.w,
              runSpacing: 1.h,
              children: _preferredLocations.map((location) {
                return Chip(
                  label: Text(location),
                  deleteIcon: CustomIconWidget(
                    iconName: 'close',
                    color: AppTheme.textSecondaryLight,
                    size: 4.w,
                  ),
                  onDeleted: () => _removeLocation(location),
                  backgroundColor:
                      AppTheme.lightTheme.primaryColor.withValues(alpha: 0.1),
                );
              }).toList(),
            ),
            SizedBox(height: 2.h),
          ],

          // Suggested locations
          Text(
            'Popular Locations',
            style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
              color: AppTheme.textSecondaryLight,
            ),
          ),
          SizedBox(height: 1.h),
          Wrap(
            spacing: 2.w,
            runSpacing: 1.h,
            children: _suggestedLocations.map((location) {
              final isSelected = _preferredLocations.contains(location);
              return ActionChip(
                label: Text(location),
                onPressed: isSelected ? null : () => _addLocation(location),
                backgroundColor: isSelected
                    ? AppTheme.borderLight.withValues(alpha: 0.3)
                    : AppTheme.lightTheme.primaryColor.withValues(alpha: 0.05),
                side: BorderSide(
                  color: isSelected
                      ? AppTheme.borderLight
                      : AppTheme.lightTheme.primaryColor.withValues(alpha: 0.3),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 3.h),

          // Additional Preferences
          Text(
            'Additional Preferences',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),

          SwitchListTile(
            title: Text('Pet-friendly'),
            subtitle: Text('I have pets or plan to get pets'),
            value: _petsAllowed,
            onChanged: (value) {
              setState(() {
                _petsAllowed = value;
              });
              _updateData();
            },
            contentPadding: EdgeInsets.zero,
          ),

          SwitchListTile(
            title: Text('Smoking allowed'),
            subtitle: Text('I smoke or prefer smoking-friendly places'),
            value: _smokingAllowed,
            onChanged: (value) {
              setState(() {
                _smokingAllowed = value;
              });
              _updateData();
            },
            contentPadding: EdgeInsets.zero,
          ),
          SizedBox(height: 2.h),

          // Preference Summary
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppTheme.accentLight.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.accentLight.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'tune',
                      color: AppTheme.accentLight,
                      size: 5.w,
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      'Smart Recommendations',
                      style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.accentLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  'Based on your preferences, we\'ll show you the most relevant properties first. You can always modify these settings later.',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.accentLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
