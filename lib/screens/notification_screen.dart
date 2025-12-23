import 'package:flutter/material.dart';
import '../widgets/translated_text.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadSampleNotifications();
  }

  void _loadSampleNotifications() {
    // Sample static notifications
    setState(() {
      _notifications.addAll([
        NotificationItem(
          id: 1,
          title: 'Course Enrollment Successful! 🎉',
          message: 'You have successfully enrolled in "Cybersecurity Essentials". Start learning now!',
          type: NotificationType.success,
          time: DateTime.now().subtract(const Duration(minutes: 5)),
          isRead: false,
          icon: Icons.check_circle,
        ),
        NotificationItem(
          id: 2,
          title: 'New Course Available',
          message: 'Check out the latest course "Advanced Ethical Hacking" now available in your category.',
          type: NotificationType.info,
          time: DateTime.now().subtract(const Duration(hours: 2)),
          isRead: false,
          icon: Icons.school,
        ),
        NotificationItem(
          id: 3,
          title: 'Course Reminder ⏰',
          message: 'You have 3 pending modules in "Web Application Security". Continue your progress!',
          type: NotificationType.reminder,
          time: DateTime.now().subtract(const Duration(hours: 6)),
          isRead: true,
          icon: Icons.access_time,
        ),
        NotificationItem(
          id: 4,
          title: 'Payment Successful 💳',
          message: 'Your payment of ₹299.00 for "Network Security Fundamentals" has been processed successfully.',
          type: NotificationType.payment,
          time: DateTime.now().subtract(const Duration(days: 1)),
          isRead: true,
          icon: Icons.payment,
        ),
        NotificationItem(
          id: 5,
          title: 'Certificate Ready! 🏆',
          message: 'Congratulations! Your certificate for "Introduction to Cybersecurity" is ready for download.',
          type: NotificationType.achievement,
          time: DateTime.now().subtract(const Duration(days: 2)),
          isRead: false,
          icon: Icons.workspace_premium,
        ),
        NotificationItem(
          id: 6,
          title: 'Course Update',
          message: 'New content has been added to "Penetration Testing Basics". Check out the latest modules!',
          type: NotificationType.update,
          time: DateTime.now().subtract(const Duration(days: 3)),
          isRead: true,
          icon: Icons.update,
        ),
        NotificationItem(
          id: 7,
          title: 'Special Offer! 🎁',
          message: 'Get 50% off on all premium courses. Limited time offer ending in 2 days!',
          type: NotificationType.promotion,
          time: DateTime.now().subtract(const Duration(days: 4)),
          isRead: true,
          icon: Icons.local_offer,
        ),
        NotificationItem(
          id: 8,
          title: 'Welcome to ThinkCyber! 👋',
          message: 'Welcome to our learning platform. Explore courses and start your cybersecurity journey today.',
          type: NotificationType.welcome,
          time: DateTime.now().subtract(const Duration(days: 7)),
          isRead: true,
          icon: Icons.waving_hand,
        ),
      ]);
    });
  }

  void _markAsRead(int notificationId) {
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index >= 0) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
      }
    });
  }

  void _markAllAsRead() {
    setState(() {
      for (int i = 0; i < _notifications.length; i++) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: TranslatedText('All notifications marked as read'),
        backgroundColor: Color(0xFF22C55E),
      ),
    );
  }

  void _deleteNotification(int notificationId) {
    setState(() {
      _notifications.removeWhere((n) => n.id == notificationId);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: TranslatedText('Notification deleted'),
        backgroundColor: Color(0xFFFF4757),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3142)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const TranslatedText(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF2D3142),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const TranslatedText(
                'Mark all read',
                style: TextStyle(
                  color: Color(0xFF2E7DFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? const _EmptyNotificationWidget()
          : Column(
              children: [
                if (unreadCount > 0)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7DFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2E7DFF),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        TranslatedText(
                          '$unreadCount new notification${unreadCount > 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Color(0xFF2E7DFF),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return _NotificationCard(
                        notification: notification,
                        onTap: () => _markAsRead(notification.id),
                        onDelete: () => _deleteNotification(notification.id),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  final NotificationItem notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _getNotificationColor(notification.type);
    final timeAgo = _getTimeAgo(notification.time);

    return Dismissible(
      key: Key(notification.id.toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFF4757),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 24,
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead 
                  ? const Color(0xFFE5E7EB) 
                  : color.withOpacity(0.3),
              width: notification.isRead ? 1 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: notification.isRead 
                    ? const Color(0x0A000000) 
                    : color.withOpacity(0.1),
                blurRadius: notification.isRead ? 8 : 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  notification.icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TranslatedText(
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w600,
                              color: const Color(0xFF2D3142),
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    TranslatedText(
                      notification.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF6B7280),
                        height: 1.4,
                        fontWeight: notification.isRead ? FontWeight.w400 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    TranslatedText(
                      timeAgo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return const Color(0xFF22C55E);
      case NotificationType.info:
        return const Color(0xFF2E7DFF);
      case NotificationType.reminder:
        return const Color(0xFFFF9500);
      case NotificationType.payment:
        return const Color(0xFF8B5CF6);
      case NotificationType.achievement:
        return const Color(0xFFFFD700);
      case NotificationType.update:
        return const Color(0xFF06B6D4);
      case NotificationType.promotion:
        return const Color(0xFFFF4757);
      case NotificationType.welcome:
        return const Color(0xFF2E7DFF);
    }
  }

  String _getTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }
}

class _EmptyNotificationWidget extends StatelessWidget {
  const _EmptyNotificationWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7DFF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_outlined,
                size: 64,
                color: Color(0xFF2E7DFF),
              ),
            ),
            const SizedBox(height: 24),
            
            const TranslatedText(
              'No Notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3142),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            TranslatedText(
              'You\'re all caught up! When you have new notifications, they\'ll appear here.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

enum NotificationType {
  success,
  info,
  reminder,
  payment,
  achievement,
  update,
  promotion,
  welcome,
}

class NotificationItem {
  final int id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime time;
  final bool isRead;
  final IconData icon;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.time,
    required this.isRead,
    required this.icon,
  });

  NotificationItem copyWith({
    int? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? time,
    bool? isRead,
    IconData? icon,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      time: time ?? this.time,
      isRead: isRead ?? this.isRead,
      icon: icon ?? this.icon,
    );
  }
}