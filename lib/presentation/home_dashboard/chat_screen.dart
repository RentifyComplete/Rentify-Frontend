import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../core/app_export.dart';

class ChatScreen extends StatefulWidget {
  final int conversationId;
  final String recipientName;
  final String recipientAvatar;
  final String propertyTitle;
  final bool isOnline;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.recipientName,
    required this.recipientAvatar,
    required this.propertyTitle,
    required this.isOnline,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  void _loadMessages() {
    // Mock messages - replace with actual backend call
    setState(() {
      _messages = [
        {
          "id": 1,
          "text": "Hi! I'm interested in viewing the property.",
          "isSentByMe": false,
          "timestamp": DateTime.now().subtract(Duration(hours: 2)),
          "isRead": true,
        },
        {
          "id": 2,
          "text": "Hello! Thank you for your interest. The property is available for viewing.",
          "isSentByMe": true,
          "timestamp": DateTime.now().subtract(Duration(hours: 2, minutes: 30)),
          "isRead": true,
        },
        {
          "id": 3,
          "text": "Great! What times are available this week?",
          "isSentByMe": false,
          "timestamp": DateTime.now().subtract(Duration(hours: 1)),
          "isRead": true,
        },
        {
          "id": 4,
          "text": "I have availability on Tuesday and Thursday between 2-5 PM. Which works better for you?",
          "isSentByMe": true,
          "timestamp": DateTime.now().subtract(Duration(hours: 1, minutes: 15)),
          "isRead": true,
        },
        {
          "id": 5,
          "text": "Thursday at 3 PM would be perfect!",
          "isSentByMe": false,
          "timestamp": DateTime.now().subtract(Duration(minutes: 30)),
          "isRead": true,
        },
        {
          "id": 6,
          "text": "Is the apartment still available for viewing?",
          "isSentByMe": false,
          "timestamp": DateTime.now().subtract(Duration(minutes: 2)),
          "isRead": false,
        },
      ];
    });

    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildPropertyHeader(),
          Expanded(
            child: _buildMessagesList(),
          ),
          if (_isTyping) _buildTypingIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 1,
      backgroundColor: Colors.white,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.arrow_back, color: Colors.black87),
      ),
      title: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 5.w,
                backgroundImage: NetworkImage(widget.recipientAvatar),
              ),
              if (widget.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 2.5.w,
                    height: 2.5.w,
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
                Text(
                  widget.recipientName,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: widget.isOnline ? Colors.green : Colors.grey,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _makeCall,
          icon: Icon(Icons.phone, color: AppTheme.primaryLight),
        ),
        IconButton(
          onPressed: _showChatOptions,
          icon: Icon(Icons.more_vert, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildPropertyHeader() {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Navigate to property details')),
        );
      },
      child: Container(
        padding: EdgeInsets.all(3.w),
        color: Colors.blue[50],
        child: Row(
          children: [
            Container(
              width: 12.w,
              height: 12.w,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.home,
                color: AppTheme.primaryLight,
                size: 6.w,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.propertyTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.sp,
                    ),
                  ),
                  Text(
                    'Tap to view property details',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(4.w),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final showTimestamp = index == 0 ||
            _messages[index - 1]['timestamp']
                .difference(message['timestamp'])
                .inMinutes
                .abs() > 30;

        return Column(
          children: [
            if (showTimestamp) _buildTimestampDivider(message['timestamp']),
            _buildMessageBubble(message),
          ],
        );
      },
    );
  }

  Widget _buildTimestampDivider(DateTime timestamp) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 3.w),
            child: Text(
              _formatTimestamp(timestamp),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10.sp,
              ),
            ),
          ),
          Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isSentByMe = message['isSentByMe'];

    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: Row(
        mainAxisAlignment:
        isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSentByMe) ...[
            CircleAvatar(
              radius: 4.w,
              backgroundImage: NetworkImage(widget.recipientAvatar),
            ),
            SizedBox(width: 2.w),
          ],
          Container(
            constraints: BoxConstraints(maxWidth: 70.w),
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            decoration: BoxDecoration(
              color: isSentByMe ? AppTheme.primaryLight : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(isSentByMe ? 16 : 4),
                bottomRight: Radius.circular(isSentByMe ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message['text'],
                  style: TextStyle(
                    color: isSentByMe ? Colors.white : Colors.black87,
                    fontSize: 11.sp,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatMessageTime(message['timestamp']),
                      style: TextStyle(
                        color: isSentByMe
                            ? Colors.white.withOpacity(0.7)
                            : Colors.grey[600],
                        fontSize: 9.sp,
                      ),
                    ),
                    if (isSentByMe) ...[
                      SizedBox(width: 1.w),
                      Icon(
                        message['isRead'] ? Icons.done_all : Icons.done,
                        size: 3.w,
                        color: message['isRead']
                            ? Colors.blue[200]
                            : Colors.white.withOpacity(0.7),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isSentByMe) SizedBox(width: 2.w),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: EdgeInsets.all(4.w),
      child: Row(
        children: [
          CircleAvatar(
            radius: 4.w,
            backgroundImage: NetworkImage(widget.recipientAvatar),
          ),
          SizedBox(width: 2.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildDot(0),
                SizedBox(width: 1.w),
                _buildDot(1),
                SizedBox(width: 1.w),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Container(
          width: 2.w,
          height: 2.w,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(3.w),
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
        child: Row(
          children: [
            IconButton(
              onPressed: _attachFile,
              icon: Icon(Icons.attach_file, color: AppTheme.primaryLight),
            ),
            IconButton(
              onPressed: _openCamera,
              icon: Icon(Icons.camera_alt, color: AppTheme.primaryLight),
            ),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (text) {
                    // Simulate typing indicator
                    if (text.isNotEmpty && !_isTyping) {
                      setState(() => _isTyping = true);
                      Future.delayed(Duration(seconds: 3), () {
                        if (mounted) setState(() => _isTyping = false);
                      });
                    }
                  },
                ),
              ),
            ),
            SizedBox(width: 2.w),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 5.w,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.add({
        "id": _messages.length + 1,
        "text": _messageController.text.trim(),
        "isSentByMe": true,
        "timestamp": DateTime.now(),
        "isRead": false,
      });
      _messageController.clear();
    });

    // Scroll to bottom
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Simulate response
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _messages.add({
            "id": _messages.length + 1,
            "text": "Thank you for your message! I'll get back to you shortly.",
            "isSentByMe": false,
            "timestamp": DateTime.now(),
            "isRead": true,
          });
        });

        Future.delayed(Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  void _attachFile() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: AppTheme.primaryLight),
              title: Text('Photo Library'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Photo library feature coming soon!')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.insert_drive_file, color: AppTheme.primaryLight),
              title: Text('Document'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Document upload coming soon!')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.location_on, color: AppTheme.primaryLight),
              title: Text('Location'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Location sharing coming soon!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openCamera() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Camera feature coming soon!')),
    );
  }

  void _makeCall() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Call ${widget.recipientName}'),
        content: Text('Would you like to make a voice or video call?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Starting voice call...')),
              );
            },
            child: Text('Voice Call'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Starting video call...')),
              );
            },
            child: Text('Video Call'),
          ),
        ],
      ),
    );
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.search),
              title: Text('Search in conversation'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Search feature coming soon!')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.volume_off),
              title: Text('Mute notifications'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Notifications muted')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.wallpaper),
              title: Text('Change wallpaper'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Wallpaper feature coming soon!')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.block, color: Colors.red),
              title: Text('Block user', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmation();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Block ${widget.recipientName}?'),
        content: Text('You won\'t be able to receive messages from this user.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('User blocked')),
              );
            },
            child: Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  String _formatMessageTime(DateTime timestamp) {
    final hour = timestamp.hour > 12 ? timestamp.hour - 12 : timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}