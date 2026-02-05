import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../core/app_export.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedTab = 0; // 0: All, 1: Unread, 2: Archived

  final List<Map<String, dynamic>> _conversations = [
    {
      "id": 1,
      "senderName": "John Smith",
      "lastMessage": "Is the apartment still available for viewing?",
      "timestamp": "2 min ago",
      "avatar": "https://cdn.pixabay.com/photo/2015/03/04/22/35/avatar-659652_640.png",
      "isUnread": true,
      "unreadCount": 2,
      "propertyTitle": "Modern 2BHK Apartment",
      "isOnline": true,
    },
    {
      "id": 2,
      "senderName": "Sarah Johnson",
      "lastMessage": "Thank you for the quick response!",
      "timestamp": "1 hour ago",
      "avatar": "https://cdn.pixabay.com/photo/2015/03/04/22/35/avatar-659652_640.png",
      "isUnread": false,
      "unreadCount": 0,
      "propertyTitle": "Luxury Villa with Pool",
      "isOnline": false,
    },
    {
      "id": 3,
      "senderName": "Michael Chen",
      "lastMessage": "What's the security deposit amount?",
      "timestamp": "3 hours ago",
      "avatar": "https://cdn.pixabay.com/photo/2015/03/04/22/35/avatar-659652_640.png",
      "isUnread": true,
      "unreadCount": 1,
      "propertyTitle": "Cozy Studio Downtown",
      "isOnline": true,
    },
    {
      "id": 4,
      "senderName": "Emma Wilson",
      "lastMessage": "I'd like to schedule a visit this weekend",
      "timestamp": "Yesterday",
      "avatar": "https://cdn.pixabay.com/photo/2015/03/04/22/35/avatar-659652_640.png",
      "isUnread": false,
      "unreadCount": 0,
      "propertyTitle": "Spacious 3BHK Penthouse",
      "isOnline": false,
    },
    {
      "id": 5,
      "senderName": "David Brown",
      "lastMessage": "Thanks for showing me around!",
      "timestamp": "2 days ago",
      "avatar": "https://cdn.pixabay.com/photo/2015/03/04/22/35/avatar-659652_640.png",
      "isUnread": false,
      "unreadCount": 0,
      "propertyTitle": "Modern 2BHK Apartment",
      "isOnline": false,
    },
  ];

  List<Map<String, dynamic>> get _filteredConversations {
    var filtered = _conversations;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((conv) {
        return conv['senderName'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
            conv['lastMessage'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
            conv['propertyTitle'].toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Filter by tab
    if (_selectedTab == 1) {
      filtered = filtered.where((conv) => conv['isUnread'] == true).toList();
    } else if (_selectedTab == 2) {
      filtered = []; // Archived messages (empty for now)
    }

    return filtered;
  }

  int get _unreadCount {
    return _conversations.where((conv) => conv['isUnread'] == true).length;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        title: Text(
          'Messages',
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showFilterOptions,
            icon: CustomIconWidget(
              iconName: 'filter_list',
              color: AppTheme.primaryLight,
              size: 6.w,
            ),
          ),
          IconButton(
            onPressed: _showMoreOptions,
            icon: CustomIconWidget(
              iconName: 'more_vert',
              color: AppTheme.primaryLight,
              size: 6.w,
            ),
          ),
          SizedBox(width: 2.w),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildTabBar(),
          Expanded(
            child: _filteredConversations.isEmpty
                ? _buildEmptyState()
                : _buildConversationsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewConversation,
        backgroundColor: AppTheme.accentLight,
        child: CustomIconWidget(
          iconName: 'edit',
          color: Colors.white,
          size: 6.w,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.all(4.w),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search messages...',
          prefixIcon: Icon(Icons.search, color: AppTheme.primaryLight),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Colors.grey),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
          )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      child: Row(
        children: [
          _buildTab('All', 0, _conversations.length),
          SizedBox(width: 2.w),
          _buildTab('Unread', 1, _unreadCount),
          SizedBox(width: 2.w),
          _buildTab('Archived', 2, 0),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, int count) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 1.5.h),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (count > 0) ...[
                SizedBox(width: 1.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected ? AppTheme.primaryLight : Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsList() {
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      itemCount: _filteredConversations.length,
      separatorBuilder: (context, index) => Divider(
        height: 0.1.h,
        indent: 20.w,
        endIndent: 4.w,
      ),
      itemBuilder: (context, index) {
        final conversation = _filteredConversations[index];
        return _buildConversationTile(conversation);
      },
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    return InkWell(
      onTap: () => _openChat(conversation),
      onLongPress: () => _showConversationOptions(conversation),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        color: conversation['isUnread'] ? Colors.blue[50] : Colors.transparent,
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 7.w,
                  backgroundImage: NetworkImage(conversation['avatar']),
                ),
                if (conversation['isOnline'])
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 3.w,
                      height: 3.w,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        conversation['senderName'],
                        style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                          fontWeight: conversation['isUnread']
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                      Text(
                        conversation['timestamp'],
                        style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    conversation['propertyTitle'],
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.primaryLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation['lastMessage'],
                          style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                            color: conversation['isUnread']
                                ? Colors.black87
                                : Colors.grey[600],
                            fontWeight: conversation['isUnread']
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation['unreadCount'] > 0)
                        Container(
                          margin: EdgeInsets.only(left: 2.w),
                          padding: EdgeInsets.symmetric(
                            horizontal: 2.w,
                            vertical: 0.5.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            conversation['unreadCount'].toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomIconWidget(
            iconName: 'chat_bubble_outline',
            color: Colors.grey[400]!,
            size: 20.w,
          ),
          SizedBox(height: 2.h),
          Text(
            _selectedTab == 2
                ? 'No archived messages'
                : _searchQuery.isNotEmpty
                ? 'No messages found'
                : 'No messages yet',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            _selectedTab == 2
                ? 'Archived conversations will appear here'
                : _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Start a conversation to get in touch',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _openChat(Map<String, dynamic> conversation) {
    // Mark as read
    setState(() {
      conversation['isUnread'] = false;
      conversation['unreadCount'] = 0;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversation['id'],
          recipientName: conversation['senderName'],
          recipientAvatar: conversation['avatar'],
          propertyTitle: conversation['propertyTitle'],
          isOnline: conversation['isOnline'],
        ),
      ),
    );
  }

  void _showConversationOptions(Map<String, dynamic> conversation) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.mark_chat_read),
              title: Text('Mark as read'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  conversation['isUnread'] = false;
                  conversation['unreadCount'] = 0;
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.archive),
              title: Text('Archive'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Conversation archived')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(conversation);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Conversation'),
        content: Text('Are you sure you want to delete this conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _conversations.remove(conversation);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Conversation deleted')),
              );
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Messages',
              style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2.h),
            ListTile(
              leading: Icon(Icons.people),
              title: Text('All Contacts'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.business),
              title: Text('Property Owners'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Tenants'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.mark_chat_read),
              title: Text('Mark all as read'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  for (var conv in _conversations) {
                    conv['isUnread'] = false;
                    conv['unreadCount'] = 0;
                  }
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Message settings'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _startNewConversation() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.all(4.w),
        height: 60.h,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Message',
              style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2.h),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: 2.h),
            Expanded(
              child: Center(
                child: Text(
                  'Contact list will appear here',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}