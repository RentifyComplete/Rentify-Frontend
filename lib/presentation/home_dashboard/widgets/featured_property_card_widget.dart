import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class FeaturedPropertyCardWidget extends StatelessWidget {
  final Map<String, dynamic> property;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final bool isCompact;

  const FeaturedPropertyCardWidget({
    super.key,
    required this.property,
    required this.onTap,
    required this.onFavorite,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final String title = property["title"] ?? "";
    final String location = property["location"] ?? "";
    final String price = property["price"] ?? "";
    final double rating = (property["rating"] as num?)?.toDouble() ?? 0.0;
    final String imageUrl = property["image"] ?? "";
    final String type = property["type"] ?? "";
    final List<String> amenities =
        (property["amenities"] as List?)?.map((e) => e.toString()).toList() ?? [];
    final bool isVerified = property["isVerified"] ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isCompact ? 70.w : 75.w,
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageSection(imageUrl, isVerified),
            Padding(
              padding: EdgeInsets.all(3.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleSection(title, type),
                  SizedBox(height: 1.h),
                  _buildLocationSection(location),
                  // ⭐ RATING REMOVED - No longer displaying rating and reviews
                  if (!isCompact && amenities.isNotEmpty) ...[
                    SizedBox(height: 1.h),
                    _buildAmenitiesSection(amenities),
                  ],
                  SizedBox(height: 1.5.h),
                  _buildPriceSection(price),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(String imageUrl, bool isVerified) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: CustomImageWidget(
            imageUrl: imageUrl,
            width: double.infinity,
            height: isCompact ? 12.h : 16.h,
            fit: BoxFit.cover,
          ),
        ),

        /// Favorite Button
        Positioned(
          top: 2.w,
          right: 2.w,
          child: GestureDetector(
            onTap: onFavorite,
            child: Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: CustomIconWidget(
                iconName: 'favorite_border',
                color: AppTheme.primaryLight,
                size: 5.w,
              ),
            ),
          ),
        ),

        /// Verified Badge
        if (isVerified)
          Positioned(
            top: 2.w,
            left: 2.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.w),
              decoration: BoxDecoration(
                color: AppTheme.successLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomIconWidget(
                    iconName: 'verified',
                    color: Colors.white,
                    size: 3.w,
                  ),
                  SizedBox(width: 1.w),
                  Text(
                    'Verified',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTitleSection(String title, String type) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 2.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.7.h),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            type,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.primaryLight,
              fontWeight: FontWeight.w500,
              fontSize: 9.sp,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection(String location) {
    return Row(
      children: [
        CustomIconWidget(
          iconName: 'location_on',
          color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
          size: 4.w,
        ),
        SizedBox(width: 1.w),
        Expanded(
          child: Text(
            location,
            style: AppTheme.lightTheme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ⭐ _buildRatingSection METHOD REMOVED - No longer needed

  Widget _buildAmenitiesSection(List<String> amenities) {
    return Wrap(
      spacing: 2.w,
      runSpacing: 1.h,
      children: amenities.take(3).map((amenity) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
          decoration: BoxDecoration(
            color: AppTheme.lightTheme.colorScheme.outline.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            amenity,
            style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
              fontSize: 9.sp,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriceSection(String price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                price,
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.primaryLight,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'per month',
                style: AppTheme.lightTheme.textTheme.bodySmall,
              ),
            ],
          ),
        ),

        // BOOK NOW
        // Container(
        //   padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
        //   decoration: BoxDecoration(
        //     color: AppTheme.accentLight,
        //     borderRadius: BorderRadius.circular(8),
        //   ),
        //   child: Text(
        //     'Book Now',
        //     style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
        //       color: Colors.white,
        //       fontWeight: FontWeight.w600,
        //       fontSize: 10.sp,
        //     ),
        //   ),
        // ),
      ],
    );
  }
}