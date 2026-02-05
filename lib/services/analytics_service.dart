// lib/services/analytics_service.dart

import 'dart:convert';
import 'mongodb_service.dart';
import 'package:mongo_dart/mongo_dart.dart';

class AnalyticsService {
  final MongoDBService _mongoService = MongoDBService();

  // ADDED: Public method to get database access
  Future<Db> getDatabase() async {
    try {
      // Always ensure we have a fresh, connected database
      if (!_mongoService.isConnected) {
        print('📊 Analytics: MongoDB not connected, connecting...');
        await _mongoService.connect();
      }
      return await _mongoService.getDatabase();
    } catch (e) {
      print('❌ Error getting database in AnalyticsService: $e');
      // Force reconnect
      print('🔄 Forcing reconnection...');
      await _mongoService.connect();
      return await _mongoService.getDatabase();
    }
  }

  /// Fetch comprehensive analytics for an owner
  Future<Map<String, dynamic>> getOwnerAnalytics(
    String ownerId, {
    String period = 'month',
  }) async {
    try {
      print('📊 Analytics: Fetching for owner: $ownerId');
      print('📊 Analytics: Connection status: ${_mongoService.isConnected}');
      
      // Ensure connection is alive before starting
      if (!_mongoService.isConnected) {
        print('🔄 Reconnecting to MongoDB...');
        await _mongoService.connect();
      }
      
      final db = await _mongoService.getDatabase();
      final properties = db.collection('properties');
      final bookings = db.collection('bookings');

      // Get owner's properties
      final ownerProperties = await properties
          .find(where.eq('ownerId', ownerId))
          .toList();

      print('📊 Analytics: Found ${ownerProperties.length} properties');

      if (ownerProperties.isEmpty) {
        print('⚠️ Analytics: No properties found for owner');
        return _getEmptyAnalytics();
      }

      // Get property IDs in both formats
      final propertyIdsAsStrings = ownerProperties
          .map((p) => p['_id'].toString())
          .toList();

      final propertyIdsAsObjectIds = ownerProperties
          .map((p) => p['_id'])
          .toList();

      print('📊 Analytics: Property IDs as strings: $propertyIdsAsStrings');
      print('📊 Analytics: Looking for bookings...');

      List<Map<String, dynamic>> allBookings = [];

      try {
        // Method 1: Try by propertyId as ObjectId
        allBookings = await bookings
            .find(where.oneFrom('propertyId', propertyIdsAsObjectIds))
            .toList();

        print('📊 Analytics: Found ${allBookings.length} bookings by propertyId (ObjectId)');

        // Method 2: If not found, try by propertyId as String
        if (allBookings.isEmpty) {
          print('🔍 Trying propertyId as String...');
          allBookings = await bookings
              .find(where.oneFrom('propertyId', propertyIdsAsStrings))
              .toList();
          print('📊 Analytics: Found ${allBookings.length} bookings by propertyId (String)');
        }

        // Method 3: If still not found, try by ownerId
        if (allBookings.isEmpty) {
          print('🔍 Trying by ownerId...');
          allBookings = await bookings
              .find(where.eq('ownerId', ownerId))
              .toList();
          print('📊 Analytics: Found ${allBookings.length} bookings by ownerId');
        }

        // Method 4: Last resort - get all bookings and filter manually
        if (allBookings.isEmpty) {
          print('🔍 Last resort: Getting all bookings and filtering manually...');
          final allDbBookings = await bookings.find().toList();
          print('📊 Total bookings in database: ${allDbBookings.length}');

          allBookings = allDbBookings.where((booking) {
            final bookingPropertyId = booking['propertyId']?.toString() ?? '';
            final bookingOwnerId = booking['ownerId']?.toString() ?? '';

            return propertyIdsAsStrings.contains(bookingPropertyId) ||
                bookingOwnerId == ownerId;
          }).toList();

          print('📊 Analytics: Found ${allBookings.length} bookings after manual filtering');
        }
      } catch (e) {
        print('❌ Error querying bookings: $e');
        allBookings = [];
      }

      print('📊 Analytics: Found ${allBookings.length} total bookings');
      
      // ⭐ DEBUG: Print first booking structure
      if (allBookings.isNotEmpty) {
        print('\n========== BOOKING STRUCTURE DEBUG ==========');
        final sampleBooking = allBookings.first;
        print('📋 Sample Booking Fields:');
        print('   Available Keys: ${sampleBooking.keys.toList()}');
        print('\n📋 Payment-Related Fields:');
        final paymentFields = [
          'lastPaymentDate', 'paymentDate', 'paymentStatus',
          'pendingDues', 'paymentHistory', 'totalPaid'
        ];
        for (var field in paymentFields) {
          if (sampleBooking.containsKey(field)) {
            print('   ✅ $field: ${sampleBooking[field]}');
          } else {
            print('   ❌ $field: NOT FOUND');
          }
        }
        print('=============================================\n');
      }

      // Filter bookings based on period
      final filteredBookings = _filterBookingsByPeriod(allBookings, period);

      print('📊 Analytics: ${filteredBookings.length} bookings after filtering');

      // Calculate analytics
      return _calculateAnalytics(
        ownerProperties,
        filteredBookings,
        allBookings,
        period,
      );
    } catch (e) {
      print('❌ Error fetching analytics: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return _getEmptyAnalytics();
    }
  }

  /// Filter bookings by time period
  List<Map<String, dynamic>> _filterBookingsByPeriod(
    List<Map<String, dynamic>> bookings,
    String period,
  ) {
    // For analytics, include all active/confirmed bookings regardless of date
    // This ensures current tenants are counted even if booking was made in the past
    return bookings.where((booking) {
      final status = booking['status']?.toString().toLowerCase() ?? '';
      return status == 'active' || status == 'confirmed';
    }).toList();
  }

  /// Calculate all analytics metrics
  Map<String, dynamic> _calculateAnalytics(
    List<Map<String, dynamic>> properties,
    List<Map<String, dynamic>> bookings,
    List<Map<String, dynamic>> allBookings,
    String period,
  ) {
    // Total properties
    final totalProperties = properties.length;

    // Occupied and vacant units
    final occupiedUnits = properties.where((p) => 
      p['status'] == 'occupied' || p['availabilityStatus'] == 'occupied'
    ).length;
    final vacantUnits = totalProperties - occupiedUnits;

    // Occupancy rate
    final occupancyRate = totalProperties > 0
        ? (occupiedUnits / totalProperties * 100).toDouble()
        : 0.0;

    // Calculate revenue from bookings' monthlyRent
    double totalRevenue = 0;
    final activeRents = <double>[];
    
    // ⭐ NEW: Calculate Monthly Collection and Monthly Dues
    double monthlyCollection = 0;
    double monthlyDues = 0;
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    
    print('📊 Calculating revenue from ${allBookings.length} total bookings');
    print('💰 Current Month: $currentYear-$currentMonth');
    
    for (var booking in allBookings) {
      final status = booking['status'];
      
      if (booking['status'] == 'confirmed' || booking['status'] == 'active') {
        final monthlyRent = (booking['monthlyRent'] ?? 0).toDouble();
        if (monthlyRent > 0) {
          print('\n   📋 Processing Booking ${booking['_id']}:');
          print('      Status: $status');
          print('      Monthly Rent: ₹$monthlyRent');
          
          // Calculate total revenue based on lease duration
          final leaseDuration = (booking['leaseDuration'] ?? 1).toInt();
          final bookingRevenue = monthlyRent * leaseDuration;
          totalRevenue += bookingRevenue;
          activeRents.add(monthlyRent);
          print('      Total Revenue: ₹$bookingRevenue (₹$monthlyRent × $leaseDuration months)');
          
          // ⭐ IMPROVED: Calculate Monthly Collection
          bool paidThisMonth = false;
          
          // Method 1: Check lastPaymentDate
          if (booking['lastPaymentDate'] != null) {
            try {
              final paymentDate = booking['lastPaymentDate'] is String
                  ? DateTime.parse(booking['lastPaymentDate'])
                  : (booking['lastPaymentDate'] as DateTime);
              
              if (paymentDate.year == currentYear && paymentDate.month == currentMonth) {
                paidThisMonth = true;
                monthlyCollection += monthlyRent;
                print('      ✅ Paid this month (lastPaymentDate): ₹$monthlyRent');
              }
            } catch (e) {
              print('      ⚠️ Could not parse lastPaymentDate: $e');
            }
          }
          
          // Method 2: Check paymentHistory array
          if (!paidThisMonth && booking['paymentHistory'] != null) {
            try {
              final paymentHistory = booking['paymentHistory'] as List;
              for (var payment in paymentHistory) {
                if (payment is Map) {
                  final paymentDate = payment['date'] is String
                      ? DateTime.parse(payment['date'])
                      : (payment['date'] as DateTime?);
                  
                  if (paymentDate != null &&
                      paymentDate.year == currentYear && 
                      paymentDate.month == currentMonth &&
                      payment['status'] == 'completed') {
                    paidThisMonth = true;
                    monthlyCollection += monthlyRent;
                    print('      ✅ Paid this month (paymentHistory): ₹$monthlyRent');
                    break;
                  }
                }
              }
            } catch (e) {
              print('      ⚠️ Could not parse paymentHistory: $e');
            }
          }
          
          // Method 3: Check if booking started this month (first payment)
          if (!paidThisMonth && booking['bookingDate'] != null) {
            try {
              final bookingDate = booking['bookingDate'] is String
                  ? DateTime.parse(booking['bookingDate'])
                  : (booking['bookingDate'] as DateTime);
              
              if (bookingDate.year == currentYear && bookingDate.month == currentMonth) {
                paidThisMonth = true;
                monthlyCollection += monthlyRent;
                print('      ✅ New booking this month: ₹$monthlyRent');
              }
            } catch (e) {
              print('      ⚠️ Could not parse bookingDate: $e');
            }
          }
          
          // ⭐ IMPROVED: Calculate Monthly Dues
          // Method 1: Use pendingDues field if available
          if (booking['pendingDues'] != null) {
            final pendingDues = (booking['pendingDues'] ?? 0).toDouble();
            if (pendingDues > 0) {
              monthlyDues += pendingDues;
              print('      ⚠️ Pending dues: ₹$pendingDues');
            }
          } 
          // Method 2: Check paymentStatus
          else if (booking['paymentStatus'] == 'pending' || 
                   booking['paymentStatus'] == 'overdue') {
            monthlyDues += monthlyRent;
            print('      ⚠️ Payment pending/overdue: ₹$monthlyRent');
          }
          // Method 3: If not paid this month and booking is active, assume due
          else if (!paidThisMonth) {
            try {
              final startDate = booking['startDate'] is String
                  ? DateTime.parse(booking['startDate'])
                  : (booking['startDate'] as DateTime?);
              
              if (startDate != null && startDate.isBefore(now)) {
                monthlyDues += monthlyRent;
                print('      ⚠️ Rent due (not paid this month): ₹$monthlyRent');
              }
            } catch (e) {
              print('      ⚠️ Could not calculate dues from startDate: $e');
            }
          }
        }
      }
    }

    print('\n📊 FINAL CALCULATIONS:');
    print('   Total Revenue: ₹$totalRevenue');
    print('   💰 Monthly Collection: ₹$monthlyCollection');
    print('   ⚠️ Monthly Dues: ₹$monthlyDues');
    print('   Active Rents: $activeRents');

    // Average rent from active bookings
    final averageRent = activeRents.isNotEmpty
        ? activeRents.reduce((a, b) => a + b) / activeRents.length
        : 0.0;

    print('   Average Rent: ₹$averageRent');

    // Total tenants (active bookings)
    final totalTenants = allBookings
        .where((b) => b['status'] == 'confirmed' || b['status'] == 'active')
        .length;

    print('   Total Tenants: $totalTenants');

    // Pending payments
    final pendingPayments = allBookings
        .where((b) => b['paymentStatus'] == 'pending')
        .length;

    // Maintenance requests
    final maintenanceRequests = 0;

    // Calculate revenue growth
    final previousPeriodRevenue = _calculatePreviousPeriodRevenue(
      allBookings,
      period,
    );
    final revenueGrowth = _calculateGrowthPercentage(
      totalRevenue,
      previousPeriodRevenue,
    );

    // New tenants in current period
    final newTenants = allBookings.where((b) {
      try {
        if (b['status'] != 'active' && b['status'] != 'confirmed') return false;
        
        final bookingDate = b['bookingDate'] is String
            ? DateTime.parse(b['bookingDate'])
            : (b['bookingDate'] as DateTime);
        final daysAgo = DateTime.now().difference(bookingDate).inDays;
        return daysAgo >= 0 && daysAgo <= _getPeriodDays(period);
      } catch (e) {
        return false;
      }
    }).length;

    // Leases expiring soon
    final leasesExpiring = allBookings.where((b) {
      try {
        if (b['endDate'] == null) return false;
        final endDate = b['endDate'] is String
            ? DateTime.parse(b['endDate'])
            : (b['endDate'] as DateTime);
        final daysUntilExpiry = endDate.difference(DateTime.now()).inDays;
        return daysUntilExpiry >= 0 && daysUntilExpiry <= 30;
      } catch (e) {
        return false;
      }
    }).length;

    // Monthly revenue trend
    final monthlyRevenue = _calculateMonthlyRevenue(allBookings);

    // Property performance
    final propertyPerformance = _calculatePropertyPerformance(
      properties,
      allBookings,
    );

    return {
      'totalRevenue': '₹${_formatNumber(totalRevenue.toInt())}',
      'totalRevenueRaw': totalRevenue,
      'totalProperties': totalProperties,
      'occupiedUnits': occupiedUnits,
      'vacantUnits': vacantUnits,
      'occupancyRate': occupancyRate.toInt(),
      'averageRent': '₹${_formatNumber(averageRent.toInt())}',
      'averageRentRaw': averageRent,
      'totalTenants': totalTenants,
      'pendingPayments': pendingPayments,
      'maintenanceRequests': maintenanceRequests,
      'revenueGrowth': revenueGrowth,
      'newTenants': newTenants,
      'leasesExpiring': leasesExpiring,
      'monthlyRevenue': monthlyRevenue,
      'propertyPerformance': propertyPerformance,
      // ⭐ NEW: Monthly Collection and Monthly Dues
      'monthlyCollection': '₹${_formatNumber(monthlyCollection.toInt())}',
      'monthlyCollectionRaw': monthlyCollection,
      'monthlyDues': '₹${_formatNumber(monthlyDues.toInt())}',
      'monthlyDuesRaw': monthlyDues,
    };
  }

  /// Calculate previous period revenue
  double _calculatePreviousPeriodRevenue(
    List<Map<String, dynamic>> allBookings,
    String period,
  ) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (period.toLowerCase()) {
      case 'week':
        endDate = now.subtract(Duration(days: 7));
        startDate = endDate.subtract(Duration(days: 7));
        break;
      case 'month':
        endDate = DateTime(now.year, now.month, 1);
        startDate = DateTime(now.year, now.month - 1, 1);
        break;
      case 'year':
        endDate = DateTime(now.year, 1, 1);
        startDate = DateTime(now.year - 1, 1, 1);
        break;
      default:
        return 0;
    }

    final previousBookings = allBookings.where((booking) {
      try {
        final bookingDate = booking['bookingDate'] is String
            ? DateTime.parse(booking['bookingDate'])
            : (booking['bookingDate'] as DateTime);
        return bookingDate.isAfter(startDate) && bookingDate.isBefore(endDate);
      } catch (e) {
        return false;
      }
    }).toList();

    double total = 0;
    for (var booking in previousBookings) {
      if (booking['status'] == 'confirmed' || booking['status'] == 'active') {
        final monthlyRent = (booking['monthlyRent'] ?? 0).toDouble();
        final leaseDuration = (booking['leaseDuration'] ?? 1).toInt();
        total += monthlyRent * leaseDuration;
      }
    }
    return total;
  }

  /// Calculate growth percentage
  String _calculateGrowthPercentage(double current, double previous) {
    if (previous == 0) return '+0%';
    final growth = ((current - previous) / previous * 100).toInt();
    return growth >= 0 ? '+$growth%' : '$growth%';
  }

  /// Get number of days in period
  int _getPeriodDays(String period) {
    switch (period.toLowerCase()) {
      case 'week':
        return 7;
      case 'month':
        return 30;
      case 'year':
        return 365;
      default:
        return 30;
    }
  }

  /// Calculate monthly revenue for chart
  List<Map<String, dynamic>> _calculateMonthlyRevenue(
    List<Map<String, dynamic>> bookings,
  ) {
    final now = DateTime.now();
    final months = <String, double>{};

    // Initialize last 6 months
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = _getMonthKey(month);
      months[monthKey] = 0;
    }

    // Calculate revenue for each month
    for (var booking in bookings) {
      try {
        if (booking['status'] != 'confirmed' && booking['status'] != 'active') {
          continue;
        }

        final bookingDate = booking['bookingDate'] is String
            ? DateTime.parse(booking['bookingDate'])
            : (booking['bookingDate'] as DateTime);

        final monthKey = _getMonthKey(bookingDate);
        if (months.containsKey(monthKey)) {
          final monthlyRent = (booking['monthlyRent'] ?? 0).toDouble();
          final leaseDuration = (booking['leaseDuration'] ?? 1).toInt();
          months[monthKey] = (months[monthKey] ?? 0) + (monthlyRent * leaseDuration);
        }
      } catch (e) {
        continue;
      }
    }

    return months.entries.map((entry) {
      final parts = entry.key.split('-');
      final month = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      return {
        'month': _getMonthName(month),
        'revenue': entry.value.toInt(),
      };
    }).toList();
  }

  /// Calculate property performance
  List<Map<String, dynamic>> _calculatePropertyPerformance(
    List<Map<String, dynamic>> properties,
    List<Map<String, dynamic>> bookings,
  ) {
    return properties.map((property) {
      final propertyId = property['_id'].toString();
      
      // Find bookings for this property
      final propertyBookings = bookings.where(
        (b) => b['propertyId'].toString() == propertyId
      ).toList();

      // Calculate revenue
      double revenue = 0;
      for (var booking in propertyBookings) {
        if (booking['status'] == 'confirmed' || booking['status'] == 'active') {
          final monthlyRent = (booking['monthlyRent'] ?? 0).toDouble();
          final leaseDuration = (booking['leaseDuration'] ?? 1).toInt();
          revenue += monthlyRent * leaseDuration;
        }
      }

      // Determine occupancy
      final isOccupied = property['status'] == 'occupied' || 
                         property['availabilityStatus'] == 'occupied';
      final occupancy = isOccupied ? 100 : 0;

      // Get rating
      final rating = (property['rating'] ?? 4.5).toDouble();

      return {
        'name': property['title'] ?? property['name'] ?? 'Unnamed Property',
        'revenue': '₹${_formatNumber(revenue.toInt())}',
        'occupancy': occupancy,
        'rating': rating,
      };
    }).toList();
  }

  /// Helper: Get month key (YYYY-MM)
  String _getMonthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  /// Helper: Get month name
  String _getMonthName(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[date.month - 1];
  }

  /// Helper: Format number with commas
  String _formatNumber(int number) {
    if (number >= 10000000) {
      return '${(number / 10000000).toStringAsFixed(1)}Cr';
    } else if (number >= 100000) {
      return '${(number / 100000).toStringAsFixed(1)}L';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  /// Get empty analytics (fallback)
  Map<String, dynamic> _getEmptyAnalytics() {
    return {
      'totalRevenue': '₹0',
      'totalRevenueRaw': 0.0,
      'totalProperties': 0,
      'occupiedUnits': 0,
      'vacantUnits': 0,
      'occupancyRate': 0,
      'averageRent': '₹0',
      'averageRentRaw': 0.0,
      'totalTenants': 0,
      'pendingPayments': 0,
      'maintenanceRequests': 0,
      'revenueGrowth': '+0%',
      'newTenants': 0,
      'leasesExpiring': 0,
      'monthlyRevenue': [],
      'propertyPerformance': [],
      // ⭐ NEW: Monthly Collection and Monthly Dues
      'monthlyCollection': '₹0',
      'monthlyCollectionRaw': 0.0,
      'monthlyDues': '₹0',
      'monthlyDuesRaw': 0.0,
    };
  }
}