import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';

class ChatConversation extends StatefulWidget {
  final String userName;
  final String userId;
  final ChatService chatService;

  const ChatConversation({
    super.key,
    required this.userName,
    required this.userId,
    required this.chatService,
  });

  @override
  State<ChatConversation> createState() => _ChatConversationState();
}

class _ChatConversationState extends State<ChatConversation> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.chatService.sendSupportResponse(widget.userId, message);
      _messageController.clear();
      _scrollToBottom();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  void _copyMessage(String message) {
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _editMessage(ChatMessage message) async {
    final controller = TextEditingController(text: message.message);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Enter new message...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != message.message) {
      try {
        await widget.chatService.editSupportMessage(
          widget.userId,
          message.id,
          result,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update message: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    controller.dispose();
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: Text(
          'Are you sure you want to delete this message?\n\n"${message.message}"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await widget.chatService.deleteSupportMessage(
          widget.userId,
          message.id,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete message: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showMessageOptions(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1e1e1e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Message preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2a2a2a),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message.message.length > 100
                    ? '${message.message.substring(0, 100)}...'
                    : message.message,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            // Options
            ListTile(
              leading: const Icon(Icons.copy, color: Color(0xFFbe00ff)),
              title: const Text(
                'Copy Message',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _copyMessage(message.message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFFbe00ff)),
              title: const Text(
                'Edit Message',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _editMessage(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Message',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChatThread?>(
      stream: widget.chatService.subscribeToThread(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            color: const Color(0xFF121212),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading conversation:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Container(
            color: const Color(0xFF121212),
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFFbe00ff)),
            ),
          );
        }

        final thread = snapshot.data;
        if (thread == null) {
          return Container(
            color: const Color(0xFF121212),
            child: const Center(
              child: Text(
                'Thread not found',
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        // Auto-scroll when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        return Container(
          color: const Color(0xFF121212),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1e1e1e),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade800, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFbe00ff),
                      child: Text(
                        thread.userName.isNotEmpty
                            ? thread.userName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            thread.userName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'User ID: ${thread.userId}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Thread info
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${thread.messages.length} messages',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        Text(
                          'Created: ${_formatMessageTime(thread.createdAt)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Messages
              Expanded(
                child: thread.messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: thread.messages.length,
                        itemBuilder: (context, index) {
                          final message = thread.messages[index];
                          final isSupport = message.isFromSupport;
                          final isExpired = message.isExpired;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: isSupport
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: GestureDetector(
                                    onLongPress: () => isSupport
                                        ? _showMessageOptions(message)
                                        : _copyMessage(message.message),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isSupport
                                            ? const Color(0xFFbe00ff)
                                            : const Color(0xFF2a2a2a),
                                        borderRadius: BorderRadius.circular(8),
                                        border: isExpired
                                            ? Border.all(
                                                color: Colors.red.shade300,
                                              )
                                            : null,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Message content
                                          Text(
                                            message.message,
                                            style: TextStyle(
                                              color: isSupport
                                                  ? Colors.white
                                                  : Colors.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Message info
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isSupport
                                                    ? Icons.support_agent
                                                    : Icons.person,
                                                size: 12,
                                                color: isSupport
                                                    ? Colors.white70
                                                    : Colors.grey.shade400,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatMessageTime(
                                                  message.timestamp,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isSupport
                                                      ? Colors.white70
                                                      : Colors.grey.shade400,
                                                ),
                                              ),
                                              if (message.edited) ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.edit,
                                                  size: 10,
                                                  color: isSupport
                                                      ? Colors.white70
                                                      : Colors.grey.shade400,
                                                ),
                                                Text(
                                                  'edited',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: isSupport
                                                        ? Colors.white70
                                                        : Colors.grey.shade400,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                              if (isExpired) ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.schedule,
                                                  size: 10,
                                                  color: Colors.red.shade300,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              // Message input
              Container(
                //adding padding below input and send area
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1e1e1e),
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade800, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (KeyEvent event) {
                          if (event is KeyDownEvent) {
                            if (event.logicalKey == LogicalKeyboardKey.enter) {
                              if (HardwareKeyboard.instance.isShiftPressed) {
                                // Shift+Enter: Add new line (do nothing, let default behavior)
                                return;
                              } else {
                                // Enter: Send message
                                _sendMessage();
                              }
                            }
                          }
                        },
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type your response...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF2a2a2a),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: null, // Disable default submission
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton.small(
                      onPressed: _isLoading ? null : _sendMessage,
                      backgroundColor: const Color(0xFFbe00ff),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
