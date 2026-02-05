import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';

class FilterScreen extends StatefulWidget {
  final Map<String, dynamic>? initialFilters;

  const FilterScreen({
    super.key,
    this.initialFilters,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  // Property Type
  String? _selectedPropertyType; // null, 'Flat', or 'PG'

  // Price Range
  RangeValues _priceRange = RangeValues(0, 100000);
  final double _minPrice = 0;
  final double _maxPrice = 100000;

  // BHK Selection (for Flats)
  final List<String> _bhkOptions = ['1 BHK', '2 BHK', '3 BHK', '4 BHK', '5+ BHK'];
  List<String> _selectedBHKs = [];

  // Number of Beds (for PG)
  int? _minBeds;
  int? _maxBeds;

  // Location
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();

  // Amenities
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

  // Verified Properties Only
  bool _verifiedOnly = false;

  @override
  void initState() {
    super.initState();
    _loadInitialFilters();
  }

  void _loadInitialFilters() {
    if (widget.initialFilters != null) {
      final filters = widget.initialFilters!;
      
      setState(() {
        _selectedPropertyType = filters['propertyType'];
        
        if (filters['minPrice'] != null || filters['maxPrice'] != null) {
          _priceRange = RangeValues(
            filters['minPrice']?.toDouble() ?? _minPrice,
            filters['maxPrice']?.toDouble() ?? _maxPrice,
          );
        }
        
        if (filters['bhks'] != null && filters['bhks'] is List) {
          _selectedBHKs = List<String>.from(filters['bhks']);
        }
        
        _minBeds = filters['minBeds'];
        _maxBeds = filters['maxBeds'];
        
        if (filters['city'] != null) {
          _cityController.text = filters['city'];
        }
        
        if (filters['state'] != null) {
          _stateController.text = filters['state'];
        }
        
        if (filters['amenities'] != null && filters['amenities'] is List) {
          for (String amenity in filters['amenities']) {
            if (_amenities.containsKey(amenity)) {
              _amenities[amenity] = true;
            }
          }
        }
        
        _verifiedOnly = filters['verifiedOnly'] ?? false;
      });
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _selectedPropertyType = null;
      _priceRange = RangeValues(_minPrice, _maxPrice);
      _selectedBHKs.clear();
      _minBeds = null;
      _maxBeds = null;
      _cityController.clear();
      _stateController.clear();
      _amenities.updateAll((key, value) => false);
      _verifiedOnly = false;
    });
  }

  Map<String, dynamic> _buildFilterMap() {
    Map<String, dynamic> filters = {};

    if (_selectedPropertyType != null) {
      filters['propertyType'] = _selectedPropertyType;
    }

    if (_priceRange.start > _minPrice || _priceRange.end < _maxPrice) {
      filters['minPrice'] = _priceRange.start.toInt();
      filters['maxPrice'] = _priceRange.end.toInt();
    }

    if (_selectedBHKs.isNotEmpty) {
      filters['bhks'] = _selectedBHKs;
    }

    if (_minBeds != null) {
      filters['minBeds'] = _minBeds;
    }

    if (_maxBeds != null) {
      filters['maxBeds'] = _maxBeds;
    }

    if (_cityController.text.trim().isNotEmpty) {
      filters['city'] = _cityController.text.trim();
    }

    if (_stateController.text.trim().isNotEmpty) {
      filters['state'] = _stateController.text.trim();
    }

    List<String> selectedAmenities = _amenities.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedAmenities.isNotEmpty) {
      filters['amenities'] = selectedAmenities;
    }

    if (_verifiedOnly) {
      filters['verifiedOnly'] = true;
    }

    return filters;
  }

  void _applyFilters() {
    Navigator.pop(context, _buildFilterMap());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppTheme.primaryLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Filter Properties',
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _clearFilters,
            child: Text(
              'Clear All',
              style: TextStyle(
                color: AppTheme.primaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(4.w),
              children: [
                _buildPropertyTypeSection(),
                SizedBox(height: 3.h),
                _buildPriceRangeSection(),
                SizedBox(height: 3.h),
                
                // Conditional sections based on property type
                if (_selectedPropertyType == 'Flat') ...[
                  _buildBHKSection(),
                  SizedBox(height: 3.h),
                ] else if (_selectedPropertyType == 'PG') ...[
                  _buildBedsSection(),
                  SizedBox(height: 3.h),
                ],
                
                _buildLocationSection(),
                SizedBox(height: 3.h),
                _buildAmenitiesSection(),
                SizedBox(height: 3.h),
                _buildVerifiedSection(),
                SizedBox(height: 2.h),
              ],
            ),
          ),
          _buildApplyButton(),
        ],
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

  Widget _buildPropertyTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Property Type'),
        SizedBox(height: 2.h),
        Row(
          children: [
            Expanded(
              child: _buildPropertyTypeCard(
                'Flat',
                Icons.apartment,
                _selectedPropertyType == 'Flat',
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: _buildPropertyTypeCard(
                'PG',
                Icons.meeting_room,
                _selectedPropertyType == 'PG',
              ),
            ),
          ],
        ),
        if (_selectedPropertyType != null)
          Padding(
            padding: EdgeInsets.only(top: 1.h),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedPropertyType = null;
                  _selectedBHKs.clear();
                  _minBeds = null;
                  _maxBeds = null;
                });
              },
              icon: Icon(Icons.clear, size: 16),
              label: Text('Clear Selection'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPropertyTypeCard(String type, IconData icon, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPropertyType = _selectedPropertyType == type ? null : type;
          // Clear type-specific filters when changing type
          _selectedBHKs.clear();
          _minBeds = null;
          _maxBeds = null;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 4.w),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryLight.withOpacity(0.1)
              : AppTheme.lightTheme.colorScheme.surface,
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
              size: 8.w,
              color: isSelected
                  ? AppTheme.primaryLight
                  : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: 1.h),
            Text(
              type,
              style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? AppTheme.primaryLight
                    : AppTheme.lightTheme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRangeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Price Range (Monthly)'),
        SizedBox(height: 1.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '₹${_priceRange.start.toInt().toString()}',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryLight,
              ),
            ),
            Text(
              '₹${_priceRange.end.toInt().toString()}',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryLight,
              ),
            ),
          ],
        ),
        RangeSlider(
          values: _priceRange,
          min: _minPrice,
          max: _maxPrice,
          divisions: 100,
          activeColor: AppTheme.primaryLight,
          inactiveColor: AppTheme.primaryLight.withOpacity(0.2),
          labels: RangeLabels(
            '₹${_priceRange.start.toInt()}',
            '₹${_priceRange.end.toInt()}',
          ),
          onChanged: (RangeValues values) {
            setState(() {
              _priceRange = values;
            });
          },
        ),
      ],
    );
  }

  Widget _buildBHKSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('BHK Type'),
        SizedBox(height: 2.h),
        Wrap(
          spacing: 2.w,
          runSpacing: 1.5.h,
          children: _bhkOptions.map((bhk) {
            final isSelected = _selectedBHKs.contains(bhk);
            return FilterChip(
              label: Text(bhk),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedBHKs.add(bhk);
                  } else {
                    _selectedBHKs.remove(bhk);
                  }
                });
              },
              selectedColor: AppTheme.primaryLight,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : AppTheme.lightTheme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor: AppTheme.lightTheme.colorScheme.surface,
              side: BorderSide(
                color: isSelected ? AppTheme.primaryLight : AppTheme.borderLight,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBedsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Number of Beds'),
        SizedBox(height: 2.h),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Min Beds',
                    style: AppTheme.lightTheme.textTheme.bodySmall,
                  ),
                  SizedBox(height: 1.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 3.w),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.borderLight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _minBeds,
                        isExpanded: true,
                        hint: Text('Any'),
                        items: [
                          DropdownMenuItem(value: null, child: Text('Any')),
                          ...List.generate(10, (index) => index + 1)
                              .map((num) => DropdownMenuItem(
                                    value: num,
                                    child: Text('$num'),
                                  ))
                              .toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _minBeds = value;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Max Beds',
                    style: AppTheme.lightTheme.textTheme.bodySmall,
                  ),
                  SizedBox(height: 1.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 3.w),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.borderLight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _maxBeds,
                        isExpanded: true,
                        hint: Text('Any'),
                        items: [
                          DropdownMenuItem(value: null, child: Text('Any')),
                          ...List.generate(10, (index) => index + 1)
                              .map((num) => DropdownMenuItem(
                                    value: num,
                                    child: Text('$num'),
                                  ))
                              .toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _maxBeds = value;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Location'),
        SizedBox(height: 2.h),
        TextFormField(
          controller: _cityController,
          decoration: InputDecoration(
            labelText: 'City',
            hintText: 'e.g., Mumbai, Delhi',
            prefixIcon: Icon(Icons.location_city, color: AppTheme.primaryLight),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
            ),
          ),
        ),
        SizedBox(height: 2.h),
        TextFormField(
          controller: _stateController,
          decoration: InputDecoration(
            labelText: 'State',
            hintText: 'e.g., Maharashtra, Delhi',
            prefixIcon: Icon(Icons.map, color: AppTheme.primaryLight),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmenitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Amenities'),
        SizedBox(height: 2.h),
        Wrap(
          spacing: 2.w,
          runSpacing: 1.h,
          children: _amenities.keys.map((amenity) {
            return FilterChip(
              label: Text(amenity),
              selected: _amenities[amenity]!,
              onSelected: (selected) {
                setState(() {
                  _amenities[amenity] = selected;
                });
              },
              selectedColor: AppTheme.primaryLight.withOpacity(0.2),
              checkmarkColor: AppTheme.primaryLight,
              labelStyle: TextStyle(
                color: _amenities[amenity]!
                    ? AppTheme.primaryLight
                    : AppTheme.lightTheme.colorScheme.onSurface,
              ),
              backgroundColor: AppTheme.lightTheme.colorScheme.surface,
              side: BorderSide(
                color: _amenities[amenity]!
                    ? AppTheme.primaryLight
                    : AppTheme.borderLight,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVerifiedSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: SwitchListTile(
        title: Text(
          'Verified Properties Only',
          style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Show only verified listings',
          style: AppTheme.lightTheme.textTheme.bodySmall,
        ),
        value: _verifiedOnly,
        onChanged: (value) {
          setState(() {
            _verifiedOnly = value;
          });
        },
        activeColor: AppTheme.primaryLight,
      ),
    );
  }

  Widget _buildApplyButton() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _applyFilters,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryLight,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 7.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            'Apply Filters',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}