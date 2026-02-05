import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class ReviewsSectionWidget extends StatefulWidget {
  final double rating;
  final int reviewCount;
  final List<Map<String, dynamic>> reviews;

  const ReviewsSectionWidget({
    super.key,
    required this.rating,
    required this.reviewCount,
    required this.reviews,
  });

  @override
  State<ReviewsSectionWidget> createState() => _ReviewsSectionWidgetState();
}

class _ReviewsSectionWidgetState extends State<ReviewsSectionWidget> {
  bool _showAllReviews = false;

  void _toggleShowAllReviews() {
    setState(() {
      _showAllReviews = !_showAllReviews;
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayedReviews =
        _showAllReviews ? widget.reviews : widget.reviews.take(2).toList();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reviews',
                style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lightTheme.colorScheme.onSurface,
                ),
              ),
              TextButton(
                onPressed: () => _showAllReviewsBottomSheet(context),
                child: Text('View all'),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildRatingSummary(),
          SizedBox(height: 3.h),
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: displayedReviews.length,
            separatorBuilder: (context, index) => SizedBox(height: 3.h),
            itemBuilder: (context, index) {
              return _buildReviewCard(displayedReviews[index]);
            },
          ),
          if (widget.reviews.length > 2 && !_showAllReviews) ...[
            SizedBox(height: 2.h),
            Center(
              child: TextButton.icon(
                onPressed: _toggleShowAllReviews,
                icon: CustomIconWidget(
                  iconName: 'expand_more',
                  color: AppTheme.lightTheme.colorScheme.primary,
                  size: 20,
                ),
                label: Text('Show ${widget.reviews.length - 2} more reviews'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingSummary() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.primary
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  widget.rating.toString(),
                  style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.lightTheme.colorScheme.primary,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (index) {
                    return CustomIconWidget(
                      iconName: index < widget.rating.floor()
                          ? 'star'
                          : 'star_border',
                      color: Colors.amber,
                      size: 16,
                    );
                  }),
                ),
              ],
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.reviewCount} reviews',
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.lightTheme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 1.h),
                _buildRatingBar('5', 0.7),
                _buildRatingBar('4', 0.2),
                _buildRatingBar('3', 0.05),
                _buildRatingBar('2', 0.03),
                _buildRatingBar('1', 0.02),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(String stars, double percentage) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.2.h),
      child: Row(
        children: [
          Text(
            stars,
            style: AppTheme.lightTheme.textTheme.bodySmall,
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Container(
              height: 0.5.h,
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.outline
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percentage,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final images = (review["images"] as List).cast<String>();

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.lightTheme.colorScheme.outline
                        .withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: ClipOval(
                  child: CustomImageWidget(
                    imageUrl: review["userImage"] as String,
                    width: 12.w,
                    height: 12.w,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review["userName"] as String,
                      style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (index) {
                            return CustomIconWidget(
                              iconName: index < (review["rating"] as int)
                                  ? 'star'
                                  : 'star_border',
                              color: Colors.amber,
                              size: 14,
                            );
                          }),
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          review["date"] as String,
                          style:
                              AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                            color: AppTheme
                                .lightTheme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            review["comment"] as String,
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (images.isNotEmpty) ...[
            SizedBox(height: 2.h),
            SizedBox(
              height: 20.w,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (context, index) => SizedBox(width: 2.w),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CustomImageWidget(
                      imageUrl: images[index],
                      width: 20.w,
                      height: 20.w,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAllReviewsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 80.h,
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.lightTheme.colorScheme.outline
                        .withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Reviews (${widget.reviewCount})',
                    style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: CustomIconWidget(
                      iconName: 'close',
                      color: AppTheme.lightTheme.colorScheme.onSurface,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.all(4.w),
                itemCount: widget.reviews.length,
                separatorBuilder: (context, index) => SizedBox(height: 3.h),
                itemBuilder: (context, index) {
                  return _buildReviewCard(widget.reviews[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
