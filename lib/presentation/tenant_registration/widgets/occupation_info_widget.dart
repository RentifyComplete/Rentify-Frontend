import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class OccupationInfoWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onDataChanged;
  final Map<String, dynamic> initialData;

  const OccupationInfoWidget({
    super.key,
    required this.onDataChanged,
    required this.initialData,
  });

  @override
  State<OccupationInfoWidget> createState() => _OccupationInfoWidgetState();
}

class _OccupationInfoWidgetState extends State<OccupationInfoWidget> {
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _incomeController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();

  String? _selectedEmploymentStatus;
  String? _selectedIncomeRange;

  final List<String> _employmentStatusOptions = [
    'Full-time Employee',
    'Part-time Employee',
    'Self-employed',
    'Freelancer',
    'Student',
    'Unemployed',
    'Retired',
  ];

  final List<String> _incomeRangeOptions = [
    'Below ₹20,000',
    '₹20,000 - ₹40,000',
    '₹40,000 - ₹60,000',
    '₹60,000 - ₹80,000',
    '₹80,000 - ₹1,00,000',
    'Above ₹1,00,000',
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    _companyController.text = widget.initialData['company'] ?? '';
    _designationController.text = widget.initialData['designation'] ?? '';
    _incomeController.text = widget.initialData['income']?.toString() ?? '';
    _experienceController.text =
        widget.initialData['experience']?.toString() ?? '';
    _selectedEmploymentStatus = widget.initialData['employmentStatus'];
    _selectedIncomeRange = widget.initialData['incomeRange'];
  }

  void _updateData() {
    final data = {
      'employmentStatus': _selectedEmploymentStatus,
      'company': _companyController.text,
      'designation': _designationController.text,
      'income': double.tryParse(_incomeController.text),
      'incomeRange': _selectedIncomeRange,
      'experience': double.tryParse(_experienceController.text),
    };
    widget.onDataChanged(data);
  }

  bool _isEmployed() {
    return _selectedEmploymentStatus == 'Full-time Employee' ||
        _selectedEmploymentStatus == 'Part-time Employee' ||
        _selectedEmploymentStatus == 'Self-employed' ||
        _selectedEmploymentStatus == 'Freelancer';
  }

  @override
  void dispose() {
    _companyController.dispose();
    _designationController.dispose();
    _incomeController.dispose();
    _experienceController.dispose();
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
            'Occupation Information',
            style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.lightTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Help property owners understand your financial stability',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryLight,
            ),
          ),
          SizedBox(height: 3.h),

          // Employment Status
          DropdownButtonFormField<String>(
            value: _selectedEmploymentStatus,
            decoration: InputDecoration(
              labelText: 'Employment Status',
              hintText: 'Select your employment status',
              prefixIcon: Padding(
                padding: EdgeInsets.all(3.w),
                child: CustomIconWidget(
                  iconName: 'work',
                  color: AppTheme.textSecondaryLight,
                  size: 5.w,
                ),
              ),
            ),
            items: _employmentStatusOptions.map((String status) {
              return DropdownMenuItem<String>(
                value: status,
                child: Text(status),
              );
            }).toList(),
            onChanged: (String? value) {
              setState(() {
                _selectedEmploymentStatus = value;
                // Clear company and designation if not employed
                if (!_isEmployed()) {
                  _companyController.clear();
                  _designationController.clear();
                }
              });
              _updateData();
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select employment status';
              }
              return null;
            },
          ),
          SizedBox(height: 2.h),

          // Company Name (only if employed)
          if (_isEmployed()) ...[
            TextFormField(
              controller: _companyController,
              decoration: InputDecoration(
                labelText: 'Company/Organization Name',
                hintText: 'Enter your company name',
                prefixIcon: Padding(
                  padding: EdgeInsets.all(3.w),
                  child: CustomIconWidget(
                    iconName: 'business',
                    color: AppTheme.textSecondaryLight,
                    size: 5.w,
                  ),
                ),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (_isEmployed() && (value == null || value.isEmpty)) {
                  return 'Company name is required';
                }
                return null;
              },
              onChanged: (_) => _updateData(),
            ),
            SizedBox(height: 2.h),

            // Designation
            TextFormField(
              controller: _designationController,
              decoration: InputDecoration(
                labelText: 'Job Title/Designation',
                hintText: 'Enter your job title',
                prefixIcon: Padding(
                  padding: EdgeInsets.all(3.w),
                  child: CustomIconWidget(
                    iconName: 'badge',
                    color: AppTheme.textSecondaryLight,
                    size: 5.w,
                  ),
                ),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (_isEmployed() && (value == null || value.isEmpty)) {
                  return 'Job title is required';
                }
                return null;
              },
              onChanged: (_) => _updateData(),
            ),
            SizedBox(height: 2.h),

            // Work Experience
            TextFormField(
              controller: _experienceController,
              decoration: InputDecoration(
                labelText: 'Work Experience (Years)',
                hintText: 'Enter years of experience',
                prefixIcon: Padding(
                  padding: EdgeInsets.all(3.w),
                  child: CustomIconWidget(
                    iconName: 'timeline',
                    color: AppTheme.textSecondaryLight,
                    size: 5.w,
                  ),
                ),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
              ],
              onChanged: (_) => _updateData(),
            ),
            SizedBox(height: 2.h),
          ],

          // Income Range
          DropdownButtonFormField<String>(
            value: _selectedIncomeRange,
            decoration: InputDecoration(
              labelText: 'Monthly Income Range',
              hintText: 'Select your income range',
              prefixIcon: Padding(
                padding: EdgeInsets.all(3.w),
                child: CustomIconWidget(
                  iconName: 'account_balance_wallet',
                  color: AppTheme.textSecondaryLight,
                  size: 5.w,
                ),
              ),
            ),
            items: _incomeRangeOptions.map((String range) {
              return DropdownMenuItem<String>(
                value: range,
                child: Text(range),
              );
            }).toList(),
            onChanged: (String? value) {
              setState(() {
                _selectedIncomeRange = value;
              });
              _updateData();
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select income range';
              }
              return null;
            },
          ),
          SizedBox(height: 2.h),

          // Exact Monthly Income (Optional)
          TextFormField(
            controller: _incomeController,
            decoration: InputDecoration(
              labelText: 'Exact Monthly Income (Optional)',
              hintText: 'Enter your exact monthly income',
              prefixIcon: Padding(
                padding: EdgeInsets.all(3.w),
                child: CustomIconWidget(
                  iconName: 'currency_rupee',
                  color: AppTheme.textSecondaryLight,
                  size: 5.w,
                ),
              ),
              suffixText: '₹',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: (_) => _updateData(),
          ),
          SizedBox(height: 4.h),

          // Income Verification Info
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppTheme.successLight.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.successLight.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'verified',
                      color: AppTheme.successLight,
                      size: 5.w,
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      'Income Verification',
                      style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.successLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  'Your income information helps property owners assess your ability to pay rent. This information is kept confidential and secure.',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.successLight,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),

          // Documents Required Info
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.lightTheme.primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'description',
                      color: AppTheme.lightTheme.primaryColor,
                      size: 5.w,
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      'Documents You May Need',
                      style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.lightTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  '• Salary slips (last 3 months)\n• Bank statements\n• Employment letter\n• Income tax returns',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightTheme.primaryColor,
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
