import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/app_export.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import 'package:mongo_dart/mongo_dart.dart' show where, ObjectId;

// ============================================================
// LEAD STATUS ENUM
// ============================================================
enum LeadStatus { viewed, pending, contacted, visited, negotiating, converted, lost }

extension LeadStatusExtension on LeadStatus {
  String get label {
    switch (this) {
      case LeadStatus.viewed:       return 'Viewed';
      case LeadStatus.pending:      return 'Pending';
      case LeadStatus.contacted:    return 'Contacted';
      case LeadStatus.visited:      return 'Visited';
      case LeadStatus.negotiating:  return 'Negotiating';
      case LeadStatus.converted:    return 'Converted';
      case LeadStatus.lost:         return 'Lost';
    }
  }

  Color get color {
    switch (this) {
      case LeadStatus.viewed:       return const Color(0xFF607D8B); // blue-grey
      case LeadStatus.pending:      return const Color(0xFFFF9800);
      case LeadStatus.contacted:    return const Color(0xFF2196F3);
      case LeadStatus.visited:      return const Color(0xFF9C27B0);
      case LeadStatus.negotiating:  return const Color(0xFF00BCD4);
      case LeadStatus.converted:    return const Color(0xFF4CAF50);
      case LeadStatus.lost:         return const Color(0xFFF44336);
    }
  }

  IconData get icon {
    switch (this) {
      case LeadStatus.viewed:       return Icons.visibility_rounded;
      case LeadStatus.pending:      return Icons.hourglass_empty_rounded;
      case LeadStatus.contacted:    return Icons.phone_in_talk_rounded;
      case LeadStatus.visited:      return Icons.home_work_rounded;
      case LeadStatus.negotiating:  return Icons.handshake_rounded;
      case LeadStatus.converted:    return Icons.check_circle_rounded;
      case LeadStatus.lost:         return Icons.cancel_rounded;
    }
  }

  static LeadStatus fromString(String value) {
    return LeadStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => LeadStatus.pending,
    );
  }
}

// ============================================================
// LEAD TRACKER SCREEN
// ============================================================
class LeadTrackerScreen extends StatefulWidget {
  const LeadTrackerScreen({super.key});

  @override
  State<LeadTrackerScreen> createState() => _LeadTrackerScreenState();
}

class _LeadTrackerScreenState extends State<LeadTrackerScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final AuthService _authService = AuthService();
  final String _baseUrl = 'https://rentify-backend-cdaj.onrender.com';

  List<Map<String, dynamic>> _allLeads = [];
  List<Map<String, dynamic>> _filteredLeads = [];
  bool _isLoading = true;
  String? _errorMessage;

  LeadStatus? _selectedFilter;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  int get _totalLeads     => _allLeads.length;
  int get _viewedCount    => _allLeads.where((l) => l['leadStatus'] == 'viewed').length;
  int get _pendingCount   => _allLeads.where((l) => (l['leadStatus'] ?? 'pending') == 'pending').length;
  int get _convertedCount => _allLeads.where((l) => l['leadStatus'] == 'converted').length;
  double get _conversionRate =>
      _totalLeads == 0 ? 0 : (_convertedCount / _totalLeads) * 100;

  @override
  void initState() {
    super.initState();
    _loadLeads();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD LEADS — bookings + property views merged
  // ============================================================
  Future<void> _loadLeads() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final userId = await _authService.getCurrentUserId();
      if (userId == null) {
        setState(() { _errorMessage = 'User not logged in'; _isLoading = false; });
        return;
      }

      print('🎯 LeadTracker: Loading leads for owner: $userId');

      final db         = await _analyticsService.getDatabase();
      final bookings   = db.collection('bookings');
      final properties = db.collection('properties');

      final ownerProperties = await properties
          .find(where.eq('ownerId', userId))
          .toList();

      print('📊 LeadTracker: Found ${ownerProperties.length} properties');

      final propertyIdStrings = ownerProperties
          .map((p) => p['_id'].toHexString())
          .toList();

      // ── Load booking leads ──
      List<Map<String, dynamic>> rawLeads = await bookings
          .find(where.eq('ownerId', userId))
          .toList();
      print('📊 LeadTracker: ${rawLeads.length} leads by ownerId (string)');

      if (rawLeads.isEmpty) {
        try {
          final userObjId = ObjectId.fromHexString(userId);
          rawLeads = await bookings
              .find(where.eq('ownerId', userObjId))
              .toList();
          print('📊 LeadTracker: ${rawLeads.length} leads by ownerId (ObjectId)');
        } catch (_) {}
      }

      if (rawLeads.isEmpty && ownerProperties.isNotEmpty) {
        final allBookings = await bookings.find().toList();
        rawLeads = allBookings.where((b) {
          final bPropId = b['propertyId']?.toHexString?.call() ??
              b['propertyId']?.toString() ?? '';
          return propertyIdStrings
              .any((pid) => bPropId.contains(pid) || pid.contains(bPropId));
        }).toList();
        print('📊 LeadTracker: ${rawLeads.length} leads by propertyId hex match');
      }

      // ── Enrich booking leads ──
      final enriched = <Map<String, dynamic>>[];
      for (var lead in rawLeads) {
        final property = ownerProperties.firstWhere(
          (p) => p['_id'].toString() == lead['propertyId'].toString(),
          orElse: () => ownerProperties.isNotEmpty ? ownerProperties.first : {},
        );
        enriched.add({
          ...lead,
          'propertyTitle': property['title'] ?? lead['propertyTitle'] ?? 'Unknown Property',
          'leadStatus': lead['leadStatus'] ?? 'pending',
          'leadType': 'booking',
        });
      }

      // ── Load property views from REST API ──
      try {
        final viewsResponse = await http.get(
          Uri.parse('$_baseUrl/api/property-views/owner/$userId'),
        ).timeout(const Duration(seconds: 10));

        if (viewsResponse.statusCode == 200) {
          final viewsData = json.decode(viewsResponse.body);
          if (viewsData['success'] == true) {
            final views = List<Map<String, dynamic>>.from(viewsData['views'] ?? []);
            print('👁️ LeadTracker: ${views.length} property views loaded');

            for (var view in views) {
              // Only add if not already in enriched (same tenant + property)
              final alreadyExists = enriched.any((e) =>
                  (e['tenantEmail'] ?? '') == (view['tenantEmail'] ?? '') &&
                  e['propertyId']?.toString() == view['propertyId']?.toString());

              if (!alreadyExists) {
                // Find property title
                String propTitle = 'Unknown Property';
                try {
                  final prop = ownerProperties.firstWhere(
                    (p) => p['_id'].toHexString() == view['propertyId']?.toString(),
                    orElse: () => {},
                  );
                  propTitle = prop['title'] ?? propTitle;
                } catch (_) {}

                enriched.add({
                  '_id': view['_id'],
                  'tenantName': view['tenantName'] ?? view['tenantEmail'] ?? 'Unknown',
                  'tenantEmail': view['tenantEmail'] ?? '',
                  'tenantPhone': view['tenantPhone'] ?? '',
                  'propertyId': view['propertyId'],
                  'propertyTitle': propTitle,
                  'leadStatus': 'viewed',
                  'leadType': 'view',
                  'createdAt': view['createdAt'],
                  'status': '',
                });
              }
            }
          }
        }
      } catch (e) {
        print('⚠️ Could not load property views: $e');
      }

      // ── Sort by date ──
      enriched.sort((a, b) {
        final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(0);
        final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(0);
        return bDate.compareTo(aDate);
      });

      print('✅ LeadTracker: Total enriched leads: ${enriched.length}');

      if (mounted) {
        setState(() { _allLeads = enriched; _isLoading = false; });
        _applyFilters();
      }
    } catch (e) {
      print('❌ LeadTracker error: $e');
      if (mounted) {
        setState(() {
          _isLoading    = false;
          _errorMessage = 'Failed to load leads. Please try again.';
        });
      }
    }
  }

  // ============================================================
  // UPDATE LEAD STATUS (only for booking leads, not view-only)
  // ============================================================
  Future<void> _updateLeadStatus(
      Map<String, dynamic> lead, LeadStatus newStatus) async {
    final leadId = lead['_id'];
    if (leadId == null) return;

    // View-only leads can't be updated in bookings collection
    if (lead['leadType'] == 'view') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This is a view-only lead. Ask tenant to send a booking request.'),
          backgroundColor: Colors.blueGrey,
          duration: Duration(seconds: 3),
        ));
      }
      return;
    }

    setState(() {
      final idx = _allLeads.indexWhere((l) => l['_id'] == leadId);
      if (idx != -1) _allLeads[idx]['leadStatus'] = newStatus.name;
    });
    _applyFilters();

    try {
      final db       = await _analyticsService.getDatabase();
      final bookings = db.collection('bookings');
      await bookings.updateOne(
        where.id(leadId),
        {r'$set': {'leadStatus': newStatus.name}},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lead marked as ${newStatus.label}'),
          backgroundColor: newStatus.color,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      setState(() {
        final idx = _allLeads.indexWhere((l) => l['_id'] == leadId);
        if (idx != -1) _allLeads[idx]['leadStatus'] = lead['leadStatus'];
      });
      _applyFilters();
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredLeads = _allLeads.where((lead) {
        final matchesStatus = _selectedFilter == null ||
            (lead['leadStatus'] ?? 'pending') == _selectedFilter!.name;
        final name      = (lead['tenantName'] ?? lead['userName'] ?? '').toLowerCase();
        final propTitle = (lead['propertyTitle'] ?? '').toLowerCase();
        final matchesSearch = _searchQuery.isEmpty ||
            name.contains(_searchQuery.toLowerCase()) ||
            propTitle.contains(_searchQuery.toLowerCase());
        return matchesStatus && matchesSearch;
      }).toList();
    });
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoader()
          : _errorMessage != null
              ? _buildError()
              : Column(children: [
                  _buildStatsRow(),
                  _buildSearchAndFilter(),
                  Expanded(child: _buildLeadList()),
                ]),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppTheme.primaryLight,
      foregroundColor: Colors.white,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Lead Tracker',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.white)),
        Text('$_totalLeads total leads',
            style: TextStyle(fontSize: 10.sp, color: Colors.white70)),
      ]),
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadLeads),
      ],
    );
  }

  Widget _buildStatsRow() {
    final stats = [
      {'label': 'Total',     'value': '$_totalLeads',                           'icon': Icons.campaign_rounded,        'color': AppTheme.primaryLight},
      {'label': 'Viewed',    'value': '$_viewedCount',                          'icon': Icons.visibility_rounded,      'color': const Color(0xFF607D8B)},
      {'label': 'Converted', 'value': '$_convertedCount',                       'icon': Icons.check_circle_rounded,    'color': const Color(0xFF4CAF50)},
      {'label': 'Conv. %',   'value': '${_conversionRate.toStringAsFixed(0)}%', 'icon': Icons.trending_up_rounded,     'color': const Color(0xFF9C27B0)},
    ];

    return Container(
      color: AppTheme.primaryLight,
      padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 3.h),
      child: Row(
        children: stats.map((s) => Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 1.w),
            padding: EdgeInsets.symmetric(vertical: 1.5.h),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white30),
            ),
            child: Column(children: [
              Icon(s['icon'] as IconData, color: Colors.white, size: 5.w),
              SizedBox(height: 0.5.h),
              Text(s['value'] as String,
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: Colors.white)),
              Text(s['label'] as String,
                  style: TextStyle(fontSize: 8.sp, color: Colors.white70)),
            ]),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 1.5.h),
      child: Column(children: [
        TextField(
          controller: _searchController,
          onChanged: (val) { _searchQuery = val; _applyFilters(); },
          decoration: InputDecoration(
            hintText: 'Search by tenant or property...',
            hintStyle: TextStyle(fontSize: 11.sp, color: Colors.grey),
            prefixIcon: Icon(Icons.search, size: 5.w, color: Colors.grey),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      _searchQuery = '';
                      _applyFilters();
                    })
                : null,
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
          ),
        ),
        SizedBox(height: 1.5.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _buildFilterChip(null, 'All', Icons.list_alt_rounded),
            SizedBox(width: 2.w),
            ...LeadStatus.values.map((s) => Padding(
                  padding: EdgeInsets.only(right: 2.w),
                  child: _buildFilterChip(s, s.label, s.icon))),
          ]),
        ),
      ]),
    );
  }

  Widget _buildFilterChip(LeadStatus? status, String label, IconData icon) {
    final isSelected = _selectedFilter == status;
    final chipColor  = status?.color ?? AppTheme.primaryLight;
    return GestureDetector(
      onTap: () { setState(() => _selectedFilter = status); _applyFilters(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? chipColor : Colors.grey.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 3.5.w,
              color: isSelected ? Colors.white : Colors.grey.shade600),
          SizedBox(width: 1.w),
          Text(label,
              style: TextStyle(
                  fontSize: 10.sp,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
        ]),
      ),
    );
  }

  Widget _buildLeadList() {
    if (_filteredLeads.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.search_off_rounded, size: 14.w, color: Colors.grey.shade300),
          SizedBox(height: 2.h),
          Text('No leads found',
              style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 0.5.h),
          Text(
            _selectedFilter != null
                ? 'Try changing the filter'
                : 'Leads appear when tenants view or request bookings',
            style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLeads,
      color: AppTheme.primaryLight,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        itemCount: _filteredLeads.length,
        itemBuilder: (context, index) => _buildLeadCard(_filteredLeads[index]),
      ),
    );
  }

  Widget _buildLeadCard(Map<String, dynamic> lead) {
    final tenantName    = lead['tenantName']    ?? lead['userName']  ?? 'Unknown Tenant';
    final phone         = lead['tenantPhone']   ?? lead['phone']     ?? '';
    final email         = lead['tenantEmail']   ?? lead['email']     ?? '';
    final propertyTitle = lead['propertyTitle'] ?? 'Unknown Property';
    final note          = lead['ownerNote']     ?? '';
    final bookingStatus = lead['status']        ?? '';
    final currentStatus = LeadStatusExtension.fromString(lead['leadStatus'] ?? 'pending');
    final isViewOnly    = lead['leadType'] == 'view';

    String formattedDate = '';
    try {
      final dt = DateTime.parse(lead['createdAt']?.toString() ?? '').toLocal();
      formattedDate = '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {}

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        // ── Header ──
        Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
          decoration: BoxDecoration(
            color: currentStatus.color.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(left: BorderSide(color: currentStatus.color, width: 4)),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 5.w,
              backgroundColor: currentStatus.color.withOpacity(0.2),
              child: Text(
                  tenantName.isNotEmpty ? tenantName[0].toUpperCase() : '?',
                  style: TextStyle(
                      color: currentStatus.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp)),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tenantName,
                    style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800)),
                SizedBox(height: 0.3.h),
                Row(children: [
                  Icon(Icons.home_rounded, size: 3.5.w, color: Colors.grey.shade500),
                  SizedBox(width: 1.w),
                  Expanded(
                      child: Text(propertyTitle,
                          style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                ]),
              ]),
            ),

            // View-only badge
            if (isViewOnly) ...[
              SizedBox(width: 2.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF607D8B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF607D8B).withOpacity(0.4)),
                ),
                child: Text('VIEW ONLY',
                    style: TextStyle(
                        fontSize: 7.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF607D8B))),
              ),
            ],

            if (!isViewOnly && bookingStatus.isNotEmpty) ...[
              SizedBox(width: 2.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.4.h),
                decoration: BoxDecoration(
                  color: bookingStatus == 'active'
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: bookingStatus == 'active'
                        ? Colors.green.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Text(bookingStatus.toUpperCase(),
                    style: TextStyle(
                        fontSize: 7.sp,
                        fontWeight: FontWeight.w600,
                        color: bookingStatus == 'active'
                            ? Colors.green
                            : Colors.orange)),
              ),
            ],

            SizedBox(width: 2.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.6.h),
              decoration: BoxDecoration(
                  color: currentStatus.color,
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(currentStatus.icon, color: Colors.white, size: 3.w),
                SizedBox(width: 1.w),
                Text(currentStatus.label,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),

        // ── Body ──
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (phone.isNotEmpty) ...[
                Icon(Icons.phone_rounded, size: 3.5.w, color: Colors.grey.shade500),
                SizedBox(width: 1.w),
                Text(phone,
                    style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600)),
                SizedBox(width: 4.w),
              ],
              if (email.isNotEmpty) ...[
                Icon(Icons.email_rounded, size: 3.5.w, color: Colors.grey.shade500),
                SizedBox(width: 1.w),
                Expanded(
                    child: Text(email,
                        style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
              ],
              if (phone.isEmpty && email.isEmpty)
                Text('No contact info',
                    style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.grey.shade400,
                        fontStyle: FontStyle.italic)),
            ]),

            if (formattedDate.isNotEmpty) ...[
              SizedBox(height: 0.8.h),
              Row(children: [
                Icon(
                  isViewOnly
                      ? Icons.visibility_rounded
                      : Icons.calendar_today_rounded,
                  size: 3.5.w, color: Colors.grey.shade500),
                SizedBox(width: 1.w),
                Text(
                  isViewOnly
                      ? 'Viewed: $formattedDate'
                      : 'Requested: $formattedDate',
                  style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade500)),
              ]),
            ],

            // View-only info banner
            if (isViewOnly) ...[
              SizedBox(height: 1.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(2.5.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF607D8B).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF607D8B).withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded,
                      size: 4.w, color: const Color(0xFF607D8B)),
                  SizedBox(width: 2.w),
                  Expanded(
                      child: Text('Tenant viewed your property details',
                          style: TextStyle(
                              fontSize: 10.sp,
                              color: const Color(0xFF607D8B)))),
                ]),
              ),
            ],

            if (!isViewOnly && note.isNotEmpty) ...[
              SizedBox(height: 1.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(2.5.w),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.sticky_note_2_rounded,
                      size: 4.w, color: Colors.amber.shade700),
                  SizedBox(width: 2.w),
                  Expanded(
                      child: Text(note,
                          style: TextStyle(
                              fontSize: 10.sp, color: Colors.amber.shade900))),
                ]),
              ),
            ],

            SizedBox(height: 1.5.h),
            Divider(color: Colors.grey.shade100, height: 1),
            SizedBox(height: 1.h),

            // ── Action buttons ──
            Row(children: [
              if (!isViewOnly) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showStatusUpdateSheet(lead, currentStatus),
                    icon: Icon(Icons.edit_rounded, size: 4.w, color: currentStatus.color),
                    label: Text('Update Status',
                        style: TextStyle(fontSize: 10.sp, color: currentStatus.color)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: currentStatus.color),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.symmetric(vertical: 1.h),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: Icon(Icons.visibility_rounded,
                        size: 4.w, color: const Color(0xFF607D8B)),
                    label: Text('Viewed Property',
                        style: TextStyle(
                            fontSize: 10.sp,
                            color: const Color(0xFF607D8B))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF607D8B)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.symmetric(vertical: 1.h),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
              if (phone.isNotEmpty) ...[
                SizedBox(width: 2.w),
                InkWell(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Calling $phone...'))),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Icon(Icons.phone_rounded,
                        color: Colors.green.shade700, size: 5.w),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }

  // ============================================================
  // STATUS BOTTOM SHEET
  // ============================================================
  void _showStatusUpdateSheet(Map<String, dynamic> lead, LeadStatus current) {
    // Exclude 'viewed' from the update options (it's auto-set)
    final updatableStatuses = LeadStatus.values
        .where((s) => s != LeadStatus.viewed)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 4.h),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 10.w,
                  height: 0.5.h,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              SizedBox(height: 2.h),
              Text('Update Lead Status',
                  style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800)),
              SizedBox(height: 0.5.h),
              Text('Select the current stage for this lead',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade500)),
              SizedBox(height: 2.h),
              ...updatableStatuses.map((status) {
                final isSelected = current == status;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _updateLeadStatus(lead, status);
                  },
                  child: Container(
                    margin: EdgeInsets.only(bottom: 1.h),
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? status.color.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSelected ? status.color : Colors.grey.shade200,
                          width: isSelected ? 2 : 1),
                    ),
                    child: Row(children: [
                      Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                            color: status.color.withOpacity(0.15),
                            shape: BoxShape.circle),
                        child: Icon(status.icon, color: status.color, size: 4.w),
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                          child: Text(status.label,
                              style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? status.color
                                      : Colors.grey.shade700))),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded,
                            color: status.color, size: 5.w),
                    ]),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoader() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: AppTheme.primaryLight),
          SizedBox(height: 2.h),
          Text('Loading leads...',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500)),
        ]),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: EdgeInsets.all(8.w),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.error_outline_rounded, size: 14.w, color: Colors.red.shade300),
            SizedBox(height: 2.h),
            Text('Failed to load leads',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
            SizedBox(height: 1.h),
            Text(_errorMessage ?? 'Unknown error',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade500),
                textAlign: TextAlign.center),
            SizedBox(height: 3.h),
            ElevatedButton.icon(
              onPressed: _loadLeads,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryLight,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
        ),
      );
}