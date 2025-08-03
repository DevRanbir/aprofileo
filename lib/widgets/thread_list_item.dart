import 'package:flutter/material.dart';
import '../models/chat_models.dart';

class ThreadListItem extends StatelessWidget {
  final ChatThread thread;
  final bool isSelected;
  final VoidCallback onTap;

  const ThreadListItem({
    super.key,
    required this.thread,
    required this.isSelected,
    required this.onTap,
  });

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  Color _getStatusColor() {
    if (thread.hasUnreadUserMessages) {
      return const Color(0xFFbe00ff); // Purple for unread
    } else if (thread.lastMessage?.isFromSupport == true) {
      return Colors.green; // Green for responded
    } else {
      return Colors.orange; // Orange for awaiting response
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastMessage = thread.lastMessage;
    final unreadCount = thread.unreadUserMessageCount;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2a2a2a) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isSelected
                    ? const Color(0xFFbe00ff)
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Status indicator
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getStatusColor(),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // User name
                  Expanded(
                    child: Text(
                      thread.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  // Unread count badge
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFbe00ff),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              // Last message preview
              if (lastMessage != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Message sender indicator
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: lastMessage.isFromUser
                            ? Colors.grey.shade700
                            : const Color(0xFFbe00ff).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Icon(
                        lastMessage.isFromUser
                            ? Icons.person
                            : Icons.support_agent,
                        size: 10,
                        color: lastMessage.isFromUser
                            ? Colors.grey.shade400
                            : const Color(0xFFbe00ff),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Message preview
                    Expanded(
                      child: Text(
                        lastMessage.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Time and message count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        _formatTime(thread.lastUpdated),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${thread.messages.length}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
              // User ID for reference
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ID: ${thread.userId.length > 16 ? '${thread.userId.substring(0, 16)}...' : thread.userId}',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.grey.shade500,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
